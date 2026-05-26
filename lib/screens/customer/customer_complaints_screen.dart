import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/complaint.dart';
import '../../providers/customer_auth_provider.dart';
import '../../providers/customer_portal_provider.dart';
import '../../theme/app_theme.dart';

class CustomerComplaintsScreen extends StatefulWidget {
  const CustomerComplaintsScreen({super.key});

  @override
  State<CustomerComplaintsScreen> createState() =>
      _CustomerComplaintsScreenState();
}

class _CustomerComplaintsScreenState extends State<CustomerComplaintsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final customer = context.read<CustomerAuthProvider>().currentCustomer;
      if (customer != null) {
        context.read<CustomerPortalProvider>().load(customer);
      }
    });
  }

  void _openCreateSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _CreateComplaintSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CustomerPortalProvider>();
    final pn = Theme.of(context).extension<PnColors>()!;
    
    // Count open complaints
    final openCount = provider.complaints.where((c) => c.status != 'resolved').length;

    return Scaffold(
      backgroundColor: pn.background,
      appBar: AppBar(
        title: const Text('My Complaints'),
        actions: [
          IconButton(
            icon: Icon(Icons.add_rounded, color: pn.text),
            onPressed: _openCreateSheet,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateSheet,
        backgroundColor: pn.accent,
        foregroundColor: pn.primary,
        icon: const Icon(Icons.add_comment_rounded),
        label: const Text('New Complaint'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: provider.refreshActive,
          color: pn.accent,
          backgroundColor: pn.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Count Subheader Details
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: openCount > 0 ? pn.accent : pn.success,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$openCount active support ${openCount == 1 ? "ticket" : "tickets"}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: pn.textSoft,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Complaints list grid/view
              Expanded(
                child: provider.loading && provider.complaints.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : provider.complaints.isEmpty
                        ? const _EmptyComplaints()
                        : ListView.separated(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            itemBuilder: (context, index) =>
                                _ComplaintCard(complaint: provider.complaints[index]),
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 14),
                            itemCount: provider.complaints.length,
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateComplaintSheet extends StatefulWidget {
  const _CreateComplaintSheet();

  @override
  State<_CreateComplaintSheet> createState() => _CreateComplaintSheetState();
}

class _CreateComplaintSheetState extends State<_CreateComplaintSheet> {
  final _issue = TextEditingController();
  String _type = 'connectivity';
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _issue.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final customer = context.read<CustomerAuthProvider>().currentCustomer;
    if (customer == null || _issue.text.trim().isEmpty) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final ok = await context.read<CustomerPortalProvider>().createComplaint(
          customer: customer,
          issue: _issue.text,
          type: _type,
        );
    if (!mounted) return;
    setState(() {
      _saving = false;
      _error = ok ? null : context.read<CustomerPortalProvider>().error;
    });
    if (ok) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final pn = Theme.of(context).extension<PnColors>()!;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: pn.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
        border: Border.all(color: pn.border),
      ),
      padding: EdgeInsets.fromLTRB(20, 10, 20, bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag Handle bar mimicking css sheet handle
          Center(
            child: Container(
              width: 38,
              height: 4,
              margin: const EdgeInsets.only(bottom: 18),
              decoration: BoxDecoration(
                color: pn.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'New Complaint',
                style: GoogleFonts.manrope(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: pn.text,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: pn.softRed,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: pn.danger.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline_rounded, color: pn.danger, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: pn.danger,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          Text(
            'COMPLAINT TYPE',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: pn.textSoft,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: _type,
            items: const [
              DropdownMenuItem(value: 'connectivity', child: Text('Connectivity')),
              DropdownMenuItem(value: 'speed', child: Text('Speed Limit')),
              DropdownMenuItem(value: 'hardware', child: Text('Hardware / Fiber')),
              DropdownMenuItem(value: 'billing', child: Text('Billing Issues')),
              DropdownMenuItem(value: 'upgrade', child: Text('Package Upgrade')),
              DropdownMenuItem(value: 'other', child: Text('Other Concerns')),
            ],
            onChanged: (value) =>
                setState(() => _type = value ?? 'connectivity'),
          ),
          const SizedBox(height: 18),
          
          Text(
            'ISSUE DESCRIPTION',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: pn.textSoft,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _issue,
            maxLines: 4,
            style: TextStyle(color: pn.text, fontSize: 14),
            decoration: const InputDecoration(
              hintText: 'Describe the connectivity or hardware issue clearly so technicians can understand...',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 24),
          
          ElevatedButton(
            onPressed: _saving || _issue.text.trim().isEmpty ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: pn.accent,
              foregroundColor: pn.primary,
              elevation: 4,
            ),
            child: _saving
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation(pn.primary),
                    ),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('SUBMIT COMPLAINT TICKET'),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded, size: 16),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _EmptyComplaints extends StatelessWidget {
  const _EmptyComplaints();

  @override
  Widget build(BuildContext context) {
    final pn = Theme.of(context).extension<PnColors>()!;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 100),
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: pn.softCyan,
            shape: BoxShape.circle,
            border: Border.all(color: pn.cyan.withOpacity(0.2)),
          ),
          child: Icon(Icons.chat_bubble_outline_rounded, size: 34, color: pn.cyan),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            'No active complaints.',
            style: GoogleFonts.manrope(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: pn.text,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: Text(
            'If you have connection issues, file a new support ticket.',
            style: TextStyle(color: pn.textMuted, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

class _ComplaintCard extends StatelessWidget {
  final Complaint complaint;
  const _ComplaintCard({required this.complaint});

  @override
  Widget build(BuildContext context) {
    final pn = Theme.of(context).extension<PnColors>()!;
    
    // Resolve status color scheme
    Color color;
    Color bg;
    String statusLabel = complaint.status.replaceAll('_', ' ').toUpperCase();

    if (complaint.status == 'resolved') {
      color = pn.success;
      bg = pn.softGreen;
    } else if (complaint.status == 'in_progress') {
      color = pn.accent;
      bg = pn.softOrange;
      statusLabel = 'IN PROGRESS';
    } else {
      color = pn.cyan;
      bg = pn.softCyan;
      statusLabel = 'AWAITING';
    }

    // Resolve Type Capitalization
    final typeName = complaint.type.substring(0, 1).toUpperCase() + complaint.type.substring(1);

    // Format Date from opened_at
    String openedDate = 'Recent';
    if (complaint.openedAt.isNotEmpty) {
      openedDate = complaint.openedAt.split('T')[0].split('-').skip(1).join(' ');
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: pn.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: pn.border),
        boxShadow: [
          BoxShadow(
            color: pn.text.withOpacity(0.02),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row with CMP code and Status chip
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                complaint.complaintCode,
                style: GoogleFonts.manrope(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: pn.text,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withOpacity(0.25)),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: color == pn.cyan ? pn.text : color,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          
          Text(
            complaint.issue,
            style: TextStyle(
              color: pn.textSoft,
              fontSize: 14,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          
          // 4-cell Metadata Grid matching html complaint-card .mini-grid
          Row(
            children: [
              _buildMiniCell(pn, 'Type', typeName),
              _buildMiniCell(pn, 'Opened', openedDate),
              _buildMiniCell(pn, 'Technician', complaint.technicianName ?? 'Not Assigned'),
              _buildMiniCell(pn, 'Notes', complaint.resolutionNotes ?? '—'),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildMiniCell(PnColors pn, String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(color: pn.textMuted, fontSize: 9, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.manrope(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: pn.text,
            ),
          ),
        ],
      ),
    );
  }
}
