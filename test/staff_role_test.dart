import 'package:flutter_test/flutter_test.dart';
import 'package:powernet_staff/models/staff.dart';

void main() {
  group('helper staff role', () {
    test('keeps helper as a complaint-capable app role', () {
      expect(normalizeStaffRole('helper'), 'helper');
      expect(normalizeStaffRole('helper technician'), 'helper_technician');
    });

    test('shows helper role label', () {
      final staff = Staff(
        id: 'staff-helper',
        fullName: 'Helper User',
        role: 'helper',
      );

      expect(staff.normalizedRole, 'helper');
      expect(staff.roleLabel, 'Helper');
    });
  });
}
