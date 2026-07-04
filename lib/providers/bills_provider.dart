import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../data/bills_repository.dart';
import '../data/cable_bills_repository.dart';
import '../models/bill.dart';

enum CollectionServiceFilter { all, internet, cable }

enum PaymentSubmissionResult { synced, queued, failed, alreadyPaid }

class BillsProvider extends ChangeNotifier {
  final BillsRepository _repo;
  final CableBillsRepository _cableRepo;
  final Stream<bool>? _onlineChanges;
  final bool _enableRealtime;
  RealtimeChannel? _billsChannel;
  StreamSubscription<bool>? _onlineSubscription;
  List<String> _activeAreaIds = const [];
  String? _activeCollectorId;
  DateTime? _lastRealtimeReloadAt;
  late bool _isOnline;
  bool _syncing = false;

  List<Bill> _bills = [];
  List<Bill> _cableBills = [];
  List<Bill> _collectedToday = [];
  List<Bill> _cableCollectedToday = [];
  List<Bill> _visitedToday = [];
  bool _loading = false;
  String? _error;
  int _pendingSyncCount = 0;
  CollectionServiceFilter _serviceFilter = CollectionServiceFilter.all;

  List<Bill> get bills => _filteredPendingBills();
  List<Bill> get internetBills => _bills;
  List<Bill> get cableBills => _cableBills;
  CollectionServiceFilter get serviceFilter => _serviceFilter;
  List<CustomerBillLedger> get pendingLedgers =>
      CustomerBillLedger.groupBills(_filteredPendingBills());
  List<Bill> get collectedToday => _collectedToday;
  List<Bill> get visitedToday => _visitedToday;
  bool get loading => _loading;
  String? get error => _error;
  int get pendingSyncCount => _pendingSyncCount;

  double get totalDue =>
      _filteredPendingBills().fold(0, (sum, b) => sum + b.remaining);

  double get internetDue =>
      _bills.fold(0, (sum, b) => sum + b.remaining);

  double get cableDue =>
      _cableBills.fold(0, (sum, b) => sum + b.remaining);

  double get collectedTodayAmount =>
      _collectedToday.fold(0.0, (sum, b) => sum + (b.paidAmount ?? 0)) +
      _cableCollectedToday.fold(0.0, (sum, b) => sum + (b.paidAmount ?? 0));

  BillsProvider({
    BillsRepository? repo,
    CableBillsRepository? cableRepo,
    Stream<bool>? onlineChanges,
    bool enableRealtime = true,
  }) : _repo = repo ?? BillsRepository(),
       _cableRepo = cableRepo ?? CableBillsRepository(),
       _onlineChanges = onlineChanges,
       _enableRealtime = enableRealtime {
    _isOnline = onlineChanges == null;
    _listenForConnectivity();
    unawaited(_initConnectivity());
  }

  Future<void> _initConnectivity() async {
    if (_onlineChanges != null) return;
    try {
      final results = await Connectivity().checkConnectivity();
      _isOnline = results.any((result) => result != ConnectivityResult.none);
      notifyListeners();
      if (_isOnline) {
        unawaited(syncQueuedNow());
      }
    } catch (e) {
      debugPrint('POWERNET_DEBUG: checkConnectivity failed: $e');
    }
  }

  void setServiceFilter(CollectionServiceFilter filter) {
    if (_serviceFilter == filter) return;
    _serviceFilter = filter;
    notifyListeners();
  }

  List<Bill> _filteredPendingBills() {
    switch (_serviceFilter) {
      case CollectionServiceFilter.internet:
        return _bills;
      case CollectionServiceFilter.cable:
        return _cableBills;
      case CollectionServiceFilter.all:
        return [..._bills, ..._cableBills];
    }
  }

  Future<void> loadPendingByAreas(
    List<String> areaIds,
    String collectorId,
  ) async {
    _activeAreaIds = areaIds;
    _activeCollectorId = collectorId;
    _ensureRealtimeSubscription();
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      if (_onlineChanges == null) {
        try {
          final results = await Connectivity().checkConnectivity();
          _isOnline = results.any(
            (result) => result != ConnectivityResult.none,
          );
        } catch (e) {
          debugPrint('POWERNET_DEBUG: checkConnectivity failed in load: $e');
        }
      }
      if (_isOnline) {
        await syncQueuedNow(refreshAfterSync: false);
        final results = await Future.wait([
          _repo.fetchPendingByAreas(areaIds),
          _cableRepo.fetchPendingByAreas(areaIds),
          _repo.fetchPaidTodayByAreas(areaIds),
          _cableRepo.fetchPaidTodayByAreas(areaIds),
          _repo.fetchVisitedToday(collectorId),
        ]).timeout(const Duration(seconds: 6));
        _bills = results[0];
        _cableBills = results[1];
        _collectedToday = results[2];
        _cableCollectedToday = results[3];
        _visitedToday = results[4];
        await _repo.cacheRecoverySnapshot(
          areaIds: areaIds,
          collectorId: collectorId,
          pending: _bills,
          collectedToday: _collectedToday,
          visitedToday: _visitedToday,
        );
      } else {
        _pendingSyncCount = await _repo.countQueuedOperations();
        await _loadCachedSnapshot(areaIds, collectorId);
      }
    } catch (e) {
      await _loadCachedSnapshot(areaIds, collectorId);
      _error =
          _bills.isEmpty && _collectedToday.isEmpty && _visitedToday.isEmpty
          ? 'No internet connection. Please connect to the internet to load data for the first time.'
          : null;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> collectPayment({
    required String billId,
    required double amount,
    required String collectorId,
    required String paymentMethod,
    String? paymentNote,
  }) async {
    final result = await submitPayment(
      billId: billId,
      amount: amount,
      collectorId: collectorId,
      paymentMethod: paymentMethod,
      paymentNote: paymentNote,
    );
    return result != PaymentSubmissionResult.failed;
  }

  Future<PaymentSubmissionResult> submitVisit({
    required String billId,
    required String collectorId,
    required String visitType,
    String? promisedDate,
  }) async {
    if (!_isOnline) {
      try {
        await _repo.queueVisit(
          billId: billId,
          collectorId: collectorId,
          visitType: visitType,
          promisedDate: promisedDate,
        );
        _applyLocalVisit(
          billId: billId,
          collectorId: collectorId,
          visitType: visitType,
          promisedDate: promisedDate,
        );
        _pendingSyncCount = await _repo.countQueuedOperations();
        _error = null;
        notifyListeners();
        return PaymentSubmissionResult.queued;
      } on Exception catch (queueError) {
        debugPrint('POWERNET_DEBUG: queueVisit failed: $queueError');
        _error = 'Local save failed. Please try again.';
        notifyListeners();
        return PaymentSubmissionResult.failed;
      }
    }

    try {
      await _repo.recordVisit(
        billId: billId,
        collectorId: collectorId,
        visitType: visitType,
        promisedDate: promisedDate,
      ).timeout(const Duration(seconds: 4));
      _applyLocalVisit(
        billId: billId,
        collectorId: collectorId,
        visitType: visitType,
        promisedDate: promisedDate,
      );
      notifyListeners();
      return PaymentSubmissionResult.synced;
    } on Exception catch (e) {
      debugPrint('POWERNET_DEBUG: submitVisit failed: $e');
      if (_isNetworkError(e)) {
        try {
          await _repo.queueVisit(
            billId: billId,
            collectorId: collectorId,
            visitType: visitType,
            promisedDate: promisedDate,
          );
          _applyLocalVisit(
            billId: billId,
            collectorId: collectorId,
            visitType: visitType,
            promisedDate: promisedDate,
          );
          _pendingSyncCount = await _repo.countQueuedOperations();
          _error = null;
          notifyListeners();
          return PaymentSubmissionResult.queued;
        } on Exception catch (queueError) {
          debugPrint('POWERNET_DEBUG: queueVisit failed: $queueError');
          _error = 'Local save failed. Please try again.';
          notifyListeners();
          return PaymentSubmissionResult.failed;
        }
      } else {
        _error = _getErrorMessage(e);
        notifyListeners();
        return PaymentSubmissionResult.failed;
      }
    }
  }

  Future<PaymentSubmissionResult> submitPayment({
    required String billId,
    required double amount,
    required String collectorId,
    required String paymentMethod,
    String? paymentNote,
    String? receiptUrl,
    RemainderAction remainderAction = RemainderAction.leave,
  }) async {
    final targetBill = findBillById(billId);
    final isCable = targetBill?.isCable ?? false;

    if (isCable) {
      if (!_isOnline) {
        _error = 'Cable collection needs an internet connection.';
        notifyListeners();
        return PaymentSubmissionResult.failed;
      }
      try {
        await _cableRepo.recordPayment(
          billId: billId,
          paidAmount: amount,
          collectorId: collectorId,
          paymentMethod: paymentMethod,
          paymentNote: paymentNote,
        ).timeout(const Duration(seconds: 4));
        _applyLocalCablePayment(
          billId: billId,
          amount: amount,
          collectorId: collectorId,
          paymentMethod: paymentMethod,
          paymentNote: paymentNote,
        );
        notifyListeners();
        return PaymentSubmissionResult.synced;
      } on Exception catch (e) {
        debugPrint('POWERNET_DEBUG: submitCablePayment failed: $e');
        _error = 'Could not record cable payment.';
        notifyListeners();
        return PaymentSubmissionResult.failed;
      }
    }

    if (!_isOnline) {
      try {
        await _repo.queuePayment(
          billId: billId,
          paidAmount: amount,
          collectorId: collectorId,
          paymentMethod: paymentMethod,
          paymentNote: paymentNote,
          receiptUrl: receiptUrl,
          remainderAction: remainderAction,
        );
        _applyLocalPayment(
          billId: billId,
          amount: amount,
          collectorId: collectorId,
          paymentMethod: paymentMethod,
          paymentNote: paymentNote,
        );
        _pendingSyncCount = await _repo.countQueuedOperations();
        _error = null;
        notifyListeners();
        return PaymentSubmissionResult.queued;
      } on Exception catch (queueError) {
        debugPrint('POWERNET_DEBUG: queuePayment failed: $queueError');
        _error = 'Local save failed. Please try again.';
        notifyListeners();
        return PaymentSubmissionResult.failed;
      }
    }

    try {
      await _repo.recordPayment(
        billId: billId,
        paidAmount: amount,
        collectorId: collectorId,
        paymentMethod: paymentMethod,
        paymentNote: paymentNote,
        receiptUrl: receiptUrl,
        remainderAction: remainderAction,
      ).timeout(const Duration(seconds: 4));
      _applyLocalPayment(
        billId: billId,
        amount: amount,
        collectorId: collectorId,
        paymentMethod: paymentMethod,
        paymentNote: paymentNote,
      );
      _pendingSyncCount = await _repo.countQueuedOperations();
      notifyListeners();
      return PaymentSubmissionResult.synced;
    } on BillAlreadyPaidException catch (e) {
      _removeBillFromPending(billId);
      await refreshActive();
      _error = e.toString();
      notifyListeners();
      return PaymentSubmissionResult.alreadyPaid;
    } on BillPaymentConflictException catch (e) {
      await refreshActive();
      _error = e.toString();
      notifyListeners();
      return PaymentSubmissionResult.failed;
    } on Exception catch (e) {
      debugPrint('POWERNET_DEBUG: submitPayment failed: $e');
      if (_isNetworkError(e)) {
        try {
          await _repo.queuePayment(
            billId: billId,
            paidAmount: amount,
            collectorId: collectorId,
            paymentMethod: paymentMethod,
            paymentNote: paymentNote,
            receiptUrl: receiptUrl,
            remainderAction: remainderAction,
          );
          _applyLocalPayment(
            billId: billId,
            amount: amount,
            collectorId: collectorId,
            paymentMethod: paymentMethod,
            paymentNote: paymentNote,
          );
          _pendingSyncCount = await _repo.countQueuedOperations();
          _error = null;
          notifyListeners();
          return PaymentSubmissionResult.queued;
        } on Exception catch (queueError) {
          debugPrint('POWERNET_DEBUG: queuePayment failed: $queueError');
          _error = 'Local save failed. Please try again.';
          notifyListeners();
          return PaymentSubmissionResult.failed;
        }
      } else {
        _error = _getErrorMessage(e);
        notifyListeners();
        return PaymentSubmissionResult.failed;
      }
    }
  }

  Future<void> refreshActive() async {
    final areaIds = _activeAreaIds;
    final collectorId = _activeCollectorId;
    if (areaIds.isEmpty || collectorId == null) return;
    await loadPendingByAreas(areaIds, collectorId);
  }

  Bill? findBillById(String billId) {
    for (final list in [
      _bills,
      _cableBills,
      _collectedToday,
      _cableCollectedToday,
      _visitedToday,
    ]) {
      for (final bill in list) {
        if (bill.id == billId) return bill;
      }
    }
    return null;
  }

  CustomerBillLedger? findLedgerByBillId(String billId) {
    for (final ledger in pendingLedgers) {
      if (ledger.bills.any((bill) => bill.id == billId)) return ledger;
    }
    return null;
  }

  CustomerBillLedger? findLedgerByCustomerId(String customerId) {
    for (final ledger in pendingLedgers) {
      if (ledger.customerId == customerId) return ledger;
    }
    return null;
  }

  Future<PaymentSubmissionResult> submitLedgerPayment({
    required CustomerBillLedger ledger,
    required double amount,
    required String collectorId,
    required String paymentMethod,
    String? paymentNote,
    String? receiptUrl,
    RemainderAction remainderAction = RemainderAction.leave,
  }) async {
    var remainingPayment = amount;
    var finalResult = PaymentSubmissionResult.synced;
    var appliedAnyPayment = false;
    var skippedStalePaid = false;
    final oldestFirst = [...ledger.bills.reversed];

    for (final bill in oldestFirst) {
      if (remainingPayment <= 0) break;
      Bill? liveBill;
      if (_isOnline) {
        try {
          liveBill = bill.isCable
              ? await _cableRepo.fetchById(bill.id).timeout(const Duration(seconds: 4))
              : await _repo.fetchById(bill.id).timeout(const Duration(seconds: 4));
        } catch (e) {
          debugPrint('POWERNET_DEBUG: fetchById failed or timed out: $e. Using local data.');
          liveBill = bill;
        }
      } else {
        liveBill = bill;
      }
      if (liveBill == null || liveBill.remaining <= 0 || liveBill.isPaid) {
        skippedStalePaid = true;
        _removeBillFromPending(bill.id);
        continue;
      }
      final amountForBill = remainingPayment > liveBill.remaining
          ? liveBill.remaining
          : remainingPayment;
      if (amountForBill <= 0) continue;

      final isPartialBill = amountForBill < liveBill.remaining;
      final billRemainderAction =
          isPartialBill &&
              remainingPayment <= amountForBill &&
              remainderAction == RemainderAction.carryForward
          ? RemainderAction.carryForward
          : RemainderAction.leave;

      final result = await submitPayment(
        billId: liveBill.id,
        amount: amountForBill,
        collectorId: collectorId,
        paymentMethod: paymentMethod,
        paymentNote: paymentNote,
        receiptUrl: receiptUrl,
        remainderAction: billRemainderAction,
      );
      if (result == PaymentSubmissionResult.failed) return result;
      if (result == PaymentSubmissionResult.alreadyPaid) {
        skippedStalePaid = true;
        continue;
      }
      if (result == PaymentSubmissionResult.queued) {
        finalResult = PaymentSubmissionResult.queued;
      }
      appliedAnyPayment = true;
      remainingPayment -= amountForBill;
    }

    if (!appliedAnyPayment && skippedStalePaid) {
      await refreshActive();
      _error = 'Bill already paid. Collection list refreshed.';
      notifyListeners();
      return PaymentSubmissionResult.alreadyPaid;
    }
    if (skippedStalePaid) {
      await refreshActive();
    }
    return finalResult;
  }

  Future<void> syncQueuedNow({bool refreshAfterSync = true}) async {
    if (_syncing) return;
    _syncing = true;
    try {
      await _repo.syncQueuedOperations();
      _pendingSyncCount = await _repo.countQueuedOperations();
      if (refreshAfterSync) {
        final areaIds = _activeAreaIds;
        final collectorId = _activeCollectorId;
        if (areaIds.isNotEmpty && collectorId != null) {
          final results = await Future.wait([
            _repo.fetchPendingByAreas(areaIds),
            _repo.fetchPaidTodayByAreas(areaIds),
            _repo.fetchVisitedToday(collectorId),
          ]);
          _bills = results[0];
          _collectedToday = results[1];
          _visitedToday = results[2];
          await _repo.cacheRecoverySnapshot(
            areaIds: areaIds,
            collectorId: collectorId,
            pending: _bills,
            collectedToday: _collectedToday,
            visitedToday: _visitedToday,
          );
          _error = null;
        }
      }
    } catch (e) {
      debugPrint('POWERNET_DEBUG: syncQueuedNow failed: $e');
    } finally {
      _syncing = false;
      notifyListeners();
    }
  }

  Future<void> _loadCachedSnapshot(
    List<String> areaIds,
    String collectorId,
  ) async {
    _bills = await _repo.getCachedPendingByAreas(areaIds);
    _collectedToday = await _repo.getCachedCollectedToday(collectorId);
    _visitedToday = await _repo.getCachedVisitedToday(collectorId);
    _pendingSyncCount = await _repo.countQueuedOperations();
  }

  void _applyLocalVisit({
    required String billId,
    required String collectorId,
    required String visitType,
    String? promisedDate,
  }) {
    final idx = _bills.indexWhere((b) => b.id == billId);
    if (idx == -1) return;
    final bill = _bills[idx];
    final updatedBill = bill.copyWith(
      collectedBy: collectorId,
      paymentMethod: 'visit',
      paymentNote: visitType,
      promisedDate: visitType == VisitType.promiseToPay.value
          ? promisedDate
          : null,
      paidAt: DateTime.now().toUtc().toIso8601String(),
    );
    _bills = [..._bills.take(idx), updatedBill, ..._bills.skip(idx + 1)];
    final alreadyInVisits = _visitedToday.any((b) => b.id == billId);
    if (!alreadyInVisits) {
      _visitedToday = [updatedBill, ..._visitedToday];
    }
  }

  void _applyLocalPayment({
    required String billId,
    required double amount,
    required String collectorId,
    required String paymentMethod,
    String? paymentNote,
  }) {
    final idx = _bills.indexWhere((b) => b.id == billId);
    if (idx == -1) return;

    final bill = _bills[idx];
    final newPaid = (bill.paidAmount ?? 0) + amount;
    if (newPaid >= bill.amount) {
      final paidBill = bill.copyWith(
        paidAmount: newPaid,
        status: 'paid',
        collectedBy: collectorId,
        paidAt: DateTime.now().toUtc().toIso8601String(),
        paymentMethod: paymentMethod,
        paymentNote: paymentNote,
      );
      _bills = [..._bills.take(idx), paidBill, ..._bills.skip(idx + 1)];
      _collectedToday = [paidBill, ..._collectedToday];
      return;
    }

    _bills = [
      ..._bills.take(idx),
      bill.copyWith(
        paidAmount: newPaid,
        collectedBy: collectorId,
        paymentMethod: paymentMethod,
        paymentNote: paymentNote,
      ),
      ..._bills.skip(idx + 1),
    ];
  }

  void _applyLocalCablePayment({
    required String billId,
    required double amount,
    required String collectorId,
    required String paymentMethod,
    String? paymentNote,
  }) {
    final idx = _cableBills.indexWhere((b) => b.id == billId);
    if (idx == -1) return;

    final bill = _cableBills[idx];
    final newPaid = (bill.paidAmount ?? 0) + amount;
    if (newPaid >= bill.amount) {
      final paidBill = bill.copyWith(
        paidAmount: newPaid,
        status: 'paid',
        collectedBy: collectorId,
        paidAt: DateTime.now().toUtc().toIso8601String(),
        paymentMethod: paymentMethod,
        paymentNote: paymentNote,
      );
      _cableBills = [..._cableBills.take(idx), paidBill, ..._cableBills.skip(idx + 1)];
      _cableCollectedToday = [paidBill, ..._cableCollectedToday];
      return;
    }

    _cableBills = [
      ..._cableBills.take(idx),
      bill.copyWith(
        paidAmount: newPaid,
        collectedBy: collectorId,
        paymentMethod: paymentMethod,
        paymentNote: paymentNote,
      ),
      ..._cableBills.skip(idx + 1),
    ];
  }

  void _removeBillFromPending(String billId) {
    _bills = _bills.where((bill) => bill.id != billId).toList();
    _cableBills = _cableBills.where((bill) => bill.id != billId).toList();
  }

  void _ensureRealtimeSubscription() {
    if (!_enableRealtime) return;
    if (_billsChannel != null) return;
    _billsChannel = supabase
        .channel('recovery-bills-${identityHashCode(this)}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'bills',
          callback: (_) {
            unawaited(_handleRealtimeChange());
          },
        )
        .subscribe();
  }

  void _listenForConnectivity() {
    final stream =
        _onlineChanges ??
        Connectivity().onConnectivityChanged.map(
          (results) =>
              results.any((result) => result != ConnectivityResult.none),
        );
    _onlineSubscription = stream.listen((isOnline) {
      _isOnline = isOnline;
      notifyListeners();
      if (isOnline) {
        unawaited(syncQueuedNow());
      }
    });
  }

  bool _isNetworkError(Object error) {
    if (error is PostgrestException || error is AuthException) {
      return false;
    }
    final text = error.toString().toLowerCase();
    return text.contains('socketexception') ||
        text.contains('failed host lookup') ||
        text.contains('clientexception') ||
        text.contains('no address associated') ||
        text.contains('network is unreachable') ||
        text.contains('offline') ||
        text.contains('timeout');
  }

  String _getErrorMessage(Object error) {
    if (error is PostgrestException) {
      return error.message;
    }
    if (error is AuthException) {
      return error.message;
    }
    return error.toString();
  }

  Future<void> _handleRealtimeChange() async {
    final now = DateTime.now();
    if (_lastRealtimeReloadAt != null &&
        now.difference(_lastRealtimeReloadAt!) < const Duration(seconds: 1)) {
      return;
    }
    _lastRealtimeReloadAt = now;
    await refreshActive();
  }

  @override
  void dispose() {
    unawaited(_onlineSubscription?.cancel());
    final channel = _billsChannel;
    if (channel != null) {
      unawaited(supabase.removeChannel(channel));
    }
    super.dispose();
  }
}
