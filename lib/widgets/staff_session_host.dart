import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/staff.dart';
import '../providers/auth_provider.dart';
import '../providers/bills_provider.dart';
import '../providers/complaint_queue_provider.dart';
import '../services/push_notification_service.dart';

/// Keeps staff push alerts, realtime refresh, and resume sync alive for the session.
class StaffSessionHost extends StatefulWidget {
  final Widget child;

  const StaffSessionHost({super.key, required this.child});

  @override
  State<StaffSessionHost> createState() => _StaffSessionHostState();
}

class _StaffSessionHostState extends State<StaffSessionHost>
    with WidgetsBindingObserver {
  final _pushService = PushNotificationService();
  String? _boundStaffId;
  String? _lastSeenStaffId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _boundStaffId = null;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    _refreshActiveData();
  }

  void _syncStaffSession(Staff? staff) {
    final nextId = staff?.id;
    if (nextId == _lastSeenStaffId) return;
    _lastSeenStaffId = nextId;

    if (staff == null) {
      _boundStaffId = null;
      return;
    }

    if (_boundStaffId == staff.id) return;
    _boundStaffId = staff.id;
    _pushService.bindStaffSession(
      staffId: staff.id,
      onAlert: _handleAlert,
      onOpen: _handleOpen,
    );
  }

  void _handleAlert(String title, String body, Map<String, String> data) {
    if (!mounted) return;
    _refreshActiveData();
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(
      SnackBar(
        content: Text(
          body.isEmpty ? title : '$title — $body',
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
        action: data['complaintId']?.isNotEmpty == true
            ? SnackBarAction(
                label: 'OPEN',
                onPressed: () => _openComplaint(data['complaintId']!),
              )
            : null,
      ),
    );
  }

  void _handleOpen(Map<String, String> data) {
    final complaintId = data['complaintId'];
    if (complaintId == null || complaintId.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _openComplaint(complaintId);
    });
  }

  void _openComplaint(String complaintId) {
    final staff = context.read<AuthProvider>().currentStaff;
    if (staff == null) return;
    final path = staff.normalizedRole == 'cable_technician'
        ? '/cable-technician/complaints/$complaintId'
        : '/technician/complaints/$complaintId';
    context.read<ComplaintQueueProvider>().refreshActive();
    context.push(path);
  }

  void _refreshActiveData() {
    if (!mounted) return;
    final staff = context.read<AuthProvider>().currentStaff;
    if (staff == null) return;

    switch (staff.normalizedRole) {
      case 'technician':
      case 'helper':
      case 'cable_technician':
        context.read<ComplaintQueueProvider>().refreshActive();
        break;
      case 'recovery_agent':
        context.read<BillsProvider>().loadPendingByAreas(
          staff.areaIds,
          staff.id,
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final staff = context.watch<AuthProvider>().currentStaff;
    _syncStaffSession(staff);
    return widget.child;
  }
}