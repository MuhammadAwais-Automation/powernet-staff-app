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
          (staff.areaIds.isEmpty ||
              !staff.areaIds.contains(bill.customerAreaId))) {
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
        break;
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
        break;
      case PaymentSubmissionResult.failed:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save. Try again.'),
            backgroundColor: danger,
          ),
        );
        break;
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
      backgroundColor: pn.background,
      appBar: AppBar(
        backgroundColor: pn.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: pn.text),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Collect Payment',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: pn.text,
            letterSpacing: -0.5,
          ),
        ),
      ),
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
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
        children: [
          _BillHeader(bill: bill),
          const SizedBox(height: 20),
          _FieldLabel(label: 'Visit type', pn: pn),
          const SizedBox(height: 8),
          _VisitTypeSelector(
            selected: visitType,
            onChanged: onVisitTypeChanged,
            pn: pn,
          ),
          const SizedBox(height: 20),
          if (!isVisitOnly) ...[
            _QuickAmountRow(bill: bill, amountCtrl: amountCtrl, pn: pn),
            const SizedBox(height: 18),
            _FieldLabel(label: 'Collected amount', pn: pn),
            const SizedBox(height: 8),
            TextFormField(
              controller: amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                prefixText: 'Rs. ',
                prefixStyle: TextStyle(color: pn.text, fontWeight: FontWeight.bold),
                hintText: '0',
                filled: true,
                fillColor: pn.input,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: pn.border),
                ),
              ),
              style: TextStyle(fontWeight: FontWeight.w800, color: pn.text),
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
            const SizedBox(height: 20),
            _FieldLabel(label: 'Payment method', pn: pn),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: method,
              items: methods
                  .map((m) => DropdownMenuItem(value: m.$1, child: Text(m.$2, style: TextStyle(color: pn.text, fontWeight: FontWeight.bold))))
                  .toList(),
              onChanged: onMethodChanged,
              dropdownColor: pn.surface,
              decoration: InputDecoration(
                filled: true,
                fillColor: pn.input,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: pn.border),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
          _FieldLabel(label: 'Recovery / Visit note', pn: pn),
          const SizedBox(height: 8),
          TextFormField(
            controller: noteCtrl,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: isVisitOnly
                  ? 'Add details about this visit...'
                  : 'e.g. partial paid, promise date...',
              hintStyle: TextStyle(color: pn.textMuted),
              filled: true,
              fillColor: pn.input,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: pn.border),
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (!isVisitOnly) _OfflineHint(pn: pn),
          const SizedBox(height: 24),
          SizedBox(
            height: 54,
            child: ElevatedButton.icon(
              onPressed: submitting ? null : onSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: pn.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                elevation: 0,
              ),
              icon: submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      isVisitOnly
                          ? Icons.location_on_outlined
                          : Icons.verified_outlined,
                      size: 20,
                    ),
              label: Text(
                submitting
                    ? 'Saving...'
                    : isVisitOnly
                    ? 'Log Visit Only'
                    : 'Collect Payment',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 0.2),
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
        final color = _colorFor(type);
        return GestureDetector(
          onTap: () => onChanged(type),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isSelected ? color.withValues(alpha: 0.08) : pn.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isSelected ? color : pn.border,
                width: isSelected ? 2 : 1.2,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _iconFor(type),
                  size: 22,
                  color: isSelected ? color : pn.textMuted,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    type.label,
                    style: TextStyle(
                      color: isSelected ? color : pn.text,
                      fontWeight: isSelected
                          ? FontWeight.w900
                          : FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (isSelected)
                  Icon(Icons.check_circle_rounded, size: 20, color: color),
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

  Color _colorFor(VisitType type) => switch (type) {
    VisitType.paymentCollected => pn.success,
    VisitType.houseLocked => pn.warning,
    VisitType.promiseToPay => pn.cyan,
    VisitType.refusedToPay => pn.danger,
  };
}

class _BillHeader extends StatelessWidget {
  final Bill bill;

  const _BillHeader({required this.bill});

  @override
  Widget build(BuildContext context) {
    final pn = Theme.of(context).extension<PnColors>()!;
    final statusColor = bill.isPaid
        ? pn.success
        : (bill.isOverdue ? pn.danger : (bill.hasPartialPayment ? pn.cyan : pn.warning));

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
            Row(
              children: [
                Expanded(
                  child: Text(
                    bill.customerName,
                    style: TextStyle(
                      color: pn.text,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    bill.collectionStatus.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: statusColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${bill.customerCode} · ${bill.month}',
              style: TextStyle(color: pn.textMuted, fontSize: 13, fontWeight: FontWeight.bold),
            ),
            if (bill.hasAddress) ...[
              const SizedBox(height: 12),
              _AddressCard(bill: bill, pn: pn),
            ],
            const SizedBox(height: 18),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                minHeight: 8,
                value: bill.collectionProgress,
                backgroundColor: pn.surfaceMuted,
                color: bill.isPaid ? pn.success : pn.accent,
              ),
            ),
            const SizedBox(height: 16),
            // Multi-column money grids matching mockup
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: pn.surfaceMuted,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: pn.border),
              ),
              child: Row(
                children: [
                  _MoneyStat(label: 'Bill', value: bill.amount, pn: pn),
                  _MoneyStat(label: 'Paid', value: bill.paidAmount ?? 0, pn: pn),
                  _MoneyStat(
                    label: 'Remaining',
                    value: bill.remaining,
                    highlight: true,
                    pn: pn,
                  ),
                ],
              ),
            ),
          ],
        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
            child: Text(
              bill.customerAddress,
              style: TextStyle(
                color: pn.text,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
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
  final PnColors pn;

  const _MoneyStat({
    required this.label,
    required this.value,
    required this.pn,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: pn.textMuted,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'PKR ${_formatMoney(value)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: highlight ? pn.accent : pn.text,
              fontSize: highlight ? 13 : 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  String _formatMoney(double val) {
    if (val >= 1000) {
      final k = val / 1000;
      return '${k.toStringAsFixed(k.truncateToDouble() == k ? 0 : 1)}K';
    }
    return val.toStringAsFixed(0);
  }
}

class _QuickAmountRow extends StatelessWidget {
  final Bill bill;
  final TextEditingController amountCtrl;
  final PnColors pn;

  const _QuickAmountRow({required this.bill, required this.amountCtrl, required this.pn});

  @override
  Widget build(BuildContext context) {
    final half = (bill.remaining / 2).round();
    final full = bill.remaining.round();
    return Row(
      children: [
        _QuickAmountButton(
          label: 'Half',
          amount: half,
          pn: pn,
          onTap: () => amountCtrl.text = half.toString(),
        ),
        const SizedBox(width: 8),
        _QuickAmountButton(
          label: 'Full',
          amount: full,
          pn: pn,
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
  final PnColors pn;
  final VoidCallback onTap;

  const _QuickAmountButton({
    required this.label,
    required this.amount,
    required this.pn,
    required this.onTap,
    this.primaryAction = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryAction ? Colors.white : pn.text,
          backgroundColor: primaryAction ? pn.primary : pn.surface,
          side: BorderSide(color: primaryAction ? pn.primary : pn.border, width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        child: Text(
          '$label - Rs. $amount',
          style: const TextStyle(fontWeight: FontWeight.w900),
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
        fontWeight: FontWeight.w800,
        fontSize: 13,
        color: pn.textSoft,
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
        color: pn.cyan.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: pn.cyan.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.offline_bolt_outlined, size: 20, color: pn.cyan),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'If internet drops, this is saved locally and auto-syncs when internet returns.',
              style: TextStyle(color: pn.text, fontSize: 12, height: 1.35, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
