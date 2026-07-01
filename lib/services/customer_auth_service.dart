import '../config/supabase_config.dart';
import '../models/customer_account.dart';

const _customerCols =
    'id, customer_code, auth_user_id, house_id, full_name, father_name, cnic, '
    'phone, whatsapp, email, package_id, area_id, status, address_value, '
    'due_amount, created_at, area:areas(id, code, name, type, is_active), '
    'package:packages(id, name, speed_mbps, default_price, is_active)';

class CustomerAuthService {
  static const portalStatuses = ['active', 'tdc'];

  Future<CustomerAccount?> login(String identifier, String password) async {
    final email = await _resolveLoginEmail(identifier);
    if (email == null) return null;

    final res = await supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
    if (res.session == null) return null;
    final customer = await fetchCustomerByAuthId(res.session!.user.id);
    if (customer != null) return customer;
    await signOut();
    return null;
  }

  Future<String?> _resolveLoginEmail(String identifier) async {
    final trimmed = identifier.trim();
    if (trimmed.isEmpty) return null;

    try {
      final response = await supabase.rpc(
        'customer_login_lookup',
        params: {'p_identifier': trimmed},
      );
      if (response is Map && response['success'] == true) {
        final email = response['email'];
        if (email is String && email.isNotEmpty) return email;
      }
    } catch (_) {
      // Fall back to deterministic house-ID email for local/dev schemas.
    }

    final digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length >= 10) {
      return 'customer_$digits@powernet.local';
    }

    final normalized = trimmed
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    if (normalized.isEmpty) return null;
    return 'customer_$normalized@powernet.local';
  }

  Future<CustomerAccount?> fetchCustomerByAuthId(String authUserId) async {
    final data = await supabase
        .from('customers')
        .select(_customerCols)
        .eq('auth_user_id', authUserId)
        .inFilter('status', portalStatuses)
        .maybeSingle();
    if (data == null) return null;
    return CustomerAccount.fromJson(data);
  }

  Future<void> signOut() async {
    await supabase.auth.signOut();
  }
}
