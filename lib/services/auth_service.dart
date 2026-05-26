import '../config/supabase_config.dart';
import '../models/staff.dart';

const _domain = '@powernet.local';
const _staffCols =
    'id, full_name, role, phone, area_id, username, auth_user_id, area:areas(name)';

Staff? parseVerifiedStaffLogin(dynamic response) {
  if (response is! Map || response['success'] != true) return null;
  final staff = response['staff'];
  if (staff is! Map) return null;
  return Staff.fromJson(Map<String, dynamic>.from(staff));
}

class AuthService {
  Future<Staff?> login(String username, String password) async {
    final normalizedUsername = username.trim().toLowerCase();
    final email = '$normalizedUsername$_domain';

    try {
      final res = await supabase.auth
          .signInWithPassword(email: email, password: password);
      if (res.session == null) return null;
      final staff = await _fetchStaff(res.session!.user.id);
      if (staff != null) return staff;
      await signOut();
      return null;
    } catch (_) {
      return _loginWithLegacyPassword(normalizedUsername, password);
    }
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

  Future<Staff?> fetchStaffById(String id) async {
    final data = await supabase
        .from('staff')
        .select(_staffCols)
        .eq('id', id)
        .eq('is_active', true)
        .maybeSingle();
    if (data == null) return null;
    return Staff.fromJson(data);
  }

  Future<Staff?> _loginWithLegacyPassword(
      String username, String password) async {
    final response = await supabase.rpc('verify_staff_login', params: {
      'p_username': username,
      'p_password': password,
    });
    return parseVerifiedStaffLogin(response);
  }
}
