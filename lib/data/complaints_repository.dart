import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/supabase_config.dart';
import '../models/complaint.dart';

const complaintBaseSelect =
    'id, complaint_code, customer_id, issue, type, priority, status, '
    'assigned_to, assigned_at, in_progress_at, opened_at, resolved_at, resolution_notes, hardware_used, '
    'customer:customers(id, full_name, area_id, customer_code, address_value, phone), '
    'technician:staff(id, full_name)';

const complaintLegacyBaseSelect =
    'id, complaint_code, customer_id, issue, type, priority, status, '
    'assigned_to, opened_at, resolved_at, '
    'customer:customers(id, full_name, area_id, customer_code, address_value, phone), '
    'technician:staff(id, full_name)';

const complaintAreaSelect =
    'id, complaint_code, customer_id, issue, type, priority, status, '
    'assigned_to, assigned_at, in_progress_at, opened_at, resolved_at, resolution_notes, hardware_used, '
    'customer:customers!inner(id, full_name, area_id, customer_code, address_value, phone), '
    'technician:staff(id, full_name)';

const complaintLegacyAreaSelect =
    'id, complaint_code, customer_id, issue, type, priority, status, '
    'assigned_to, opened_at, resolved_at, '
    'customer:customers!inner(id, full_name, area_id, customer_code, address_value, phone), '
    'technician:staff(id, full_name)';

const _queuedActionsKey = 'queued_complaint_actions';
const _cachedTechnicianPrefix = 'cached_technician_complaints_';

class QueuedComplaintAction {
  final String id;
  final String complaintId;
  final String status;
  final String? notes;
  final String? hardware;
  final String queuedAt;

  const QueuedComplaintAction({
    required this.id,
    required this.complaintId,
    required this.status,
    this.notes,
    this.hardware,
    required this.queuedAt,
  });

  factory QueuedComplaintAction.fromJson(Map<String, dynamic> json) =>
      QueuedComplaintAction(
        id: json['id'] as String,
        complaintId: json['complaint_id'] as String,
        status: json['status'] as String,
        notes: json['notes'] as String?,
        hardware: json['hardware'] as String?,
        queuedAt: json['queued_at'] as String,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'complaint_id': complaintId,
    'status': status,
    'notes': notes,
    'hardware': hardware,
    'queued_at': queuedAt,
  };
}

class ComplaintsRepository {
  Future<List<Complaint>> fetchAssigned(String technicianId) async {
    try {
      return await _fetchAssigned(technicianId, complaintBaseSelect);
    } catch (e) {
      if (!_isMissingResolutionColumns(e)) rethrow;
      return _fetchAssigned(technicianId, complaintLegacyBaseSelect);
    }
  }

  Future<List<Complaint>> fetchByAreas(List<String> areaIds) async {
    try {
      return await _fetchByAreas(areaIds, complaintAreaSelect);
    } catch (e) {
      if (!_isMissingResolutionColumns(e)) rethrow;
      return _fetchByAreas(areaIds, complaintLegacyAreaSelect);
    }
  }

  Future<List<Complaint>> fetchAll({String? status}) async {
    try {
      return await _fetchAll(status: status, select: complaintBaseSelect);
    } catch (e) {
      if (!_isMissingResolutionColumns(e)) rethrow;
      return _fetchAll(status: status, select: complaintLegacyBaseSelect);
    }
  }

  Future<Complaint?> fetchById(String id) async {
    try {
      return await _fetchById(id, complaintBaseSelect);
    } catch (e) {
      if (!_isMissingResolutionColumns(e)) rethrow;
      return _fetchById(id, complaintLegacyBaseSelect);
    }
  }

  Future<void> updateStatus(String id, String status) async {
    final update = <String, dynamic>{'status': status};
    if (status == 'in_progress') {
      update['in_progress_at'] = DateTime.now().toUtc().toIso8601String();
    }
    if (status == 'resolved') {
      update['resolved_at'] = DateTime.now().toUtc().toIso8601String();
    }
    await supabase.from('complaints').update(update).eq('id', id);
  }

  Future<void> resolveWithDetails(
    String id,
    String notes,
    String hardware,
  ) async {
    try {
      await supabase
          .from('complaints')
          .update({
            'status': 'resolved',
            'resolved_at': DateTime.now().toUtc().toIso8601String(),
            'resolution_notes': notes,
            'hardware_used': hardware,
          })
          .eq('id', id);
    } catch (e) {
      if (!_isMissingResolutionColumns(e)) rethrow;
      await updateStatus(id, 'resolved');
    }
  }

  Future<void> assignTo(String complaintId, String technicianId) async {
    await supabase
        .from('complaints')
        .update({
          'assigned_to': technicianId,
          'assigned_at': DateTime.now().toUtc().toIso8601String(),
          'status': 'in_progress',
          'in_progress_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', complaintId);
  }

  Future<List<QueuedComplaintAction>> getQueuedActions() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_queuedActionsKey);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((j) => QueuedComplaintAction.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<void> queueStatusUpdate({
    required String complaintId,
    required String status,
    String? notes,
    String? hardware,
  }) async {
    final queued = await getQueuedActions();
    final draft = QueuedComplaintAction(
      id: '${DateTime.now().microsecondsSinceEpoch}-$complaintId',
      complaintId: complaintId,
      status: status,
      notes: notes,
      hardware: hardware,
      queuedAt: DateTime.now().toUtc().toIso8601String(),
    );
    await _saveQueuedActions([...queued, draft]);
  }

  Future<int> syncQueuedActions() async {
    final queued = await getQueuedActions();
    if (queued.isEmpty) return 0;

    final remaining = <QueuedComplaintAction>[];
    var synced = 0;
    for (final action in queued) {
      try {
        if (action.status == 'resolved' && action.notes != null) {
          await resolveWithDetails(
            action.complaintId,
            action.notes!,
            action.hardware ?? '',
          );
        } else {
          await updateStatus(action.complaintId, action.status);
        }
        synced++;
      } catch (e) {
        debugPrint(
          'POWERNET_DEBUG: syncQueuedComplaint failed for '
          '${action.complaintId}: $e',
        );
        remaining.add(action);
      }
    }
    await _saveQueuedActions(remaining);
    return synced;
  }

  Future<int> countQueuedActions() async {
    final queued = await getQueuedActions();
    return queued.length;
  }

  Future<void> cacheTechnicianSnapshot({
    required String technicianId,
    required List<String> areaIds,
    required List<Complaint> complaints,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _cacheKey(technicianId, areaIds),
      jsonEncode(complaints.map((c) => c.toJson()).toList()),
    );
  }

  Future<List<Complaint>> getCachedTechnicianSnapshot(
    String technicianId,
    List<String> areaIds,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey(technicianId, areaIds));
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((j) => Complaint.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<void> _saveQueuedActions(List<QueuedComplaintAction> actions) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _queuedActionsKey,
      jsonEncode(actions.map((a) => a.toJson()).toList()),
    );
  }

  String _cacheKey(String technicianId, List<String> areaIds) =>
      '$_cachedTechnicianPrefix$technicianId-${areaIds.isEmpty ? 'none' : areaIds.join('-')}';

  Future<List<Complaint>> _fetchAssigned(
    String technicianId,
    String select,
  ) async {
    final res = await supabase
        .from('complaints')
        .select(select)
        .eq('assigned_to', technicianId)
        .inFilter('status', ['open', 'in_progress'])
        .order('opened_at', ascending: false);
    return _parseComplaintList(res);
  }

  Future<List<Complaint>> _fetchByAreas(
    List<String> areaIds,
    String select,
  ) async {
    if (areaIds.isEmpty) return [];
    final res = await supabase
        .from('complaints')
        .select(select)
        .inFilter('customer.area_id', areaIds)
        .inFilter('status', ['open', 'in_progress'])
        .order('opened_at', ascending: false);
    return _parseComplaintList(res);
  }

  Future<List<Complaint>> _fetchAll({
    required String? status,
    required String select,
  }) async {
    var query = supabase.from('complaints').select(select);
    if (status != null) query = query.eq('status', status);
    final res = await query.order('opened_at', ascending: false).limit(100);
    return _parseComplaintList(res);
  }

  Future<Complaint?> _fetchById(String id, String select) async {
    final res = await supabase
        .from('complaints')
        .select(select)
        .eq('id', id)
        .maybeSingle();
    if (res == null) return null;
    return Complaint.fromJson(res);
  }

  List<Complaint> _parseComplaintList(Object? res) {
    return (res as List)
        .map((j) => Complaint.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  bool _isMissingResolutionColumns(Object error) {
    final text = error.toString();
    return text.contains('42703') ||
        text.contains('resolution_notes') ||
        text.contains('hardware_used') ||
        text.contains('assigned_at') ||
        text.contains('in_progress_at');
  }
}
