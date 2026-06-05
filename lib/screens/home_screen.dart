import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/bills_provider.dart';
import '../providers/complaint_queue_provider.dart';
import '../providers/customers_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/pn_kpi_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  void _loadData() {
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

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final staff = auth.currentStaff;
    if (staff == null) return const SizedBox.shrink();

    // Deep navy background for full-screen premium visual styling
    final pn = Theme.of(context).extension<PnColors>()!;

    return Scaffold(
      backgroundColor: pn.background,
      body: SafeArea(
        child: _RoleHome(role: staff.normalizedRole, onRefresh: _loadData),
      ),
    );
  }
}

class _RoleHome extends StatelessWidget {
  final String role;
  final VoidCallback onRefresh;

  const _RoleHome({required this.role, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final pn = Theme.of(context).extension<PnColors>()!;
    final auth = context.watch<AuthProvider>();
    final staff = auth.currentStaff;

    if (staff == null) return const SizedBox.shrink();

    if (role == 'technician') {
      return _buildTechnicianHome(context, staff, pn);
    } else if (role == 'recovery_agent') {
      return _buildRecoveryHome(context, staff, pn);
    }

    // Default layout for Field Agent and Cable Operator, upgraded with premium visual elements
    return Column(
      children: [
        _buildAppBar(context, staff.fullName, staff.roleLabel, pn),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            children: [
              _buildGeneralWelcomeCard(staff, pn),
              const SizedBox(height: 24),
              Text(
                'Today Overview',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: pn.text,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 12),
              _KpiGrid(role: role, pn: pn),
              const SizedBox(height: 28),
              _QuickActions(role: role),
            ],
          ),
        ),
        _buildBottomNav(
          context,
          'home',
          pn,
          showComplaints: role == 'cable_operator',
          showCollections: false,
        ),
      ],
    );
  }

  // --- Technician Home Design Overhaul (09-technician-home.html) ---
  Widget _buildTechnicianHome(
    BuildContext context,
    dynamic staff,
    PnColors pn,
  ) {
    final q = context.watch<ComplaintQueueProvider>();
    final loading = q.loading;

    return Column(
      children: [
        _buildAppBar(context, staff.fullName, 'Technician', pn),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => onRefresh(),
            color: pn.accent,
            backgroundColor: pn.surface,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                // Live Sync Banner container matching the premium layout
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: pn.surfaceMuted,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: pn.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              loading ? 'Syncing...' : 'Online Sync',
                              style: TextStyle(
                                color: pn.text,
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Assigned area: ${staff.areaName ?? "Gulshan Block 4"}',
                              style: TextStyle(
                                color: pn.textMuted,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          onRefresh();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Data synced successfully!'),
                              backgroundColor: pn.success,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: pn.cyan.withValues(alpha: 0.12),
                          foregroundColor: pn.cyan,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Sync',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            color: pn.cyan,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Today',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: pn.text,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 12),
                // Today Stats Grid
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.4,
                  children: [
                    _buildKpiCard(
                      label: 'Assigned',
                      value: loading ? '…' : '${q.open.length + q.inProgress.length}',
                      pn: pn,
                      onTap: () => context.push('/technician/complaints'),
                    ),
                    _buildKpiCard(
                      label: 'Open',
                      value: loading ? '…' : '${q.open.length}',
                      valueColor: pn.warning,
                      pn: pn,
                      onTap: () => context.push('/technician/complaints'),
                    ),
                    _buildKpiCard(
                      label: 'In Progress',
                      value: loading ? '…' : '${q.inProgress.length}',
                      valueColor: pn.cyan,
                      pn: pn,
                      onTap: () => context.push('/technician/complaints'),
                    ),
                    _buildKpiCard(
                      label: 'Resolved (Today / Month)',
                      value: loading ? '…' : '${q.resolvedToday.length} / ${q.resolvedThisMonth.length}',
                      valueColor: pn.success,
                      pn: pn,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Queued Offline Actions Card
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: pn.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: pn.border),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Queued Offline Actions',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: pn.textSoft,
                        ),
                      ),
                      Text(
                        '${q.pendingSyncCount}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: pn.text,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // View Complaints Core CTA styled orange button
                ElevatedButton(
                  onPressed: () => context.push('/technician/complaints'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: pn.accent,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'View Complaints',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        _buildBottomNav(
          context,
          'home',
          pn,
          showComplaints: true,
          showCollections: false,
        ),
      ],
    );
  }

  // --- Recovery Agent Home Design Overhaul (11-recovery-home.html) ---
  Widget _buildRecoveryHome(BuildContext context, dynamic staff, PnColors pn) {
    final bills = context.watch<BillsProvider>();
    final loading = bills.loading;

    return Column(
      children: [
        _buildAppBar(context, staff.fullName, 'Recovery Agent', pn),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => onRefresh(),
            color: pn.accent,
            backgroundColor: pn.surface,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                // Collection Route sync banner
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: pn.surfaceMuted,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: pn.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Collection route',
                              style: TextStyle(
                                color: pn.text,
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${staff.areaName ?? "North Zone"} - ${bills.bills.length} pending visits',
                              style: TextStyle(
                                color: pn.textMuted,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Live indicator dot matching mockup
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: pn.success.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: pn.success,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
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
                ),
                const SizedBox(height: 24),
                Text(
                  'Payments',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: pn.text,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 12),
                // Payments KPI Grid
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.4,
                  children: [
                    _buildKpiCard(
                      label: 'Pending Bills',
                      value: loading ? '…' : '${bills.bills.length}',
                      pn: pn,
                      onTap: () => context.push('/collector/bills'),
                    ),
                    _buildKpiCard(
                      label: 'Overdue Bills',
                      value: loading
                          ? '…'
                          : '${bills.bills.where((b) => b.isOverdue).length}',
                      valueColor: pn.warning,
                      pn: pn,
                      onTap: () => context.push('/collector/bills'),
                    ),
                    _buildKpiCard(
                      label: 'Collected Today',
                      value: loading
                          ? '…'
                          : 'PKR ${_formatShortAmount(bills.collectedTodayAmount)}',
                      valueColor: pn.success,
                      pn: pn,
                    ),
                    _buildKpiCard(
                      label: 'Visits Logged',
                      value: loading ? '…' : '${bills.visitedToday.length}',
                      valueColor: pn.cyan,
                      pn: pn,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Offline Actions Card
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: pn.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: pn.border),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Offline Queue',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: pn.textSoft,
                        ),
                      ),
                      Text(
                        '${bills.pendingSyncCount}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: pn.text,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Primary CTA button to open collection list
                ElevatedButton(
                  onPressed: () => context.push('/collector/bills'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: pn.accent,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Open Collection List',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        _buildBottomNav(
          context,
          'home',
          pn,
          showComplaints: false,
          showCollections: true,
        ),
      ],
    );
  }

  // --- Supporting Reusable Widgets matching HTML layouts ---
  Widget _buildAppBar(
    BuildContext context,
    String name,
    String subtitle,
    PnColors pn,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      decoration: BoxDecoration(
        color: pn.background,
        border: Border(
          bottom: BorderSide(color: pn.border.withValues(alpha: 0.5)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: pn.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: pn.text,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => context.push('/profile'),
            style: ElevatedButton.styleFrom(
              backgroundColor: pn.surfaceMuted,
              foregroundColor: pn.text,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              minimumSize: Size.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(99),
                side: BorderSide(color: pn.border),
              ),
            ),
            child: Text(
              'Profile',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: pn.text,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard({
    required String label,
    required String value,
    Color? valueColor,
    required PnColors pn,
    VoidCallback? onTap,
  }) {
    final block = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: pn.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: pn.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: pn.textMuted,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: valueColor ?? pn.text,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return block;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: block,
    );
  }

  Widget _buildGeneralWelcomeCard(dynamic staff, PnColors pn) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: pn.surfaceMuted,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: pn.border),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: pn.primary,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              staff.fullName.isNotEmpty ? staff.fullName[0].toUpperCase() : '?',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 20,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Khushamdeed,',
                  style: TextStyle(
                    fontSize: 13,
                    color: pn.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  staff.fullName,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: pn.text,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav(
    BuildContext context,
    String activeTab,
    PnColors pn, {
    required bool showComplaints,
    required bool showCollections,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: pn.surface,
        border: Border(top: BorderSide(color: pn.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _BottomNavItem(
            icon: Icons.home_filled,
            label: 'Home',
            isActive: activeTab == 'home',
            pn: pn,
            onTap: () {}, // Already here
          ),
          if (showComplaints)
            _BottomNavItem(
              icon: Icons.assignment_outlined,
              label: 'Complaints',
              isActive: activeTab == 'complaints',
              pn: pn,
              onTap: () => context.push('/technician/complaints'),
            ),
          if (showCollections)
            _BottomNavItem(
              icon: Icons.payments_outlined,
              label: 'Collections',
              isActive: activeTab == 'collections',
              pn: pn,
              onTap: () => context.push('/collector/bills'),
            ),
          _BottomNavItem(
            icon: Icons.notifications_none_outlined,
            label: 'Alerts',
            isActive: activeTab == 'alerts',
            pn: pn,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Notifications are up-to-date'),
                  backgroundColor: pn.primary,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
          _BottomNavItem(
            icon: Icons.person_outline,
            label: 'Profile',
            isActive: activeTab == 'profile',
            pn: pn,
            onTap: () => context.push('/profile'),
          ),
        ],
      ),
    );
  }

  String _formatShortAmount(double amount) {
    if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(0)}K';
    }
    return amount.toStringAsFixed(0);
  }
}

class _BottomNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final PnColors pn;
  final VoidCallback onTap;

  const _BottomNavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.pn,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = pn.accent;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isActive ? activeColor : pn.textMuted, size: 24),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
                color: isActive ? activeColor : pn.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KpiGrid extends StatelessWidget {
  final String role;
  final PnColors pn;
  const _KpiGrid({required this.role, required this.pn});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.4,
      children: _cards(context),
    );
  }

  List<Widget> _cards(BuildContext context) {
    switch (role) {
      case 'technician':
        final q = context.watch<ComplaintQueueProvider>();
        final loading = q.loading;
        return [
          PnKpiCard(
            label: 'Assigned',
            value: loading ? '…' : '${q.complaints.length}',
            icon: Icons.assignment_outlined,
            onTap: () => context.push('/technician/complaints'),
          ),
          PnKpiCard(
            label: 'Open',
            value: loading ? '…' : '${q.open.length}',
            icon: Icons.error_outline,
            valueColor: pn.warning,
            onTap: () => context.push('/technician/complaints'),
          ),
          PnKpiCard(
            label: 'Resolved Today',
            value: loading ? '…' : '${q.resolvedToday.length}',
            icon: Icons.check_circle_outline,
            valueColor: pn.success,
          ),
          PnKpiCard(
            label: 'In Progress',
            value: loading ? '…' : '${q.inProgress.length}',
            icon: Icons.schedule,
            valueColor: pn.cyan,
            onTap: () => context.push('/technician/complaints'),
          ),
        ];
      case 'recovery_agent':
        final bills = context.watch<BillsProvider>();
        final loading = bills.loading;
        return [
          PnKpiCard(
            label: 'Pending Bills',
            value: loading ? '…' : '${bills.bills.length}',
            icon: Icons.people_outline,
            onTap: () => context.push('/collector/bills'),
          ),
          PnKpiCard(
            label: 'Total Due',
            value: loading ? '…' : 'Rs.${bills.totalDue.toStringAsFixed(0)}',
            icon: Icons.account_balance_wallet_outlined,
            valueColor: pn.warning,
            onTap: () => context.push('/collector/bills'),
          ),
          PnKpiCard(
            label: 'Collected Today',
            value: loading
                ? '…'
                : 'Rs.${bills.collectedTodayAmount.toStringAsFixed(0)}',
            icon: Icons.payments_outlined,
            valueColor: pn.success,
          ),
          PnKpiCard(
            label: 'Visited Today',
            value: loading ? '…' : '${bills.visitedToday.length}',
            icon: Icons.location_on_outlined,
          ),
        ];
      case 'field_agent':
        final custs = context.watch<CustomersProvider>();
        final custLoading = custs.loading;
        return [
          PnKpiCard(
            label: 'Total',
            value: custLoading ? '…' : '${custs.customers.length}',
            icon: Icons.people_outline,
            onTap: () => context.push('/field-agent/customers'),
          ),
          PnKpiCard(
            label: 'Active',
            value: custLoading ? '…' : '${custs.activeCount}',
            icon: Icons.check_circle_outline,
            valueColor: pn.success,
            onTap: () => context.push('/field-agent/customers'),
          ),
          PnKpiCard(
            label: 'Suspended',
            value: custLoading ? '…' : '${custs.suspendedCount}',
            icon: Icons.pause_circle_outline,
            valueColor: pn.warning,
          ),
          PnKpiCard(
            label: 'Disconnected',
            value: custLoading ? '…' : '${custs.disconnectedCount}',
            icon: Icons.cancel_outlined,
            valueColor: pn.danger,
          ),
        ];
      case 'cable_operator':
        final coCusts = context.watch<CustomersProvider>();
        final coQ = context.watch<ComplaintQueueProvider>();
        final coLoading = coCusts.loading;
        final coQLoading = coQ.loading;
        return [
          PnKpiCard(
            label: 'Customers',
            value: coLoading ? '…' : '${coCusts.customers.length}',
            icon: Icons.people_outline,
            onTap: () => context.push('/cable-operator/customers'),
          ),
          PnKpiCard(
            label: 'Active',
            value: coLoading ? '…' : '${coCusts.activeCount}',
            icon: Icons.check_circle_outline,
            valueColor: pn.success,
            onTap: () => context.push('/cable-operator/customers'),
          ),
          PnKpiCard(
            label: 'Open Complaints',
            value: coQLoading ? '…' : '${coQ.open.length}',
            icon: Icons.error_outline,
            valueColor: pn.warning,
          ),
          PnKpiCard(
            label: 'Disconnected',
            value: coLoading ? '…' : '${coCusts.disconnectedCount}',
            icon: Icons.cancel_outlined,
            valueColor: pn.danger,
          ),
        ];
      default:
        return [
          PnKpiCard(label: 'Customers', value: '—', icon: Icons.people_outline),
          PnKpiCard(
            label: 'Complaints',
            value: '—',
            icon: Icons.report_problem_outlined,
          ),
        ];
    }
  }
}

class _QuickActions extends StatelessWidget {
  final String role;
  const _QuickActions({required this.role});

  @override
  Widget build(BuildContext context) {
    final pn = Theme.of(context).extension<PnColors>()!;

    final actions = _actionsForRole(role);
    if (actions.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: pn.text,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 12),
        ...actions.map(
          (a) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _ActionTile(label: a.$1, icon: a.$2, route: a.$3, pn: pn),
          ),
        ),
      ],
    );
  }

  List<(String, IconData, String)> _actionsForRole(String role) {
    switch (role) {
      case 'technician':
        return [
          (
            'View Complaints',
            Icons.list_alt_outlined,
            '/technician/complaints',
          ),
        ];
      case 'recovery_agent':
        return [
          (
            'View Pending Bills',
            Icons.receipt_long_outlined,
            '/collector/bills',
          ),
        ];
      case 'field_agent':
        return [
          ('View Customers', Icons.people_outline, '/field-agent/customers'),
        ];
      case 'cable_operator':
        return [
          ('View Customers', Icons.people_outline, '/cable-operator/customers'),
        ];
      default:
        return [];
    }
  }
}

class _ActionTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final String route;
  final PnColors pn;

  const _ActionTile({
    required this.label,
    required this.icon,
    required this.route,
    required this.pn,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: pn.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: pn.border),
      ),
      child: InkWell(
        onTap: () => context.push(route),
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              Icon(icon, color: pn.accent, size: 22),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: pn.text,
                ),
              ),
              const Spacer(),
              Icon(Icons.chevron_right, color: pn.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
