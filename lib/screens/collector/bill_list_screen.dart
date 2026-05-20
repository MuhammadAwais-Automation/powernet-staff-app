import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../models/bill.dart';
import '../../providers/auth_provider.dart';
import '../../providers/bills_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/pn_status_badge.dart';

class BillListScreen extends StatefulWidget {
  const BillListScreen({super.key});

  @override
  State<BillListScreen> createState() => _BillListScreenState();
}

class _BillListScreenState extends State<BillListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _load() {
    final auth = context.read<AuthProvider>();
    final bills = context.read<BillsProvider>();
    final staff = auth.currentStaff;
    if (staff == null || staff.areaId == null) return;
    bills.loadPendingByArea(staff.areaId!, staff.id);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pn = Theme.of(context).extension<PnColors>()!;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Collections'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Collected Today'),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: Consumer<BillsProvider>(
        builder: (context, provider, _) {
          if (provider.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.error != null) {
            return ErrorState(message: provider.error!, onRetry: _load);
          }
          return TabBarView(
            controller: _tabs,
            children: [
              _BillList(
                items: provider.bills,
                pn: pn,
                onTap: (b) => context.push('/collector/bills/${b.id}/collect'),
              ),
              _BillList(
                items: provider.collectedToday,
                pn: pn,
                readOnly: true,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BillList extends StatelessWidget {
  final List<Bill> items;
  final PnColors pn;
  final void Function(Bill)? onTap;
  final bool readOnly;

  const _BillList({
    required this.items,
    required this.pn,
    this.onTap,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return EmptyState(
        message: readOnly ? 'No collections today' : 'No pending bills',
      );
    }
    return RefreshIndicator(
      onRefresh: () async {
        final auth = context.read<AuthProvider>();
        final bills = context.read<BillsProvider>();
        final staff = auth.currentStaff;
        if (staff == null || staff.areaId == null) return;
        await bills.loadPendingByArea(staff.areaId!, staff.id);
      },
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemBuilder: (context, i) => _BillTile(
          bill: items[i],
          pn: pn,
          onTap: onTap != null ? () => onTap!(items[i]) : null,
        ),
      ),
    );
  }
}

class _BillTile extends StatelessWidget {
  final Bill bill;
  final PnColors pn;
  final VoidCallback? onTap;

  const _BillTile({required this.bill, required this.pn, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      bill.customerName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  PnStatusBadge.fromString(bill.status),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                bill.customerCode,
                style: TextStyle(fontSize: 12, color: pn.textMuted),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    'Month: ${bill.month}',
                    style: TextStyle(fontSize: 12, color: pn.textMuted),
                  ),
                  const Spacer(),
                  Text(
                    'Rs. ${bill.remaining.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: Color(0xFFF05A2B),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
