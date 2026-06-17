import '../config/supabase_config.dart';
import '../models/bill.dart';
import '../models/complaint.dart';
import '../models/customer_account.dart';
import '../models/payment_verification.dart';


const _customerBillSelect =
    'id, customer_id, amount, paid_amount, month, status, collected_by, '
    'paid_at, receipt_no, payment_method, payment_note, payment_source, created_at, '
    'customer:customers(id, customer_code, full_name, address_type, address_value, area_id)';

const _customerComplaintSelect =
    'id, complaint_code, customer_id, issue, type, priority, status, '
    'assigned_to, assigned_at, in_progress_at, opened_at, resolved_at, resolution_notes, hardware_used, '
    'customer:customers(id, full_name, area_id, customer_code, address_value, phone)';

const _customerComplaintLegacySelect =
    'id, complaint_code, customer_id, issue, type, priority, status, '
    'assigned_to, opened_at, resolved_at, '
    'customer:customers(id, full_name, area_id, customer_code, address_value, phone)';

class CustomerPortalRepository {
  Future<List<Bill>> fetchBills(String customerId) async {
    final res = await supabase
        .from('bills')
        .select(_customerBillSelect)
        .eq('customer_id', customerId)
        .order('month', ascending: false);
    return (res as List)
        .map((j) => Bill.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<List<Complaint>> fetchComplaints(String customerId) async {
    final res = await _fetchComplaints(customerId, _customerComplaintSelect);
    return res;
  }

  Future<List<Complaint>> _fetchComplaints(
    String customerId,
    String select,
  ) async {
    try {
      final res = await supabase
          .from('complaints')
          .select(select)
          .eq('customer_id', customerId)
          .order('opened_at', ascending: false);
      return (res as List)
          .map((j) => Complaint.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (select == _customerComplaintLegacySelect ||
          !_isMissingResolutionColumns(e)) {
        rethrow;
      }
      return _fetchComplaints(customerId, _customerComplaintLegacySelect);
    }
  }

  Future<Complaint> _insertComplaint(Map<String, dynamic> payload) async {
    final data = await supabase
        .from('complaints')
        .insert(payload)
        .select(_customerComplaintLegacySelect)
        .single();
    return Complaint.fromJson(data);
  }

  bool _isMissingResolutionColumns(Object error) {
    final text = error.toString();
    return text.contains('42703') ||
        text.contains('resolution_notes') ||
        text.contains('hardware_used') ||
        text.contains('assigned_at') ||
        text.contains('in_progress_at');
  }

  Future<Complaint> createComplaint({
    required CustomerAccount customer,
    required String issue,
    required String type,
  }) async {
    return _insertComplaint({
      'customer_id': customer.id,
      'issue': issue.trim(),
      'type': type,
      'priority': 'medium',
      'status': 'open',
      'assigned_to': null,
    });
  }

  Future<void> submitPaymentVerification({
    required String billId,
    required String customerId,
    required double amount,
    required String method,
    required String receiptUrl,
    String? remarks,
  }) async {
    final billRes = await supabase
        .from('bills')
        .select('id, customer_id, amount, paid_amount, status')
        .eq('id', billId)
        .maybeSingle();

    if (billRes == null) {
      throw Exception('Bill not found.');
    }

    if (billRes['customer_id'] != customerId) {
      throw Exception('Bill does not belong to this customer.');
    }

    final billAmount = (billRes['amount'] as num?)?.toInt() ?? 0;
    final paidAmount = (billRes['paid_amount'] as num?)?.toInt() ?? 0;
    final status = billRes['status'] as String? ?? '';
    final remaining = billAmount - paidAmount;

    if (status == 'paid' || remaining <= 0) {
      throw Exception('This bill is already paid. No receipt upload is needed.');
    }

    if (amount.toInt() > remaining) {
      throw Exception(
        'Payment amount exceeds remaining bill balance (Rs. $remaining).',
      );
    }

    final pendingRes = await supabase
        .from('payment_verifications')
        .select('id')
        .eq('bill_id', billId)
        .eq('status', 'pending')
        .maybeSingle();

    if (pendingRes != null) {
      throw Exception(
        'A payment receipt for this bill is already pending review.',
      );
    }

    await supabase.from('payment_verifications').insert({
      'bill_id': billId,
      'customer_id': customerId,
      'amount': amount.toInt(),
      'method': method,
      'receipt_url': receiptUrl,
      'customer_remarks': remarks?.trim(),
      'status': 'pending',
    });
  }

  Future<List<PaymentVerification>> fetchPaymentVerifications(String customerId) async {
    final res = await supabase
        .from('payment_verifications')
        .select('*')
        .eq('customer_id', customerId)
        .order('created_at', ascending: false);
    return (res as List)
        .map((j) => PaymentVerification.fromJson(j as Map<String, dynamic>))
        .toList();
  }
}

