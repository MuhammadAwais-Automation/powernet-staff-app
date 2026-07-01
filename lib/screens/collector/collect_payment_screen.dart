import 'dart:io' show File;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../data/bills_repository.dart';
import '../../models/bill.dart';
import '../../providers/auth_provider.dart';
import '../../providers/bills_provider.dart';
import '../../services/cloudinary_service.dart';
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
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  CustomerBillLedger? _ledger;
  bool _loading = true;
  bool _submitting = false;
  String? _error;
  String _method = 'cash';
  VisitType _visitType = VisitType.paymentCollected;
  DateTime? _promisedDate;
  XFile? _proofImage;
  RemainderAction _remainderAction = RemainderAction.leave;
  final _cloudinaryService = CloudinaryService();
  final _imagePicker = ImagePicker();

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
    final cachedLedger = context.read<BillsProvider>().findLedgerByBillId(
      widget.billId,
    );
    if (cachedLedger != null) {
      _applyLoadedLedger(cachedLedger);
      if (mounted) setState(() => _loading = false);
    }
    try {
      final bill = await _repo.fetchById(widget.billId);
      if (mounted) {
        if (bill == null) {
          _applyLoadedLedger(null);
        } else {
          final customerBills = await _repo.fetchByCustomer(bill.customerId);
          final pendingBills = customerBills
              .where((item) => !item.isPaid && item.remaining > 0)
              .toList();
          _applyLoadedLedger(
            pendingBills.isEmpty
                ? CustomerBillLedger.fromBills([bill])
                : CustomerBillLedger.fromBills(customerBills),
          );
        }
      }
    } on Exception catch (e) {
      if (_ledger == null) {
        debugPrint('POWERNET_DEBUG: collect bill load failed: $e');
        _error =
            'No internet connection. To view bill details, please select a cached bill from the Recovery Console first.';
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyLoadedLedger(CustomerBillLedger? ledger) {
    final auth = context.read<AuthProvider>();
    final staff = auth.currentStaff;
    if (ledger != null && staff != null) {
      final isRecovery = staff.normalizedRole == 'recovery_agent';
      if (isRecovery &&
          (staff.areaIds.isEmpty ||
              !staff.areaIds.contains(ledger.customerAreaId))) {
        _error =
            'Access Denied: This bill does not belong to your assigned service area.';
        _ledger = null;
        return;
      }
    }
    _ledger = ledger;
    _error = null;
    if (ledger != null) {
      _amountCtrl.text = ledger.totalRemaining.toStringAsFixed(0);
    }
  }

  DateTime _defaultPromisedDate() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day).add(const Duration(days: 3));
  }

  String _formatDateOnly(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  void _onVisitTypeChanged(VisitType? type) {
    if (type == null) return;
    setState(() {
      _visitType = type;
      if (type.isVisitOnly) {
        _amountCtrl.text = '0';
        if (_noteCtrl.text.isEmpty) _noteCtrl.text = type.label;
        if (type == VisitType.promiseToPay) {
          _promisedDate ??= _defaultPromisedDate();
        } else {
          _promisedDate = null;
        }
      } else {
        _promisedDate = null;
        final ledger = _ledger;
        if (ledger != null) {
          _amountCtrl.text = ledger.totalRemaining.toStringAsFixed(0);
        }
        final autoNotes = VisitType.values.map((v) => v.label).toSet();
        if (autoNotes.contains(_noteCtrl.text)) _noteCtrl.text = '';
      }
    });
  }

  Future<void> _pickPromisedDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _promisedDate ?? _defaultPromisedDate(),
      firstDate: today,
      lastDate: today.add(const Duration(days: 30)),
      helpText: 'Select promised pay date',
    );
    if (picked != null && mounted) {
      setState(() => _promisedDate = DateTime(picked.year, picked.month, picked.day));
    }
  }

  Future<void> _pickProofImage(ImageSource source) async {
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (picked != null && mounted) {
        setState(() => _proofImage = picked);
      }
    } on Exception catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not pick image: $e'), backgroundColor: danger),
      );
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_visitType == VisitType.promiseToPay && _promisedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select the promised payment date'),
          backgroundColor: danger,
        ),
      );
      return;
    }
    final auth = context.read<AuthProvider>();
    final bills = context.read<BillsProvider>();
    final staff = auth.currentStaff;
    final ledger = _ledger;
    if (staff == null || ledger == null) return;

    setState(() => _submitting = true);

    double? paidAmount;
    final PaymentSubmissionResult result;
    if (_visitType.isVisitOnly) {
      result = await bills.submitVisit(
        billId: ledger.currentBill.id,
        collectorId: staff.id,
        visitType: _visitType.value,
        promisedDate: _visitType == VisitType.promiseToPay && _promisedDate != null
            ? _formatDateOnly(_promisedDate!)
            : null,
      );
    } else {
      paidAmount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
      final rawNote = _noteCtrl.text.trim();
      String? receiptUrl;
      if (_proofImage != null) {
        receiptUrl = await _cloudinaryService.uploadReceipt(_proofImage!);
        if (receiptUrl == null) {
          if (mounted) {
            setState(() => _submitting = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Proof upload failed. Try again or continue without proof.'),
                backgroundColor: danger,
              ),
            );
          }
          return;
        }
      }
      final isPartial = paidAmount < ledger.totalRemaining;
      result = await bills.submitLedgerPayment(
        ledger: ledger,
        amount: paidAmount,
        collectorId: staff.id,
        paymentMethod: _method,
        paymentNote: rawNote.isEmpty ? null : rawNote,
        receiptUrl: receiptUrl,
        remainderAction: isPartial ? _remainderAction : RemainderAction.leave,
      );
    }
    if (mounted) setState(() => _submitting = false);
    if (!mounted) return;

    final fullPayment =
        paidAmount != null && paidAmount >= ledger.totalRemaining;
    final isPartialPayment =
        paidAmount != null && paidAmount < ledger.totalRemaining;
    switch (result) {
      case PaymentSubmissionResult.synced:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _visitType.isVisitOnly
                  ? '${_visitType.label} logged'
                  : fullPayment
                  ? 'Full payment recorded'
                  : isPartialPayment &&
                        _remainderAction == RemainderAction.carryForward
                  ? 'Less paid recorded — remainder added to next month bill'
                  : 'Less paid recorded — remainder stays on current bill',
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
              'Saved offline. Will auto-sync when internet connection is restored.',
            ),
            backgroundColor: warning,
          ),
        );
        context.go('/collector/bills');
        break;
      case PaymentSubmissionResult.failed:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(bills.error ?? 'Failed to save. Try again.'),
            backgroundColor: danger,
          ),
        );
        break;
      case PaymentSubmissionResult.alreadyPaid:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(bills.error ?? 'Bill already paid. List refreshed.'),
            backgroundColor: warning,
          ),
        );
        context.go('/collector/bills');
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
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/collector/bills');
            }
          },
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
          : _ledger == null
          ? const EmptyState(message: 'Bill not found')
          : _PaymentForm(
              ledger: _ledger!,
              formKey: _formKey,
              amountCtrl: _amountCtrl,
              noteCtrl: _noteCtrl,
              method: _method,
              methods: _methods,
              submitting: _submitting,
              visitType: _visitType,
              promisedDate: _promisedDate,
              proofImage: _proofImage,
              remainderAction: _remainderAction,
              onPickPromisedDate: _pickPromisedDate,
              onPickProof: _pickProofImage,
              onClearProof: () => setState(() => _proofImage = null),
              onRemainderActionChanged: (action) =>
                  setState(() => _remainderAction = action),
              onVisitTypeChanged: _onVisitTypeChanged,
              onMethodChanged: (value) {
                if (value != null) setState(() => _method = value);
              },
              onSubmit: _submit,
            ),
    );
  }
}

class _PaymentForm extends StatefulWidget {
  final CustomerBillLedger ledger;
  final GlobalKey<FormState> formKey;
  final TextEditingController amountCtrl;
  final TextEditingController noteCtrl;
  final String method;
  final List<(String, String)> methods;
  final bool submitting;
  final VisitType visitType;
  final DateTime? promisedDate;
  final XFile? proofImage;
  final RemainderAction remainderAction;
  final VoidCallback onPickPromisedDate;
  final void Function(ImageSource source) onPickProof;
  final VoidCallback onClearProof;
  final void Function(RemainderAction action) onRemainderActionChanged;
  final void Function(VisitType?) onVisitTypeChanged;
  final void Function(String?) onMethodChanged;
  final VoidCallback onSubmit;

  const _PaymentForm({
    required this.ledger,
    required this.formKey,
    required this.amountCtrl,
    required this.noteCtrl,
    required this.method,
    required this.methods,
    required this.submitting,
    required this.visitType,
    required this.promisedDate,
    required this.proofImage,
    required this.remainderAction,
    required this.onPickPromisedDate,
    required this.onPickProof,
    required this.onClearProof,
    required this.onRemainderActionChanged,
    required this.onVisitTypeChanged,
    required this.onMethodChanged,
    required this.onSubmit,
  });

  @override
  State<_PaymentForm> createState() => _PaymentFormState();
}

class _PaymentFormState extends State<_PaymentForm> {
  @override
  void initState() {
    super.initState();
    widget.amountCtrl.addListener(_onAmountChanged);
  }

  @override
  void dispose() {
    widget.amountCtrl.removeListener(_onAmountChanged);
    super.dispose();
  }

  void _onAmountChanged() => setState(() {});

  double get _enteredAmount =>
      double.tryParse(widget.amountCtrl.text.trim()) ?? 0;

  bool get _isLessPaid =>
      !widget.visitType.isVisitOnly &&
      _enteredAmount > 0 &&
      _enteredAmount < widget.ledger.totalRemaining;

  double get _remainderAmount =>
      (widget.ledger.totalRemaining - _enteredAmount).clamp(0, double.infinity);

  Future<void> _showProofSourceDialog() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source != null) widget.onPickProof(source);
  }

  @override
  Widget build(BuildContext context) {
    final pn = Theme.of(context).extension<PnColors>()!;
    final isVisitOnly = widget.visitType.isVisitOnly;
    return Form(
      key: widget.formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
        children: [
          _BillHeader(ledger: widget.ledger),
          const SizedBox(height: 20),
          _FieldLabel(label: 'Visit type', pn: pn),
          const SizedBox(height: 8),
          _VisitTypeSelector(
            selected: widget.visitType,
            onChanged: widget.onVisitTypeChanged,
            pn: pn,
          ),
          if (widget.visitType == VisitType.promiseToPay) ...[
            const SizedBox(height: 20),
            _FieldLabel(label: 'Promised pay date', pn: pn),
            const SizedBox(height: 8),
            _PromisedDateField(
              promisedDate: widget.promisedDate,
              onPick: widget.onPickPromisedDate,
              pn: pn,
            ),
          ],
          const SizedBox(height: 20),
          if (!isVisitOnly) ...[
            _QuickAmountRow(
              ledger: widget.ledger,
              amountCtrl: widget.amountCtrl,
              pn: pn,
            ),
            const SizedBox(height: 18),
            _FieldLabel(label: 'Collected amount', pn: pn),
            const SizedBox(height: 8),
            TextFormField(
              controller: widget.amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                prefixText: 'Rs. ',
                prefixStyle: TextStyle(
                  color: pn.text,
                  fontWeight: FontWeight.bold,
                ),
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
                if (amount > widget.ledger.totalRemaining) {
                  return 'Amount cannot exceed Rs. ${widget.ledger.totalRemaining.toStringAsFixed(0)}';
                }
                return null;
              },
            ),
            if (_isLessPaid) ...[
              const SizedBox(height: 16),
              _LessPaidRemainderCard(
                remainderAmount: _remainderAmount,
                selectedAction: widget.remainderAction,
                onActionChanged: widget.onRemainderActionChanged,
                pn: pn,
              ),
            ],
            const SizedBox(height: 20),
            _FieldLabel(label: 'Payment method', pn: pn),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: widget.method,
              items: widget.methods
                  .map(
                    (m) => DropdownMenuItem(
                      value: m.$1,
                      child: Text(
                        m.$2,
                        style: TextStyle(
                          color: pn.text,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: widget.onMethodChanged,
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
            _FieldLabel(label: 'Payment proof (optional)', pn: pn),
            const SizedBox(height: 8),
            _ProofPicker(
              proofImage: widget.proofImage,
              onPick: () {
                if (kIsWeb) {
                  widget.onPickProof(ImageSource.gallery);
                } else {
                  _showProofSourceDialog();
                }
              },
              onClear: widget.onClearProof,
              pn: pn,
            ),
          ],
          const SizedBox(height: 20),
          _FieldLabel(label: 'Recovery / Visit note', pn: pn),
          const SizedBox(height: 8),
          TextFormField(
            controller: widget.noteCtrl,
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
              onPressed: widget.submitting ? null : widget.onSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: pn.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                elevation: 0,
              ),
              icon: widget.submitting
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
                widget.submitting
                    ? 'Saving...'
                    : isVisitOnly
                    ? 'Log Visit Only'
                    : _isLessPaid
                    ? 'Record Less Paid'
                    : 'Collect Payment',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LessPaidRemainderCard extends StatelessWidget {
  final double remainderAmount;
  final RemainderAction selectedAction;
  final void Function(RemainderAction action) onActionChanged;
  final PnColors pn;

  const _LessPaidRemainderCard({
    required this.remainderAmount,
    required this.selectedAction,
    required this.onActionChanged,
    required this.pn,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: pn.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: pn.warning.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, size: 18, color: pn.warning),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Rs. ${remainderAmount.toStringAsFixed(0)} will remain after this payment',
                  style: TextStyle(
                    color: pn.text,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'What should happen to the remaining amount?',
            style: TextStyle(
              color: pn.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          _RemainderOption(
            title: 'Leave outstanding',
            subtitle: 'Keep remainder on current bill(s)',
            icon: Icons.schedule_outlined,
            color: pn.warning,
            selected: selectedAction == RemainderAction.leave,
            onTap: () => onActionChanged(RemainderAction.leave),
            pn: pn,
          ),
          const SizedBox(height: 8),
          _RemainderOption(
            title: 'Add to next month bill',
            subtitle: 'Carry remainder forward to next billing cycle',
            icon: Icons.forward_outlined,
            color: pn.cyan,
            selected: selectedAction == RemainderAction.carryForward,
            onTap: () => onActionChanged(RemainderAction.carryForward),
            pn: pn,
          ),
        ],
      ),
    );
  }
}

class _RemainderOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final PnColors pn;

  const _RemainderOption({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
    required this.pn,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.1) : pn.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? color : pn.border,
            width: selected ? 2 : 1.2,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: selected ? color : pn.textMuted),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: selected ? color : pn.text,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: pn.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle_rounded, size: 18, color: color),
          ],
        ),
      ),
    );
  }
}

class _ProofPicker extends StatelessWidget {
  final XFile? proofImage;
  final VoidCallback onPick;
  final VoidCallback onClear;
  final PnColors pn;

  const _ProofPicker({
    required this.proofImage,
    required this.onPick,
    required this.onClear,
    required this.pn,
  });

  @override
  Widget build(BuildContext context) {
    if (proofImage != null) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              height: 140,
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(color: pn.border),
                image: DecorationImage(
                  image: kIsWeb
                      ? NetworkImage(proofImage!.path) as ImageProvider
                      : FileImage(File(proofImage!.path)),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: CircleAvatar(
              backgroundColor: Colors.black.withValues(alpha: 0.6),
              radius: 18,
              child: IconButton(
                icon: const Icon(Icons.delete, size: 16, color: Colors.white),
                onPressed: onClear,
              ),
            ),
          ),
        ],
      );
    }

    return InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 110,
        decoration: BoxDecoration(
          color: pn.cyan.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: pn.cyan.withValues(alpha: 0.35)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined, size: 32, color: pn.cyan),
            const SizedBox(height: 8),
            Text(
              'Attach payment proof (Camera / Gallery)',
              style: TextStyle(
                color: pn.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PromisedDateField extends StatelessWidget {
  final DateTime? promisedDate;
  final VoidCallback onPick;
  final PnColors pn;

  const _PromisedDateField({
    required this.promisedDate,
    required this.onPick,
    required this.pn,
  });

  String _formatDisplay(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPick,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: pn.cyan.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: pn.cyan.withValues(alpha: 0.35), width: 1.5),
          ),
          child: Row(
            children: [
              Icon(Icons.calendar_month_rounded, color: pn.cyan, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      promisedDate == null
                          ? 'Tap to select date'
                          : _formatDisplay(promisedDate!),
                      style: TextStyle(
                        color: promisedDate == null ? pn.textMuted : pn.text,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Customer committed to pay on this date',
                      style: TextStyle(
                        color: pn.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: pn.textMuted),
            ],
          ),
        ),
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
  final CustomerBillLedger ledger;

  const _BillHeader({required this.ledger});

  @override
  Widget build(BuildContext context) {
    final pn = Theme.of(context).extension<PnColors>()!;
    final statusColor = ledger.totalRemaining <= 0
        ? pn.success
        : (ledger.isOverdue
              ? pn.danger
              : (ledger.hasPartialPayment ? pn.cyan : pn.warning));

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
                    ledger.customerName,
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    ledger.collectionStatus.toUpperCase(),
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
              '${ledger.customerCode} - ${ledger.monthRange}',
              style: TextStyle(
                color: pn.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (ledger.hasAddress) ...[
              const SizedBox(height: 12),
              _AddressCard(ledger: ledger, pn: pn),
            ],
            const SizedBox(height: 18),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                minHeight: 8,
                value: ledger.collectionProgress,
                backgroundColor: pn.surfaceMuted,
                color: ledger.totalRemaining <= 0 ? pn.success : pn.accent,
              ),
            ),
            const SizedBox(height: 16),
            _BillBreakdown(ledger: ledger, pn: pn),
            const SizedBox(height: 12),
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
                  _MoneyStat(label: 'Bills', value: ledger.totalAmount, pn: pn),
                  _MoneyStat(label: 'Paid', value: ledger.totalPaid, pn: pn),
                  _MoneyStat(
                    label: 'Total Due',
                    value: ledger.totalRemaining,
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
  final CustomerBillLedger ledger;
  final PnColors pn;

  const _AddressCard({required this.ledger, required this.pn});

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
              ledger.customerAddress,
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

class _BillBreakdown extends StatelessWidget {
  final CustomerBillLedger ledger;
  final PnColors pn;

  const _BillBreakdown({required this.ledger, required this.pn});

  @override
  Widget build(BuildContext context) {
    // Show each open bill as its own row, oldest first (FIFO order)
    final openBills = [...ledger.openBills].reversed.toList();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: pn.softOrange.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: pn.warning.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Per-month rows
          ...openBills.map((bill) => _MonthBillRow(bill: bill, pn: pn)),
          const Divider(height: 18),
          // Total
          _BreakdownRow(
            label: 'Total payable',
            value: ledger.totalRemaining,
            pn: pn,
            strong: true,
          ),
          const SizedBox(height: 10),
          // FIFO note
          Row(
            children: [
              Icon(Icons.info_outline, size: 12, color: pn.textMuted),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  'Payment clears oldest bills first (FIFO)',
                  style: TextStyle(
                    fontSize: 10,
                    color: pn.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MonthBillRow extends StatelessWidget {
  final Bill bill;
  final PnColors pn;

  const _MonthBillRow({required this.bill, required this.pn});

  Color _statusColor() {
    if (bill.isOverdue) return pn.danger;
    if ((bill.paidAmount ?? 0) > 0) return pn.cyan;
    return pn.warning;
  }

  String _statusLabel() {
    if (bill.isOverdue) return 'OVERDUE';
    if ((bill.paidAmount ?? 0) > 0) return 'PARTIAL';
    return 'PENDING';
  }

  String _formatMonth(String month) {
    // Convert '2026-04' to 'Apr 2026'
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final parts = month.split('-');
    if (parts.length == 2) {
      final m = int.tryParse(parts[1]) ?? 0;
      final y = parts[0];
      if (m >= 1 && m <= 12) return '${months[m]} $y';
    }
    return month;
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor();
    final remaining = bill.remaining;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          // Color dot
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(right: 8, top: 1),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          // Month label
          Expanded(
            child: Text(
              _formatMonth(bill.month),
              style: TextStyle(
                color: pn.textSoft,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          // Status badge
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              _statusLabel(),
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: color,
                letterSpacing: 0.3,
              ),
            ),
          ),
          // Remaining amount
          Text(
            'Rs. ${remaining.toStringAsFixed(0)}',
            style: TextStyle(
              color: pn.text,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}


class _BreakdownRow extends StatelessWidget {
  final String label;
  final double value;
  final PnColors pn;
  final bool strong;

  const _BreakdownRow({
    required this.label,
    required this.value,
    required this.pn,
    this.strong = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: strong ? pn.text : pn.textSoft,
              fontSize: strong ? 13 : 12,
              fontWeight: strong ? FontWeight.w900 : FontWeight.w700,
            ),
          ),
        ),
        Text(
          'Rs. ${value.toStringAsFixed(0)}',
          style: TextStyle(
            color: strong ? pn.accent : pn.text,
            fontSize: strong ? 15 : 13,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
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
  final CustomerBillLedger ledger;
  final TextEditingController amountCtrl;
  final PnColors pn;

  const _QuickAmountRow({
    required this.ledger,
    required this.amountCtrl,
    required this.pn,
  });

  @override
  Widget build(BuildContext context) {
    final half = (ledger.totalRemaining / 2).round();
    final full = ledger.totalRemaining.round();
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
          side: BorderSide(
            color: primaryAction ? pn.primary : pn.border,
            width: 1.2,
          ),
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
              style: TextStyle(
                color: pn.text,
                fontSize: 12,
                height: 1.35,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
