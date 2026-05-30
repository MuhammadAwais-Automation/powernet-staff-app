import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/bill.dart';
import '../../providers/customer_auth_provider.dart';
import '../../providers/customer_portal_provider.dart';
import '../../theme/app_theme.dart';

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

  void _triggerPaymentMock() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Payment request initiated. Please pay your recovery agent or visit manager office.',
        ),
        backgroundColor: accentColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final customer = context.watch<CustomerAuthProvider>().currentCustomer;
    final provider = context.watch<CustomerPortalProvider>();
    final pn = Theme.of(context).extension<PnColors>()!;
    final totalDue = provider.totalDue;

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
                        ElevatedButton(
                          onPressed: _triggerPaymentMock,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: pn.accent,
                            foregroundColor: pn.primary,
                            minimumSize: const Size(80, 44),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Pay Now'),
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

    // Resolve color scheme for status chip
    Color statusColor;
    Color statusBg;
    String statusLabel = bill.collectionStatus.toUpperCase();

    if (bill.collectionStatus == 'paid') {
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
