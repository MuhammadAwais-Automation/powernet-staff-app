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
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    // 5 tabs to handle complete collection list workflow
    _tabs = TabController(length: 5, vsync: this);
    _searchCtrl.addListener(() {
      if (mounted) {
        setState(() => _query = _searchCtrl.text.trim().toLowerCase());
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final auth = context.read<AuthProvider>();
    final bills = context.read<BillsProvider>();
    await auth.refreshProfile();
    final staff = auth.currentStaff;
    if (staff == null) return;
    await bills.loadPendingByAreas(staff.areaIds, staff.id);
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

    if (staff != null && staff.areaIds.isEmpty) {
      return Scaffold(
        backgroundColor: pn.background,
        appBar: AppBar(
          backgroundColor: pn.background,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: pn.text),
            onPressed: () => context.pop(),
          ),
          title: Text(
            'Recovery Console',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: pn.text,
              letterSpacing: -0.5,
            ),
          ),
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
                    fontWeight: FontWeight.w900,
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
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () => context.push('/profile'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: pn.accent,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(200, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Apna Profile Dekhein',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: pn.background,
      appBar: AppBar(
        backgroundColor: pn.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: pn.text),
          onPressed: () => context.pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Collections',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: pn.text,
                letterSpacing: -0.5,
              ),
            ),
            Text(
              'Search customer bill',
              style: TextStyle(
                fontSize: 12,
                color: pn.textMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12, top: 12, bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: pn.cyan.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(99),
            ),
            alignment: Alignment.center,
            child: Text(
              'Online',
              style: TextStyle(
                color: pn.cyan,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.refresh, color: pn.text),
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
            color: pn.accent,
            child: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: Column(
                      children: [
                        // Search Row matching 12-recovery-payment.html mockup
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _searchCtrl,
                                decoration: InputDecoration(
                                  hintText: 'Search name, code, area',
                                  hintStyle: TextStyle(color: pn.textMuted),
                                  prefixIcon: Icon(Icons.search, color: pn.textMuted, size: 20),
                                  filled: true,
                                  fillColor: pn.surface,
                                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(18),
                                    borderSide: BorderSide(color: pn.border),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(18),
                                    borderSide: BorderSide(color: pn.border),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text('Search filters updated'),
                                    backgroundColor: pn.primary,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: pn.cyan.withValues(alpha: 0.12),
                                foregroundColor: pn.cyan,
                                elevation: 0,
                                minimumSize: const Size(54, 52),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                  side: BorderSide(color: pn.cyan.withValues(alpha: 0.2)),
                                ),
                              ),
                              child: const Text('Go', style: TextStyle(fontWeight: FontWeight.w900)),
                            ),
                          ],
                        ),
                        if (provider.pendingSyncCount > 0) ...[
                          const SizedBox(height: 12),
                          _SyncBanner(count: provider.pendingSyncCount, pn: pn),
                        ],
                      ],
                    ),
                  ),
                ),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _TabsHeader(
                    controller: _tabs,
                    background: pn.background,
                    pn: pn,
                  ),
                ),
              ],
              body: TabBarView(
                controller: _tabs,
                children: [
                  _BillList(
                    items: all,
                    emptyMessage: 'No pending recoveries in this area',
                    pn: pn,
                    onTap: (b) =>
                        context.push('/collector/bills/${b.id}/collect'),
                  ),
                  _BillList(
                    items: overdue,
                    emptyMessage: 'No overdue bills right now',
                    pn: pn,
                    onTap: (b) =>
                        context.push('/collector/bills/${b.id}/collect'),
                  ),
                  _BillList(
                    items: partial,
                    emptyMessage: 'No partial collections pending',
                    pn: pn,
                    onTap: (b) =>
                        context.push('/collector/bills/${b.id}/collect'),
                  ),
                  _BillList(
                    items: today,
                    emptyMessage: 'No collections recorded today',
                    pn: pn,
                    readOnly: true,
                  ),
                  _VisitList(
                    items: visits,
                    pn: pn,
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
        color: pn.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: pn.warning.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_upload_outlined, color: pn.warning, size: 20),
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

class _TabsHeader extends SliverPersistentHeaderDelegate {
  final TabController controller;
  final Color background;
  final PnColors pn;

  const _TabsHeader({required this.controller, required this.background, required this.pn});

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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Container(
        decoration: BoxDecoration(
          color: pn.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: pn.border),
        ),
        child: TabBar(
          controller: controller,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorSize: TabBarIndicatorSize.tab,
          splashBorderRadius: BorderRadius.circular(12),
          labelColor: Colors.white,
          unselectedLabelColor: pn.textMuted,
          indicator: BoxDecoration(
            color: pn.primary,
            borderRadius: BorderRadius.circular(12),
          ),
          dividerColor: Colors.transparent,
          labelStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
          tabs: const [
            Tab(text: 'All Rec.'),
            Tab(text: 'Overdue'),
            Tab(text: 'Partial'),
            Tab(text: 'Today'),
            Tab(text: 'Visits'),
          ],
        ),
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
  final PnColors pn;

  const _BillList({
    required this.items,
    required this.emptyMessage,
    this.onTap,
    this.readOnly = false,
    required this.pn,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return EmptyState(message: emptyMessage);
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: items.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, i) => _BillTile(
        bill: items[i],
        readOnly: readOnly,
        pn: pn,
        onTap: onTap != null ? () => onTap!(items[i]) : null,
      ),
    );
  }
}

class _BillTile extends StatelessWidget {
  final Bill bill;
  final VoidCallback? onTap;
  final bool readOnly;
  final PnColors pn;

  const _BillTile({required this.bill, this.onTap, required this.readOnly, required this.pn});

  Color _statusColor() {
    switch (bill.collectionStatus) {
      case 'paid':
        return pn.success;
      case 'overdue':
        return pn.danger;
      case 'partial':
        return pn.cyan;
      default:
        return pn.warning;
    }
  }

  String _statusLabel() {
    switch (bill.collectionStatus) {
      case 'paid':
        return 'Paid';
      case 'overdue':
        return 'Overdue';
      case 'partial':
        return 'Partial';
      default:
        return 'Pending';
    }
  }

  @override
  Widget build(BuildContext context) {
    final paid = bill.paidAmount ?? 0;

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: pn.border, width: 1.2),
      ),
      child: InkWell(
        onTap: onTap,
        child: Container(
          color: pn.surface,
          child: Stack(
            children: [
              // Decorative Left Accent Line matching mockup
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: 6,
                child: Container(
                  color: _statusColor(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
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
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _statusColor().withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            _statusLabel().toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: _statusColor(),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${bill.customerCode} - ${bill.customerAddress.isNotEmpty ? bill.customerAddress : "Gulshan Block 4"} - ${bill.month}',
                      style: TextStyle(
                        fontSize: 12,
                        color: pn.textMuted,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 14),
                    // High fidelity Money Grid Layout
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: pn.surfaceMuted,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: pn.border),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildMiniCell('Amount', 'PKR ${_formatMoney(bill.amount)}', pn),
                          ),
                          Expanded(
                            child: _buildMiniCell(
                              readOnly ? 'Collected' : 'Remaining',
                              'PKR ${_formatMoney(readOnly ? paid : bill.remaining)}',
                              pn,
                              highlight: !readOnly,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        minHeight: 8,
                        value: bill.collectionProgress,
                        backgroundColor: pn.surfaceMuted,
                        color: bill.isPaid ? pn.success : pn.accent,
                      ),
                    ),
                  ],
                ),
              ),
              if (!readOnly)
                Positioned(
                  right: 12,
                  bottom: 50,
                  child: Icon(Icons.chevron_right, color: pn.textMuted),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniCell(String label, String value, PnColors pn, {bool highlight = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: pn.textMuted,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: highlight ? pn.accent : pn.text,
          ),
        ),
      ],
    );
  }

  String _formatMoney(double value) {
    if (value >= 1000) {
      final k = value / 1000;
      return '${k.toStringAsFixed(k.truncateToDouble() == k ? 0 : 1)}K';
    }
    return value.toStringAsFixed(0);
  }
}

class _VisitList extends StatelessWidget {
  final List<Bill> items;
  final String emptyMessage;
  final PnColors pn;

  const _VisitList({required this.items, required this.emptyMessage, required this.pn});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return EmptyState(message: emptyMessage);
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: items.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, i) => _VisitTile(bill: items[i], pn: pn),
    );
  }
}

class _VisitTile extends StatelessWidget {
  final Bill bill;
  final PnColors pn;

  const _VisitTile({required this.bill, required this.pn});

  @override
  Widget build(BuildContext context) {
    final visitType = VisitType.fromValue(bill.paymentNote ?? '');
    final (icon, color) = switch (visitType) {
      VisitType.houseLocked => (Icons.lock_outline, pn.warning),
      VisitType.promiseToPay => (Icons.handshake_outlined, pn.cyan),
      VisitType.refusedToPay => (Icons.block_outlined, pn.danger),
      VisitType.paymentCollected => (Icons.check_circle_outline, pn.success),
    };

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: pn.border),
      ),
      child: Container(
        color: pn.surface,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
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
                    style: TextStyle(fontSize: 12, color: pn.textMuted, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                visitType.label.toUpperCase(),
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
