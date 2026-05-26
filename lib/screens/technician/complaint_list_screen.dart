import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/complaint_queue_provider.dart';
import '../../models/complaint.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state.dart';

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
    // 3 tabs: Open, In Progress, Resolved matching 10-technician-complaints.html
    _tabs = TabController(length: 3, vsync: this);
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
    queue.loadForTechnicianAndAreas(staff.id, staff.areaIds);
    queue.listenToComplaints(staff.id, staff.areaIds);
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
    final auth = context.watch<AuthProvider>();
    final staff = auth.currentStaff;

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
              'Complaints',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: pn.text,
                letterSpacing: -0.5,
              ),
            ),
            Text(
              staff?.areaName ?? 'Gulshan Block 4',
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
            margin: const EdgeInsets.only(right: 16, top: 12, bottom: 12),
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
          // Show all resolved complaints in the third tab
          final filteredResolved = _filter(queue.complaints.where((c) => c.isResolved).toList());

          return NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Column(
                    children: [
                      // Styled Search Bar matching input system
                      TextField(
                        controller: _searchCtrl,
                        decoration: InputDecoration(
                          hintText: 'Search name, code, area',
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
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide(color: pn.accent),
                          ),
                        ),
                      ),
                      if (queue.pendingSyncCount > 0) ...[
                        const SizedBox(height: 12),
                        _SyncBanner(count: queue.pendingSyncCount, pn: pn),
                      ],
                    ],
                  ),
                ),
              ),
              SliverPersistentHeader(
                pinned: true,
                delegate: _PersistentTabsHeader(
                  controller: _tabs,
                  background: pn.background,
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
                  emptyMsg: 'No open complaints assigned.',
                  onRefresh: _load,
                ),
                _ComplaintList(
                  items: filteredWorking,
                  pn: pn,
                  emptyMsg: 'No complaints in progress.',
                  onRefresh: _load,
                ),
                _ComplaintList(
                  items: filteredResolved,
                  pn: pn,
                  emptyMsg: 'No resolved complaints today.',
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
              '$count complaint update${count == 1 ? '' : 's'} locally saved. Internet on hotay hi auto sync ho jayega.',
              style: TextStyle(color: pn.text, fontSize: 12, height: 1.35),
            ),
          ),
        ],
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
      child: Container(
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
            color: pn.primary,
            borderRadius: BorderRadius.circular(12),
          ),
          dividerColor: Colors.transparent,
          labelStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
          tabs: const [
            Tab(text: 'Open'),
            Tab(text: 'In Progress'),
            Tab(text: 'Resolved'),
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
      color: pn.accent,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: items.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
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
      case 'urgent':
        return pn.danger;
      case 'medium':
        return pn.warning;
      default:
        return pn.textMuted;
    }
  }

  String _priorityLabel() {
    switch (complaint.priority) {
      case 'high':
      case 'urgent':
        return 'Urgent';
      case 'medium':
        return 'Medium';
      default:
        return 'Normal';
    }
  }

  void _showCallDialerModal(BuildContext context) {
    final phone = complaint.customerPhone;
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Customer phone number not available'),
          backgroundColor: pn.danger,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: pn.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: pn.border)),
        title: Row(
          children: [
            Icon(Icons.phone_outlined, color: pn.primary),
            const SizedBox(width: 10),
            Text(
              'Call Customer',
              style: TextStyle(fontWeight: FontWeight.w900, color: pn.text, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              complaint.customerName,
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: pn.text),
            ),
            const SizedBox(height: 4),
            Text(
              'Phone: $phone',
              style: TextStyle(color: pn.textMuted, fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'Aap is number ko copy kar sakte hain ya onsite calling simulate kar sakte hain.',
              style: TextStyle(fontSize: 13, height: 1.4, color: pn.textSoft),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: phone));
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Phone number copied to clipboard!'),
                  backgroundColor: pn.success,
                ),
              );
            },
            child: Text('Copy Number', style: TextStyle(color: pn.textSoft, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Simulating call to $phone...'),
                  backgroundColor: pn.primary,
                  duration: const Duration(seconds: 3),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: pn.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(110, 38),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Call Now', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = complaint.isResolved
        ? pn.success
        : (complaint.isInProgress ? pn.cyan : pn.warning);

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
              // Left Accent line indicator matching high-fidelity layout
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: 6,
                child: Container(color: _priorityColor()),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          complaint.complaintCode,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: pn.text,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: _priorityColor().withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            _priorityLabel(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: _priorityColor(),
                            ),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            complaint.status.toUpperCase(),
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
                    const SizedBox(height: 12),
                    Text(
                      '${complaint.customerName} - ${complaint.customerCode}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: pn.text,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      complaint.issue,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: pn.textSoft,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 14),
                    // High-fidelity Mini Grid matching the mockup
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: pn.surfaceMuted,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: pn.border),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _buildMiniCell('Address', complaint.customerAddress.isNotEmpty ? complaint.customerAddress : 'No Address', pn),
                              ),
                              Expanded(
                                child: _buildMiniCell('Type', complaint.type, pn),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: _buildMiniCell('Phone', complaint.customerPhone.isNotEmpty ? complaint.customerPhone : 'No Number', pn),
                                    ),
                                    if (complaint.customerPhone.isNotEmpty)
                                      IconButton(
                                        icon: Icon(Icons.phone_enabled_outlined, color: pn.success, size: 16),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed: () => _showCallDialerModal(context),
                                      ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: _buildMiniCell('Opened', _formatTime(complaint.openedAt), pn),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniCell(String label, String value, PnColors pn) {
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
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: pn.text,
          ),
        ),
      ],
    );
  }

  String _formatTime(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'Recent';
    try {
      final dt = DateTime.parse(dateStr);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) {
      return 'Recent';
    }
  }
}
