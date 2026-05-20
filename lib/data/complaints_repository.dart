import '../models/complaint.dart';
import '../config/supabase_config.dart';

const _cols =
    'id, complaint_code, customer_id, issue, type, priority, status, '
    'assigned_to, opened_at, resolved_at, '
    'customer:customers(id, full_name, area_id), '
    'technician:staff(id, full_name)';

class ComplaintsRepository {
  Future<List<Complaint>> fetchAssigned(String technicianId) async {
    final res = await supabase
        .from('complaints')
        .select(_cols)
        .eq('assigned_to', technicianId)
        .inFilter('status', ['open', 'in_progress'])
        .order('opened_at', ascending: false);
    return (res as List).map((j) => Complaint.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<List<Complaint>> fetchByArea(String areaId) async {
    final res = await supabase
        .from('complaints')
        .select('$_cols, customer:customers!inner(id, full_name, area_id)')
        .eq('customer.area_id', areaId)
        .inFilter('status', ['open', 'in_progress'])
        .order('opened_at', ascending: false);
    return (res as List).map((j) => Complaint.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<List<Complaint>> fetchAll({String? status}) async {
    var q = supabase.from('complaints').select(_cols);
    if (status != null) q = q.eq('status', status);
    final res = await q.order('opened_at', ascending: false).limit(100);
    return (res as List).map((j) => Complaint.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<Complaint?> fetchById(String id) async {
    final res = await supabase
        .from('complaints')
        .select(_cols)
        .eq('id', id)
        .maybeSingle();
    if (res == null) return null;
    return Complaint.fromJson(res);
  }

  Future<void> updateStatus(String id, String status) async {
    final update = <String, dynamic>{'status': status};
    if (status == 'resolved') {
      update['resolved_at'] = DateTime.now().toUtc().toIso8601String();
    }
    await supabase.from('complaints').update(update).eq('id', id);
  }

  Future<void> assignTo(String complaintId, String technicianId) async {
    await supabase.from('complaints').update({
      'assigned_to': technicianId,
      'status': 'in_progress',
    }).eq('id', complaintId);
  }
}
