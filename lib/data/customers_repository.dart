import '../models/customer.dart';
import '../config/supabase_config.dart';

const _cols =
    'id, customer_code, username, full_name, cnic, phone, package_id, iptv, '
    'address_type, address_value, area_id, connection_date, due_amount, '
    'onu_number, status, disconnected_date, reconnected_date, remarks, '
    'created_at, area:areas(id, code, name, type, is_active)';

class CustomersRepository {
  Future<List<Customer>> fetchByAreas(List<String> areaIds) async {
    if (areaIds.isEmpty) return [];
    final res = await supabase
        .from('customers')
        .select(_cols)
        .inFilter('area_id', areaIds)
        .order('full_name');
    return (res as List)
        .map((j) => Customer.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<List<Customer>> fetchDue({List<String>? areaIds}) async {
    var q = supabase
        .from('customers')
        .select(_cols)
        .gt('due_amount', 0)
        .eq('status', 'active');
    if (areaIds != null && areaIds.isNotEmpty) {
      q = q.inFilter('area_id', areaIds);
    }
    final res = await q.order('due_amount', ascending: false);
    return (res as List)
        .map((j) => Customer.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<List<Customer>> search(String query, {List<String>? areaIds}) async {
    var q = supabase.from('customers').select(_cols);
    if (areaIds != null && areaIds.isNotEmpty) {
      q = q.inFilter('area_id', areaIds);
    }
    final res = await q
        .or(
          'full_name.ilike.%$query%,customer_code.ilike.%$query%,username.ilike.%$query%,phone.ilike.%$query%',
        )
        .order('full_name')
        .limit(50);
    return (res as List)
        .map((j) => Customer.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<Customer?> fetchById(String id) async {
    final res = await supabase
        .from('customers')
        .select(_cols)
        .eq('id', id)
        .maybeSingle();
    if (res == null) return null;
    return Customer.fromJson(res);
  }
}
