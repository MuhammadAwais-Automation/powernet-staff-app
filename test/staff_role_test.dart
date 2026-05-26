import 'package:flutter_test/flutter_test.dart';
import 'package:powernet_staff/models/staff.dart';

void main() {
  group('removed helper staff role', () {
    test('does not expose helper roles as special app roles', () {
      expect(normalizeStaffRole('helper'), 'helper');
      expect(normalizeStaffRole('helper technician'), 'helper_technician');
    });

    test('falls back to raw helper role label', () {
      final staff = Staff(
        id: 'staff-helper',
        fullName: 'Helper User',
        role: 'helper',
      );

      expect(staff.normalizedRole, 'helper');
      expect(staff.roleLabel, 'helper');
    });
  });
}
