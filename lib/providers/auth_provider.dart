import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/staff.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  static const _prefsKey = 'staff_json';
  final AuthService _service = AuthService();

  Staff? _currentStaff;
  Staff? get currentStaff => _currentStaff;
  bool get isLoggedIn => _currentStaff != null;

  Future<void> loadSavedStaff() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_prefsKey);
    if (json == null) return;
    try {
      _currentStaff = Staff.fromJson(jsonDecode(json) as Map<String, dynamic>);
      notifyListeners();
    } catch (_) {
      await prefs.remove(_prefsKey);
    }
  }

  Future<bool> login(String username, String password) async {
    final staff = await _service.login(username, password);
    if (staff == null) return false;
    _currentStaff = staff;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(staff.toJson()));
    notifyListeners();
    return true;
  }

  Future<void> logout() async {
    _currentStaff = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
    notifyListeners();
  }
}
