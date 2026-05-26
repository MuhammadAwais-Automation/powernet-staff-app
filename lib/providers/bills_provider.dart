import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../data/bills_repository.dart';
import '../models/bill.dart';

enum PaymentSubmissionResult { synced, queued, failed }

class BillsProvider extends ChangeNotifier {
  final BillsRepository _repo;
  final Stream<bool>? _onlineChanges;
  final bool _enableRealtime;
  RealtimeChannel? _billsChannel;
  StreamSubscription<bool>? _onlineSubscription;
  String? _activeAreaId;
  String? _activeCollectorId;
  DateTime? _lastRealtimeReloadAt;
  late bool _isOnline;
  bool _syncing = false;

  List<Bill> _bills = [];
  List<Bill> _collectedToday = [];
  List<Bill> _visitedToday = [];
  bool _loading = false;
  String? _error;
  int _pendingSyncCount = 0;

  List<Bill> get bills => _bills;
  List<Bill> get collectedToday => _collectedToday;
  List<Bill> get visitedToday => _visitedToday;
  bool get loading => _loading;
  String? get error => _error;
  int get pendingSyncCount => _pendingSyncCount;

  double get totalDue => _bills.fold(0, (sum, b) => sum + b.remaining);

  double get collectedTodayAmount =>
      _collectedToday.fold(0, (sum, b) => sum + (b.paidAmount ?? 0));

  BillsProvider({
    BillsRepository? repo,
    Stream<bool>? onlineChanges,
    bool enableRealtime = true,
  }) : _repo = repo ?? BillsRepository(),
       _onlineChanges = onlineChanges,
       _enableRealtime = enableRealtime {
    _isOnline = onlineChanges == null;
    _listenForConnectivity();
  }

  Future<void> loadPendingByArea(String areaId, String collectorId) async {
    _activeAreaId = areaId;
    _activeCollectorId = collectorId;
    _ensureRealtimeSubscription();
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      if (_isOnline) {
        await syncQueuedNow(refreshAfterSync: false);
      } else {
        _pendingSyncCount = await _repo.countQueuedOperations();
      }
      final results = await Future.wait([
        _repo.fetchPendingByArea(areaId),
        _repo.fetchCollectedToday(collectorId),
        _repo.fetchVisitedToday(collectorId),
      ]);
      _bills = results[0];
      _collectedToday = results[1];
      _visitedToday = results[2];
      await _repo.cacheRecoverySnapshot(
        areaId: areaId,
        collectorId: collectorId,
        pending: _bills,
        collectedToday: _collectedToday,
        visitedToday: _visitedToday,
      );
    } catch (e) {
      await _loadCachedSnapshot(areaId, collectorId);
      _error =
          _bills.isEmpty && _collectedToday.isEmpty && _visitedToday.isEmpty
          ? 'Internet band hai. Pehli dafa data load karne ke liye internet on karein.'
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
  }) async {
    try {
      await _repo.recordVisit(
        billId: billId,
        collectorId: collectorId,
        visitType: visitType,
      );
      _applyLocalVisit(
        billId: billId,
        collectorId: collectorId,
        visitType: visitType,
      );
      notifyListeners();
      return PaymentSubmissionResult.synced;
    } on Exception catch (e) {
      debugPrint('POWERNET_DEBUG: submitVisit failed: $e');
      try {
        await _repo.queueVisit(
          billId: billId,
          collectorId: collectorId,
          visitType: visitType,
        );
        _applyLocalVisit(
          billId: billId,
          collectorId: collectorId,
          visitType: visitType,
        );
        _pendingSyncCount = await _repo.countQueuedOperations();
        _error = null;
        notifyListeners();
        return PaymentSubmissionResult.queued;
      } on Exception catch (queueError) {
        debugPrint('POWERNET_DEBUG: queueVisit failed: $queueError');
        _error = 'Local save failed. Dobara try karein.';
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
  }) async {
    try {
      await _repo.recordPayment(
        billId: billId,
        paidAmount: amount,
        collectorId: collectorId,
        paymentMethod: paymentMethod,
        paymentNote: paymentNote,
      );
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
    } on Exception catch (e) {
      debugPrint('POWERNET_DEBUG: submitPayment failed: $e');
      try {
        await _repo.queuePayment(
          billId: billId,
          paidAmount: amount,
          collectorId: collectorId,
          paymentMethod: paymentMethod,
          paymentNote: paymentNote,
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
        _error = 'Local save failed. Dobara try karein.';
        notifyListeners();
        return PaymentSubmissionResult.failed;
      }
    }
  }

  Future<void> refreshActive() async {
    final areaId = _activeAreaId;
    final collectorId = _activeCollectorId;
    if (areaId == null || collectorId == null) return;
    await loadPendingByArea(areaId, collectorId);
  }

  Bill? findBillById(String billId) {
    for (final list in [_bills, _collectedToday, _visitedToday]) {
      for (final bill in list) {
        if (bill.id == billId) return bill;
      }
    }
    return null;
  }

  Future<void> syncQueuedNow({bool refreshAfterSync = true}) async {
    if (_syncing) return;
    _syncing = true;
    try {
      await _repo.syncQueuedOperations();
      _pendingSyncCount = await _repo.countQueuedOperations();
      if (refreshAfterSync) {
        final areaId = _activeAreaId;
        final collectorId = _activeCollectorId;
        if (areaId != null && collectorId != null) {
          final results = await Future.wait([
            _repo.fetchPendingByArea(areaId),
            _repo.fetchCollectedToday(collectorId),
            _repo.fetchVisitedToday(collectorId),
          ]);
          _bills = results[0];
          _collectedToday = results[1];
          _visitedToday = results[2];
          await _repo.cacheRecoverySnapshot(
            areaId: areaId,
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

  Future<void> _loadCachedSnapshot(String areaId, String collectorId) async {
    _bills = await _repo.getCachedPendingByArea(areaId);
    _collectedToday = await _repo.getCachedCollectedToday(collectorId);
    _visitedToday = await _repo.getCachedVisitedToday(collectorId);
    _pendingSyncCount = await _repo.countQueuedOperations();
  }

  void _applyLocalVisit({
    required String billId,
    required String collectorId,
    required String visitType,
  }) {
    final idx = _bills.indexWhere((b) => b.id == billId);
    if (idx == -1) return;
    final bill = _bills[idx];
    final updatedBill = bill.copyWith(
      collectedBy: collectorId,
      paymentMethod: 'visit',
      paymentNote: visitType,
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
      _bills = _bills.where((b) => b.id != billId).toList();
      _collectedToday = [
        bill.copyWith(
          paidAmount: newPaid,
          status: 'paid',
          collectedBy: collectorId,
          paidAt: DateTime.now().toUtc().toIso8601String(),
          paymentMethod: paymentMethod,
          paymentNote: paymentNote,
        ),
        ..._collectedToday,
      ];
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
      if (isOnline) {
        unawaited(syncQueuedNow());
      }
    });
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
