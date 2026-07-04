import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/complaint.dart';

const complaintBaseSelect =
    'id, complaint_code, customer_id, issue, type, service_line, priority, status, '
    'assigned_to, assigned_at, in_progress_at, opened_at, resolved_at, resolution_notes, hardware_used, team_id, '
    'customer:customers(id, full_name, area_id, customer_code, address_value, phone), '
    'technician:staff(id, full_name), '
    'team:teams(id, name)';

const complaintLegacyBaseSelect =
    'id, complaint_code, customer_id, issue, type, priority, status, '
    'assigned_to, opened_at, resolved_at, '
    'customer:customers(id, full_name, area_id, customer_code, address_value, phone), '
    'technician:staff(id, full_name)';

const complaintAreaSelect =
    'id, complaint_code, customer_id, issue, type, service_line, priority, status, '
    'assigned_to, assigned_at, in_progress_at, opened_at, resolved_at, resolution_notes, hardware_used, team_id, '
    'customer:customers!inner(id, full_name, area_id, customer_code, address_value, phone), '
    'technician:staff(id, full_name), '
    'team:teams(id, name)';

const complaintLegacyAreaSelect =
    'id, complaint_code, customer_id, issue, type, priority, status, '
    'assigned_to, opened_at, resolved_at, '
    'customer:customers!inner(id, full_name, area_id, customer_code, address_value, phone), '
    'technician:staff(id, full_name)';

const _queuedActionsKey = 'queued_complaint_actions';
const _cachedTechnicianPrefix = 'cached_technician_complaints_';
const _defaultManagerApiBaseUrl = 'https://powernet-manager.vercel.app';

class QueuedComplaintAction {
  final String id;
  final String complaintId;
  final String status;
  final bool assignToTechnician;
  final bool clearAssignedTo;
  final String? notes;
  final String? hardware;
  final String queuedAt;

  const QueuedComplaintAction({
    required this.id,
    required this.complaintId,
    required this.status,
    required this.assignToTechnician,
    this.clearAssignedTo = false,
    this.notes,
    this.hardware,
    required this.queuedAt,
  });

  factory QueuedComplaintAction.fromJson(Map<String, dynamic> json) =>
      QueuedComplaintAction(
        id: json['id'] as String,
        complaintId: json['complaint_id'] as String,
        status: json['status'] as String,
        assignToTechnician: json['assign_to_technician'] as bool? ?? true,
        clearAssignedTo: json['clear_assigned_to'] as bool? ?? false,
        notes: json['notes'] as String?,
        hardware: json['hardware'] as String?,
        queuedAt: json['queued_at'] as String,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'complaint_id': complaintId,
    'status': status,
    'assign_to_technician': assignToTechnician,
    'clear_assigned_to': clearAssignedTo,
    'notes': notes,
    'hardware': hardware,
    'queued_at': queuedAt,
  };
}

class ComplaintsRepository {
  Future<List<Complaint>> fetchAssigned(
    String technicianId, {
    String? serviceLine,
  }) async {
    try {
      return _filterByServiceLine(
        await _fetchAssigned(technicianId, complaintBaseSelect, serviceLine: serviceLine),
        serviceLine,
      );
    } catch (e) {
      if (!_isMissingResolutionColumns(e) && !_isMissingServiceLineColumn(e)) rethrow;
      return _filterByServiceLine(
        await _fetchAssigned(technicianId, complaintLegacyBaseSelect, serviceLine: null),
        serviceLine,
      );
    }
  }

  Future<List<Complaint>> fetchByAreas(
    List<String> areaIds, {
    String? serviceLine,
  }) async {
    try {
      return _filterByServiceLine(
        await _fetchByAreas(areaIds, complaintAreaSelect, serviceLine: serviceLine),
        serviceLine,
      );
    } catch (e) {
      if (!_isMissingResolutionColumns(e) && !_isMissingServiceLineColumn(e)) rethrow;
      return _filterByServiceLine(
        await _fetchByAreas(areaIds, complaintLegacyAreaSelect, serviceLine: null),
        serviceLine,
      );
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

  Future<void> updateStatus(
    String id,
    String status, {
    String? technicianId,
    bool clearAssignedTo = false,
  }) async {
    final update = <String, dynamic>{'status': status};
    if (status == 'in_progress') {
      update['in_progress_at'] = DateTime.now().toUtc().toIso8601String();
    }
    if (status == 'resolved') {
      update['resolved_at'] = DateTime.now().toUtc().toIso8601String();
    }
    if (technicianId != null) {
      update['assigned_to'] = technicianId;
      update['assigned_at'] = DateTime.now().toUtc().toIso8601String();
    } else if (clearAssignedTo) {
      update['assigned_to'] = null;
    }
    await supabase.from('complaints').update(update).eq('id', id);
  }

  Future<void> resolveWithDetails(
    String id,
    String notes,
    String hardware, {
    String? technicianId,
    bool clearAssignedTo = false,
  }) async {
    try {
      final update = <String, dynamic>{
        'status': 'resolved',
        'resolved_at': DateTime.now().toUtc().toIso8601String(),
        'resolution_notes': notes,
        'hardware_used': hardware,
      };
      if (technicianId != null) {
        update['assigned_to'] = technicianId;
        update['assigned_at'] = DateTime.now().toUtc().toIso8601String();
      } else if (clearAssignedTo) {
        update['assigned_to'] = null;
      }
      await supabase.from('complaints').update(update).eq('id', id);
    } catch (e) {
      if (!_isMissingResolutionColumns(e)) rethrow;
      await updateStatus(
        id,
        'resolved',
        technicianId: technicianId,
        clearAssignedTo: clearAssignedTo,
      );
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
    required bool assignToTechnician,
    bool clearAssignedTo = false,
    String? notes,
    String? hardware,
  }) async {
    final queued = await getQueuedActions();
    final draft = QueuedComplaintAction(
      id: '${DateTime.now().microsecondsSinceEpoch}-$complaintId',
      complaintId: complaintId,
      status: status,
      assignToTechnician: assignToTechnician,
      clearAssignedTo: clearAssignedTo,
      notes: notes,
      hardware: hardware,
      queuedAt: DateTime.now().toUtc().toIso8601String(),
    );
    await _saveQueuedActions([
      ...queued.where((action) => action.complaintId != complaintId),
      draft,
    ]);
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

  Future<int> syncQueuedActions({String? technicianId}) async {
    final queued = await getQueuedActions();
    if (queued.isEmpty) return 0;

    final remaining = <QueuedComplaintAction>[];
    var synced = 0;
    for (final action in queued) {
      try {
        final actionTechnicianId = action.assignToTechnician
            ? technicianId
            : null;
        if (action.status == 'resolved' && action.notes != null) {
          await resolveWithDetails(
            action.complaintId,
            action.notes!,
            action.hardware ?? '',
            technicianId: actionTechnicianId,
            clearAssignedTo: action.clearAssignedTo,
          );
        } else {
          await updateStatus(
            action.complaintId,
            action.status,
            technicianId: actionTechnicianId,
            clearAssignedTo: action.clearAssignedTo,
          );
        }
        synced++;
      } catch (e) {
        debugPrint(
          'POWERNET_DEBUG: syncQueuedComplaint failed for '
          '${action.complaintId}: $e',
        );
        if (_isNetworkError(e)) {
          remaining.add(action);
        } else {
          debugPrint(
            'POWERNET_DEBUG: Discarding queued complaint action for complaint ${action.complaintId} due to permanent error: $e',
          );
        }
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
    String select, {
    String? serviceLine,
  }) async {
    final startOfMonth = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      1,
    ).toUtc().toIso8601String();

    final teamIds = await _fetchTeamIdsForStaff(technicianId);

    var orCondition = 'assigned_to.eq.$technicianId';
    if (teamIds.isNotEmpty) {
      orCondition += ',team_id.in.(${teamIds.join(",")})';
    }

    var query = supabase
        .from('complaints')
        .select(select)
        .or(orCondition)
        .or(
          'status.in.(open,in_progress),and(status.eq.resolved,resolved_at.gte.$startOfMonth)',
        );
    if (serviceLine != null && select.contains('service_line')) {
      query = query.eq('service_line', serviceLine);
    }
    final res = await query.order('opened_at', ascending: false);
    return _parseComplaintList(res);
  }

  Future<List<String>> _fetchTeamIdsForStaff(String technicianId) async {
    try {
      final teamMembersRes = await supabase
          .from('team_members')
          .select('team_id')
          .eq('staff_id', technicianId);
      final directIds = _teamIdsFromRows(teamMembersRes);
      if (directIds.isNotEmpty) return directIds;
    } catch (e) {
      debugPrint('POWERNET_DEBUG: failed to fetch direct team memberships: $e');
    }

    try {
      final uri = Uri.parse(
        '${_managerApiBaseUrl()}/api/mobile/staff-team-ids',
      ).replace(queryParameters: {'staffId': technicianId});
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        debugPrint(
          'POWERNET_DEBUG: staff team fallback failed with ${response.statusCode}',
        );
        return const [];
      }
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final teamIds = decoded['teamIds'];
      if (teamIds is! List) return const [];
      return teamIds
          .whereType<String>()
          .where((teamId) => teamId.isNotEmpty)
          .toSet()
          .toList();
    } catch (e) {
      debugPrint('POWERNET_DEBUG: staff team fallback failed: $e');
      return const [];
    }
  }

  List<String> _teamIdsFromRows(List<dynamic> rows) {
    final ids = <String>{};
    for (final row in rows) {
      if (row is Map && row['team_id'] != null) {
        ids.add(row['team_id'].toString());
      }
    }
    return ids.toList();
  }

  String _managerApiBaseUrl() {
    final configured = dotenv.env['POWER_NET_API_BASE_URL']?.trim();
    final base = configured == null || configured.isEmpty
        ? _defaultManagerApiBaseUrl
        : configured;
    return base.replaceFirst(RegExp(r'/+$'), '');
  }

  Future<List<Complaint>> _fetchByAreas(
    List<String> areaIds,
    String select, {
    String? serviceLine,
  }) async {
    if (areaIds.isEmpty) return [];
    var query = supabase
        .from('complaints')
        .select(select)
        .inFilter('customer.area_id', areaIds)
        .inFilter('status', ['open', 'in_progress']);
    if (serviceLine != null && select.contains('service_line')) {
      query = query.eq('service_line', serviceLine);
    }
    final res = await query.order('opened_at', ascending: false);
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

  bool _isMissingServiceLineColumn(Object error) {
    final text = error.toString();
    return text.contains('service_line');
  }

  List<Complaint> _filterByServiceLine(
    List<Complaint> items,
    String? serviceLine,
  ) {
    if (serviceLine == null) return items;
    return items
        .where(
          (c) => serviceLine == 'cable' ? c.isCableService : !c.isCableService,
        )
        .toList();
  }
}
