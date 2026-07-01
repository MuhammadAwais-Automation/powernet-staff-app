import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/bill.dart';
import '../config/supabase_config.dart';

const billBaseSelect =
    'id, customer_id, amount, paid_amount, month, status, collected_by, '
    'paid_at, receipt_no, payment_method, payment_note, payment_source, promised_date, created_at, '
    'customer:customers(id, customer_code, full_name, address_type, address_value, area_id)';

const billAreaSelect =
    'id, customer_id, amount, paid_amount, month, status, collected_by, '
    'paid_at, receipt_no, payment_method, payment_note, payment_source, promised_date, created_at, '
    'customer:customers!inner(id, customer_code, full_name, address_type, address_value, area_id)';

const _queuedPaymentsKey = 'queued_bill_payments';
const _queuedVisitsKey = 'queued_bill_visits';
const _cachedPendingPrefix = 'cached_pending_bills_';
const _cachedCollectedPrefix = 'cached_collected_bills_';
const _cachedVisitedPrefix = 'cached_visited_bills_';

class BillAlreadyPaidException implements Exception {
  const BillAlreadyPaidException();

  @override
  String toString() => 'Bill already paid. Collection list refreshed.';
}

class BillPaymentConflictException implements Exception {
  const BillPaymentConflictException();

  @override
  String toString() => 'Bill balance changed. Collection list refreshed.';
}

enum RemainderAction {
  leave,
  carryForward;

  String get value => switch (this) {
    RemainderAction.leave => 'leave',
    RemainderAction.carryForward => 'carry_forward',
  };

  static RemainderAction fromValue(String? value) {
    return value == 'carry_forward'
        ? RemainderAction.carryForward
        : RemainderAction.leave;
  }
}

class QueuedBillPayment {
  final String id;
  final String billId;
  final double amount;
  final String collectorId;
  final String paymentMethod;
  final String? paymentNote;
  final String? receiptUrl;
  final String remainderAction;
  final String queuedAt;

  const QueuedBillPayment({
    required this.id,
    required this.billId,
    required this.amount,
    required this.collectorId,
    required this.paymentMethod,
    this.paymentNote,
    this.receiptUrl,
    this.remainderAction = 'leave',
    required this.queuedAt,
  });

  factory QueuedBillPayment.fromJson(Map<String, dynamic> json) =>
      QueuedBillPayment(
        id: json['id'] as String,
        billId: json['bill_id'] as String,
        amount: (json['amount'] as num).toDouble(),
        collectorId: json['collector_id'] as String,
        paymentMethod: json['payment_method'] as String,
        paymentNote: json['payment_note'] as String?,
        receiptUrl: json['receipt_url'] as String?,
        remainderAction: json['remainder_action'] as String? ?? 'leave',
        queuedAt: json['queued_at'] as String,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'bill_id': billId,
    'amount': amount,
    'collector_id': collectorId,
    'payment_method': paymentMethod,
    'payment_note': paymentNote,
    'receipt_url': receiptUrl,
    'remainder_action': remainderAction,
    'queued_at': queuedAt,
  };
}

class QueuedBillVisit {
  final String id;
  final String billId;
  final String collectorId;
  final String visitType;
  final String? promisedDate;
  final String queuedAt;

  const QueuedBillVisit({
    required this.id,
    required this.billId,
    required this.collectorId,
    required this.visitType,
    this.promisedDate,
    required this.queuedAt,
  });

  factory QueuedBillVisit.fromJson(Map<String, dynamic> json) =>
      QueuedBillVisit(
        id: json['id'] as String,
        billId: json['bill_id'] as String,
        collectorId: json['collector_id'] as String,
        visitType: json['visit_type'] as String,
        promisedDate: json['promised_date'] as String?,
        queuedAt: json['queued_at'] as String,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'bill_id': billId,
    'collector_id': collectorId,
    'visit_type': visitType,
    'promised_date': promisedDate,
    'queued_at': queuedAt,
  };
}

class BillsRepository {
  Future<List<Bill>> fetchPendingByAreas(List<String> areaIds) async {
    if (areaIds.isEmpty) return [];
    final openRes = await supabase
        .from('bills')
        .select(billAreaSelect)
        .inFilter('customer.area_id', areaIds)
        .inFilter('status', ['pending', 'overdue'])
        .order('created_at', ascending: false);
    final openBills = (openRes as List)
        .map((j) => Bill.fromJson(j as Map<String, dynamic>))
        .toList();
    if (openBills.isEmpty) return [];

    final customerIds = openBills
        .map((bill) => bill.customerId)
        .toSet()
        .toList();
    final ledgerRes = await supabase
        .from('bills')
        .select(billBaseSelect)
        .inFilter('customer_id', customerIds)
        .order('month', ascending: false);
    return (ledgerRes as List)
        .map((j) => Bill.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<List<Bill>> fetchByCustomer(String customerId) async {
    final res = await supabase
        .from('bills')
        .select(billBaseSelect)
        .eq('customer_id', customerId)
        .order('month', ascending: false);
    return (res as List)
        .map((j) => Bill.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<List<Bill>> fetchCollectedToday(String collectorId) async {
    final today = DateTime.now().toUtc();
    final dateStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final res = await supabase
        .from('payments')
        .select(
          'id, bill_id, customer_id, amount, collected_by, method, source, '
          'note, receipt_no, paid_at, created_at, '
          'bill:bills(month, amount, paid_amount, status), '
          'customer:customers(id, customer_code, full_name, address_type, address_value, area_id)',
        )
        .eq('collected_by', collectorId)
        .gte('paid_at', '${dateStr}T00:00:00Z')
        .lte('paid_at', '${dateStr}T23:59:59Z')
        .order('paid_at', ascending: false);
    return (res as List)
        .map((j) => _billFromPayment(j as Map<String, dynamic>))
        .toList();
  }

  Future<List<Bill>> fetchPaidTodayByAreas(List<String> areaIds) async {
    if (areaIds.isEmpty) return [];
    final today = DateTime.now().toUtc();
    final dateStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final res = await supabase
        .from('payments')
        .select(
          'id, bill_id, customer_id, amount, collected_by, method, source, '
          'note, receipt_no, paid_at, created_at, '
          'bill:bills(month, amount, paid_amount, status), '
          'customer:customers!inner(id, customer_code, full_name, address_type, address_value, area_id)',
        )
        .inFilter('customer.area_id', areaIds)
        .gte('paid_at', '${dateStr}T00:00:00Z')
        .lte('paid_at', '${dateStr}T23:59:59Z')
        .order('paid_at', ascending: false);
    return (res as List)
        .map((j) => _billFromPayment(j as Map<String, dynamic>))
        .toList();
  }

  Future<List<Bill>> fetchVisitedToday(String collectorId) async {
    final today = DateTime.now().toUtc();
    final dateStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final res = await supabase
        .from('bills')
        .select(billBaseSelect)
        .eq('collected_by', collectorId)
        .eq('payment_method', 'visit')
        .gte('paid_at', '${dateStr}T00:00:00Z')
        .lte('paid_at', '${dateStr}T23:59:59Z')
        .order('paid_at', ascending: false);
    return (res as List)
        .map((j) => Bill.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<Bill?> fetchById(String id) async {
    final res = await supabase
        .from('bills')
        .select(billBaseSelect)
        .eq('id', id)
        .maybeSingle();
    if (res == null) return null;
    return Bill.fromJson(res);
  }

  Future<void> cacheRecoverySnapshot({
    required List<String> areaIds,
    required String collectorId,
    required List<Bill> pending,
    required List<Bill> collectedToday,
    required List<Bill> visitedToday,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final areasKey = areaIds.join('-');
    await Future.wait([
      prefs.setString(
        _cacheKey(_cachedPendingPrefix, areasKey),
        _encodeBills(pending),
      ),
      prefs.setString(
        _cacheKey(_cachedCollectedPrefix, collectorId),
        _encodeBills(collectedToday),
      ),
      prefs.setString(
        _cacheKey(_cachedVisitedPrefix, collectorId),
        _encodeBills(visitedToday),
      ),
    ]);
  }

  Future<List<Bill>> getCachedPendingByAreas(List<String> areaIds) async {
    return _readCachedBills(_cacheKey(_cachedPendingPrefix, areaIds.join('-')));
  }

  Future<List<Bill>> getCachedCollectedToday(String collectorId) async {
    return _readCachedBills(_cacheKey(_cachedCollectedPrefix, collectorId));
  }

  Future<List<Bill>> getCachedVisitedToday(String collectorId) async {
    return _readCachedBills(_cacheKey(_cachedVisitedPrefix, collectorId));
  }

  Future<void> recordVisit({
    required String billId,
    required String collectorId,
    required String visitType,
    String? promisedDate,
  }) async {
    await supabase
        .from('bills')
        .update({
          'payment_method': 'visit',
          'payment_note': visitType,
          'collected_by': collectorId,
          'paid_at': DateTime.now().toUtc().toIso8601String(),
          'promised_date': visitType == VisitType.promiseToPay.value
              ? promisedDate
              : null,
        })
        .eq('id', billId);
  }

  Future<void> recordPayment({
    required String billId,
    required double paidAmount,
    required String collectorId,
    required String paymentMethod,
    String? paymentNote,
    String? receiptUrl,
    RemainderAction remainderAction = RemainderAction.leave,
  }) async {
    final params = {
      'p_bill_id': billId,
      'p_amount': paidAmount.round(),
      'p_collected_by': collectorId,
      'p_method': paymentMethod,
      'p_source': 'agent',
      'p_note': paymentNote,
      'p_receipt_url': receiptUrl,
      'p_remainder_action': remainderAction.value,
    };
    try {
      await supabase.rpc('record_bill_payment', params: params);
    } on PostgrestException catch (e) {
      final message = e.message.toLowerCase();
      if (message.contains('already fully paid')) {
        throw const BillAlreadyPaidException();
      }
      if (message.contains('exceeds remaining balance')) {
        throw const BillPaymentConflictException();
      }
      if (message.contains('could not find the function') ||
          message.contains('record_bill_payment') &&
              message.contains('schema cache')) {
        await supabase.rpc(
          'record_bill_payment',
          params: {
            'p_bill_id': billId,
            'p_amount': paidAmount.round(),
            'p_collected_by': collectorId,
            'p_method': paymentMethod,
            'p_note': paymentNote,
            'p_receipt_url': receiptUrl,
            'p_remainder_action': remainderAction.value,
          },
        );
        return;
      }
      rethrow;
    }
  }

  Future<List<QueuedBillPayment>> getQueuedPayments() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_queuedPaymentsKey);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((j) => QueuedBillPayment.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<List<QueuedBillVisit>> getQueuedVisits() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_queuedVisitsKey);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((j) => QueuedBillVisit.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<void> queuePayment({
    required String billId,
    required double paidAmount,
    required String collectorId,
    required String paymentMethod,
    String? paymentNote,
    String? receiptUrl,
    RemainderAction remainderAction = RemainderAction.leave,
  }) async {
    final queued = await getQueuedPayments();
    final draft = QueuedBillPayment(
      id: '${DateTime.now().microsecondsSinceEpoch}-$billId',
      billId: billId,
      amount: paidAmount,
      collectorId: collectorId,
      paymentMethod: paymentMethod,
      paymentNote: paymentNote,
      receiptUrl: receiptUrl,
      remainderAction: remainderAction.value,
      queuedAt: DateTime.now().toUtc().toIso8601String(),
    );
    await _saveQueuedPayments([...queued, draft]);
  }

  Future<void> queueVisit({
    required String billId,
    required String collectorId,
    required String visitType,
    String? promisedDate,
  }) async {
    final queued = await getQueuedVisits();
    final draft = QueuedBillVisit(
      id: '${DateTime.now().microsecondsSinceEpoch}-$billId',
      billId: billId,
      collectorId: collectorId,
      visitType: visitType,
      promisedDate: visitType == VisitType.promiseToPay.value
          ? promisedDate
          : null,
      queuedAt: DateTime.now().toUtc().toIso8601String(),
    );
    await _saveQueuedVisits([...queued, draft]);
  }

  bool _isNetworkError(Object error) {
    if (error is PostgrestException || error is AuthException) {
      return false;
    }
    final text = error.toString().toLowerCase();
    return text.contains('socketexception') ||
        text.contains('failed host lookup') ||
        text.contains('clientexception') ||
        text.contains('no address associated') ||
        text.contains('network is unreachable') ||
        text.contains('offline') ||
        text.contains('timeout');
  }

  Future<int> syncQueuedPayments() async {
    final queued = await getQueuedPayments();
    if (queued.isEmpty) return 0;

    final remaining = <QueuedBillPayment>[];
    var synced = 0;
    bool connectionFailed = false;

    for (final payment in queued) {
      if (connectionFailed) {
        remaining.add(payment);
        continue;
      }
      try {
        await recordPayment(
          billId: payment.billId,
          paidAmount: payment.amount,
          collectorId: payment.collectorId,
          paymentMethod: payment.paymentMethod,
          paymentNote: payment.paymentNote,
          receiptUrl: payment.receiptUrl,
          remainderAction: RemainderAction.fromValue(payment.remainderAction),
        ).timeout(const Duration(seconds: 4));
        synced++;
      } catch (e) {
        debugPrint(
          'POWERNET_DEBUG: syncQueuedPayments failed for bill ${payment.billId}: $e',
        );
        if (_isNetworkError(e)) {
          remaining.add(payment);
          connectionFailed = true;
        } else {
          debugPrint(
            'POWERNET_DEBUG: Discarding queued payment for bill ${payment.billId} due to permanent error: $e',
          );
        }
      }
    }
    await _saveQueuedPayments(remaining);
    return synced;
  }

  Future<int> syncQueuedVisits() async {
    final queued = await getQueuedVisits();
    if (queued.isEmpty) return 0;

    final remaining = <QueuedBillVisit>[];
    var synced = 0;
    bool connectionFailed = false;

    for (final visit in queued) {
      if (connectionFailed) {
        remaining.add(visit);
        continue;
      }
      try {
        await recordVisit(
          billId: visit.billId,
          collectorId: visit.collectorId,
          visitType: visit.visitType,
          promisedDate: visit.promisedDate,
        ).timeout(const Duration(seconds: 4));
        synced++;
      } catch (e) {
        debugPrint(
          'POWERNET_DEBUG: syncQueuedVisits failed for bill '
          '${visit.billId}: $e',
        );
        if (_isNetworkError(e)) {
          remaining.add(visit);
          connectionFailed = true;
        } else {
          debugPrint(
            'POWERNET_DEBUG: Discarding queued visit for bill ${visit.billId} due to permanent error: $e',
          );
        }
      }
    }
    await _saveQueuedVisits(remaining);
    return synced;
  }

  Future<int> syncQueuedOperations() async {
    final syncedPayments = await syncQueuedPayments();
    final syncedVisits = await syncQueuedVisits();
    return syncedPayments + syncedVisits;
  }

  Future<int> countQueuedOperations() async {
    final payments = await getQueuedPayments();
    final visits = await getQueuedVisits();
    return payments.length + visits.length;
  }

  Future<void> _saveQueuedPayments(List<QueuedBillPayment> payments) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(payments.map((p) => p.toJson()).toList());
    await prefs.setString(_queuedPaymentsKey, encoded);
  }

  Future<void> _saveQueuedVisits(List<QueuedBillVisit> visits) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(visits.map((v) => v.toJson()).toList());
    await prefs.setString(_queuedVisitsKey, encoded);
  }

  Future<List<Bill>> _readCachedBills(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((j) => Bill.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  String _encodeBills(List<Bill> bills) {
    return jsonEncode(bills.map((bill) => bill.toJson()).toList());
  }

  Bill _billFromPayment(Map<String, dynamic> payment) {
    final bill = payment['bill'] as Map<String, dynamic>? ?? {};
    return Bill.fromJson({
      'id': payment['bill_id'] ?? payment['id'],
      'customer_id': payment['customer_id'],
      'amount': payment['amount'],
      'paid_amount': payment['amount'],
      'month': bill['month'] ?? '',
      'status': 'paid',
      'collected_by': payment['collected_by'],
      'paid_at': payment['paid_at'],
      'receipt_no': payment['receipt_no'],
      'payment_method': payment['method'],
      'payment_note': payment['note'],
      'payment_source': payment['source'],
      'created_at': payment['created_at'],
      'customer': payment['customer'],
    });
  }

  String _cacheKey(String prefix, String value) => '$prefix$value';
}
