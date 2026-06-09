import 'package:flutter_test/flutter_test.dart';
import 'package:powernet_staff/models/bill.dart';

void main() {
  group('CustomerBillLedger', () {
    test('groups multiple unpaid months into one customer ledger', () {
      final ledgers = CustomerBillLedger.groupBills([
        _bill(
          id: 'may-bill',
          customerId: 'customer-1',
          month: 'May 2026',
          amount: 1500,
        ),
        _bill(
          id: 'apr-bill',
          customerId: 'customer-1',
          month: 'April 2026',
          amount: 1200,
        ),
      ]);

      expect(ledgers, hasLength(1));
      expect(ledgers.single.billCount, 2);
      expect(ledgers.single.currentBill.id, 'may-bill');
      expect(ledgers.single.currentDue, 1500);
      expect(ledgers.single.previousDue, 1200);
      expect(ledgers.single.totalRemaining, 2700);
    });

    test('keeps different customers as separate ledgers', () {
      final ledgers = CustomerBillLedger.groupBills([
        _bill(id: 'bill-1', customerId: 'customer-1', month: 'May 2026'),
        _bill(id: 'bill-2', customerId: 'customer-2', month: 'May 2026'),
      ]);

      expect(ledgers, hasLength(2));
      expect(ledgers.map((ledger) => ledger.customerId), [
        'customer-1',
        'customer-2',
      ]);
    });

    test('uses paid history to mark open customer ledger as partial', () {
      final ledgers = CustomerBillLedger.groupBills([
        _bill(
          id: 'jun-open',
          customerId: 'customer-1',
          month: 'June 2026',
          amount: 2200,
        ),
        _bill(
          id: 'may-open',
          customerId: 'customer-1',
          month: 'May 2026',
          amount: 2200,
        ),
        _bill(
          id: 'apr-paid',
          customerId: 'customer-1',
          month: 'April 2026',
          amount: 2200,
          paidAmount: 2200,
          status: 'paid',
        ),
      ]);

      final ledger = ledgers.single;
      expect(ledger.currentBill.id, 'jun-open');
      expect(ledger.billCount, 2);
      expect(ledger.currentDue, 2200);
      expect(ledger.previousDue, 2200);
      expect(ledger.totalPaid, 2200);
      expect(ledger.totalRemaining, 4400);
      expect(ledger.hasPartialPayment, isTrue);
      expect(ledger.collectionStatus, 'partial');
    });
  });
}

Bill _bill({
  required String id,
  required String customerId,
  required String month,
  double amount = 1000,
  double paidAmount = 0,
  String status = 'pending',
}) {
  return Bill(
    id: id,
    customerId: customerId,
    amount: amount,
    paidAmount: paidAmount,
    month: month,
    status: status,
    createdAt: '2026-05-01T00:00:00Z',
    customer: {
      'id': customerId,
      'customer_code': 'C-$customerId',
      'full_name': 'Test Customer $customerId',
      'address_type': 'house',
      'address_value': 'Street 1',
      'area_id': 'area-1',
    },
  );
}
