import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
              'Internet band hai. Complaint detail open karne ke liye pehle cached complaint select karein.';
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
                ? 'Saved offline. Internet on hotay hi auto sync ho jayega.'
                : 'Complaint updated.',
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
                ? 'Resolution saved offline. Internet on hotay hi auto sync ho jayega.'
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
      backgroundColor: pn.surfaceMuted,
      appBar: AppBar(
        title: Text(_complaint?.complaintCode ?? 'Complaint Details'),
        backgroundColor: pn.surfaceMuted,
        actions: [
          if (_complaint != null && !_complaint!.isResolved)
            IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
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
            16,
            16,
            16,
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
                      decoration: BoxDecoration(
                        color: pn.border,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Resolve Complaint',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Resolution Details',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: pn.text,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: notesCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Describe how this issue was resolved...',
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Notes are required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Hardware Log (Equipment Used)',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
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
                          decoration: const InputDecoration(
                            labelText: 'Cable Wire (Mtrs)',
                            hintText: '0',
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
                          decoration: const InputDecoration(
                            labelText: 'RJ45 Connectors',
                            hintText: '0',
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
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: routerCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Replaced Router/ONT (Optional)',
                      hintText: 'e.g. Netis WF2419, ZTE ONT...',
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
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
                      child: const Text(
                        'SUBMIT RESOLUTION',
                        style: TextStyle(fontWeight: FontWeight.w800),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepperProgress(status: complaint.status, pn: pn),
          const SizedBox(height: 16),
          _CustomerInfoCard(complaint: complaint, pn: pn),
          const SizedBox(height: 12),
          _IssueDetailsCard(complaint: complaint, pn: pn),
          if (complaint.isResolved && complaint.resolutionNotes != null) ...[
            const SizedBox(height: 12),
            _ResolutionResultsCard(complaint: complaint, pn: pn),
          ],
          const SizedBox(height: 24),
          if (!complaint.isResolved) ...[
            if (complaint.isOpen)
              _ActionBtn(
                label: 'Start Working Onsite',
                icon: Icons.play_arrow_rounded,
                color: const Color(0xFF2563EB),
                loading: updating,
                onTap: () => onUpdateStatus('in_progress'),
              ),
            if (complaint.isInProgress)
              _ActionBtn(
                label: 'Log Work & Resolve',
                icon: Icons.verified_outlined,
                color: const Color(0xFF16A34A),
                loading: updating,
                onTap: () => _showResolveBottomSheet(context),
              ),
          ] else
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: pn.success.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: pn.success.withValues(alpha: 0.28)),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: pn.success, size: 24),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Complaint Successfully Resolved & Logged',
                      style: TextStyle(
                        color: Color(0xFF16A34A),
                        fontWeight: FontWeight.w800,
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
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: Row(
          children: [
            _Step(
              title: 'Open',
              isActive: activeIndex >= 0,
              isCurrent: activeIndex == 0,
              color: pn.warning,
            ),
            _Line(isActive: activeIndex >= 1),
            _Step(
              title: 'Working',
              isActive: activeIndex >= 1,
              isCurrent: activeIndex == 1,
              color: primary,
            ),
            _Line(isActive: activeIndex >= 2),
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
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isCurrent
                ? color
                : isActive
                ? color.withValues(alpha: 0.16)
                : Colors.grey.withValues(alpha: 0.12),
            shape: BoxShape.circle,
            border: Border.all(
              color: isActive ? color : Colors.grey.withValues(alpha: 0.28),
              width: 2,
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
                ? FontWeight.bold
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
  const _Line({required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: 3,
        decoration: BoxDecoration(
          color: isActive ? primary : Colors.grey.withValues(alpha: 0.2),
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
        backgroundColor: success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final phone = complaint.customerPhone;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: pn.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Customer Details',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: pn.text,
                  ),
                ),
              ],
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
            child: Icon(icon, color: primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(color: pn.textMuted, fontSize: 11),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    color: pn.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
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
        return const Color(0xFFDC2626);
      case 'medium':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF6B7280);
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
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: pn.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Complaint & Issue Details',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: pn.text,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  'Category Type',
                  style: TextStyle(color: pn.textMuted, fontSize: 12),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    complaint.type,
                    style: const TextStyle(
                      color: primary,
                      fontWeight: FontWeight.bold,
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
                  style: TextStyle(color: pn.textMuted, fontSize: 12),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _priorityColor().withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    complaint.priority.toUpperCase(),
                    style: TextStyle(
                      color: _priorityColor(),
                      fontWeight: FontWeight.bold,
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
                  style: TextStyle(color: pn.textMuted, fontSize: 12),
                ),
                const Spacer(),
                Text(
                  _formatDate(complaint.openedAt),
                  style: TextStyle(
                    color: pn.text,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Text(
              'Reported Issue',
              style: TextStyle(
                color: pn.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: pn.surfaceMuted,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                complaint.issue,
                style: TextStyle(color: pn.text, fontSize: 13, height: 1.45),
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
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: pn.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Resolution Summary & Log',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: pn.text,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Resolution Note',
              style: TextStyle(
                color: pn.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: pn.success.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: pn.success.withValues(alpha: 0.12)),
              ),
              child: Text(
                complaint.resolutionNotes ?? '—',
                style: TextStyle(color: pn.text, fontSize: 13, height: 1.4),
              ),
            ),
            if (mtr > 0 || rj > 0 || router.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Materials Replaced / Installed',
                style: TextStyle(
                  color: pn.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
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
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(Icons.inventory_2_outlined, size: 14, color: pn.textMuted),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontSize: 12, color: pn.text)),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: primary,
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
      height: 52,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
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
            : Icon(icon),
        label: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
      ),
    );
  }
}
