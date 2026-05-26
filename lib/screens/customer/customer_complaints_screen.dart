import 'package:flutter/material.dart';
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
      builder: (_) => const _CreateComplaintSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CustomerPortalProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('My Complaints')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateSheet,
        icon: const Icon(Icons.add),
        label: const Text('New'),
      ),
      body: RefreshIndicator(
        onRefresh: provider.refreshActive,
        child: provider.loading && provider.complaints.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : provider.complaints.isEmpty
            ? const _EmptyComplaints()
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemBuilder: (context, index) =>
                    _ComplaintCard(complaint: provider.complaints[index]),
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 10),
                itemCount: provider.complaints.length,
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

  @override
  void dispose() {
    _issue.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final customer = context.read<CustomerAuthProvider>().currentCustomer;
    if (customer == null || _issue.text.trim().isEmpty) return;
    setState(() => _saving = true);
    final ok = await context.read<CustomerPortalProvider>().createComplaint(
      customer: customer,
      issue: _issue.text,
      type: _type,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'New complaint',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _type,
            decoration: const InputDecoration(labelText: 'Type'),
            items: const [
              DropdownMenuItem(
                value: 'connectivity',
                child: Text('Connectivity'),
              ),
              DropdownMenuItem(value: 'speed', child: Text('Speed')),
              DropdownMenuItem(value: 'hardware', child: Text('Hardware')),
              DropdownMenuItem(value: 'billing', child: Text('Billing')),
              DropdownMenuItem(value: 'upgrade', child: Text('Upgrade')),
              DropdownMenuItem(value: 'other', child: Text('Other')),
            ],
            onChanged: (value) =>
                setState(() => _type = value ?? 'connectivity'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _issue,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Issue description'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _saving || _issue.text.trim().isEmpty ? null : _submit,
            child: _saving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  )
                : const Text('Submit complaint'),
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
    return ListView(
      padding: const EdgeInsets.all(24),
      children: const [
        SizedBox(height: 120),
        Icon(Icons.report_problem_outlined, size: 48, color: primary),
        SizedBox(height: 12),
        Center(child: Text('No complaints yet')),
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
    final color = complaint.status == 'resolved'
        ? pn.success
        : complaint.status == 'in_progress'
        ? pn.warning
        : pn.danger;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    complaint.complaintCode,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: pn.text,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    complaint.status.replaceAll('_', ' ').toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(complaint.issue, style: TextStyle(color: pn.text)),
            const SizedBox(height: 8),
            Text(
              complaint.technician == null
                  ? 'Awaiting technician assignment'
                  : 'Technician: ${complaint.technicianName}',
              style: TextStyle(color: pn.textMuted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
