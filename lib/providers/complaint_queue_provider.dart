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
  List<String> _activeAreaIds = const [];
  DateTime? _lastRealtimeReloadAt;
  late bool _isOnline;
  String? _subscribedTechnicianId;
  List<String> _subscribedAreaIds = const [];
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

  List<Complaint> get resolvedThisMonth {
    final today = DateTime.now();
    return _complaints.where((c) {
      if (!c.isResolved || c.resolvedAt == null) return false;
      final d = DateTime.tryParse(c.resolvedAt!);
      return d != null && d.year == today.year && d.month == today.month;
    }).toList();
  }

  Future<void> loadForTechnician(String technicianId) async {
    await loadForTechnicianAndAreas(technicianId, const []);
  }

  Future<void> loadForAreas(List<String> areaIds, {bool silent = false}) async {
    _activeAreaIds = areaIds;
    _activeTechnicianId = null;
    _ensureRealtimeSubscription(null, areaIds);
    if (!silent) {
      _loading = true;
      _error = null;
      notifyListeners();
    }
    try {
      if (_onlineChanges == null) {
        try {
          final results = await Connectivity().checkConnectivity();
          _isOnline = results.any(
            (result) => result != ConnectivityResult.none,
          );
        } catch (e) {
          debugPrint(
            'POWERNET_DEBUG: checkConnectivity failed in loadForAreas: $e',
          );
        }
      }
      _complaints = await _repo.fetchByAreas(areaIds);
      _sortComplaints();
    } catch (e) {
      debugPrint('POWERNET_DEBUG: loadForAreas failed: $e');
      _error = 'No internet connection. Complaints could not be loaded.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> loadForTechnicianAndAreas(
    String technicianId,
    List<String> areaIds, {
    bool silent = false,
  }) async {
    _activeTechnicianId = technicianId;
    _activeAreaIds = areaIds;
    _ensureRealtimeSubscription(technicianId, areaIds);
    if (!silent) {
      _loading = true;
      _error = null;
      notifyListeners();
    }
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
      } else {
        _pendingSyncCount = await _repo.countQueuedActions();
      }
      final assigned = await _repo.fetchAssigned(technicianId);
      if (areaIds.isNotEmpty) {
        final areaComplaints = await _repo.fetchByAreas(areaIds);
        _complaints = _mergeComplaints(assigned, areaComplaints);
      } else {
        _complaints = assigned;
      }
      _sortComplaints();
      await _repo.cacheTechnicianSnapshot(
        technicianId: technicianId,
        areaIds: areaIds,
        complaints: _complaints,
      );
    } catch (e) {
      debugPrint('POWERNET_DEBUG: complaint load failed: $e');
      _complaints = await _repo.getCachedTechnicianSnapshot(
        technicianId,
        areaIds,
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
    if (!_isOnline) {
      return _queueStatus(id, 'resolved', notes: notes, hardware: hardware);
    }
    final technicianId = _technicianIdForAssignmentWrite(id);
    final clearAssignedTo = _isTeamComplaint(id);
    try {
      await _repo.resolveWithDetails(
        id,
        notes,
        hardware,
        technicianId: technicianId,
        clearAssignedTo: clearAssignedTo,
      );
      _applyLocalStatus(
        id,
        'resolved',
        technicianId: technicianId,
        notes: notes,
        hardware: hardware,
      );
      await _cacheActiveSnapshot();
      _pendingSyncCount = await _repo.countQueuedActions();
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('POWERNET_DEBUG: resolveComplaintWithOptions failed: $e');
      if (_isNetworkError(e)) {
        return _queueStatus(id, 'resolved', notes: notes, hardware: hardware);
      } else {
        _error = _getErrorMessage(e);
        notifyListeners();
        return false;
      }
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
      await _repo.syncQueuedActions(technicianId: _activeTechnicianId);
      _pendingSyncCount = await _repo.countQueuedActions();
      if (refreshAfterSync) {
        final technicianId = _activeTechnicianId;
        if (technicianId != null) {
          await loadForTechnicianAndAreas(technicianId, _activeAreaIds);
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
    if (!_isOnline) {
      return _queueStatus(id, status);
    }
    final technicianId = _technicianIdForAssignmentWrite(id);
    final clearAssignedTo = _isTeamComplaint(id);
    try {
      await _repo.updateStatus(
        id,
        status,
        technicianId: technicianId,
        clearAssignedTo: clearAssignedTo,
      );
      _applyLocalStatus(id, status, technicianId: technicianId);
      await _cacheActiveSnapshot();
      _pendingSyncCount = await _repo.countQueuedActions();
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('POWERNET_DEBUG: submit complaint status failed: $e');
      if (_isNetworkError(e)) {
        return _queueStatus(id, status);
      } else {
        _error = _getErrorMessage(e);
        notifyListeners();
        return false;
      }
    }
  }

  Future<bool> _queueStatus(
    String id,
    String status, {
    String? notes,
    String? hardware,
  }) async {
    final technicianId = _technicianIdForAssignmentWrite(id);
    final clearAssignedTo = _isTeamComplaint(id);
    try {
      await _repo.queueStatusUpdate(
        complaintId: id,
        status: status,
        assignToTechnician: technicianId != null,
        clearAssignedTo: clearAssignedTo,
        notes: notes,
        hardware: hardware,
      );
      _applyLocalStatus(
        id,
        status,
        technicianId: technicianId,
        notes: notes,
        hardware: hardware,
      );
      await _cacheActiveSnapshot();
      _pendingSyncCount = await _repo.countQueuedActions();
      _error = null;
      notifyListeners();
      return true;
    } catch (queueError) {
      debugPrint('POWERNET_DEBUG: queue complaint status failed: $queueError');
      _error = 'Local save failed. Please try again.';
      notifyListeners();
      return false;
    }
  }

  String? _technicianIdForAssignmentWrite(String complaintId) {
    if (_isTeamComplaint(complaintId)) return null;
    return _activeTechnicianId;
  }

  bool _isTeamComplaint(String complaintId) {
    final complaint = findComplaintById(complaintId);
    final teamId = complaint?.teamId;
    return teamId != null && teamId.isNotEmpty;
  }

  void _applyLocalStatus(
    String id,
    String status, {
    String? technicianId,
    String? notes,
    String? hardware,
  }) {
    final idx = _complaints.indexWhere((c) => c.id == id);
    if (idx == -1) return;
    final resolvedAt = status == 'resolved'
        ? DateTime.now().toUtc().toIso8601String()
        : null;
    final statusAt = DateTime.now().toUtc().toIso8601String();
    final updated = _complaints[idx].copyWith(
      status: status,
      assignedTo: technicianId,
      assignedAt: technicianId == null ? null : statusAt,
      inProgressAt: status == 'in_progress' ? statusAt : null,
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
      return 'No internet connection. Please connect to the internet to load complaints for the first time.';
    }
    return 'Complaints could not be loaded. Please retry or contact the administrator to verify schema configuration.';
  }

  Future<void> _cacheActiveSnapshot() async {
    final technicianId = _activeTechnicianId;
    if (technicianId == null) return;
    await _repo.cacheTechnicianSnapshot(
      technicianId: technicianId,
      areaIds: _activeAreaIds,
      complaints: _complaints,
    );
  }

  void listenToComplaints(String technicianId, List<String> areaIds) {
    _ensureRealtimeSubscription(technicianId, areaIds);
  }

  void _ensureRealtimeSubscription(String? technicianId, List<String> areaIds) {
    if (!_enableRealtime) return;
    final isSameTech = _subscribedTechnicianId == technicianId;
    final isSameAreas = listEquals(_subscribedAreaIds, areaIds);
    if (_channel != null && isSameTech && isSameAreas) {
      return;
    }
    stopListening();
    _subscribedTechnicianId = technicianId;
    _subscribedAreaIds = areaIds;
    _channel = supabase
        .channel('complaints-realtime-${identityHashCode(this)}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'complaints',
          callback: (_) {
            unawaited(_handleRealtimeChange(technicianId, areaIds));
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'team_members',
          callback: (_) {
            unawaited(_handleRealtimeChange(technicianId, areaIds));
          },
        )
        .subscribe();
  }

  Future<void> _handleRealtimeChange(
    String? technicianId,
    List<String> areaIds,
  ) async {
    final now = DateTime.now();
    if (_lastRealtimeReloadAt != null &&
        now.difference(_lastRealtimeReloadAt!) < const Duration(seconds: 1)) {
      return;
    }
    _lastRealtimeReloadAt = now;
    if (technicianId != null) {
      await loadForTechnicianAndAreas(technicianId, areaIds, silent: true);
    } else {
      await loadForAreas(areaIds, silent: true);
    }
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

  void stopListening() {
    final channel = _channel;
    if (channel != null) {
      unawaited(supabase.removeChannel(channel));
    }
    _channel = null;
    _subscribedTechnicianId = null;
    _subscribedAreaIds = const [];
  }

  @override
  void dispose() {
    unawaited(_onlineSubscription?.cancel());
    stopListening();
    super.dispose();
  }
}
