import '../config/supabase_config.dart';
import '../models/bill.dart';

const cableBillBaseSelect =
    'id, customer_id, amount, paid_amount, month, status, collected_by, '
    'paid_at, receipt_no, payment_method, payment_note, payment_source, created_at, '
    'customer:customers(id, customer_code, full_name, address_type, address_value, area_id, has_cable)';

const cableBillAreaSelect =
    'id, customer_id, amount, paid_amount, month, status, collected_by, '
    'paid_at, receipt_no, payment_method, payment_note, payment_source, created_at, '
    'customer:customers!inner(id, customer_code, full_name, address_type, address_value, area_id, has_cable)';

class CableBillsRepository {
  Future<List<Bill>> fetchPendingByAreas(List<String> areaIds) async {
    if (areaIds.isEmpty) return [];
    final openRes = await supabase
        .from('cable_bills')
        .select(cableBillAreaSelect)
        .inFilter('customer.area_id', areaIds)
        .eq('customer.has_cable', true)
        .inFilter('status', ['pending', 'overdue'])
        .order('created_at', ascending: false);
    final openBills = (openRes as List)
        .map((j) => Bill.fromJson(j as Map<String, dynamic>, serviceType: 'cable'))
        .where((bill) => bill.remaining > 0)
        .toList();
    if (openBills.isEmpty) return [];

    final customerIds = openBills.map((bill) => bill.customerId).toSet().toList();
    final ledgerRes = await supabase
        .from('cable_bills')
        .select(cableBillBaseSelect)
        .inFilter('customer_id', customerIds)
        .order('month', ascending: false);
    return (ledgerRes as List)
        .map((j) => Bill.fromJson(j as Map<String, dynamic>, serviceType: 'cable'))
        .toList();
  }

  Future<Bill?> fetchById(String id) async {
    final res = await supabase
        .from('cable_bills')
        .select(cableBillBaseSelect)
        .eq('id', id)
        .maybeSingle();
    if (res == null) return null;
    return Bill.fromJson(res, serviceType: 'cable');
  }

  Future<List<Bill>> fetchByCustomer(String customerId) async {
    final res = await supabase
        .from('cable_bills')
        .select(cableBillBaseSelect)
        .eq('customer_id', customerId)
        .order('month', ascending: false);
    return (res as List)
        .map((j) => Bill.fromJson(j as Map<String, dynamic>, serviceType: 'cable'))
        .toList();
  }

  Future<List<Bill>> fetchPaidTodayByAreas(List<String> areaIds) async {
    if (areaIds.isEmpty) return [];
    final today = DateTime.now().toUtc();
    final dateStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final res = await supabase
        .from('cable_payments')
        .select(
          'id, cable_bill_id, customer_id, amount, collected_by, method, source, '
          'note, receipt_no, paid_at, created_at, '
          'cable_bill:cable_bills(month, amount, paid_amount, status), '
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

  Bill _billFromPayment(Map<String, dynamic> j) {
    final cableBill = j['cable_bill'] as Map<String, dynamic>?;
    return Bill(
      id: j['cable_bill_id'] as String,
      customerId: j['customer_id'] as String,
      amount: (cableBill?['amount'] as num?)?.toDouble() ?? (j['amount'] as num).toDouble(),
      paidAmount: (cableBill?['paid_amount'] as num?)?.toDouble() ?? (j['amount'] as num).toDouble(),
      month: cableBill?['month'] as String? ?? '',
      status: cableBill?['status'] as String? ?? 'paid',
      collectedBy: j['collected_by'] as String?,
      paidAt: j['paid_at'] as String?,
      receiptNo: j['receipt_no'] as String?,
      paymentMethod: j['method'] as String?,
      paymentNote: j['note'] as String?,
      paymentSource: j['source'] as String?,
      createdAt: j['created_at'] as String? ?? j['paid_at'] as String? ?? '',
      customer: j['customer'] as Map<String, dynamic>?,
      serviceType: 'cable',
    );
  }

  Future<void> recordPayment({
    required String billId,
    required double paidAmount,
    required String collectorId,
    required String paymentMethod,
    String? paymentNote,
  }) async {
    await supabase.rpc('record_cable_bill_payment', params: {
      'p_bill_id': billId,
      'p_amount': paidAmount.round(),
      'p_collected_by': collectorId,
      'p_method': paymentMethod,
      'p_source': 'agent',
      'p_note': paymentNote,
    });
  }
}
