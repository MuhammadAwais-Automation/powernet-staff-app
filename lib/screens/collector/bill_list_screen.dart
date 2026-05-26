import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../models/bill.dart';
import '../../providers/auth_provider.dart';
import '../../providers/bills_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/pn_status_badge.dart';
import '../../widgets/recovery_console_widgets.dart';

class BillListScreen extends StatefulWidget {
  const BillListScreen({super.key});

  @override
  State<BillListScreen> createState() => _BillListScreenState();
}

class _BillListScreenState extends State<BillListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this);
    _searchCtrl.addListener(() {
      setState(() => _query = _searchCtrl.text.trim().toLowerCase());
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final auth = context.read<AuthProvider>();
    final bills = context.read<BillsProvider>();
    await auth.refreshProfile();
    final staff = auth.currentStaff;
    if (staff == null || staff.areaId == null) return;
    await bills.loadPendingByArea(staff.areaId!, staff.id);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pn = Theme.of(context).extension<PnColors>()!;
    final auth = context.watch<AuthProvider>();
    final staff = auth.currentStaff;

    if (staff != null && staff.areaId == null) {
      return Scaffold(
        backgroundColor: pn.surfaceMuted,
        appBar: AppBar(
          title: const Text('Recovery Console'),
          actions: [
            IconButton(
              icon: const Icon(Icons.person_outline),
              tooltip: 'Profile',
              onPressed: () => context.push('/profile'),
            ),
          ],
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: pn.warning.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.map_outlined, color: pn.warning, size: 64),
                ),
                const SizedBox(height: 24),
                Text(
                  'No Area Assigned',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: pn.text,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Aapko koi service area assign nahi kiya gaya hai.\nApne administrator se rabta karein taake aap recovery details dekh sakein.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: pn.textMuted,
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: () => context.push('/profile'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: pn.surface,
                    foregroundColor: pn.text,
                    side: BorderSide(color: pn.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    minimumSize: const Size(200, 48),
                  ),
                  icon: const Icon(Icons.person_outline, size: 20),
                  label: const Text(
                    'Apna Profile Dekhein',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: pn.surfaceMuted,
      appBar: AppBar(
        title: const Text('Recovery Console'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'Profile',
            onPressed: () => context.push('/profile'),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _load,
          ),
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

          final all = _filter(provider.bills);
          final overdue = all.where((b) => b.isOverdue).toList();
          final partial = all.where((b) => b.hasPartialPayment).toList();
          final today = _filter(provider.collectedToday);
          final visits = _filter(provider.visitedToday);

          return RefreshIndicator(
            onRefresh: _load,
            child: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                    child: Column(
                      children: [
                        RecoveryHeroCard(
                          areaName: staff?.areaName ?? '—',
                          totalDue: provider.totalDue,
                          billCount: provider.bills.length,
                          collectedTodayAmount: provider.collectedTodayAmount,
                          overdueCount: provider.bills
                              .where((b) => b.isOverdue)
                              .length,
                          partialCount: provider.bills
                              .where((b) => b.hasPartialPayment)
                              .length,
                        ),
                        if (provider.pendingSyncCount > 0) ...[
                          const SizedBox(height: 12),
                          _SyncBanner(count: provider.pendingSyncCount, pn: pn),
                        ],
                        const SizedBox(height: 14),
                        _SearchBox(controller: _searchCtrl),
                      ],
                    ),
                  ),
                ),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _TabsHeader(
                    controller: _tabs,
                    background: pn.surfaceMuted,
                  ),
                ),
              ],
              body: TabBarView(
                controller: _tabs,
                children: [
                  _BillList(
                    items: all,
                    emptyMessage: 'No pending recoveries in this area',
                    onTap: (b) =>
                        context.push('/collector/bills/${b.id}/collect'),
                  ),
                  _BillList(
                    items: overdue,
                    emptyMessage: 'No overdue bills right now',
                    onTap: (b) =>
                        context.push('/collector/bills/${b.id}/collect'),
                  ),
                  _BillList(
                    items: partial,
                    emptyMessage: 'No partial collections pending',
                    onTap: (b) =>
                        context.push('/collector/bills/${b.id}/collect'),
                  ),
                  _BillList(
                    items: today,
                    emptyMessage: 'No collections recorded today',
                    readOnly: true,
                  ),
                  _VisitList(
                    items: visits,
                    emptyMessage: 'No visits logged today',
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  List<Bill> _filter(List<Bill> items) {
    if (_query.isEmpty) return items;
    return items.where((bill) {
      final haystack = '${bill.customerName} ${bill.customerCode} ${bill.month}'
          .toLowerCase();
      return haystack.contains(_query);
    }).toList();
  }
}

class _SyncBanner extends StatelessWidget {
  final int count;
  final PnColors pn;

  const _SyncBanner({required this.count, required this.pn});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: warning.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_upload_outlined, color: warning, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$count item${count == 1 ? '' : 's'} locally saved. Internet on hotay hi auto sync ho jayega.',
              style: TextStyle(color: pn.text, fontSize: 12, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchBox extends StatelessWidget {
  final TextEditingController controller;

  const _SearchBox({required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: const InputDecoration(
        prefixIcon: Icon(Icons.search),
        hintText: 'Search customer, code or month',
      ),
    );
  }
}

class _TabsHeader extends SliverPersistentHeaderDelegate {
  final TabController controller;
  final Color background;

  const _TabsHeader({required this.controller, required this.background});

  @override
  double get minExtent => 54;

  @override
  double get maxExtent => 54;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: background,
      child: RecoverySegmentedTabs(
        controller: controller,
        background: background,
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _TabsHeader oldDelegate) =>
      oldDelegate.controller != controller ||
      oldDelegate.background != background;
}

class _BillList extends StatelessWidget {
  final List<Bill> items;
  final String emptyMessage;
  final void Function(Bill)? onTap;
  final bool readOnly;

  const _BillList({
    required this.items,
    required this.emptyMessage,
    this.onTap,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return EmptyState(message: emptyMessage);
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
      itemCount: items.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, i) => _BillTile(
        bill: items[i],
        readOnly: readOnly,
        onTap: onTap != null ? () => onTap!(items[i]) : null,
      ),
    );
  }
}

class _BillTile extends StatelessWidget {
  final Bill bill;
  final VoidCallback? onTap;
  final bool readOnly;

  const _BillTile({required this.bill, this.onTap, required this.readOnly});

  @override
  Widget build(BuildContext context) {
    final pn = Theme.of(context).extension<PnColors>()!;
    final paid = bill.paidAmount ?? 0;

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: pn.border, width: 1),
      ),
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            // Decorative Left Accent Line
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 5,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [primary, primary.withValues(alpha: 0.5)],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          bill.customerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            color: pn.text,
                          ),
                        ),
                      ),
                      PnStatusBadge.fromString(bill.collectionStatus),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: pn.surfaceMuted,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: pn.border),
                        ),
                        child: Text(
                          bill.customerCode,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: pn.text,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Month ${bill.month}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (bill.hasAddress) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: pn.textMuted,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            bill.customerAddress,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: pn.textMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      minHeight: 8,
                      value: bill.collectionProgress,
                      backgroundColor: pn.surfaceMuted,
                      color: bill.isPaid ? pn.success : primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _AmountBlock(
                        label: 'Bill',
                        value: bill.amount,
                        muted: true,
                      ),
                      _AmountBlock(label: 'Paid', value: paid, muted: true),
                      _AmountBlock(
                        label: readOnly ? 'Collected' : 'Balance',
                        value: readOnly ? paid : bill.remaining,
                        highlight: true,
                      ),
                      if (!readOnly)
                        Icon(Icons.chevron_right, color: pn.textMuted),
                    ],
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

class _AmountBlock extends StatelessWidget {
  final String label;
  final double value;
  final bool muted;
  final bool highlight;

  const _AmountBlock({
    required this.label,
    required this.value,
    this.muted = false,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final pn = Theme.of(context).extension<PnColors>()!;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: pn.textMuted, fontSize: 11)),
          const SizedBox(height: 2),
          Text(
            'Rs. ${value.toStringAsFixed(0)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: highlight ? primary : (muted ? pn.textMuted : pn.text),
              fontWeight: highlight ? FontWeight.w900 : FontWeight.w700,
              fontSize: highlight ? 14 : 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _VisitList extends StatelessWidget {
  final List<Bill> items;
  final String emptyMessage;

  const _VisitList({required this.items, required this.emptyMessage});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return EmptyState(message: emptyMessage);
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
      itemCount: items.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, i) => _VisitTile(bill: items[i]),
    );
  }
}

class _VisitTile extends StatelessWidget {
  final Bill bill;

  const _VisitTile({required this.bill});

  @override
  Widget build(BuildContext context) {
    final pn = Theme.of(context).extension<PnColors>()!;
    final visitType = VisitType.fromValue(bill.paymentNote ?? '');
    final (icon, color) = switch (visitType) {
      VisitType.houseLocked => (Icons.lock_outline, warning),
      VisitType.promiseToPay => (Icons.handshake_outlined, info),
      VisitType.refusedToPay => (Icons.block_outlined, danger),
      VisitType.paymentCollected => (Icons.check_circle_outline, pn.success),
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bill.customerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: pn.text,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    bill.customerCode,
                    style: TextStyle(fontSize: 12, color: pn.textMuted),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                visitType.label,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
