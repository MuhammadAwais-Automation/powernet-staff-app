import 'package:flutter/foundation.dart';
import '../data/complaints_repository.dart';
import '../models/complaint.dart';

class ComplaintQueueProvider extends ChangeNotifier {
  final ComplaintsRepository _repo = ComplaintsRepository();

  List<Complaint> _complaints = [];
  bool _loading = false;
  String? _error;

  List<Complaint> get complaints => _complaints;
  bool get loading => _loading;
  String? get error => _error;

  List<Complaint> get open => _complaints.where((c) => c.isOpen).toList();
  List<Complaint> get inProgress => _complaints.where((c) => c.isInProgress).toList();
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
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _complaints = await _repo.fetchAssigned(technicianId);
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> loadForArea(String areaId) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _complaints = await _repo.fetchByArea(areaId);
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> resolveComplaint(String id) async {
    try {
      await _repo.updateStatus(id, 'resolved');
      final idx = _complaints.indexWhere((c) => c.id == id);
      if (idx != -1) {
        final c = _complaints[idx];
        final updated = Complaint.fromJson({
          'id': c.id,
          'complaint_code': c.complaintCode,
          'customer_id': c.customerId,
          'issue': c.issue,
          'type': c.type,
          'priority': c.priority,
          'status': 'resolved',
          'assigned_to': c.assignedTo,
          'opened_at': c.openedAt,
          'resolved_at': DateTime.now().toUtc().toIso8601String(),
          'customer': c.customer,
          'technician': c.technician,
        });
        _complaints = List.from(_complaints)..[idx] = updated;
        notifyListeners();
      }
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> startComplaint(String id) async {
    try {
      await _repo.updateStatus(id, 'in_progress');
      final idx = _complaints.indexWhere((c) => c.id == id);
      if (idx != -1) {
        final c = _complaints[idx];
        final updated = Complaint.fromJson({
          'id': c.id,
          'complaint_code': c.complaintCode,
          'customer_id': c.customerId,
          'issue': c.issue,
          'type': c.type,
          'priority': c.priority,
          'status': 'in_progress',
          'assigned_to': c.assignedTo,
          'opened_at': c.openedAt,
          'resolved_at': c.resolvedAt,
          'customer': c.customer,
          'technician': c.technician,
        });
        _complaints = List.from(_complaints)..[idx] = updated;
        notifyListeners();
      }
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }
}
