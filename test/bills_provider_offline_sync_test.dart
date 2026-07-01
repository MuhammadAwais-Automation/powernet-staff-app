import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:powernet_staff/data/bills_repository.dart';
import 'package:powernet_staff/models/bill.dart';
import 'package:powernet_staff/providers/bills_provider.dart';

void main() {
  group('BillsProvider offline sync', () {
    test('queues promise-to-pay visit with promised date', () async {
      final repo = _FakeBillsRepository(failVisitWrite: true);
      final provider = BillsProvider(
        repo: repo,
        onlineChanges: const Stream.empty(),
        enableRealtime: false,
      );

      final result = await provider.submitVisit(
        billId: _bill.id,
        collectorId: 'staff-1',
        visitType: VisitType.promiseToPay.value,
        promisedDate: '2026-07-05',
      );

      expect(result, PaymentSubmissionResult.queued);
      expect(repo.queuedVisits.single.promisedDate, '2026-07-05');
    });

    test('Bill model round-trips promised_date', () {
      final bill = Bill.fromJson({
        ..._bill.toJson(),
        'payment_method': 'visit',
        'payment_note': 'promise_to_pay',
        'promised_date': '2026-07-05',
      });

      expect(bill.promisedDate, '2026-07-05');
      expect(bill.isPromiseToPay, isTrue);
    });

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

    test(
      'marks customer partial when paid history exists with open bills',
      () async {
        final provider = BillsProvider(
          repo: _FakeBillsRepository(
            pendingBills: [
              _bill.copyWithMonth(
                id: 'jun-open',
                month: 'June 2026',
                amount: 2200,
              ),
              _bill.copyWithMonth(
                id: 'may-open',
                month: 'May 2026',
                amount: 2200,
              ),
              _bill.copyWithMonth(
                id: 'apr-paid',
                month: 'April 2026',
                amount: 2200,
                paidAmount: 2200,
                status: 'paid',
              ),
            ],
          ),
          onlineChanges: const Stream.empty(),
          enableRealtime: false,
        );

        await provider.loadPendingByAreas(const ['area-1'], 'staff-1');

        final ledger = provider.pendingLedgers.single;
        expect(ledger.currentBill.id, 'jun-open');
        expect(ledger.billCount, 2);
        expect(ledger.totalPaid, 2200);
        expect(ledger.totalRemaining, 4400);
        expect(ledger.hasPartialPayment, isTrue);
        expect(ledger.collectionStatus, 'partial');
      },
    );

    test(
      'skips stale fully paid bills and records against remaining ledger bills',
      () async {
        final staleBill = _bill.copyWithMonth(
          id: 'bill-stale',
          month: 'April 2026',
          amount: 1000,
        );
        final liveBill = _bill.copyWithMonth(
          id: 'bill-live',
          month: 'May 2026',
          amount: 1000,
        );
        final repo = _FakeBillsRepository(
          pendingBills: [liveBill, staleBill],
          alreadyPaidBillIds: {'bill-stale'},
        );
        final online = StreamController<bool>();
        final provider = BillsProvider(
          repo: repo,
          onlineChanges: online.stream,
          enableRealtime: false,
        );
        online.add(true);
        await Future<void>.delayed(Duration.zero);
        await provider.loadPendingByAreas(const ['area-1'], 'staff-1');

        final result = await provider.submitLedgerPayment(
          ledger: provider.pendingLedgers.single,
          amount: 2000,
          collectorId: 'staff-1',
          paymentMethod: 'cash',
        );

        expect(result, PaymentSubmissionResult.synced);
        expect(repo.recordedPayments, ['bill-live:1000.0']);
        expect(provider.pendingLedgers, isEmpty);
        await online.close();
        provider.dispose();
      },
    );

    test(
      'keeps remaining customer ledger partial after oldest bill is fully paid',
      () async {
        final online = StreamController<bool>();
        final provider = BillsProvider(
          repo: _FakeBillsRepository(
            pendingBills: [
              _bill.copyWithMonth(
                id: 'may-open',
                month: 'May 2026',
                amount: 1000,
              ),
              _bill.copyWithMonth(
                id: 'apr-open',
                month: 'April 2026',
                amount: 1000,
              ),
            ],
          ),
          onlineChanges: online.stream,
          enableRealtime: false,
        );
        online.add(true);
        await Future<void>.delayed(Duration.zero);

        await provider.loadPendingByAreas(const ['area-1'], 'staff-1');

        final result = await provider.submitLedgerPayment(
          ledger: provider.pendingLedgers.single,
          amount: 1000,
          collectorId: 'staff-1',
          paymentMethod: 'cash',
        );

        final ledger = provider.pendingLedgers.single;
        expect(result, PaymentSubmissionResult.synced);
        expect(ledger.currentBill.id, 'may-open');
        expect(ledger.totalPaid, 1000);
        expect(ledger.totalRemaining, 1000);
        expect(ledger.hasPartialPayment, isTrue);
        expect(ledger.collectionStatus, 'partial');
        await online.close();
        provider.dispose();
      },
    );

    test('reports stale fully paid bill without generic failure', () async {
      final repo = _FakeBillsRepository(
        pendingBills: [_bill],
        alreadyPaidBillIds: {_bill.id},
      );
      final online = StreamController<bool>();
      final provider = BillsProvider(
        repo: repo,
        onlineChanges: online.stream,
        enableRealtime: false,
      );
      online.add(true);
      await Future<void>.delayed(Duration.zero);
      await provider.loadPendingByAreas(const ['area-1'], 'staff-1');

      final result = await provider.submitLedgerPayment(
        ledger: provider.pendingLedgers.single,
        amount: 1000,
        collectorId: 'staff-1',
        paymentMethod: 'cash',
      );

      expect(result, PaymentSubmissionResult.alreadyPaid);
      expect(provider.error, 'Bill already paid. Collection list refreshed.');
      expect(provider.bills, isEmpty);
      await online.close();
      provider.dispose();
    });
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
  final Set<String> alreadyPaidBillIds;
  final List<QueuedBillVisit> queuedVisits = [];
  final List<String> recordedPayments = [];
  int fetchPendingCalls = 0;
  int syncCalls = 0;
  var _queuedPayments = <QueuedBillPayment>[];

  _FakeBillsRepository({
    this.failVisitWrite = false,
    this.initialQueuedPayments = 0,
    Set<String> alreadyPaidBillIds = const {},
    List<Bill>? pendingBills,
  }) : pendingBills = pendingBills ?? [_bill],
       alreadyPaidBillIds = {...alreadyPaidBillIds} {
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
  Future<List<Bill>> fetchPendingByAreas(List<String> areaIds) async {
    fetchPendingCalls++;
    if (fetchPendingCalls == 1) return pendingBills;
    return pendingBills
        .where((bill) => !alreadyPaidBillIds.contains(bill.id))
        .toList();
  }

  @override
  Future<Bill?> fetchById(String id) async {
    final bill = pendingBills.where((bill) => bill.id == id).firstOrNull;
    if (bill == null) return null;
    if (alreadyPaidBillIds.contains(id)) {
      return bill.copyWith(paidAmount: bill.amount, status: 'paid');
    }
    return bill;
  }

  @override
  Future<List<Bill>> fetchCollectedToday(String collectorId) async => [];

  @override
  Future<List<Bill>> fetchPaidTodayByAreas(List<String> areaIds) async => [];

  @override
  Future<List<Bill>> fetchVisitedToday(String collectorId) async => [];

  @override
  Future<List<Bill>> getCachedPendingByAreas(List<String> areaIds) async => pendingBills;

  @override
  Future<List<Bill>> getCachedCollectedToday(String collectorId) async => [];

  @override
  Future<List<Bill>> getCachedVisitedToday(String collectorId) async => [];

  @override
  Future<void> recordVisit({
    required String billId,
    required String collectorId,
    required String visitType,
    String? promisedDate,
  }) async {
    if (failVisitWrite) throw Exception('offline');
  }

  @override
  Future<void> recordPayment({
    required String billId,
    required double paidAmount,
    required String collectorId,
    required String paymentMethod,
    String? paymentNote,
    String? receiptUrl,
    RemainderAction remainderAction = RemainderAction.leave,
  }) async {
    if (alreadyPaidBillIds.contains(billId)) {
      throw const BillAlreadyPaidException();
    }
    recordedPayments.add('$billId:$paidAmount');
    alreadyPaidBillIds.add(billId);
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
    String? promisedDate,
  }) async {
    queuedVisits.add(
      QueuedBillVisit(
        id: 'visit-${queuedVisits.length}',
        billId: billId,
        collectorId: collectorId,
        visitType: visitType,
        promisedDate: promisedDate,
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
    double? paidAmount,
    String? status,
  }) {
    return Bill(
      id: id,
      customerId: customerId,
      amount: amount,
      paidAmount: paidAmount ?? this.paidAmount,
      month: month,
      status: status ?? this.status,
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
