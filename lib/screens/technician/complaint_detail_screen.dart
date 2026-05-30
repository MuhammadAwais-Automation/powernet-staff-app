import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../data/complaints_repository.dart';
import '../../models/complaint.dart';
import '../../providers/complaint_queue_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state.dart';

class ComplaintDetailScreen extends StatefulWidget {
  final String complaintId;
  const ComplaintDetailScreen({super.key, required this.complaintId});

  @override
  State<ComplaintDetailScreen> createState() => _ComplaintDetailScreenState();
}

class _ComplaintDetailScreenState extends State<ComplaintDetailScreen> {
  final ComplaintsRepository _repo = ComplaintsRepository();
  Complaint? _complaint;
  bool _loading = true;
  String? _error;
  bool _updating = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final cached = context.read<ComplaintQueueProvider>().findComplaintById(
      widget.complaintId,
    );
    if (cached != null) {
      setState(() {
        _complaint = cached;
        _loading = false;
      });
    }
    try {
      final complaint = await _repo.fetchById(widget.complaintId);
      if (mounted) {
        setState(() {
          _complaint = complaint;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted && _complaint == null) {
        debugPrint('POWERNET_DEBUG: complaint detail load failed: $e');
        setState(() {
          _error =
              'No internet connection. To view complaint details, please select a cached complaint first.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _updateStatus(String status) async {
    setState(() => _updating = true);
    final queue = context.read<ComplaintQueueProvider>();
    bool ok;
    if (status == 'resolved') {
      ok = await queue.resolveComplaint(widget.complaintId);
    } else {
      ok = await queue.startComplaint(widget.complaintId);
    }
    if (ok && mounted) {
      setState(() => _complaint = queue.findComplaintById(widget.complaintId));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            queue.pendingSyncCount > 0
                ? 'Saved offline. Will auto-sync when internet connection is restored.'
                : 'Complaint status updated.',
          ),
          backgroundColor: queue.pendingSyncCount > 0 ? warning : success,
        ),
      );
    }
    if (mounted) setState(() => _updating = false);
  }

  Future<void> _resolveWithDetails(String notes, String hardware) async {
    setState(() => _updating = true);
    final queue = context.read<ComplaintQueueProvider>();
    final ok = await queue.resolveComplaintWithOptions(
      widget.complaintId,
      notes,
      hardware,
    );
    if (ok && mounted) {
      setState(() => _complaint = queue.findComplaintById(widget.complaintId));
    }
    if (mounted) setState(() => _updating = false);
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            queue.pendingSyncCount > 0
                ? 'Resolution saved offline. Will auto-sync when internet connection is restored.'
                : 'Complaint successfully resolved!',
          ),
          backgroundColor: queue.pendingSyncCount > 0 ? warning : success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pn = Theme.of(context).extension<PnColors>()!;
    return Scaffold(
      backgroundColor: pn.background,
      appBar: AppBar(
        backgroundColor: pn.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: pn.text),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/technician/complaints');
            }
          },
        ),
        title: Text(
          _complaint?.complaintCode ?? 'Complaint Details',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: pn.text,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          if (_complaint != null && !_complaint!.isResolved)
            IconButton(
              icon: Icon(Icons.refresh, color: pn.text),
              onPressed: _load,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? ErrorState(message: _error!, onRetry: _load)
          : _complaint == null
          ? const EmptyState(message: 'Complaint not found')
          : _Body(
              complaint: _complaint!,
              pn: pn,
              updating: _updating,
              onUpdateStatus: _updateStatus,
              onResolveWithDetails: _resolveWithDetails,
            ),
    );
  }
}

class _Body extends StatelessWidget {
  final Complaint complaint;
  final PnColors pn;
  final bool updating;
  final void Function(String) onUpdateStatus;
  final void Function(String, String) onResolveWithDetails;

  const _Body({
    required this.complaint,
    required this.pn,
    required this.updating,
    required this.onUpdateStatus,
    required this.onResolveWithDetails,
  });

  void _showResolveBottomSheet(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final notesCtrl = TextEditingController();
    final cableCtrl = TextEditingController(text: '0');
    final connectorsCtrl = TextEditingController(text: '0');
    final routerCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: pn.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 48,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: pn.border,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Resolve Complaint',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: pn.text,
                          letterSpacing: -0.5,
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Close',
                          style: TextStyle(
                            color: pn.textMuted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  // Client Card inside sheet
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: pn.surfaceMuted,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: pn.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              complaint.customerName,
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                color: pn.text,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: pn.warning.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Text(
                                complaint.status.toUpperCase(),
                                style: TextStyle(
                                  color: pn.warning,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${complaint.customerCode} - ${complaint.customerAddress} - ${complaint.customerPhone}',
                          style: TextStyle(
                            fontSize: 12,
                            color: pn.textMuted,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Resolution Notes',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: pn.text,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: notesCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Describe how this issue was resolved...',
                      hintStyle: TextStyle(color: pn.textMuted),
                      filled: true,
                      fillColor: pn.input,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: pn.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: pn.border),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Notes are required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Hardware Log (Equipment Used)',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: pn.text,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: cableCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Cable Wire (Mtrs)',
                            labelStyle: TextStyle(
                              color: pn.textSoft,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                            hintText: '0',
                            filled: true,
                            fillColor: pn.input,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: pn.border),
                            ),
                          ),
                          validator: (v) {
                            if (v == null || int.tryParse(v) == null) {
                              return 'Enter number';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: connectorsCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'RJ45 Connectors',
                            labelStyle: TextStyle(
                              color: pn.textSoft,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                            hintText: '0',
                            filled: true,
                            fillColor: pn.input,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: pn.border),
                            ),
                          ),
                          validator: (v) {
                            if (v == null || int.tryParse(v) == null) {
                              return 'Enter number';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: routerCtrl,
                    decoration: InputDecoration(
                      labelText: 'Replaced Router/ONT (Optional)',
                      labelStyle: TextStyle(
                        color: pn.textSoft,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      hintText: 'e.g. Netis WF2419, ZTE ONT...',
                      filled: true,
                      fillColor: pn.input,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: pn.border),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      if (!formKey.currentState!.validate()) return;
                      final hardwareLog = {
                        'cables_meter': int.tryParse(cableCtrl.text) ?? 0,
                        'rj45_connectors':
                            int.tryParse(connectorsCtrl.text) ?? 0,
                        'router_replaced': routerCtrl.text.trim(),
                      };
                      onResolveWithDetails(
                        notesCtrl.text.trim(),
                        jsonEncode(hardwareLog),
                      );
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: pn.accent,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 54),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Resolve Complaint',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepperProgress(status: complaint.status, pn: pn),
          const SizedBox(height: 20),
          _CustomerInfoCard(complaint: complaint, pn: pn),
          const SizedBox(height: 14),
          _IssueDetailsCard(complaint: complaint, pn: pn),
          if (complaint.isResolved && complaint.resolutionNotes != null) ...[
            const SizedBox(height: 14),
            _ResolutionResultsCard(complaint: complaint, pn: pn),
          ],
          const SizedBox(height: 28),
          if (!complaint.isResolved) ...[
            if (complaint.isOpen)
              _ActionBtn(
                label: 'Start Work',
                icon: Icons.play_arrow_rounded,
                color: pn.cyan,
                loading: updating,
                onTap: () => onUpdateStatus('in_progress'),
              ),
            if (complaint.isInProgress)
              _ActionBtn(
                label: 'Resolve Complaint',
                icon: Icons.verified_outlined,
                color: pn.accent,
                loading: updating,
                onTap: () => _showResolveBottomSheet(context),
              ),
          ] else
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: pn.success.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: pn.success.withValues(alpha: 0.28)),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: pn.success, size: 26),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Complaint Successfully Resolved & Logged',
                      style: TextStyle(
                        color: pn.success,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _StepperProgress extends StatelessWidget {
  final String status;
  final PnColors pn;

  const _StepperProgress({required this.status, required this.pn});

  @override
  Widget build(BuildContext context) {
    final activeIndex = switch (status) {
      'in_progress' => 1,
      'resolved' => 2,
      _ => 0,
    };

    return Card(
      elevation: 0,
      color: pn.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: pn.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Row(
          children: [
            _Step(
              title: 'Open',
              isActive: activeIndex >= 0,
              isCurrent: activeIndex == 0,
              color: pn.warning,
            ),
            _Line(isActive: activeIndex >= 1, pn: pn),
            _Step(
              title: 'Working',
              isActive: activeIndex >= 1,
              isCurrent: activeIndex == 1,
              color: pn.cyan,
            ),
            _Line(isActive: activeIndex >= 2, pn: pn),
            _Step(
              title: 'Resolved',
              isActive: activeIndex >= 2,
              isCurrent: activeIndex == 2,
              color: pn.success,
            ),
          ],
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final String title;
  final bool isActive;
  final bool isCurrent;
  final Color color;

  const _Step({
    required this.title,
    required this.isActive,
    required this.isCurrent,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: isCurrent
                ? color
                : isActive
                ? color.withValues(alpha: 0.14)
                : Colors.grey.withValues(alpha: 0.12),
            shape: BoxShape.circle,
            border: Border.all(
              color: isActive ? color : Colors.grey.withValues(alpha: 0.28),
              width: 2.2,
            ),
          ),
          child: Icon(
            isCurrent
                ? Icons.edit_outlined
                : isActive
                ? Icons.check
                : Icons.circle_outlined,
            size: 16,
            color: isCurrent ? Colors.white : (isActive ? color : Colors.grey),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          title,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isCurrent || isActive
                ? FontWeight.w800
                : FontWeight.w500,
            color: isCurrent || isActive ? color : Colors.grey,
          ),
        ),
      ],
    );
  }
}

class _Line extends StatelessWidget {
  final bool isActive;
  final PnColors pn;
  const _Line({required this.isActive, required this.pn});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: 3,
        decoration: BoxDecoration(
          color: isActive ? pn.cyan : pn.border,
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}

class _CustomerInfoCard extends StatelessWidget {
  final Complaint complaint;
  final PnColors pn;

  const _CustomerInfoCard({required this.complaint, required this.pn});

  void _copyToClipboard(BuildContext context, String title, String val) {
    Clipboard.setData(ClipboardData(text: val));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$title copied to clipboard!'),
        backgroundColor: pn.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final phone = complaint.customerPhone;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: pn.border),
      ),
      child: Container(
        color: pn.surface,
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Customer Details',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: pn.text,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 16),
            _DetailTileRow(
              icon: Icons.person_outline,
              label: 'Subscriber Name',
              value: complaint.customerName,
              pn: pn,
            ),
            const Divider(height: 24),
            _DetailTileRow(
              icon: Icons.qr_code_outlined,
              label: 'Subscriber ID Code',
              value: complaint.customerCode,
              pn: pn,
              onTap: () =>
                  _copyToClipboard(context, 'Code', complaint.customerCode),
            ),
            if (phone.isNotEmpty) ...[
              const Divider(height: 24),
              _DetailTileRow(
                icon: Icons.phone_outlined,
                label: 'Phone Number',
                value: phone,
                pn: pn,
                onTap: () => _copyToClipboard(context, 'Phone number', phone),
              ),
            ],
            if (complaint.hasAddress) ...[
              const Divider(height: 24),
              _DetailTileRow(
                icon: Icons.location_on_outlined,
                label: 'Address Value',
                value: complaint.customerAddress,
                pn: pn,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DetailTileRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final PnColors pn;
  final VoidCallback? onTap;

  const _DetailTileRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.pn,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: pn.surfaceMuted,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: pn.accent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: pn.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: TextStyle(
                    color: pn.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null)
            Icon(Icons.copy_outlined, size: 14, color: pn.textMuted),
        ],
      ),
    );
  }
}

class _IssueDetailsCard extends StatelessWidget {
  final Complaint complaint;
  final PnColors pn;

  const _IssueDetailsCard({required this.complaint, required this.pn});

  Color _priorityColor() {
    switch (complaint.priority) {
      case 'high':
      case 'urgent':
        return pn.danger;
      case 'medium':
        return pn.warning;
      default:
        return pn.textMuted;
    }
  }

  String _formatDate(String iso) {
    try {
      final d = DateTime.parse(iso).toLocal();
      return '${d.day}/${d.month}/${d.year}  ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: pn.border),
      ),
      child: Container(
        color: pn.surface,
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Complaint & Issue Details',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: pn.text,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  'Category Type',
                  style: TextStyle(
                    color: pn.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: pn.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    complaint.type,
                    style: TextStyle(
                      color: pn.primary,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Text(
                  'Priority Level',
                  style: TextStyle(
                    color: pn.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: _priorityColor().withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    complaint.priority.toUpperCase(),
                    style: TextStyle(
                      color: _priorityColor(),
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Text(
                  'Opened Date',
                  style: TextStyle(
                    color: pn.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  _formatDate(complaint.openedAt),
                  style: TextStyle(
                    color: pn.text,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Text(
              'Reported Issue Description',
              style: TextStyle(
                color: pn.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: pn.surfaceMuted,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: pn.border),
              ),
              child: Text(
                complaint.issue,
                style: TextStyle(
                  color: pn.text,
                  fontSize: 13,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResolutionResultsCard extends StatelessWidget {
  final Complaint complaint;
  final PnColors pn;

  const _ResolutionResultsCard({required this.complaint, required this.pn});

  @override
  Widget build(BuildContext context) {
    Map<String, dynamic> hardware = {};
    try {
      if (complaint.hardwareUsed != null &&
          complaint.hardwareUsed!.isNotEmpty) {
        hardware = jsonDecode(complaint.hardwareUsed!) as Map<String, dynamic>;
      }
    } catch (_) {}

    final mtr = hardware['cables_meter'] ?? 0;
    final rj = hardware['rj45_connectors'] ?? 0;
    final router = hardware['router_replaced'] as String? ?? '';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: pn.border),
      ),
      child: Container(
        color: pn.surface,
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Resolution Summary & Log',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: pn.text,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Resolution Notes',
              style: TextStyle(
                color: pn.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: pn.success.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: pn.success.withValues(alpha: 0.12)),
              ),
              child: Text(
                complaint.resolutionNotes ?? '—',
                style: TextStyle(
                  color: pn.text,
                  fontSize: 13,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (mtr > 0 || rj > 0 || router.isNotEmpty) ...[
              const SizedBox(height: 18),
              Text(
                'Materials Replaced / Installed',
                style: TextStyle(
                  color: pn.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              if (mtr > 0)
                _InventoryRow(
                  label: 'Cable Wire Used',
                  value: '$mtr Meters',
                  pn: pn,
                ),
              if (rj > 0)
                _InventoryRow(
                  label: 'RJ45 Connectors',
                  value: '$rj Units',
                  pn: pn,
                ),
              if (router.isNotEmpty)
                _InventoryRow(label: 'Router replaced', value: router, pn: pn),
            ],
          ],
        ),
      ),
    );
  }
}

class _InventoryRow extends StatelessWidget {
  final String label;
  final String value;
  final PnColors pn;

  const _InventoryRow({
    required this.label,
    required this.value,
    required this.pn,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(Icons.inventory_2_outlined, size: 14, color: pn.textMuted),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: pn.text,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: pn.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool loading;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          elevation: 0,
        ),
        onPressed: loading ? null : onTap,
        icon: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Icon(icon, size: 20),
        label: Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 15,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}
