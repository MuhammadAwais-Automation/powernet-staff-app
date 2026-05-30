import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/bills_provider.dart';
import '../providers/complaint_queue_provider.dart';
import '../providers/customers_provider.dart';
import '../theme/app_theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<AuthProvider>().refreshProfile();
        _loadRoleData();
      }
    });
  }

  void _loadRoleData() {
    final auth = context.read<AuthProvider>();
    final staff = auth.currentStaff;
    if (staff == null) return;
    switch (staff.normalizedRole) {
      case 'technician':
        context.read<ComplaintQueueProvider>().loadForTechnicianAndAreas(
          staff.id,
          staff.areaIds,
        );
        break;
      case 'recovery_agent':
        context.read<BillsProvider>().loadPendingByAreas(
          staff.areaIds,
          staff.id,
        );
        break;
      case 'field_agent':
        context.read<CustomersProvider>().loadByAreas(staff.areaIds);
        break;
      case 'cable_operator':
        context.read<CustomersProvider>().loadByAreas(staff.areaIds);
        context.read<ComplaintQueueProvider>().loadForAreas(staff.areaIds);
        break;
    }
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  String _formatShortAmount(double amount) {
    if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(0)}K';
    }
    return amount.toStringAsFixed(0);
  }

  Future<void> _handleSync() async {
    setState(() => _syncing = true);
    final auth = context.read<AuthProvider>();
    final staff = auth.currentStaff;
    if (staff != null) {
      try {
        switch (staff.normalizedRole) {
          case 'technician':
            await context.read<ComplaintQueueProvider>().syncQueuedNow();
            break;
          case 'recovery_agent':
            await context.read<BillsProvider>().syncQueuedNow();
            break;
          case 'field_agent':
            await context.read<CustomersProvider>().loadByAreas(staff.areaIds);
            break;
          case 'cable_operator':
            await Future.wait([
              context.read<CustomersProvider>().loadByAreas(staff.areaIds),
              context.read<ComplaintQueueProvider>().loadForAreas(
                staff.areaIds,
              ),
            ]);
            break;
        }
      } catch (e) {
        debugPrint('Sync failed: $e');
      }
    }
    if (!mounted) return;
    setState(() => _syncing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Database Sync completed successfully!'),
        backgroundColor: successColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pn = Theme.of(context).extension<PnColors>()!;
    final auth = context.watch<AuthProvider>();
    final staff = auth.currentStaff;

    if (staff == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: pn.background,
      appBar: AppBar(
        title: const Text('Staff Profile'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: pn.text),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Glassmorphism Staff Avatar Card (Matches CSS .card.glass.stack)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: pn.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: pn.border),
                boxShadow: [
                  BoxShadow(
                    color: pn.text.withValues(alpha: 0.04),
                    blurRadius: 26,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Avatar UI
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: pn.accent.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: pn.accent.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            _getInitials(staff.fullName),
                            style: GoogleFonts.manrope(
                              color: pn.accent,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Details Box
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              staff.fullName,
                              style: GoogleFonts.manrope(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: pn.text,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${staff.phone ?? "No phone"} | ${staff.username ?? ""}',
                              style: TextStyle(
                                fontSize: 12,
                                color: pn.textSoft,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: pn.softGreen,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: pn.success.withValues(alpha: 0.2),
                                ),
                              ),
                              child: Text(
                                'ACTIVE',
                                style: TextStyle(
                                  color: pn.success,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.0),
                    child: Divider(),
                  ),
                  // Bottom mini metadata row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'USERNAME',
                              style: TextStyle(
                                color: pn.textMuted,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              staff.username ?? '—',
                              style: TextStyle(
                                color: pn.text,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ASSIGNED AREA',
                              style: TextStyle(
                                color: pn.textMuted,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              staff.areaName ?? '—',
                              style: TextStyle(
                                color: pn.text,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Role Stats Section Title
            Text(
              '${staff.roleLabel} Stats',
              style: GoogleFonts.manrope(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: pn.text,
              ),
            ),
            const SizedBox(height: 12),

            _buildDynamicStatsGrid(context, staff, pn),
            const SizedBox(height: 24),

            // Sync and Logout Actions Stack
            ElevatedButton.icon(
              onPressed: _syncing ? null : _handleSync,
              style: ElevatedButton.styleFrom(
                backgroundColor: pn.softCyan,
                foregroundColor: pn.primary,
                side: BorderSide(color: pn.cyan.withValues(alpha: 0.3)),
              ),
              icon: _syncing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(primaryColor),
                      ),
                    )
                  : Icon(Icons.sync_rounded, color: pn.cyan, size: 20),
              label: Text(_syncing ? 'Syncing...' : 'Sync Data Now'),
            ),
            const SizedBox(height: 12),

            OutlinedButton.icon(
              onPressed: () async {
                await auth.logout();
                if (context.mounted) context.go('/login');
              },
              style: OutlinedButton.styleFrom(
                backgroundColor: pn.softRed,
                foregroundColor: pn.danger,
                side: BorderSide(color: pn.danger.withValues(alpha: 0.2)),
              ),
              icon: Icon(Icons.logout_rounded, color: pn.danger, size: 20),
              label: const Text('Logout Session'),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildDynamicStatsGrid(
    BuildContext context,
    dynamic staff,
    PnColors pn,
  ) {
    switch (staff.normalizedRole) {
      case 'technician':
        final q = context.watch<ComplaintQueueProvider>();
        final loading = q.loading;
        return GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.5,
          children: [
            _buildKpiCard(
              pn,
              'Resolved Today',
              loading ? '…' : '${q.resolvedToday.length}',
              pn.softGreen,
              pn.success,
            ),
            _buildKpiCard(
              pn,
              'Pending Jobs',
              loading ? '…' : '${q.open.length}',
              pn.softOrange,
              pn.accent,
            ),
            _buildKpiCard(
              pn,
              'In Progress',
              loading ? '…' : '${q.inProgress.length}',
              pn.softCyan,
              pn.cyan,
            ),
            _buildKpiCard(
              pn,
              'Offline Queue',
              loading ? '…' : '${q.pendingSyncCount}',
              pn.softCyan,
              pn.cyan,
            ),
          ],
        );

      case 'recovery_agent':
        final bills = context.watch<BillsProvider>();
        final loading = bills.loading;
        return GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.5,
          children: [
            _buildKpiCard(
              pn,
              'Collected Today',
              loading
                  ? '…'
                  : 'PKR ${_formatShortAmount(bills.collectedTodayAmount)}',
              pn.softGreen,
              pn.success,
            ),
            _buildKpiCard(
              pn,
              'Pending Bills',
              loading ? '…' : '${bills.bills.length}',
              pn.softOrange,
              pn.accent,
            ),
            _buildKpiCard(
              pn,
              'Visits Logged',
              loading ? '…' : '${bills.visitedToday.length}',
              pn.softCyan,
              pn.cyan,
            ),
            _buildKpiCard(
              pn,
              'Offline Queue',
              loading ? '…' : '${bills.pendingSyncCount}',
              pn.softCyan,
              pn.cyan,
            ),
          ],
        );

      case 'field_agent':
        final custs = context.watch<CustomersProvider>();
        final loading = custs.loading;
        return GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.5,
          children: [
            _buildKpiCard(
              pn,
              'Total Customers',
              loading ? '…' : '${custs.customers.length}',
              pn.softCyan,
              pn.cyan,
            ),
            _buildKpiCard(
              pn,
              'Active',
              loading ? '…' : '${custs.activeCount}',
              pn.softGreen,
              pn.success,
            ),
            _buildKpiCard(
              pn,
              'Suspended',
              loading ? '…' : '${custs.suspendedCount}',
              pn.softOrange,
              pn.accent,
            ),
            _buildKpiCard(
              pn,
              'Disconnected',
              loading ? '…' : '${custs.disconnectedCount}',
              pn.softRed,
              pn.danger,
            ),
          ],
        );

      case 'cable_operator':
        final coCusts = context.watch<CustomersProvider>();
        final coQ = context.watch<ComplaintQueueProvider>();
        final loading = coCusts.loading || coQ.loading;
        return GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.5,
          children: [
            _buildKpiCard(
              pn,
              'Total Customers',
              loading ? '…' : '${coCusts.customers.length}',
              pn.softCyan,
              pn.cyan,
            ),
            _buildKpiCard(
              pn,
              'Active',
              loading ? '…' : '${coCusts.activeCount}',
              pn.softGreen,
              pn.success,
            ),
            _buildKpiCard(
              pn,
              'Open Complaints',
              loading ? '…' : '${coQ.open.length}',
              pn.softOrange,
              pn.accent,
            ),
            _buildKpiCard(
              pn,
              'Disconnected',
              loading ? '…' : '${coCusts.disconnectedCount}',
              pn.softRed,
              pn.danger,
            ),
          ],
        );

      default:
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: pn.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: pn.border),
          ),
          child: Text(
            'Dynamic metrics are not available for this role.',
            textAlign: TextAlign.center,
            style: TextStyle(color: pn.textSoft, fontSize: 13),
          ),
        );
    }
  }

  Widget _buildKpiCard(
    PnColors pn,
    String label,
    String count,
    Color bgHighlight,
    Color accentColor,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: pn.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              count,
              style: GoogleFonts.manrope(
                fontSize: count.length > 5 ? 18 : 22,
                fontWeight: FontWeight.w900,
                color: accentColor == pn.cyan ? pn.text : accentColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
