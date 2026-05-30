import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

import '../models/bill.dart';
import '../config/supabase_config.dart';

const billBaseSelect =
    'id, customer_id, amount, paid_amount, month, status, collected_by, '
    'paid_at, receipt_no, payment_method, payment_note, payment_source, created_at, '
    'customer:customers(id, customer_code, full_name, address_type, address_value, area_id)';

const billAreaSelect =
    'id, customer_id, amount, paid_amount, month, status, collected_by, '
    'paid_at, receipt_no, payment_method, payment_note, payment_source, created_at, '
    'customer:customers!inner(id, customer_code, full_name, address_type, address_value, area_id)';

const _queuedPaymentsKey = 'queued_bill_payments';
const _queuedVisitsKey = 'queued_bill_visits';
const _cachedPendingPrefix = 'cached_pending_bills_';
const _cachedCollectedPrefix = 'cached_collected_bills_';
const _cachedVisitedPrefix = 'cached_visited_bills_';

class QueuedBillPayment {
  final String id;
  final String billId;
  final double amount;
  final String collectorId;
  final String paymentMethod;
  final String? paymentNote;
  final String queuedAt;

  const QueuedBillPayment({
    required this.id,
    required this.billId,
    required this.amount,
    required this.collectorId,
    required this.paymentMethod,
    this.paymentNote,
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
        queuedAt: json['queued_at'] as String,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'bill_id': billId,
    'amount': amount,
    'collector_id': collectorId,
    'payment_method': paymentMethod,
    'payment_note': paymentNote,
    'queued_at': queuedAt,
  };
}

class QueuedBillVisit {
  final String id;
  final String billId;
  final String collectorId;
  final String visitType;
  final String queuedAt;

  const QueuedBillVisit({
    required this.id,
    required this.billId,
    required this.collectorId,
    required this.visitType,
    required this.queuedAt,
  });

  factory QueuedBillVisit.fromJson(Map<String, dynamic> json) =>
      QueuedBillVisit(
        id: json['id'] as String,
        billId: json['bill_id'] as String,
        collectorId: json['collector_id'] as String,
        visitType: json['visit_type'] as String,
        queuedAt: json['queued_at'] as String,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'bill_id': billId,
    'collector_id': collectorId,
    'visit_type': visitType,
    'queued_at': queuedAt,
  };
}

class BillsRepository {
  Future<List<Bill>> fetchPendingByAreas(List<String> areaIds) async {
    if (areaIds.isEmpty) return [];
    final res = await supabase
        .from('bills')
        .select(billAreaSelect)
        .inFilter('customer.area_id', areaIds)
        .inFilter('status', ['pending', 'overdue'])
        .order('created_at', ascending: false);
    return (res as List)
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
        .from('bills')
        .select(billBaseSelect)
        .eq('collected_by', collectorId)
        .eq('status', 'paid')
        .gte('paid_at', '${dateStr}T00:00:00Z')
        .lte('paid_at', '${dateStr}T23:59:59Z')
        .order('paid_at', ascending: false);
    return (res as List)
        .map((j) => Bill.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<List<Bill>> fetchPaidTodayByAreas(List<String> areaIds) async {
    if (areaIds.isEmpty) return [];
    final today = DateTime.now().toUtc();
    final dateStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final res = await supabase
        .from('bills')
        .select(billAreaSelect)
        .inFilter('customer.area_id', areaIds)
        .eq('status', 'paid')
        .gte('paid_at', '${dateStr}T00:00:00Z')
        .lte('paid_at', '${dateStr}T23:59:59Z')
        .order('paid_at', ascending: false);
    return (res as List)
        .map((j) => Bill.fromJson(j as Map<String, dynamic>))
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
  }) async {
    await supabase
        .from('bills')
        .update({
          'payment_method': 'visit',
          'payment_note': visitType,
          'collected_by': collectorId,
          'paid_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', billId);
  }

  Future<void> recordPayment({
    required String billId,
    required double paidAmount,
    required String collectorId,
    required String paymentMethod,
    String? paymentNote,
  }) async {
    await supabase.rpc(
      'record_bill_payment',
      params: {
        'p_bill_id': billId,
        'p_amount': paidAmount.round(),
        'p_collected_by': collectorId,
        'p_method': paymentMethod,
        'p_source': 'agent',
        'p_note': paymentNote,
      },
    );
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
  }) async {
    final queued = await getQueuedPayments();
    final draft = QueuedBillPayment(
      id: '${DateTime.now().microsecondsSinceEpoch}-$billId',
      billId: billId,
      amount: paidAmount,
      collectorId: collectorId,
      paymentMethod: paymentMethod,
      paymentNote: paymentNote,
      queuedAt: DateTime.now().toUtc().toIso8601String(),
    );
    await _saveQueuedPayments([...queued, draft]);
  }

  Future<void> queueVisit({
    required String billId,
    required String collectorId,
    required String visitType,
  }) async {
    final queued = await getQueuedVisits();
    final draft = QueuedBillVisit(
      id: '${DateTime.now().microsecondsSinceEpoch}-$billId',
      billId: billId,
      collectorId: collectorId,
      visitType: visitType,
      queuedAt: DateTime.now().toUtc().toIso8601String(),
    );
    await _saveQueuedVisits([...queued, draft]);
  }

  Future<int> syncQueuedPayments() async {
    final queued = await getQueuedPayments();
    if (queued.isEmpty) return 0;

    final remaining = <QueuedBillPayment>[];
    var synced = 0;
    for (final payment in queued) {
      try {
        await recordPayment(
          billId: payment.billId,
          paidAmount: payment.amount,
          collectorId: payment.collectorId,
          paymentMethod: payment.paymentMethod,
          paymentNote: payment.paymentNote,
        );
        synced++;
      } catch (e) {
        debugPrint(
          'POWERNET_DEBUG: syncQueuedPayments failed for bill ${payment.billId}: $e',
        );
        remaining.add(payment);
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
    for (final visit in queued) {
      try {
        await recordVisit(
          billId: visit.billId,
          collectorId: visit.collectorId,
          visitType: visit.visitType,
        );
        synced++;
      } catch (e) {
        debugPrint(
          'POWERNET_DEBUG: syncQueuedVisits failed for bill '
          '${visit.billId}: $e',
        );
        remaining.add(visit);
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

  String _cacheKey(String prefix, String value) => '$prefix$value';
}
