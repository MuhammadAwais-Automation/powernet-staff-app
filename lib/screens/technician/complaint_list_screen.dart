import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/complaint_queue_provider.dart';
import '../../models/complaint.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/pn_status_badge.dart';

class ComplaintListScreen extends StatefulWidget {
  const ComplaintListScreen({super.key});

  @override
  State<ComplaintListScreen> createState() => _ComplaintListScreenState();
}

class _ComplaintListScreenState extends State<ComplaintListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _searchCtrl.addListener(() {
      if (mounted) {
        setState(() => _query = _searchCtrl.text.trim().toLowerCase());
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _load() {
    final auth = context.read<AuthProvider>();
    final queue = context.read<ComplaintQueueProvider>();
    final staff = auth.currentStaff;
    if (staff == null) return;
    queue.loadForTechnicianAndArea(staff.id, staff.areaId);
    queue.listenToComplaints(staff.id, staff.areaId);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchCtrl.dispose();
    try {
      context.read<ComplaintQueueProvider>().stopListening();
    } catch (_) {}
    super.dispose();
  }

  List<Complaint> _filter(List<Complaint> items) {
    if (_query.isEmpty) return items;
    return items.where((c) {
      final haystack =
          '${c.customerName} ${c.customerCode} ${c.complaintCode} ${c.issue} ${c.type}'
              .toLowerCase();
      return haystack.contains(_query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final pn = Theme.of(context).extension<PnColors>()!;
    return Scaffold(
      backgroundColor: pn.surfaceMuted,
      appBar: AppBar(
        title: const Text('Complaints Console'),
        backgroundColor: pn.surfaceMuted,
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
      body: Consumer<ComplaintQueueProvider>(
        builder: (context, queue, _) {
          if (queue.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (queue.error != null) {
            return ErrorState(message: queue.error!, onRetry: _load);
          }

          final filteredOpen = _filter(queue.open);
          final filteredWorking = _filter(queue.inProgress);

          return NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                  child: Column(
                    children: [
                      _KPIHeroCard(
                        openCount: queue.open.length,
                        workingCount: queue.inProgress.length,
                        resolvedCount: queue.resolvedToday.length,
                        pn: pn,
                      ),
                      if (queue.pendingSyncCount > 0) ...[
                        const SizedBox(height: 12),
                        _SyncBanner(count: queue.pendingSyncCount, pn: pn),
                      ],
                      const SizedBox(height: 14),
                      _SearchBox(controller: _searchCtrl),
                    ],
                  ),
                ),
              ),
              SliverPersistentHeader(
                pinned: true,
                delegate: _PersistentTabsHeader(
                  controller: _tabs,
                  background: pn.surfaceMuted,
                  pn: pn,
                ),
              ),
            ],
            body: TabBarView(
              controller: _tabs,
              children: [
                _ComplaintList(
                  items: filteredOpen,
                  pn: pn,
                  emptyMsg: 'No pending complaints assigned.',
                  onRefresh: _load,
                ),
                _ComplaintList(
                  items: filteredWorking,
                  pn: pn,
                  emptyMsg: 'No complaints in progress.',
                  onRefresh: _load,
                ),
              ],
            ),
          );
        },
      ),
    );
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
              '$count complaint update${count == 1 ? '' : 's'} locally saved. Internet on hotay hi auto sync ho jayega.',
              style: TextStyle(color: pn.text, fontSize: 12, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _KPIHeroCard extends StatelessWidget {
  final int openCount;
  final int workingCount;
  final int resolvedCount;
  final PnColors pn;

  const _KPIHeroCard({
    required this.openCount,
    required this.workingCount,
    required this.resolvedCount,
    required this.pn,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E3A8A), Color(0xFF0F172A)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.handyman_outlined,
                  color: Colors.blueAccent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Technician Command Center',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _KPITile(
                label: 'New Assigned',
                value: '$openCount',
                color: pn.warning,
              ),
              const SizedBox(width: 10),
              _KPITile(
                label: 'Working',
                value: '$workingCount',
                color: primary,
              ),
              const SizedBox(width: 10),
              _KPITile(
                label: 'Resolved Today',
                value: '$resolvedCount',
                color: pn.success,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _KPITile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _KPITile({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
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
        hintText: 'Search complaints, code or customers...',
      ),
    );
  }
}

class _PersistentTabsHeader extends SliverPersistentHeaderDelegate {
  final TabController controller;
  final Color background;
  final PnColors pn;

  const _PersistentTabsHeader({
    required this.controller,
    required this.background,
    required this.pn,
  });

  @override
  double get minExtent => 52;
  @override
  double get maxExtent => 52;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: background,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: pn.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: pn.border),
        ),
        child: TabBar(
          controller: controller,
          indicatorSize: TabBarIndicatorSize.tab,
          splashBorderRadius: BorderRadius.circular(12),
          labelColor: Colors.white,
          unselectedLabelColor: pn.textMuted,
          indicator: BoxDecoration(
            color: primary,
            borderRadius: BorderRadius.circular(12),
          ),
          dividerColor: Colors.transparent,
          labelStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
          tabs: const [
            Tab(text: 'Open Assigned'),
            Tab(text: 'Active Working'),
          ],
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _PersistentTabsHeader oldDelegate) =>
      oldDelegate.controller != controller ||
      oldDelegate.background != background;
}

class _ComplaintList extends StatelessWidget {
  final List<Complaint> items;
  final PnColors pn;
  final String emptyMsg;
  final VoidCallback onRefresh;

  const _ComplaintList({
    required this.items,
    required this.pn,
    required this.emptyMsg,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return EmptyState(message: emptyMsg);
    }
    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: items.length,
        separatorBuilder: (context, index) => const SizedBox(height: 10),
        itemBuilder: (context, i) => _ComplaintTile(
          complaint: items[i],
          pn: pn,
          onTap: () => context.push('/technician/complaints/${items[i].id}'),
        ),
      ),
    );
  }
}

class _ComplaintTile extends StatelessWidget {
  final Complaint complaint;
  final PnColors pn;
  final VoidCallback onTap;

  const _ComplaintTile({
    required this.complaint,
    required this.pn,
    required this.onTap,
  });

  Color _priorityColor() {
    switch (complaint.priority) {
      case 'high':
        return const Color(0xFFDC2626);
      case 'medium':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF6B7280);
    }
  }

  void _showCallDialerModal(BuildContext context) {
    final phone = complaint.customerPhone;
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Customer phone number not available'),
          backgroundColor: danger,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.phone_outlined, color: primary),
            const SizedBox(width: 10),
            const Text(
              'Dialer Options',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              complaint.customerName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              'Phone: $phone',
              style: TextStyle(color: pn.textMuted, fontSize: 14),
            ),
            const SizedBox(height: 12),
            const Text(
              'Aap is number ko copy kar sakte hain ya onsite calling simulate kar sakte hain.',
              style: TextStyle(fontSize: 12, height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: phone));
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Phone number copied to clipboard!'),
                  backgroundColor: success,
                ),
              );
            },
            child: const Text('Copy Number'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Simulating call to $phone...'),
                  backgroundColor: primary,
                  duration: const Duration(seconds: 3),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(120, 36),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Call Now'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
            // Decorative Left Accent Line (Priority based)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 5,
              child: Container(color: _priorityColor()),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                          complaint.complaintCode,
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
                          color: _priorityColor().withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          complaint.priority.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: _priorityColor(),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const Spacer(),
                      PnStatusBadge.fromString(complaint.status),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    complaint.issue,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: pn.text,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.person_outline, size: 14, color: pn.textMuted),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          complaint.customerName,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: pn.textMuted,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (complaint.hasAddress) ...[
                    const SizedBox(height: 6),
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
                            complaint.customerAddress,
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
                  const Divider(height: 20),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          complaint.type,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: primary,
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (complaint.customerPhone.isNotEmpty)
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _showCallDialerModal(context),
                            borderRadius: BorderRadius.circular(99),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: pn.success.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.phone_enabled_outlined,
                                color: pn.success,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
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
