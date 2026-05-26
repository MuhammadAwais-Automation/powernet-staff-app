import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthChangeEvent;

import '../config/supabase_config.dart';
import '../models/customer_account.dart';
import '../services/customer_auth_service.dart';

class CustomerAuthProvider extends ChangeNotifier {
  static const _key = 'pn_customer';
  static const _storage = FlutterSecureStorage();
  final CustomerAuthService _service = CustomerAuthService();

  CustomerAccount? _currentCustomer;
  bool _loading = true;

  CustomerAccount? get currentCustomer => _currentCustomer;
  bool get isLoggedIn => _currentCustomer != null;
  bool get loading => _loading;

  Future<void> initialize() async {
    await _loadSavedCustomer();
    _listenAuthState();
  }

  Future<void> _loadSavedCustomer() async {
    try {
      final raw = await _storage
          .read(key: _key)
          .timeout(const Duration(seconds: 5));
      if (raw != null) {
        final saved = CustomerAccount.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
        final session = supabase.auth.currentSession;
        if (session == null || saved.authUserId != session.user.id) {
          await _storage.delete(key: _key);
        } else {
          _currentCustomer = saved;
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
            _currentCustomer = null;
            notifyListeners();
            return;
          }

          if (event == AuthChangeEvent.tokenRefreshed ||
              event == AuthChangeEvent.signedIn ||
              event == AuthChangeEvent.initialSession) {
            if (_currentCustomer?.authUserId == session.user.id) return;
            final customer = await _service.fetchCustomerByAuthId(
              session.user.id,
            );
            if (customer == null) {
              _currentCustomer = null;
            } else {
              _currentCustomer = customer;
              await _persist(customer);
            }
            notifyListeners();
          }
        } catch (e) {
          debugPrint('CustomerAuthProvider: auth state handler error: $e');
          notifyListeners();
        }
      },
      onError: (Object e) {
        debugPrint('CustomerAuthProvider: auth stream error: $e');
      },
      cancelOnError: false,
    );
  }

  Future<({bool ok, String? error})> login(
    String identifier,
    String password,
  ) async {
    try {
      await _service.signOut().catchError((_) {});
      final customer = await _service.login(identifier, password);
      if (customer == null) {
        return (ok: false, error: 'Invalid customer credentials');
      }
      _currentCustomer = customer;
      await _persist(customer).catchError((_) {});
      notifyListeners();
      return (ok: true, error: null);
    } catch (e) {
      return (ok: false, error: 'Connection error. Check your network.');
    }
  }

  Future<void> logout() async {
    await _service.signOut();
    _currentCustomer = null;
    await _storage.delete(key: _key);
    notifyListeners();
  }

  Future<void> refreshProfile() async {
    final customer = _currentCustomer;
    if (customer?.authUserId == null) return;
    try {
      final updated = await _service.fetchCustomerByAuthId(
        customer!.authUserId!,
      );
      if (updated != null) {
        _currentCustomer = updated;
        await _persist(updated);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('CustomerAuthProvider: refreshProfile failed: $e');
    }
  }

  Future<void> _persist(CustomerAccount customer) async {
    await _storage.write(key: _key, value: jsonEncode(customer.toJson()));
  }
}
