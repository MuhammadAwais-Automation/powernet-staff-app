import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../data/bills_repository.dart';
import '../../models/bill.dart';
import '../../providers/auth_provider.dart';
import '../../providers/bills_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/pn_status_badge.dart';

class CollectPaymentScreen extends StatefulWidget {
  final String billId;
  const CollectPaymentScreen({super.key, required this.billId});

  @override
  State<CollectPaymentScreen> createState() => _CollectPaymentScreenState();
}

class _CollectPaymentScreenState extends State<CollectPaymentScreen> {
  final BillsRepository _repo = BillsRepository();
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  Bill? _bill;
  bool _loading = true;
  bool _submitting = false;
  String? _error;
  String _method = 'cash';
  VisitType _visitType = VisitType.paymentCollected;

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
    final cachedBill = context.read<BillsProvider>().findBillById(
      widget.billId,
    );
    if (cachedBill != null) {
      _applyLoadedBill(cachedBill);
      if (mounted) setState(() => _loading = false);
    }
    try {
      final bill = await _repo.fetchById(widget.billId);
      if (mounted) {
        _applyLoadedBill(bill);
      }
    } on Exception catch (e) {
      if (_bill == null) {
        debugPrint('POWERNET_DEBUG: collect bill load failed: $e');
        _error =
            'Internet band hai. Bill detail open karne ke liye pehle Recovery Console se synced/cached bill select karein.';
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyLoadedBill(Bill? bill) {
    final auth = context.read<AuthProvider>();
    final staff = auth.currentStaff;
    if (bill != null && staff != null) {
      final isRecovery = staff.normalizedRole == 'recovery_agent';
      if (isRecovery &&
          (staff.areaId == null || bill.customerAreaId != staff.areaId)) {
        _error = 'Access Denied: Yeh bill aapke assigned area ka nahi hai.';
        _bill = null;
        return;
      }
    }
    _bill = bill;
    _error = null;
    if (bill != null) _amountCtrl.text = bill.remaining.toStringAsFixed(0);
  }

  void _onVisitTypeChanged(VisitType? type) {
    if (type == null) return;
    setState(() {
      _visitType = type;
      if (type.isVisitOnly) {
        _amountCtrl.text = '0';
        if (_noteCtrl.text.isEmpty) _noteCtrl.text = type.label;
      } else {
        final bill = _bill;
        if (bill != null) _amountCtrl.text = bill.remaining.toStringAsFixed(0);
        final autoNotes = VisitType.values.map((v) => v.label).toSet();
        if (autoNotes.contains(_noteCtrl.text)) _noteCtrl.text = '';
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final bills = context.read<BillsProvider>();
    final staff = auth.currentStaff;
    final bill = _bill;
    if (staff == null || bill == null) return;

    setState(() => _submitting = true);

    double? paidAmount;
    final PaymentSubmissionResult result;
    if (_visitType.isVisitOnly) {
      result = await bills.submitVisit(
        billId: widget.billId,
        collectorId: staff.id,
        visitType: _visitType.value,
      );
    } else {
      paidAmount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
      final rawNote = _noteCtrl.text.trim();
      result = await bills.submitPayment(
        billId: widget.billId,
        amount: paidAmount,
        collectorId: staff.id,
        paymentMethod: _method,
        paymentNote: rawNote.isEmpty ? null : rawNote,
      );
    }
    if (mounted) setState(() => _submitting = false);
    if (!mounted) return;

    final fullPayment = paidAmount != null && paidAmount >= bill.remaining;
    switch (result) {
      case PaymentSubmissionResult.synced:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _visitType.isVisitOnly
                  ? '${_visitType.label} logged'
                  : fullPayment
                  ? 'Full payment recorded'
                  : 'Partial payment recorded',
            ),
            backgroundColor: success,
          ),
        );
        context.go('/collector/bills');
      case PaymentSubmissionResult.queued:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Saved offline. Internet on hotay hi auto sync ho jayega.',
            ),
            backgroundColor: warning,
          ),
        );
        context.go('/collector/bills');
      case PaymentSubmissionResult.failed:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save. Try again.'),
            backgroundColor: danger,
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
      backgroundColor: pn.surfaceMuted,
      appBar: AppBar(title: const Text('Collect Payment')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? ErrorState(message: _error!, onRetry: _load)
          : _bill == null
          ? const EmptyState(message: 'Bill not found')
          : _PaymentForm(
              bill: _bill!,
              formKey: _formKey,
              amountCtrl: _amountCtrl,
              noteCtrl: _noteCtrl,
              method: _method,
              methods: _methods,
              submitting: _submitting,
              visitType: _visitType,
              onVisitTypeChanged: _onVisitTypeChanged,
              onMethodChanged: (value) {
                if (value != null) setState(() => _method = value);
              },
              onSubmit: _submit,
            ),
    );
  }
}

class _PaymentForm extends StatelessWidget {
  final Bill bill;
  final GlobalKey<FormState> formKey;
  final TextEditingController amountCtrl;
  final TextEditingController noteCtrl;
  final String method;
  final List<(String, String)> methods;
  final bool submitting;
  final VisitType visitType;
  final void Function(VisitType?) onVisitTypeChanged;
  final void Function(String?) onMethodChanged;
  final VoidCallback onSubmit;

  const _PaymentForm({
    required this.bill,
    required this.formKey,
    required this.amountCtrl,
    required this.noteCtrl,
    required this.method,
    required this.methods,
    required this.submitting,
    required this.visitType,
    required this.onVisitTypeChanged,
    required this.onMethodChanged,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final pn = Theme.of(context).extension<PnColors>()!;
    final isVisitOnly = visitType.isVisitOnly;
    return Form(
      key: formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
        children: [
          _BillHeader(bill: bill),
          const SizedBox(height: 16),
          _FieldLabel(label: 'Visit type', pn: pn),
          const SizedBox(height: 8),
          _VisitTypeSelector(
            selected: visitType,
            onChanged: onVisitTypeChanged,
            pn: pn,
          ),
          const SizedBox(height: 16),
          if (!isVisitOnly) ...[
            _QuickAmountRow(bill: bill, amountCtrl: amountCtrl),
            const SizedBox(height: 14),
            _FieldLabel(label: 'Collected amount', pn: pn),
            const SizedBox(height: 8),
            TextFormField(
              controller: amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                prefixText: 'Rs. ',
                hintText: '0',
              ),
              validator: (value) {
                if (isVisitOnly) return null;
                final amount = double.tryParse(value ?? '');
                if (amount == null || amount <= 0) return 'Enter valid amount';
                if (amount > bill.remaining) {
                  return 'Amount cannot exceed Rs. ${bill.remaining.toStringAsFixed(0)}';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            _FieldLabel(label: 'Payment method', pn: pn),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: method,
              items: methods
                  .map((m) => DropdownMenuItem(value: m.$1, child: Text(m.$2)))
                  .toList(),
              onChanged: onMethodChanged,
              decoration: const InputDecoration(),
            ),
            const SizedBox(height: 16),
          ],
          _FieldLabel(label: 'Recovery note', pn: pn),
          const SizedBox(height: 8),
          TextFormField(
            controller: noteCtrl,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: isVisitOnly
                  ? 'Add details about this visit...'
                  : 'e.g. partial paid, promise date...',
            ),
          ),
          const SizedBox(height: 18),
          if (!isVisitOnly) _OfflineHint(pn: pn),
          const SizedBox(height: 22),
          SizedBox(
            height: 54,
            child: ElevatedButton.icon(
              onPressed: submitting ? null : onSubmit,
              icon: submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      isVisitOnly
                          ? Icons.location_on_outlined
                          : Icons.verified_outlined,
                    ),
              label: Text(
                submitting
                    ? 'Saving...'
                    : isVisitOnly
                    ? 'Log Visit'
                    : 'Record Collection',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VisitTypeSelector extends StatelessWidget {
  final VisitType selected;
  final void Function(VisitType?) onChanged;
  final PnColors pn;

  const _VisitTypeSelector({
    required this.selected,
    required this.onChanged,
    required this.pn,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: VisitType.values.map((type) {
        final isSelected = selected == type;
        return GestureDetector(
          onTap: () => onChanged(type),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? primary.withValues(alpha: 0.1) : pn.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? primary : pn.border,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _iconFor(type),
                  size: 20,
                  color: isSelected ? primary : pn.textMuted,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    type.label,
                    style: TextStyle(
                      color: isSelected ? primary : pn.text,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (isSelected)
                  Icon(Icons.check_circle, size: 18, color: primary),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  IconData _iconFor(VisitType type) => switch (type) {
    VisitType.paymentCollected => Icons.payments_outlined,
    VisitType.houseLocked => Icons.lock_outline,
    VisitType.promiseToPay => Icons.handshake_outlined,
    VisitType.refusedToPay => Icons.block_outlined,
  };
}

class _BillHeader extends StatelessWidget {
  final Bill bill;

  const _BillHeader({required this.bill});

  @override
  Widget build(BuildContext context) {
    final pn = Theme.of(context).extension<PnColors>()!;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: pn.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: pn.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  bill.customerName,
                  style: TextStyle(
                    color: pn.text,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              PnStatusBadge.fromString(bill.collectionStatus),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${bill.customerCode} · ${bill.month}',
            style: TextStyle(color: pn.textMuted, fontSize: 13),
          ),
          if (bill.hasAddress) ...[
            const SizedBox(height: 10),
            _AddressCard(bill: bill, pn: pn),
          ],
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: bill.collectionProgress,
              backgroundColor: pn.surfaceMuted,
              color: primary,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _MoneyStat(label: 'Bill', value: bill.amount),
              _MoneyStat(label: 'Paid', value: bill.paidAmount ?? 0),
              _MoneyStat(
                label: 'Balance',
                value: bill.remaining,
                highlight: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AddressCard extends StatelessWidget {
  final Bill bill;
  final PnColors pn;

  const _AddressCard({required this.bill, required this.pn});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: pn.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: pn.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.location_on_outlined, size: 16, color: pn.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bill.customerAddress,
                  style: TextStyle(
                    color: pn.text,
                    fontSize: 12,
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

class _MoneyStat extends StatelessWidget {
  final String label;
  final double value;
  final bool highlight;

  const _MoneyStat({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final pn = Theme.of(context).extension<PnColors>()!;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: pn.textMuted, fontSize: 11)),
          const SizedBox(height: 3),
          Text(
            'Rs. ${value.toStringAsFixed(0)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: highlight ? primary : pn.text,
              fontSize: highlight ? 16 : 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAmountRow extends StatelessWidget {
  final Bill bill;
  final TextEditingController amountCtrl;

  const _QuickAmountRow({required this.bill, required this.amountCtrl});

  @override
  Widget build(BuildContext context) {
    final half = (bill.remaining / 2).round();
    final full = bill.remaining.round();
    return Row(
      children: [
        _QuickAmountButton(
          label: 'Half',
          amount: half,
          onTap: () => amountCtrl.text = half.toString(),
        ),
        const SizedBox(width: 8),
        _QuickAmountButton(
          label: 'Full',
          amount: full,
          primaryAction: true,
          onTap: () => amountCtrl.text = full.toString(),
        ),
      ],
    );
  }
}

class _QuickAmountButton extends StatelessWidget {
  final String label;
  final int amount;
  final bool primaryAction;
  final VoidCallback onTap;

  const _QuickAmountButton({
    required this.label,
    required this.amount,
    required this.onTap,
    this.primaryAction = false,
  });

  @override
  Widget build(BuildContext context) {
    final pn = Theme.of(context).extension<PnColors>()!;
    return Expanded(
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryAction ? Colors.white : pn.text,
          backgroundColor: primaryAction ? primary : pn.surface,
          side: BorderSide(color: primaryAction ? primary : pn.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        child: Text(
          '$label - Rs. $amount',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;
  final PnColors pn;

  const _FieldLabel({required this.label, required this.pn});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 13,
        color: pn.text,
      ),
    );
  }
}

class _OfflineHint extends StatelessWidget {
  final PnColors pn;

  const _OfflineHint({required this.pn});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: info.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: info.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.offline_bolt_outlined, size: 19, color: info),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'If internet drops, this is saved locally and auto-syncs when internet returns.',
              style: TextStyle(color: pn.text, fontSize: 12, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}
