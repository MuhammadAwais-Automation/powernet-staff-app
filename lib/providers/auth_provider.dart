import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthChangeEvent;
import '../config/supabase_config.dart';
import '../models/staff.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  static const _key = 'pn_staff';
  static const _storage = FlutterSecureStorage();
  final AuthService _service = AuthService();

  Staff? _currentStaff;
  bool _loading = true;

  Staff? get currentStaff => _currentStaff;
  bool get isLoggedIn => _currentStaff != null;
  bool get loading => _loading;

  Future<void> initialize() async {
    await _loadSavedStaff();
    _listenAuthState();
  }

  Future<void> _loadSavedStaff() async {
    try {
      final json = await _storage
          .read(key: _key)
          .timeout(const Duration(seconds: 5));
      if (json != null) {
        _currentStaff =
            Staff.fromJson(jsonDecode(json) as Map<String, dynamic>);
      }
    } catch (_) {
      try {
        await _storage.delete(key: _key);
      } catch (_) {}
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void _listenAuthState() {
    supabase.auth.onAuthStateChange.listen(
      (data) async {
        try {
          final session = data.session;
          final event = data.event;

          if (session == null) {
            _currentStaff = null;
            notifyListeners();
            return;
          }

          // Skip silent events when same user already loaded
          if (event == AuthChangeEvent.tokenRefreshed ||
              event == AuthChangeEvent.signedIn ||
              event == AuthChangeEvent.initialSession) {
            if (_currentStaff?.authUserId == session.user.id) return;
            final staff = await _service.fetchStaffByAuthId(session.user.id);
            if (staff == null) {
              await _service.signOut();
              _currentStaff = null;
            } else {
              _currentStaff = staff;
              await _persist(staff);
            }
            notifyListeners();
          }
        } catch (e) {
          debugPrint('AuthProvider: auth state handler error: $e');
          notifyListeners();
        }
      },
      onError: (Object e) {
        debugPrint('AuthProvider: auth stream error: $e');
      },
      cancelOnError: false,
    );
  }

  Future<({bool ok, String? error})> login(
      String username, String password) async {
    try {
      final staff = await _service.login(username, password);
      if (staff == null) {
        return (ok: false, error: 'Invalid credentials');
      }
      _currentStaff = staff;
      await _persist(staff).catchError((_) {});
      notifyListeners();
      return (ok: true, error: null);
    } catch (e) {
      return (ok: false, error: 'Connection error. Check your network.');
    }
  }

  Future<void> logout() async {
    await _service.signOut();
    _currentStaff = null;
    await _storage.delete(key: _key);
    notifyListeners();
  }

  Future<void> _persist(Staff staff) async {
    await _storage.write(key: _key, value: jsonEncode(staff.toJson()));
  }
}
