import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../data/bills_repository.dart';
import '../../models/bill.dart';
import '../../providers/auth_provider.dart';
import '../../providers/bills_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state.dart';

class CollectPaymentScreen extends StatefulWidget {
  final String billId;
  const CollectPaymentScreen({super.key, required this.billId});

  @override
  State<CollectPaymentScreen> createState() => _CollectPaymentScreenState();
}

class _CollectPaymentScreenState extends State<CollectPaymentScreen> {
  final BillsRepository _repo = BillsRepository();
  Bill? _bill;
  bool _loading = true;
  String? _error;

  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  // ignore: prefer_final_fields
  String _method = 'cash';
  bool _submitting = false;
  final _formKey = GlobalKey<FormState>();

  static const _methods = [
    ('cash', 'Cash'),
    ('easypaisa', 'EasyPaisa'),
    ('jazzcash', 'JazzCash'),
    ('bank', 'Bank'),
    ('other', 'Other'),
  ];

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
      _bill = await _repo.fetchById(widget.billId);
      if (_bill != null) {
        _amountCtrl.text = _bill!.remaining.toStringAsFixed(0);
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final bills = context.read<BillsProvider>();
    final staff = auth.currentStaff;
    if (staff == null || _bill == null) return;

    setState(() => _submitting = true);
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    final ok = await bills.collectPayment(
      billId: widget.billId,
      amount: amount,
      collectorId: staff.id,
      paymentMethod: _method,
      paymentNote: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
    );
    if (mounted) setState(() => _submitting = false);
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment collected successfully'),
          backgroundColor: Color(0xFF16A34A),
        ),
      );
      context.pop();
    } else if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to record payment. Try again.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pn = Theme.of(context).extension<PnColors>()!;
    return Scaffold(
      appBar: AppBar(title: const Text('Collect Payment')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ErrorState(message: _error!, onRetry: _load)
              : _bill == null
                  ? const EmptyState(message: 'Bill not found')
                  : _Form(
                      bill: _bill!,
                      pn: pn,
                      amountCtrl: _amountCtrl,
                      noteCtrl: _noteCtrl,
                      method: _method,
                      methods: _methods,
                      submitting: _submitting,
                      formKey: _formKey,
                      onMethodChanged: (v) => (v != null)
                          ? null
                          : null,
                      onSubmit: _submit,
                    ),
    );
  }
}

class _Form extends StatelessWidget {
  final Bill bill;
  final PnColors pn;
  final TextEditingController amountCtrl;
  final TextEditingController noteCtrl;
  final String method;
  final List<(String, String)> methods;
  final bool submitting;
  final GlobalKey<FormState> formKey;
  final void Function(String?) onMethodChanged;
  final VoidCallback onSubmit;

  const _Form({
    required this.bill,
    required this.pn,
    required this.amountCtrl,
    required this.noteCtrl,
    required this.method,
    required this.methods,
    required this.submitting,
    required this.formKey,
    required this.onMethodChanged,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SummaryCard(bill: bill, pn: pn),
            const SizedBox(height: 20),
            Text('Amount (Rs.)',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: pn.text)),
            const SizedBox(height: 8),
            TextFormField(
              controller: amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                prefixText: 'Rs. ',
                hintText: '0',
              ),
              validator: (v) {
                final n = double.tryParse(v ?? '');
                if (n == null || n <= 0) return 'Enter valid amount';
                return null;
              },
            ),
            const SizedBox(height: 16),
            Text('Payment Method',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: pn.text)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              // ignore: deprecated_member_use
              value: method,
              items: methods
                  .map((m) => DropdownMenuItem(value: m.$1, child: Text(m.$2)))
                  .toList(),
              onChanged: onMethodChanged,
              decoration: const InputDecoration(),
            ),
            const SizedBox(height: 16),
            Text('Note (optional)',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: pn.text)),
            const SizedBox(height: 8),
            TextFormField(
              controller: noteCtrl,
              maxLines: 2,
              decoration: const InputDecoration(hintText: 'Add a note...'),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: submitting ? null : onSubmit,
                child: submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Confirm Payment',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final Bill bill;
  final PnColors pn;
  const _SummaryCard({required this.bill, required this.pn});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _Row(label: 'Customer', value: bill.customerName, pn: pn),
            _Row(label: 'Code', value: bill.customerCode, pn: pn),
            _Row(label: 'Month', value: bill.month, pn: pn),
            _Row(
                label: 'Bill Amount',
                value: 'Rs. ${bill.amount.toStringAsFixed(0)}',
                pn: pn),
            if (bill.paidAmount != null && bill.paidAmount! > 0)
              _Row(
                  label: 'Already Paid',
                  value: 'Rs. ${bill.paidAmount!.toStringAsFixed(0)}',
                  pn: pn),
            const Divider(height: 16),
            Row(
              children: [
                Text('Remaining',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, color: pn.text)),
                const Spacer(),
                Text(
                  'Rs. ${bill.remaining.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: Color(0xFFF05A2B),
                  ),
                ),
              ],
            ),
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
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label, style: TextStyle(color: pn.textMuted, fontSize: 13)),
          const Spacer(),
          Text(value,
              style: TextStyle(
                  color: pn.text,
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
