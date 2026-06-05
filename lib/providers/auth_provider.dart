import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthChangeEvent, AuthException, PostgrestException;
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
        final saved = Staff.fromJson(jsonDecode(json) as Map<String, dynamic>);
        final session = supabase.auth.currentSession;
        if (saved.authUserId != null &&
            (session == null || session.user.id != saved.authUserId)) {
          await _storage.delete(key: _key);
        } else {
          _currentStaff = saved;
        }
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
    String username,
    String password,
  ) async {
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
      if (e is AuthException) {
        return (ok: false, error: e.message);
      }
      if (e is PostgrestException) {
        return (ok: false, error: e.message);
      }
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('invalid') || errStr.contains('credential') || errStr.contains('password') || errStr.contains('username') || errStr.contains('incorrect') || errStr.contains('not found')) {
        return (ok: false, error: 'Invalid credentials');
      }
      return (ok: false, error: 'Connection error. Check your network.');
    }
  }

  Future<void> logout() async {
    await _service.signOut();
    _currentStaff = null;
    await _storage.delete(key: _key);
    notifyListeners();
  }

  Future<void> refreshProfile() async {
    final staff = _currentStaff;
    if (staff == null) return;
    try {
      Staff? updated;
      if (staff.authUserId != null) {
        updated = await _service.fetchStaffByAuthId(staff.authUserId!);
      } else {
        updated = await _service.fetchStaffById(staff.id);
      }
      if (updated != null) {
        _currentStaff = updated;
        await _persist(updated);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('AuthProvider: refreshProfile failed: $e');
    }
  }

  Future<void> _persist(Staff staff) async {
    await _storage.write(key: _key, value: jsonEncode(staff.toJson()));
  }
}
