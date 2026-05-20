import 'package:flutter_test/flutter_test.dart';
import 'package:powernet_staff/models/staff.dart';
import 'package:powernet_staff/services/auth_service.dart';

void main() {
  group('parseVerifiedStaffLogin', () {
    test('returns staff from legacy verify_staff_login success response', () {
      final staff = parseVerifiedStaffLogin({
        'success': true,
        'staff': {
          'id': 'staff-1',
          'full_name': 'ali',
          'role': 'recovery_agent',
          'phone': null,
          'area_id': 'area-1',
          'area_name': 'Alama Iqbal Town',
          'username': 'ali',
          'auth_user_id': null,
        },
      });

      expect(staff, isA<Staff>());
      expect(staff?.fullName, 'ali');
      expect(staff?.role, 'recovery_agent');
      expect(staff?.authUserId, isNull);
    });

    test('returns null for invalid legacy credentials response', () {
      final staff = parseVerifiedStaffLogin({
        'success': false,
        'error': 'Invalid credentials',
      });

      expect(staff, isNull);
    });
  });
}
