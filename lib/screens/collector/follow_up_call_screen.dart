import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/follow_up_repository.dart';
import '../../models/bill.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';

class FollowUpCallScreen extends StatefulWidget {
  final String billId;
  const FollowUpCallScreen({super.key, required this.billId});

  @override
  State<FollowUpCallScreen> createState() => _FollowUpCallScreenState();
}

class _FollowUpCallScreenState extends State<FollowUpCallScreen> {
  final _repo = FollowUpRepository();
  final _notesCtrl = TextEditingController();

  Bill? _bill;
  List<FollowUpCall> _history = [];
  bool _loading = true;
  bool _saving = false;
  String _outcome = 'answered';
  String _action = 'none';
  DateTime? _promisedDate;
  DateTime? _nextFollowUp;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final billRow = await _repo.supabase
          .from('bills')
          .select('*, customer:customers(id, full_name, customer_code, phone)')
          .eq('id', widget.billId)
          .maybeSingle();
      if (billRow != null) {
        _bill = Bill.fromJson(billRow as Map<String, dynamic>);
      }
      _history = await _repo.fetchCallsForBill(widget.billId);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _dial(String? phone) async {
    if (phone == null || phone.trim().isEmpty) return;
    final uri = Uri(scheme: 'tel', path: phone.trim());
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _save() async {
    final staff = context.read<AuthProvider>().currentStaff;
    final bill = _bill;
    if (staff == null || bill == null) return;
    setState(() => _saving = true);
    try {
      await _repo.recordCall(
        customerId: bill.customerId,
        billId: bill.id,
        callerId: staff.id,
        callerChannel: 'recovery_agent',
        callOutcome: _outcome,
        commitmentAction: _action == 'none' ? null : _action,
        promisedDate: _action == 'new_promise_date' && _promisedDate != null
            ? _formatDate(_promisedDate!)
            : null,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        nextFollowUpDate: _nextFollowUp != null ? _formatDate(_nextFollowUp!) : null,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Call record saved'), backgroundColor: success),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: danger),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pn = Theme.of(context).extension<PnColors>()!;
    final customer = _bill?.customer;
    final phone = customer?['phone'] as String?;

    return Scaffold(
      backgroundColor: pn.background,
      appBar: AppBar(
        title: const Text('Log Follow-up Call'),
        backgroundColor: pn.background,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _bill == null
          ? const Center(child: Text('Bill not found'))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  customer?['full_name'] as String? ?? 'Customer',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: pn.text),
                ),
                if (phone != null && phone.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => _dial(phone),
                    icon: const Icon(Icons.phone_outlined),
                    label: Text('Call $phone'),
                  ),
                ],
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  initialValue: _outcome,
                  decoration: const InputDecoration(labelText: 'Call outcome'),
                  items: const [
                    DropdownMenuItem(value: 'answered', child: Text('Answered')),
                    DropdownMenuItem(value: 'no_answer', child: Text('No answer')),
                    DropdownMenuItem(value: 'busy', child: Text('Busy')),
                    DropdownMenuItem(value: 'wrong_number', child: Text('Wrong number')),
                    DropdownMenuItem(value: 'switched_off', child: Text('Switched off')),
                  ],
                  onChanged: (v) => setState(() => _outcome = v ?? 'answered'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _action,
                  decoration: const InputDecoration(labelText: 'Customer response'),
                  items: const [
                    DropdownMenuItem(value: 'none', child: Text('No commitment change')),
                    DropdownMenuItem(value: 'new_promise_date', child: Text('New promised date')),
                    DropdownMenuItem(value: 'will_pay_office', child: Text('Will pay at office')),
                    DropdownMenuItem(value: 'will_pay_field', child: Text('Will pay to agent')),
                    DropdownMenuItem(value: 'refused', child: Text('Refused')),
                    DropdownMenuItem(value: 'already_paid', child: Text('Already paid')),
                    DropdownMenuItem(value: 'callback_later', child: Text('Call back later')),
                  ],
                  onChanged: (v) => setState(() => _action = v ?? 'none'),
                ),
                if (_action == 'new_promise_date') ...[
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('New promised date'),
                    subtitle: Text(_promisedDate == null ? 'Tap to pick' : _formatDate(_promisedDate!)),
                    trailing: const Icon(Icons.calendar_month),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now().add(const Duration(days: 3)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 60)),
                      );
                      if (picked != null) setState(() => _promisedDate = picked);
                    },
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: _notesCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Notes'),
                ),
                if (_history.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text('Previous calls', style: TextStyle(fontWeight: FontWeight.w800, color: pn.textSoft)),
                  const SizedBox(height: 8),
                  ..._history.map(
                    (c) => Card(
                      child: ListTile(
                        title: Text(c.callOutcome),
                        subtitle: Text(c.notes ?? c.commitmentAction ?? ''),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Saving...' : 'Save Call Record'),
                ),
              ],
            ),
    );
  }
}