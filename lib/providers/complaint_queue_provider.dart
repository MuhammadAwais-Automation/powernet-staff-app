import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../data/complaints_repository.dart';
import '../models/complaint.dart';

class ComplaintQueueProvider extends ChangeNotifier {
  final ComplaintsRepository _repo;
  final Stream<bool>? _onlineChanges;
  final bool _enableRealtime;
  RealtimeChannel? _channel;
  StreamSubscription<bool>? _onlineSubscription;
  String? _activeTechnicianId;
  String? _activeAreaId;
  DateTime? _lastRealtimeReloadAt;
  late bool _isOnline;
  bool _syncing = false;

  List<Complaint> _complaints = [];
  bool _loading = false;
  String? _error;
  int _pendingSyncCount = 0;

  ComplaintQueueProvider({
    ComplaintsRepository? repo,
    Stream<bool>? onlineChanges,
    bool enableRealtime = true,
  }) : _repo = repo ?? ComplaintsRepository(),
       _onlineChanges = onlineChanges,
       _enableRealtime = enableRealtime {
    _isOnline = onlineChanges == null;
    _listenForConnectivity();
  }

  List<Complaint> get complaints => _complaints;
  bool get loading => _loading;
  String? get error => _error;
  int get pendingSyncCount => _pendingSyncCount;

  List<Complaint> get open => _complaints.where((c) => c.isOpen).toList();
  List<Complaint> get inProgress =>
      _complaints.where((c) => c.isInProgress).toList();
  List<Complaint> get resolvedToday {
    final today = DateTime.now();
    return _complaints.where((c) {
      if (!c.isResolved || c.resolvedAt == null) return false;
      final d = DateTime.tryParse(c.resolvedAt!);
      return d != null &&
          d.year == today.year &&
          d.month == today.month &&
          d.day == today.day;
    }).toList();
  }

  Future<void> loadForTechnician(String technicianId) async {
    await loadForTechnicianAndArea(technicianId, null);
  }

  Future<void> loadForArea(String areaId) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _complaints = await _repo.fetchByArea(areaId);
      _sortComplaints();
    } catch (e) {
      debugPrint('POWERNET_DEBUG: loadForArea failed: $e');
      _error = 'Internet band hai. Complaints load nahi ho sakin.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> loadForTechnicianAndArea(
    String technicianId,
    String? areaId,
  ) async {
    _activeTechnicianId = technicianId;
    _activeAreaId = areaId;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      if (_isOnline) {
        await syncQueuedNow(refreshAfterSync: false);
      } else {
        _pendingSyncCount = await _repo.countQueuedActions();
      }
      final assigned = await _repo.fetchAssigned(technicianId);
      if (areaId != null) {
        final areaComplaints = await _repo.fetchByArea(areaId);
        _complaints = _mergeComplaints(assigned, areaComplaints);
      } else {
        _complaints = assigned;
      }
      _sortComplaints();
      await _repo.cacheTechnicianSnapshot(
        technicianId: technicianId,
        areaId: areaId,
        complaints: _complaints,
      );
    } catch (e) {
      debugPrint('POWERNET_DEBUG: complaint load failed: $e');
      _complaints = await _repo.getCachedTechnicianSnapshot(
        technicianId,
        areaId,
      );
      _pendingSyncCount = await _repo.countQueuedActions();
      _sortComplaints();
      _error = _complaints.isEmpty ? _messageForLoadError(e) : null;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> resolveComplaint(String id) async {
    return _submitStatus(id, 'resolved');
  }

  Future<bool> resolveComplaintWithOptions(
    String id,
    String notes,
    String hardware,
  ) async {
    try {
      await _repo.resolveWithDetails(id, notes, hardware);
      _applyLocalStatus(id, 'resolved', notes: notes, hardware: hardware);
      await _cacheActiveSnapshot();
      _pendingSyncCount = await _repo.countQueuedActions();
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('POWERNET_DEBUG: resolveComplaintWithOptions failed: $e');
      return _queueStatus(id, 'resolved', notes: notes, hardware: hardware);
    }
  }

  Future<bool> startComplaint(String id) async {
    return _submitStatus(id, 'in_progress');
  }

  Complaint? findComplaintById(String id) {
    for (final complaint in _complaints) {
      if (complaint.id == id) return complaint;
    }
    return null;
  }

  Future<void> syncQueuedNow({bool refreshAfterSync = true}) async {
    if (_syncing) return;
    _syncing = true;
    try {
      await _repo.syncQueuedActions();
      _pendingSyncCount = await _repo.countQueuedActions();
      if (refreshAfterSync) {
        final technicianId = _activeTechnicianId;
        if (technicianId != null) {
          await loadForTechnicianAndArea(technicianId, _activeAreaId);
        }
      }
    } catch (e) {
      debugPrint('POWERNET_DEBUG: syncQueuedComplaints failed: $e');
    } finally {
      _syncing = false;
      notifyListeners();
    }
  }

  Future<bool> _submitStatus(String id, String status) async {
    try {
      await _repo.updateStatus(id, status);
      _applyLocalStatus(id, status);
      await _cacheActiveSnapshot();
      _pendingSyncCount = await _repo.countQueuedActions();
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('POWERNET_DEBUG: submit complaint status failed: $e');
      return _queueStatus(id, status);
    }
  }

  Future<bool> _queueStatus(
    String id,
    String status, {
    String? notes,
    String? hardware,
  }) async {
    try {
      await _repo.queueStatusUpdate(
        complaintId: id,
        status: status,
        notes: notes,
        hardware: hardware,
      );
      _applyLocalStatus(id, status, notes: notes, hardware: hardware);
      await _cacheActiveSnapshot();
      _pendingSyncCount = await _repo.countQueuedActions();
      _error = null;
      notifyListeners();
      return true;
    } catch (queueError) {
      debugPrint('POWERNET_DEBUG: queue complaint status failed: $queueError');
      _error = 'Local save failed. Dobara try karein.';
      notifyListeners();
      return false;
    }
  }

  void _applyLocalStatus(
    String id,
    String status, {
    String? notes,
    String? hardware,
  }) {
    final idx = _complaints.indexWhere((c) => c.id == id);
    if (idx == -1) return;
    final resolvedAt = status == 'resolved'
        ? DateTime.now().toUtc().toIso8601String()
        : null;
    final updated = _complaints[idx].copyWith(
      status: status,
      resolvedAt: resolvedAt,
      resolutionNotes: notes,
      hardwareUsed: hardware,
    );
    _complaints = [
      ..._complaints.take(idx),
      updated,
      ..._complaints.skip(idx + 1),
    ];
    _sortComplaints();
  }

  List<Complaint> _mergeComplaints(
    List<Complaint> assigned,
    List<Complaint> areaComplaints,
  ) {
    final merged = <String, Complaint>{};
    for (final complaint in assigned) {
      merged[complaint.id] = complaint;
    }
    for (final complaint in areaComplaints) {
      merged[complaint.id] = complaint;
    }
    return merged.values.toList();
  }

  void _sortComplaints() {
    _complaints.sort((a, b) => b.openedAt.compareTo(a.openedAt));
  }

  String _messageForLoadError(Object error) {
    final text = error.toString().toLowerCase();
    final networkIssue =
        text.contains('socketexception') ||
        text.contains('failed host lookup') ||
        text.contains('clientexception') ||
        text.contains('no address associated') ||
        text.contains('network is unreachable');
    if (networkIssue) {
      return 'Internet band hai. Pehli dafa complaints load karne ke liye internet on karein.';
    }
    return 'Complaints load nahi ho sakin. Retry karein ya admin se schema/config check karwayein.';
  }

  Future<void> _cacheActiveSnapshot() async {
    final technicianId = _activeTechnicianId;
    if (technicianId == null) return;
    await _repo.cacheTechnicianSnapshot(
      technicianId: technicianId,
      areaId: _activeAreaId,
      complaints: _complaints,
    );
  }

  void listenToComplaints(String technicianId, String? areaId) {
    if (!_enableRealtime) return;
    stopListening();
    _channel = supabase
        .channel('complaints-realtime-queue')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'complaints',
          callback: (_) {
            unawaited(_handleRealtimeChange(technicianId, areaId));
          },
        )
        .subscribe();
  }

  Future<void> _handleRealtimeChange(
    String technicianId,
    String? areaId,
  ) async {
    final now = DateTime.now();
    if (_lastRealtimeReloadAt != null &&
        now.difference(_lastRealtimeReloadAt!) < const Duration(seconds: 1)) {
      return;
    }
    _lastRealtimeReloadAt = now;
    await loadForTechnicianAndArea(technicianId, areaId);
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

  void stopListening() {
    final channel = _channel;
    if (channel != null) {
      unawaited(supabase.removeChannel(channel));
    }
    _channel = null;
  }

  @override
  void dispose() {
    unawaited(_onlineSubscription?.cancel());
    stopListening();
    super.dispose();
  }
}
