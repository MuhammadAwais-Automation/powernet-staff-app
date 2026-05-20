import '../config/supabase_config.dart';
import '../models/staff.dart';

const _domain = '@powernet.local';
const _staffCols =
    'id, full_name, role, phone, area_id, username, auth_user_id';

class AuthService {
  Future<Staff?> login(String username, String password) async {
    final email = '${username.trim().toLowerCase()}$_domain';
    final res = await supabase.auth
        .signInWithPassword(email: email, password: password);
    if (res.session == null) return null;
    return _fetchStaff(res.session!.user.id);
  }

  Future<Staff?> fetchStaffByAuthId(String authUserId) async {
    return _fetchStaff(authUserId);
  }

  Future<void> signOut() async {
    await supabase.auth.signOut();
  }

  Future<Staff?> _fetchStaff(String authUserId) async {
    final data = await supabase
        .from('staff')
        .select(_staffCols)
        .eq('auth_user_id', authUserId)
        .eq('is_active', true)
        .maybeSingle();
    if (data == null) return null;
    return Staff.fromJson(data);
  }
}
