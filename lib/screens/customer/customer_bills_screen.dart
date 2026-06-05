import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/bill.dart';
import '../../providers/customer_auth_provider.dart';
import '../../providers/customer_portal_provider.dart';
import '../../theme/app_theme.dart';
import 'payment_upload_receipt_sheet.dart';

class CustomerBillsScreen extends StatefulWidget {
  const CustomerBillsScreen({super.key});

  @override
  State<CustomerBillsScreen> createState() => _CustomerBillsScreenState();
}

class _CustomerBillsScreenState extends State<CustomerBillsScreen> {
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

  void _openPaymentUploadSheet(Bill bill) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PaymentUploadReceiptSheet(bill: bill),
    );
  }

  @override
  Widget build(BuildContext context) {
    final customer = context.watch<CustomerAuthProvider>().currentCustomer;
    final provider = context.watch<CustomerPortalProvider>();
    final pn = Theme.of(context).extension<PnColors>()!;
    final totalDue = provider.totalDue;

    final hasPendingBill = provider.bills.any((b) => b.status != 'paid');
    final Bill? pendingBill = hasPendingBill 
        ? provider.bills.firstWhere((b) => b.status != 'paid') 
        : (provider.bills.isNotEmpty ? provider.bills.first : null);

    return Scaffold(
      backgroundColor: pn.background,
      appBar: AppBar(title: const Text('My Bills')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: provider.refreshActive,
          color: pn.accent,
          backgroundColor: pn.surface,
          child: Column(
            children: [
              // House ID Header Detail
              if (customer != null) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      Text(
                        'HOUSE ID: ',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: pn.textMuted,
                        ),
                      ),
                      Text(
                        customer.displayHouseId,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: pn.textSoft,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Total Due Glass Card Overview (Matches CSS .card.glass.between)
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: pn.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: pn.cyan.withValues(alpha: 0.35)),
                    boxShadow: [
                      BoxShadow(
                        color: pn.cyan.withValues(alpha: 0.04),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total Outstanding Due',
                            style: TextStyle(
                              color: pn.textMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Rs. ${totalDue.toStringAsFixed(0)}',
                            style: GoogleFonts.manrope(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              color: totalDue > 0 ? pn.danger : pn.success,
                            ),
                          ),
                        ],
                      ),
                      if (totalDue > 0) ...[
                        Builder(
                          builder: (context) {
                            final isPendingVerif = pendingBill != null && provider.isVerificationPending(pendingBill.id);
                            final isRejectedVerif = pendingBill != null && provider.isVerificationRejected(pendingBill.id);
                            
                            return ElevatedButton(
                              onPressed: (pendingBill != null && !isPendingVerif) 
                                  ? () {
                                      if (isRejectedVerif) {
                                        showRejectionDialog(
                                          context: context,
                                          bill: pendingBill,
                                          provider: provider,
                                          onReupload: _openPaymentUploadSheet,
                                        );
                                      } else {
                                        _openPaymentUploadSheet(pendingBill);
                                      }
                                    }
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isPendingVerif ? pn.softOrange : pn.accent,
                                foregroundColor: isPendingVerif ? pn.warning : pn.primary,
                                minimumSize: const Size(80, 44),
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(isPendingVerif ? 'Verifying ⏳' : 'Pay Now'),
                            );
                          }
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Divider
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Row(
                  children: [
                    Text(
                      'BILLING STATEMENT HISTORY',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: pn.textMuted,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(left: 8.0),
                        child: Divider(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Bills list history
              Expanded(
                child: provider.loading && provider.bills.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : provider.bills.isEmpty
                    ? const _EmptyBills()
                    : ListView.separated(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        itemBuilder: (context, index) =>
                            _BillCard(bill: provider.bills[index]),
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 12),
                        itemCount: provider.bills.length,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyBills extends StatelessWidget {
  const _EmptyBills();

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
            border: Border.all(color: pn.cyan.withValues(alpha: 0.2)),
          ),
          child: Icon(Icons.receipt_long_outlined, size: 34, color: pn.cyan),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            'No statements generated yet.',
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
            'Statements will appear when your monthly cycle starts.',
            style: TextStyle(color: pn.textMuted, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

class _BillCard extends StatelessWidget {
  final Bill bill;
  const _BillCard({required this.bill});

  @override
  Widget build(BuildContext context) {
    final pn = Theme.of(context).extension<PnColors>()!;
    final paid = bill.paidAmount ?? 0;
    final remaining = bill.remaining.clamp(0, double.infinity);
    final provider = context.watch<CustomerPortalProvider>();
    final isPendingVerification = provider.isVerificationPending(bill.id);
    final isRejectedVerification = provider.isVerificationRejected(bill.id);

    // Resolve color scheme for status chip
    Color statusColor;
    Color statusBg;
    String statusLabel = bill.collectionStatus.toUpperCase();

    if (isPendingVerification) {
      statusColor = pn.warning;
      statusBg = pn.softOrange;
      statusLabel = 'VERIFYING';
    } else if (isRejectedVerification) {
      statusColor = pn.danger;
      statusBg = pn.softRed;
      statusLabel = 'REJECTED';
    } else if (bill.collectionStatus == 'paid') {
      statusColor = pn.success;
      statusBg = pn.softGreen;
    } else if (bill.collectionStatus == 'overdue') {
      statusColor = pn.danger;
      statusBg = pn.softRed;
    } else if (bill.collectionStatus == 'partial') {
      statusColor = pn.accent;
      statusBg = pn.softOrange;
      statusLabel = 'PARTIAL';
    } else {
      statusColor = pn.warning;
      statusBg = pn.softOrange;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: pn.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: pn.border),
        boxShadow: [
          BoxShadow(
            color: pn.text.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Month and status row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                bill.month,
                style: GoogleFonts.manrope(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: pn.text,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: statusColor.withValues(alpha: 0.2)),
                ),
                child: Text(
                  statusLabel,
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
          const SizedBox(height: 14),

          // Custom columns details row mimicking money-row in html mockup
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMiniCell(
                pn,
                'Amount',
                'Rs. ${bill.amount.toStringAsFixed(0)}',
                pn.text,
              ),
              _buildMiniCell(
                pn,
                'Paid',
                'Rs. ${paid.toStringAsFixed(0)}',
                pn.success,
              ),
              _buildMiniCell(
                pn,
                'Remaining',
                'Rs. ${remaining.toStringAsFixed(0)}',
                remaining > 0 ? pn.danger : pn.textSoft,
              ),
              _buildMiniCell(pn, 'Receipt', bill.receiptNo ?? '—', pn.textSoft),
            ],
          ),

          if (bill.paidAt != null) ...[
            const Padding(
              padding: EdgeInsets.only(top: 10.0),
              child: Divider(),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6.0),
              child: Row(
                children: [
                  Icon(
                    Icons.event_available_rounded,
                    size: 13,
                    color: pn.textMuted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Paid on: ${bill.paidAt}',
                    style: TextStyle(
                      color: pn.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 13,
                    color: pn.textMuted,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      bill.paymentSourceLabel,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: pn.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),            ),
          ],
          if (isRejectedVerification) ...[
            const SizedBox(height: 12),
            InkWell(
              onTap: () => showRejectionDialog(
                context: context,
                bill: bill,
                provider: provider,
                onReupload: (b) {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    useRootNavigator: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => PaymentUploadReceiptSheet(bill: b),
                  );
                },
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: pn.softRed,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: pn.danger.withValues(alpha: 0.15)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 14, color: pn.danger),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Receipt rejected: ${provider.getRejectionReason(bill.id) ?? "Click to view reason"}',
                        style: TextStyle(
                          color: pn.danger,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios, size: 10, color: pn.danger),
                  ],
                ),
              ),
            ),
          ] else if (isPendingVerification) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: pn.softOrange,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: pn.warning.withValues(alpha: 0.15)),
              ),
              child: Row(
                children: [
                  Icon(Icons.hourglass_empty_rounded, size: 14, color: pn.warning),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Admin is verifying your uploaded receipt.',
                      style: TextStyle(
                        color: pn.warning,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMiniCell(
    PnColors pn,
    String label,
    String value,
    Color valueColor,
  ) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: pn.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.manrope(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

void showRejectionDialog({
  required BuildContext context,
  required Bill bill,
  required CustomerPortalProvider provider,
  required Function(Bill) onReupload,
}) {
  final pn = Theme.of(context).extension<PnColors>()!;
  final reason = provider.getRejectionReason(bill.id) ?? 'No reason provided by administrator.';
  showDialog(
    context: context,
    useRootNavigator: true,
    builder: (context) => AlertDialog(
      backgroundColor: pn.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Icon(Icons.error_outline, color: pn.danger, size: 24),
          const SizedBox(width: 10),
          Text(
            'Receipt Rejected',
            style: GoogleFonts.manrope(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: pn.text,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your uploaded receipt for ${bill.month} was rejected during review.',
            style: TextStyle(color: pn.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: pn.softRed,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: pn.danger.withValues(alpha: 0.15)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'REJECTION REASON:',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: pn.danger,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  reason,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: pn.danger,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Please verify your transaction and upload a clear screenshot of your payment receipt.',
            style: TextStyle(color: pn.textMuted, fontSize: 12),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Close', style: TextStyle(color: pn.textMuted, fontWeight: FontWeight.bold)),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            onReupload(bill);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: pn.accent,
            foregroundColor: pn.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('Re-upload Receipt'),
        ),
      ],
    ),
  );
}

