import 'package:flutter_test/flutter_test.dart';
import 'package:powernet_staff/data/bills_repository.dart';
import 'package:powernet_staff/data/complaints_repository.dart';

void main() {
  group('bills query shapes', () {
    test('area query joins customer exactly once and includes area_id', () {
      expect(
        RegExp(r'customer:customers').allMatches(billAreaSelect).length,
        1,
      );
      expect(billAreaSelect, contains('customer:customers!inner'));
      expect(billAreaSelect, contains('area_id'));
      expect(billAreaSelect, contains('customer_code'));
      expect(billAreaSelect, contains('full_name'));
      expect(billAreaSelect, contains('payment_source'));
    });

    test('base bill select keeps customer fields used by models', () {
      expect(billBaseSelect, contains('customer:customers('));
      expect(billBaseSelect, contains('customer_code'));
      expect(billBaseSelect, contains('full_name'));
      expect(billBaseSelect, contains('payment_source'));
    });
  });

  group('complaints query shapes', () {
    test('area query joins customer exactly once and includes area_id', () {
      expect(
        RegExp(r'customer:customers').allMatches(complaintAreaSelect).length,
        1,
      );
      expect(complaintAreaSelect, contains('customer:customers!inner'));
      expect(complaintAreaSelect, contains('area_id'));
      expect(complaintAreaSelect, contains('technician:staff('));
    });

    test('base complaint select keeps related customer and technician', () {
      expect(complaintBaseSelect, contains('customer:customers('));
      expect(complaintBaseSelect, contains('technician:staff('));
      expect(complaintBaseSelect, contains('resolution_notes'));
      expect(complaintBaseSelect, contains('hardware_used'));
    });
  });
}
