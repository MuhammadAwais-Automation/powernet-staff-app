import '../config/supabase_config.dart';
import '../models/staff.dart';

class AuthService {
  Future<Staff?> login(String username, String password) async {
    final response = await supabase.rpc('verify_staff_login', params: {
      'p_username': username,
      'p_password': password,
    });

    if (response is Map<String, dynamic> && response['success'] == true) {
      return Staff.fromJson(response['staff'] as Map<String, dynamic>);
    }
    return null;
  }
}
