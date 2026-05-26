import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../providers/customer_auth_provider.dart';
import '../../providers/customer_portal_provider.dart';
import '../../theme/app_theme.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
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

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    final customer = context.watch<CustomerAuthProvider>().currentCustomer;
    final portal = context.watch<CustomerPortalProvider>();
    final pn = Theme.of(context).extension<PnColors>()!;
    if (customer == null) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: pn.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: portal.refreshActive,
          color: pn.accent,
          backgroundColor: pn.surface,
          child: ListView(
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            children: [
              // Welcome Header Bar (06-customer-home.html)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      // Cyan Avatar
                      GestureDetector(
                        onTap: () => context.push('/customer/profile'),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: pn.cyan.withOpacity(0.12),
                            shape: BoxShape.circle,
                            border: Border.all(color: pn.cyan.withOpacity(0.35)),
                          ),
                          child: Center(
                            child: Text(
                              _getInitials(customer.fullName),
                              style: GoogleFonts.manrope(
                                color: pn.accent,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome back,',
                            style: TextStyle(color: pn.textMuted, fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            customer.fullName.split(' ')[0],
                            style: GoogleFonts.manrope(
                              color: pn.text,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  
                  // Live indicator sync chip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: pn.softGreen,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: pn.success.withOpacity(0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: pn.cyan,
                            boxShadow: [
                              BoxShadow(
                                color: pn.cyan,
                                blurRadius: 4,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Live',
                          style: TextStyle(
                            color: pn.success,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Active Internet Package details glass card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: pn.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: pn.border),
                  boxShadow: [
                    BoxShadow(
                      color: pn.text.withOpacity(0.03),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ACTIVE PACKAGE',
                              style: TextStyle(
                                color: pn.textMuted,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              customer.package?.name ?? 'No active package',
                              style: GoogleFonts.manrope(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: pn.text,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: pn.softOrange,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: pn.accent.withOpacity(0.3)),
                          ),
                          child: Icon(Icons.wifi_tethering, color: pn.accent, size: 22),
                        ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14.0),
                      child: Divider(),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'House ID: ${customer.displayHouseId}',
                          style: TextStyle(color: pn.textSoft, fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                        Text(
                          'Area: ${customer.area?.name ?? "—"}',
                          style: TextStyle(color: pn.textSoft, fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ],
                    )
                  ],
                ),
              ),
              const SizedBox(height: 24),

              if (portal.error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: pn.softRed,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    portal.error!,
                    style: TextStyle(color: pn.danger, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],

              // KPI analytic metrics
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.35,
                children: [
                  _buildDashboardKpi(
                    pn,
                    'Total Due Amount',
                    portal.loading ? '...' : 'Rs. ${portal.totalDue.toStringAsFixed(0)}',
                    portal.totalDue > 0 ? pn.danger : pn.success,
                    Icons.account_balance_wallet_outlined,
                  ),
                  _buildDashboardKpi(
                    pn,
                    'Pending Bills',
                    portal.loading ? '...' : '${portal.pendingBillCount}',
                    portal.pendingBillCount > 0 ? pn.accent : pn.success,
                    Icons.receipt_long_rounded,
                  ),
                  _buildDashboardKpi(
                    pn,
                    'Open complaints',
                    portal.loading ? '...' : '${portal.openComplaintCount}',
                    pn.cyan,
                    Icons.chat_bubble_outline_rounded,
                  ),
                  _buildDashboardKpi(
                    pn,
                    'Sync status',
                    'Stable',
                    pn.success,
                    Icons.sync_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Action Tiles
              Text(
                'Services Actions',
                style: GoogleFonts.manrope(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: pn.text,
                ),
              ),
              const SizedBox(height: 12),

              _buildActionCard(
                pn,
                'Pay Bills',
                'View invoices, receipts, and payment status.',
                Icons.payment_rounded,
                pn.softOrange,
                pn.accent,
                () => context.push('/customer/bills'),
              ),
              const SizedBox(height: 12),

              _buildActionCard(
                pn,
                'Support Complaints',
                'Report connection issues or browse active support tickets.',
                Icons.support_agent_rounded,
                pn.softCyan,
                pn.cyan,
                () => context.push('/customer/complaints'),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardKpi(
    PnColors pn,
    String label,
    String value,
    Color highlightColor,
    IconData icon,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: pn.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(icon, color: pn.textMuted.withOpacity(0.5), size: 16),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: GoogleFonts.manrope(
                fontSize: value.length > 8 ? 16 : 20,
                fontWeight: FontWeight.w900,
                color: highlightColor == pn.cyan ? pn.text : highlightColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(
    PnColors pn,
    String title,
    String description,
    IconData icon,
    Color iconBg,
    Color iconColor,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: pn.border),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: iconColor.withOpacity(0.35)),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.manrope(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: pn.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: pn.textSoft,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_right_rounded,
                color: pn.accent,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

