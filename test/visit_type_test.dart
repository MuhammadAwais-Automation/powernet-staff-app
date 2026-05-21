import 'package:flutter_test/flutter_test.dart';
import 'package:powernet_staff/models/bill.dart';

void main() {
  group('VisitType.fromValue', () {
    test('parses stored snake_case values', () {
      expect(VisitType.fromValue('house_locked'), VisitType.houseLocked);
      expect(VisitType.fromValue('promise_to_pay'), VisitType.promiseToPay);
      expect(VisitType.fromValue('refused_to_pay'), VisitType.refusedToPay);
    });

    test('keeps backward compatibility with old label values', () {
      expect(VisitType.fromValue('House Locked'), VisitType.houseLocked);
      expect(VisitType.fromValue('Promise to Pay'), VisitType.promiseToPay);
      expect(VisitType.fromValue('Refused to Pay'), VisitType.refusedToPay);
    });
  });
}
