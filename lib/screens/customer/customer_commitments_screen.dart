import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/follow_up_repository.dart';
import '../../providers/customer_auth_provider.dart';
import '../../theme/app_theme.dart';

class CustomerCommitmentsScreen extends StatefulWidget {
  const CustomerCommitmentsScreen({super.key});

  @override
  State<CustomerCommitmentsScreen> createState() => _CustomerCommitmentsScreenState();
}

class _CustomerCommitmentsScreenState extends State<CustomerCommitmentsScreen> {
  final _repo = FollowUpRepository();
  List<CommitmentEvent> _events = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final customer = context.read<CustomerAuthProvider>().currentCustomer;
    if (customer == null) return;
    setState(() => _loading = true);
    try {
      _events = await _repo.fetchCommitmentEvents(customer.id);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatEventType(String type) {
    return switch (type) {
      'visit_logged' => 'Field Visit',
      'office_call' => 'Office Call',
      'agent_call' => 'Recovery Call',
      'payment_received' => 'Payment',
      'promise_updated' => 'Promise Updated',
      _ => type,
    };
  }

  @override
  Widget build(BuildContext context) {
    final pn = Theme.of(context).extension<PnColors>()!;
    return Scaffold(
      backgroundColor: pn.background,
      appBar: AppBar(title: const Text('Payment Commitments')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _events.isEmpty
          ? Center(
              child: Text(
                'No commitment history yet',
                style: TextStyle(color: pn.textMuted),
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: _events.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final event = _events[index];
                  final date = DateTime.tryParse(event.createdAt);
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: pn.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: pn.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _formatEventType(event.eventType),
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: pn.cyan,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            if (date != null)
                              Text(
                                '${date.day}/${date.month}/${date.year}',
                                style: TextStyle(fontSize: 11, color: pn.textMuted),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(event.summary, style: TextStyle(color: pn.text, fontSize: 13)),
                        if (event.promisedDate != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Promised: ${event.promisedDate}',
                            style: TextStyle(color: pn.warning, fontWeight: FontWeight.w700, fontSize: 12),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }
}