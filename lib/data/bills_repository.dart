import '../models/bill.dart';
import '../config/supabase_config.dart';

const _cols =
    'id, customer_id, amount, paid_amount, month, status, collected_by, '
    'paid_at, receipt_no, payment_method, payment_note, created_at, '
    'customer:customers(id, customer_code, full_name)';

class BillsRepository {
  Future<List<Bill>> fetchPendingByArea(String areaId) async {
    final res = await supabase
        .from('bills')
        .select('$_cols, customer:customers!inner(id, customer_code, full_name, area_id)')
        .eq('customer.area_id', areaId)
        .inFilter('status', ['pending', 'overdue'])
        .order('created_at', ascending: false);
    return (res as List).map((j) => Bill.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<List<Bill>> fetchByCustomer(String customerId) async {
    final res = await supabase
        .from('bills')
        .select(_cols)
        .eq('customer_id', customerId)
        .order('month', ascending: false);
    return (res as List).map((j) => Bill.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<List<Bill>> fetchCollectedToday(String collectorId) async {
    final today = DateTime.now();
    final dateStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final res = await supabase
        .from('bills')
        .select(_cols)
        .eq('collected_by', collectorId)
        .eq('status', 'paid')
        .gte('paid_at', '${dateStr}T00:00:00')
        .lte('paid_at', '${dateStr}T23:59:59')
        .order('paid_at', ascending: false);
    return (res as List).map((j) => Bill.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<Bill?> fetchById(String id) async {
    final res = await supabase
        .from('bills')
        .select(_cols)
        .eq('id', id)
        .maybeSingle();
    if (res == null) return null;
    return Bill.fromJson(res);
  }

  Future<void> markPaid({
    required String billId,
    required double paidAmount,
    required String collectorId,
    required String paymentMethod,
    String? paymentNote,
    String? receiptNo,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await supabase.from('bills').update({
      'paid_amount': paidAmount,
      'status': 'paid',
      'collected_by': collectorId,
      'paid_at': now,
      'payment_method': paymentMethod,
      'payment_note': paymentNote,
      'receipt_no': receiptNo,
    }).eq('id', billId);
  }
}
