import '../config/supabase_config.dart';
import '../models/bill.dart';
import '../models/complaint.dart';
import '../models/customer_account.dart';

const _customerBillSelect =
    'id, customer_id, amount, paid_amount, month, status, collected_by, '
    'paid_at, receipt_no, payment_method, payment_note, created_at, '
    'customer:customers(id, customer_code, full_name, address_type, address_value, area_id)';

const _customerComplaintSelect =
    'id, complaint_code, customer_id, issue, type, priority, status, '
    'assigned_to, opened_at, resolved_at, resolution_notes, hardware_used, '
    'customer:customers(id, full_name, area_id, customer_code, address_value, phone), '
    'technician:staff(id, full_name)';

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
    final res = await supabase
        .from('complaints')
        .select(_customerComplaintSelect)
        .eq('customer_id', customerId)
        .order('opened_at', ascending: false);
    return (res as List)
        .map((j) => Complaint.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<Complaint> createComplaint({
    required CustomerAccount customer,
    required String issue,
    required String type,
  }) async {
    final data = await supabase
        .from('complaints')
        .insert({
          'customer_id': customer.id,
          'issue': issue.trim(),
          'type': type,
          'priority': 'medium',
          'status': 'open',
          'assigned_to': null,
        })
        .select(_customerComplaintSelect)
        .single();
    return Complaint.fromJson(data);
  }
}
