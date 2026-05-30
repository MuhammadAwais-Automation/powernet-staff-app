import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:powernet_staff/data/bills_repository.dart';
import 'package:powernet_staff/models/bill.dart';
import 'package:powernet_staff/providers/bills_provider.dart';

void main() {
  group('BillsProvider offline sync', () {
    test('queues visit logs when network write fails', () async {
      final repo = _FakeBillsRepository(failVisitWrite: true);
      final provider = BillsProvider(
        repo: repo,
        onlineChanges: const Stream.empty(),
        enableRealtime: false,
      );

      final result = await provider.submitVisit(
        billId: _bill.id,
        collectorId: 'staff-1',
        visitType: VisitType.houseLocked.value,
      );

      expect(result, PaymentSubmissionResult.queued);
      expect(provider.pendingSyncCount, 1);
      expect(repo.queuedVisits, hasLength(1));
      expect(repo.queuedVisits.single.visitType, VisitType.houseLocked.value);
    });

    test('syncs queued work automatically when connectivity returns', () async {
      final online = StreamController<bool>();
      final repo = _FakeBillsRepository(initialQueuedPayments: 1);
      final provider = BillsProvider(
        repo: repo,
        onlineChanges: online.stream,
        enableRealtime: false,
      );

      await provider.loadPendingByAreas(const ['area-1'], 'staff-1');
      expect(provider.pendingSyncCount, 1);

      online.add(true);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(repo.syncCalls, 1);
      expect(provider.pendingSyncCount, 0);
      await online.close();
      provider.dispose();
    });

    test('finds cached bills for offline detail screen fallback', () async {
      final provider = BillsProvider(
        repo: _FakeBillsRepository(),
        onlineChanges: const Stream.empty(),
        enableRealtime: false,
      );

      await provider.loadPendingByAreas(const ['area-1'], 'staff-1');

      expect(provider.findBillById(_bill.id), isNotNull);
      expect(provider.findBillById('missing'), isNull);
    });

    test(
      'exposes one pending ledger per customer for recovery cards',
      () async {
        final provider = BillsProvider(
          repo: _FakeBillsRepository(
            pendingBills: [
              _bill,
              _bill.copyWithMonth(
                id: 'bill-previous',
                month: 'April 2026',
                amount: 900,
              ),
            ],
          ),
          onlineChanges: const Stream.empty(),
          enableRealtime: false,
        );

        await provider.loadPendingByAreas(const ['area-1'], 'staff-1');

        expect(provider.pendingLedgers, hasLength(1));
        expect(provider.pendingLedgers.single.billCount, 2);
        expect(provider.pendingLedgers.single.totalRemaining, 1900);
      },
    );
  });
}

final _bill = Bill(
  id: 'bill-1',
  customerId: 'customer-1',
  amount: 1000,
  paidAmount: 0,
  month: 'May 2026',
  status: 'pending',
  createdAt: '2026-05-01T00:00:00Z',
  customer: const {
    'id': 'customer-1',
    'customer_code': 'C-001',
    'full_name': 'Test Customer',
    'address_type': 'house',
    'address_value': 'Street 1',
    'area_id': 'area-1',
  },
);

class _FakeBillsRepository extends BillsRepository {
  final bool failVisitWrite;
  final int initialQueuedPayments;
  final List<Bill> pendingBills;
  final List<QueuedBillVisit> queuedVisits = [];
  int syncCalls = 0;
  var _queuedPayments = <QueuedBillPayment>[];

  _FakeBillsRepository({
    this.failVisitWrite = false,
    this.initialQueuedPayments = 0,
    List<Bill>? pendingBills,
  }) : pendingBills = pendingBills ?? [_bill] {
    _queuedPayments = List.generate(
      initialQueuedPayments,
      (index) => QueuedBillPayment(
        id: 'queued-$index',
        billId: _bill.id,
        amount: 100,
        collectorId: 'staff-1',
        paymentMethod: 'cash',
        queuedAt: '2026-05-25T00:00:00Z',
      ),
    );
  }

  @override
  Future<List<Bill>> fetchPendingByAreas(List<String> areaIds) async =>
      pendingBills;

  @override
  Future<List<Bill>> fetchCollectedToday(String collectorId) async => [];

  @override
  Future<List<Bill>> fetchPaidTodayByAreas(List<String> areaIds) async => [];

  @override
  Future<List<Bill>> fetchVisitedToday(String collectorId) async => [];

  @override
  Future<void> recordVisit({
    required String billId,
    required String collectorId,
    required String visitType,
  }) async {
    if (failVisitWrite) throw Exception('offline');
  }

  @override
  Future<List<QueuedBillPayment>> getQueuedPayments() async => _queuedPayments;

  @override
  Future<List<QueuedBillVisit>> getQueuedVisits() async => queuedVisits;

  @override
  Future<void> queueVisit({
    required String billId,
    required String collectorId,
    required String visitType,
  }) async {
    queuedVisits.add(
      QueuedBillVisit(
        id: 'visit-${queuedVisits.length}',
        billId: billId,
        collectorId: collectorId,
        visitType: visitType,
        queuedAt: '2026-05-25T00:00:00Z',
      ),
    );
  }

  @override
  Future<int> countQueuedOperations() async =>
      _queuedPayments.length + queuedVisits.length;

  @override
  Future<int> syncQueuedOperations() async {
    syncCalls++;
    final synced = _queuedPayments.length + queuedVisits.length;
    _queuedPayments = [];
    queuedVisits.clear();
    return synced;
  }

  @override
  Future<void> cacheRecoverySnapshot({
    required List<String> areaIds,
    required String collectorId,
    required List<Bill> pending,
    required List<Bill> collectedToday,
    required List<Bill> visitedToday,
  }) async {}
}

extension on Bill {
  Bill copyWithMonth({
    required String id,
    required String month,
    required double amount,
  }) {
    return Bill(
      id: id,
      customerId: customerId,
      amount: amount,
      paidAmount: paidAmount,
      month: month,
      status: status,
      collectedBy: collectedBy,
      paidAt: paidAt,
      receiptNo: receiptNo,
      paymentMethod: paymentMethod,
      paymentNote: paymentNote,
      paymentSource: paymentSource,
      createdAt: createdAt,
      customer: customer,
    );
  }
}
