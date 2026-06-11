import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:powernet_staff/data/complaints_repository.dart';
import 'package:powernet_staff/models/complaint.dart';
import 'package:powernet_staff/providers/complaint_queue_provider.dart';

void main() {
  group('ComplaintQueueProvider offline sync', () {
    test('queues start action when network write fails', () async {
      final repo = _FakeComplaintsRepository(failStatusWrite: true);
      final provider = ComplaintQueueProvider(
        repo: repo,
        onlineChanges: const Stream.empty(),
        enableRealtime: false,
      );

      await provider.loadForTechnicianAndAreas('tech-1', const ['area-1']);
      final ok = await provider.startComplaint(_complaint.id);

      expect(ok, isTrue);
      expect(provider.pendingSyncCount, 1);
      expect(repo.queuedActions, hasLength(1));
      expect(repo.queuedActions.single.assignToTechnician, isTrue);
      expect(provider.findComplaintById(_complaint.id)?.status, 'in_progress');
      provider.dispose();
    });

    test('queues resolution details when network write fails', () async {
      final repo = _FakeComplaintsRepository(failResolutionWrite: true);
      final provider = ComplaintQueueProvider(
        repo: repo,
        onlineChanges: const Stream.empty(),
        enableRealtime: false,
      );

      await provider.loadForTechnicianAndAreas('tech-1', const ['area-1']);
      await provider.startComplaint(_complaint.id);
      final ok = await provider.resolveComplaintWithOptions(
        _complaint.id,
        'Fixed cable issue',
        '{"cables_meter":5}',
      );

      expect(ok, isTrue);
      expect(provider.pendingSyncCount, 1);
      expect(repo.queuedActions.single.status, 'resolved');
      expect(
        provider.findComplaintById(_complaint.id)?.resolutionNotes,
        'Fixed cable issue',
      );
      provider.dispose();
    });

    test(
      'syncs queued complaint actions automatically when connectivity returns',
      () async {
        final online = StreamController<bool>();
        final repo = _FakeComplaintsRepository(initialQueuedActions: 1);
        final provider = ComplaintQueueProvider(
          repo: repo,
          onlineChanges: online.stream,
          enableRealtime: false,
        );

        await provider.loadForTechnicianAndAreas('tech-1', const ['area-1']);
        expect(provider.pendingSyncCount, 1);

        online.add(true);
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(repo.syncCalls, 1);
        expect(provider.pendingSyncCount, 0);
        await online.close();
        provider.dispose();
      },
    );

    test('finds cached complaints for offline detail fallback', () async {
      final provider = ComplaintQueueProvider(
        repo: _FakeComplaintsRepository(),
        onlineChanges: const Stream.empty(),
        enableRealtime: false,
      );

      await provider.loadForTechnicianAndAreas('tech-1', const ['area-1']);

      expect(provider.findComplaintById(_complaint.id), isNotNull);
      expect(provider.findComplaintById('missing'), isNull);
      provider.dispose();
    });

    test('preserves team assignment when team complaint starts', () async {
      final online = StreamController<bool>();
      final repo = _FakeComplaintsRepository(complaints: [_teamComplaint]);
      final provider = ComplaintQueueProvider(
        repo: repo,
        onlineChanges: online.stream,
        enableRealtime: false,
      );

      online.add(true);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await provider.loadForTechnicianAndAreas('tech-2', const ['area-1']);
      final ok = await provider.startComplaint(_teamComplaint.id);

      expect(ok, isTrue);
      expect(repo.lastStatusTechnicianId, isNull);
      expect(repo.lastStatusClearAssignedTo, isTrue);
      expect(
        provider.findComplaintById(_teamComplaint.id)?.teamId,
        _teamComplaint.teamId,
      );
      expect(provider.findComplaintById(_teamComplaint.id)?.assignedTo, isNull);
      await online.close();
      provider.dispose();
    });

    test(
      'queues team complaint actions without technician assignment',
      () async {
        final repo = _FakeComplaintsRepository(
          complaints: [_teamComplaint],
          failStatusWrite: true,
        );
        final provider = ComplaintQueueProvider(
          repo: repo,
          onlineChanges: const Stream.empty(),
          enableRealtime: false,
        );

        await provider.loadForTechnicianAndAreas('tech-2', const ['area-1']);
        final ok = await provider.startComplaint(_teamComplaint.id);

        expect(ok, isTrue);
        expect(repo.queuedActions, hasLength(1));
        expect(repo.queuedActions.single.assignToTechnician, isFalse);
        expect(repo.queuedActions.single.clearAssignedTo, isTrue);
        expect(
          provider.findComplaintById(_teamComplaint.id)?.teamId,
          _teamComplaint.teamId,
        );
        expect(
          provider.findComplaintById(_teamComplaint.id)?.assignedTo,
          isNull,
        );
        provider.dispose();
      },
    );

    test(
      'syncs queued team complaint actions without technician assignment',
      () async {
        final online = StreamController<bool>();
        final repo = _FakeComplaintsRepository(
          complaints: [_teamComplaint],
          initialQueuedActions: 1,
          initialQueuedComplaintId: _teamComplaint.id,
          initialQueuedAssignToTechnician: false,
          initialQueuedClearAssignedTo: true,
        );
        final provider = ComplaintQueueProvider(
          repo: repo,
          onlineChanges: online.stream,
          enableRealtime: false,
        );

        await provider.loadForTechnicianAndAreas('tech-2', const ['area-1']);
        expect(provider.pendingSyncCount, 1);

        online.add(true);
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(repo.syncCalls, 1);
        expect(repo.lastSyncTechnicianId, 'tech-2');
        expect(repo.lastStatusTechnicianId, isNull);
        expect(repo.lastStatusClearAssignedTo, isTrue);
        await online.close();
        provider.dispose();
      },
    );
  });
}

final _complaint = Complaint(
  id: 'complaint-1',
  complaintCode: 'CMP-001',
  customerId: 'customer-1',
  issue: 'No internet',
  type: 'fiber',
  priority: 'high',
  status: 'open',
  assignedTo: 'tech-1',
  openedAt: '2026-05-25T00:00:00Z',
  customer: const {
    'id': 'customer-1',
    'full_name': 'Test Customer',
    'area_id': 'area-1',
    'customer_code': 'C-001',
    'address_value': 'Street 1',
    'phone': '03000000000',
  },
  technician: const {'id': 'tech-1', 'full_name': 'Tech One'},
);

final _teamComplaint = Complaint(
  id: 'complaint-team-1',
  complaintCode: 'CMP-T01',
  customerId: 'customer-1',
  issue: 'Team assigned fault',
  type: 'fiber',
  priority: 'high',
  status: 'open',
  teamId: 'team-1',
  openedAt: '2026-05-25T00:00:00Z',
  customer: const {
    'id': 'customer-1',
    'full_name': 'Team Customer',
    'area_id': 'area-1',
    'customer_code': 'C-002',
    'address_value': 'Street 2',
    'phone': '03000000001',
  },
  team: const {'id': 'team-1', 'name': 'Urgent Team'},
);

class _FakeComplaintsRepository extends ComplaintsRepository {
  final bool failStatusWrite;
  final bool failResolutionWrite;
  final int initialQueuedActions;
  final String? initialQueuedComplaintId;
  final bool initialQueuedAssignToTechnician;
  final bool initialQueuedClearAssignedTo;
  final List<Complaint> complaints;
  final List<QueuedComplaintAction> queuedActions = [];
  String? lastStatusTechnicianId;
  String? lastResolutionTechnicianId;
  String? lastSyncTechnicianId;
  bool? lastStatusClearAssignedTo;
  bool? lastResolutionClearAssignedTo;
  int syncCalls = 0;

  _FakeComplaintsRepository({
    this.failStatusWrite = false,
    this.failResolutionWrite = false,
    this.initialQueuedActions = 0,
    this.initialQueuedComplaintId,
    this.initialQueuedAssignToTechnician = true,
    this.initialQueuedClearAssignedTo = false,
    List<Complaint>? complaints,
  }) : complaints = complaints ?? [_complaint] {
    queuedActions.addAll(
      List.generate(
        initialQueuedActions,
        (index) => QueuedComplaintAction(
          id: 'queued-$index',
          complaintId: initialQueuedComplaintId ?? _complaint.id,
          status: 'in_progress',
          assignToTechnician: initialQueuedAssignToTechnician,
          clearAssignedTo: initialQueuedClearAssignedTo,
          queuedAt: '2026-05-25T00:00:00Z',
        ),
      ),
    );
  }

  @override
  Future<List<Complaint>> fetchAssigned(String technicianId) async =>
      complaints;

  @override
  Future<List<Complaint>> fetchByAreas(List<String> areaIds) async =>
      complaints;

  @override
  Future<void> updateStatus(
    String id,
    String status, {
    String? technicianId,
    bool clearAssignedTo = false,
  }) async {
    lastStatusTechnicianId = technicianId;
    lastStatusClearAssignedTo = clearAssignedTo;
    if (failStatusWrite) throw Exception('offline');
  }

  @override
  Future<void> resolveWithDetails(
    String id,
    String notes,
    String hardware, {
    String? technicianId,
    bool clearAssignedTo = false,
  }) async {
    lastResolutionTechnicianId = technicianId;
    lastResolutionClearAssignedTo = clearAssignedTo;
    if (failResolutionWrite) throw Exception('offline');
  }

  @override
  Future<List<QueuedComplaintAction>> getQueuedActions() async => queuedActions;

  @override
  Future<void> queueStatusUpdate({
    required String complaintId,
    required String status,
    required bool assignToTechnician,
    bool clearAssignedTo = false,
    String? notes,
    String? hardware,
  }) async {
    queuedActions.removeWhere((action) => action.complaintId == complaintId);
    queuedActions.add(
      QueuedComplaintAction(
        id: 'queued-${queuedActions.length}',
        complaintId: complaintId,
        status: status,
        assignToTechnician: assignToTechnician,
        clearAssignedTo: clearAssignedTo,
        notes: notes,
        hardware: hardware,
        queuedAt: '2026-05-25T00:00:00Z',
      ),
    );
  }

  @override
  Future<int> syncQueuedActions({String? technicianId}) async {
    lastSyncTechnicianId = technicianId;
    syncCalls++;
    final synced = queuedActions.length;
    for (final action in List<QueuedComplaintAction>.of(queuedActions)) {
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
    }
    queuedActions.clear();
    return synced;
  }

  @override
  Future<int> countQueuedActions() async => queuedActions.length;

  @override
  Future<void> cacheTechnicianSnapshot({
    required String technicianId,
    required List<String> areaIds,
    required List<Complaint> complaints,
  }) async {}
}
