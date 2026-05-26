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
        context.read<ComplaintQueueProvider>().loadForTechnicianAndArea(
          staff.id,
          staff.areaId,
        );
        break;
      case 'recovery_agent':
        if (staff.areaId != null) {
          context.read<BillsProvider>().loadPendingByArea(
            staff.areaId!,
            staff.id,
          );
        }
        break;
      case 'field_agent':
        if (staff.areaId != null) {
          context.read<CustomersProvider>().loadByArea(staff.areaId!);
        }
        break;
      case 'cable_operator':
        if (staff.areaId != null) {
          context.read<CustomersProvider>().loadByArea(staff.areaId!);
          context.read<ComplaintQueueProvider>().loadForArea(staff.areaId!);
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final staff = auth.currentStaff;
    if (staff == null) return const SizedBox.shrink();

    return Scaffold(
      appBar: AppBar(
        title: const Text('PowerNet Staff'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.push('/profile'),
          ),
        ],
      ),
      body: _RoleHome(role: staff.normalizedRole),
    );
  }
}

class _RoleHome extends StatelessWidget {
  final String role;
  const _RoleHome({required this.role});

  @override
  Widget build(BuildContext context) {
    final pn = Theme.of(context).extension<PnColors>()!;
    final staff = context.watch<AuthProvider>().currentStaff!;

    if (staff.normalizedRole == 'recovery_agent') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/collector/bills');
      });
      return const Center(child: CircularProgressIndicator());
    }

    if (staff.normalizedRole == 'technician') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/technician/complaints');
      });
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _WelcomeCard(staff: staff, pn: pn),
        const SizedBox(height: 24),
        Text(
          'Quick Overview',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: pn.text,
          ),
        ),
        const SizedBox(height: 12),
        _KpiGrid(role: role, pn: pn),
        const SizedBox(height: 24),
        _QuickActions(role: role),
      ],
    );
  }
}

class _WelcomeCard extends StatelessWidget {
  final dynamic staff;
  final PnColors pn;
  const _WelcomeCard({required this.staff, required this.pn});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: primary,
            child: Text(
              staff.fullName.isNotEmpty ? staff.fullName[0].toUpperCase() : '?',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  staff.fullName,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: pn.text,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    staff.roleLabel,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: primary,
                    ),
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
            valueColor: pn.info,
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
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: pn.text,
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
      child: InkWell(
        onTap: () => context.push(route),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: primary, size: 22),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
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
