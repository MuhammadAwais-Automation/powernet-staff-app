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

      await provider.loadForTechnicianAndArea('tech-1', 'area-1');
      final ok = await provider.startComplaint(_complaint.id);

      expect(ok, isTrue);
      expect(provider.pendingSyncCount, 1);
      expect(repo.queuedActions, hasLength(1));
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

      await provider.loadForTechnicianAndArea('tech-1', 'area-1');
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

        await provider.loadForTechnicianAndArea('tech-1', 'area-1');
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

      await provider.loadForTechnicianAndArea('tech-1', 'area-1');

      expect(provider.findComplaintById(_complaint.id), isNotNull);
      expect(provider.findComplaintById('missing'), isNull);
      provider.dispose();
    });
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

class _FakeComplaintsRepository extends ComplaintsRepository {
  final bool failStatusWrite;
  final bool failResolutionWrite;
  final int initialQueuedActions;
  final List<QueuedComplaintAction> queuedActions = [];
  int syncCalls = 0;

  _FakeComplaintsRepository({
    this.failStatusWrite = false,
    this.failResolutionWrite = false,
    this.initialQueuedActions = 0,
  }) {
    queuedActions.addAll(
      List.generate(
        initialQueuedActions,
        (index) => QueuedComplaintAction(
          id: 'queued-$index',
          complaintId: _complaint.id,
          status: 'in_progress',
          queuedAt: '2026-05-25T00:00:00Z',
        ),
      ),
    );
  }

  @override
  Future<List<Complaint>> fetchAssigned(String technicianId) async => [
    _complaint,
  ];

  @override
  Future<List<Complaint>> fetchByArea(String areaId) async => [_complaint];

  @override
  Future<void> updateStatus(String id, String status) async {
    if (failStatusWrite) throw Exception('offline');
  }

  @override
  Future<void> resolveWithDetails(
    String id,
    String notes,
    String hardware,
  ) async {
    if (failResolutionWrite) throw Exception('offline');
  }

  @override
  Future<List<QueuedComplaintAction>> getQueuedActions() async => queuedActions;

  @override
  Future<void> queueStatusUpdate({
    required String complaintId,
    required String status,
    String? notes,
    String? hardware,
  }) async {
    queuedActions.add(
      QueuedComplaintAction(
        id: 'queued-${queuedActions.length}',
        complaintId: complaintId,
        status: status,
        notes: notes,
        hardware: hardware,
        queuedAt: '2026-05-25T00:00:00Z',
      ),
    );
  }

  @override
  Future<int> syncQueuedActions() async {
    syncCalls++;
    final synced = queuedActions.length;
    queuedActions.clear();
    return synced;
  }

  @override
  Future<int> countQueuedActions() async => queuedActions.length;

  @override
  Future<void> cacheTechnicianSnapshot({
    required String technicianId,
    required String? areaId,
    required List<Complaint> complaints,
  }) async {}
}
