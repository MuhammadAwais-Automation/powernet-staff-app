import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/customer_auth_provider.dart';
import '../../providers/customer_portal_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/pn_kpi_card.dart';

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

  @override
  Widget build(BuildContext context) {
    final customer = context.watch<CustomerAuthProvider>().currentCustomer;
    final portal = context.watch<CustomerPortalProvider>();
    final pn = Theme.of(context).extension<PnColors>()!;
    if (customer == null) return const SizedBox.shrink();

    return Scaffold(
      appBar: AppBar(
        title: const Text('PowerNet Customer'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.push('/customer/profile'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: portal.refreshActive,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: primary.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: primary,
                    child: Text(
                      customer.fullName.isNotEmpty
                          ? customer.fullName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          customer.fullName,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: pn.text,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${customer.displayHouseId} - ${customer.area?.name ?? 'No area'}',
                          style: TextStyle(color: pn.textMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            if (portal.error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  portal.error!,
                  style: const TextStyle(color: danger),
                ),
              ),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.35,
              children: [
                PnKpiCard(
                  label: 'Pending Bills',
                  value: portal.loading ? '...' : '${portal.pendingBillCount}',
                  icon: Icons.receipt_long_outlined,
                  valueColor: pn.warning,
                  onTap: () => context.push('/customer/bills'),
                ),
                PnKpiCard(
                  label: 'Total Due',
                  value: portal.loading
                      ? '...'
                      : 'Rs.${portal.totalDue.toStringAsFixed(0)}',
                  icon: Icons.account_balance_wallet_outlined,
                  valueColor: pn.danger,
                  onTap: () => context.push('/customer/bills'),
                ),
                PnKpiCard(
                  label: 'Complaints',
                  value: portal.loading
                      ? '...'
                      : '${portal.openComplaintCount}',
                  icon: Icons.report_problem_outlined,
                  valueColor: pn.info,
                  onTap: () => context.push('/customer/complaints'),
                ),
                PnKpiCard(
                  label: 'Package',
                  value: customer.package?.name ?? '-',
                  icon: Icons.speed_outlined,
                ),
              ],
            ),
            const SizedBox(height: 20),
            _ActionTile(
              icon: Icons.receipt_long_outlined,
              label: 'View bills',
              route: '/customer/bills',
              pn: pn,
            ),
            const SizedBox(height: 8),
            _ActionTile(
              icon: Icons.add_comment_outlined,
              label: 'Create complaint',
              route: '/customer/complaints',
              pn: pn,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String route;
  final PnColors pn;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.route,
    required this.pn,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: primary),
        title: Text(
          label,
          style: TextStyle(color: pn.text, fontWeight: FontWeight.w600),
        ),
        trailing: Icon(Icons.chevron_right, color: pn.textMuted),
        onTap: () => context.push(route),
      ),
    );
  }
}
