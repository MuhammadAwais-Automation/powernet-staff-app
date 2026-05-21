import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/bill.dart';
import '../config/supabase_config.dart';

const billBaseSelect =
    'id, customer_id, amount, paid_amount, month, status, collected_by, '
    'paid_at, receipt_no, payment_method, payment_note, created_at, '
    'customer:customers(id, customer_code, full_name, address_type, address_value, connection_no)';

const billAreaSelect =
    'id, customer_id, amount, paid_amount, month, status, collected_by, '
    'paid_at, receipt_no, payment_method, payment_note, created_at, '
    'customer:customers!inner(id, customer_code, full_name, address_type, address_value, connection_no, area_id)';

const _queuedPaymentsKey = 'queued_bill_payments';

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

class BillsRepository {
  Future<List<Bill>> fetchPendingByArea(String areaId) async {
    final res = await supabase
        .from('bills')
        .select(billAreaSelect)
        .eq('customer.area_id', areaId)
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

  Future<Bill?> fetchById(String id) async {
    final res = await supabase
        .from('bills')
        .select(billBaseSelect)
        .eq('id', id)
        .maybeSingle();
    if (res == null) return null;
    return Bill.fromJson(res);
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
      } catch (_) {
        remaining.add(payment);
      }
    }
    await _saveQueuedPayments(remaining);
    return synced;
  }

  Future<void> _saveQueuedPayments(List<QueuedBillPayment> payments) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(payments.map((p) => p.toJson()).toList());
    await prefs.setString(_queuedPaymentsKey, encoded);
  }
}
