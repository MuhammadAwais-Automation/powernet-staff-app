import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../data/complaints_repository.dart';
import '../../models/complaint.dart';
import '../../providers/complaint_queue_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/pn_status_badge.dart';

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
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _complaint = await _repo.fetchById(widget.complaintId);
    } catch (e) {
      _error = e.toString();
    } finally {
      setState(() => _loading = false);
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
    if (ok) await _load();
    if (mounted) setState(() => _updating = false);
    if (ok && status == 'resolved' && mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final pn = Theme.of(context).extension<PnColors>()!;
    return Scaffold(
      appBar: AppBar(
        title: Text(_complaint?.complaintCode ?? 'Complaint'),
        actions: [
          if (_complaint != null && !_complaint!.isResolved)
            IconButton(
              icon: const Icon(Icons.refresh),
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
                    ),
    );
  }
}

class _Body extends StatelessWidget {
  final Complaint complaint;
  final PnColors pn;
  final bool updating;
  final void Function(String) onUpdateStatus;

  const _Body({
    required this.complaint,
    required this.pn,
    required this.updating,
    required this.onUpdateStatus,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoCard(complaint: complaint, pn: pn),
          const SizedBox(height: 12),
          _IssueCard(complaint: complaint, pn: pn),
          const SizedBox(height: 24),
          if (!complaint.isResolved) ...[
            if (complaint.isOpen)
              _ActionButton(
                label: 'Start Working',
                icon: Icons.play_arrow_rounded,
                color: const Color(0xFF2563EB),
                loading: updating,
                onTap: () => onUpdateStatus('in_progress'),
              ),
            if (complaint.isInProgress)
              _ActionButton(
                label: 'Mark Resolved',
                icon: Icons.check_circle_outline,
                color: const Color(0xFF16A34A),
                loading: updating,
                onTap: () => onUpdateStatus('resolved'),
              ),
          ] else
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF16A34A).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF16A34A).withValues(alpha: 0.3),
                ),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle, color: Color(0xFF16A34A)),
                  SizedBox(width: 10),
                  Text(
                    'Complaint resolved',
                    style: TextStyle(
                      color: Color(0xFF16A34A),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final Complaint complaint;
  final PnColors pn;
  const _InfoCard({required this.complaint, required this.pn});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _Row(label: 'Code', value: complaint.complaintCode, pn: pn),
            _Row(label: 'Customer', value: complaint.customerName, pn: pn),
            _Row(label: 'Type', value: complaint.type, pn: pn),
            _Row(label: 'Priority', value: complaint.priority.toUpperCase(), pn: pn),
            Row(
              children: [
                Text('Status', style: TextStyle(color: pn.textMuted, fontSize: 13)),
                const Spacer(),
                PnStatusBadge.fromString(complaint.status),
              ],
            ),
            _Row(label: 'Opened', value: _formatDate(complaint.openedAt), pn: pn),
            if (complaint.resolvedAt != null)
              _Row(label: 'Resolved', value: _formatDate(complaint.resolvedAt!), pn: pn),
          ],
        ),
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      final d = DateTime.parse(iso).toLocal();
      return '${d.day}/${d.month}/${d.year}  ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }
}

class _IssueCard extends StatelessWidget {
  final Complaint complaint;
  final PnColors pn;
  const _IssueCard({required this.complaint, required this.pn});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Issue', style: TextStyle(color: pn.textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(complaint.issue, style: TextStyle(fontSize: 14, color: pn.text, height: 1.5)),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final PnColors pn;
  const _Row({required this.label, required this.value, required this.pn});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Text(label, style: TextStyle(color: pn.textMuted, fontSize: 13)),
          const Spacer(),
          Text(value, style: TextStyle(color: pn.text, fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool loading;
  final VoidCallback onTap;

  const _ActionButton({
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
      height: 50,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: loading ? null : onTap,
        icon: loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Icon(icon),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }
}
