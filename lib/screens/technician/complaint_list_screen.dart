import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _load() {
    final auth = context.read<AuthProvider>();
    final queue = context.read<ComplaintQueueProvider>();
    final staff = auth.currentStaff;
    if (staff == null) return;
    if (staff.areaId != null) {
      queue.loadForArea(staff.areaId!);
    } else {
      queue.loadForTechnician(staff.id);
    }
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
        title: const Text('Complaints'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Open'),
            Tab(text: 'In Progress'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
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
            return ErrorState(
              message: queue.error!,
              onRetry: _load,
            );
          }
          return TabBarView(
            controller: _tabs,
            children: [
              _ComplaintList(items: queue.open, pn: pn),
              _ComplaintList(items: queue.inProgress, pn: pn),
            ],
          );
        },
      ),
    );
  }
}

class _ComplaintList extends StatelessWidget {
  final List<Complaint> items;
  final PnColors pn;

  const _ComplaintList({required this.items, required this.pn});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const EmptyState(message: 'No complaints');
    }
    return RefreshIndicator(
      onRefresh: () async {
        final auth = context.read<AuthProvider>();
        final queue = context.read<ComplaintQueueProvider>();
        final staff = auth.currentStaff;
        if (staff == null) return;
        if (staff.areaId != null) {
          await queue.loadForArea(staff.areaId!);
        } else {
          await queue.loadForTechnician(staff.id);
        }
      },
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        separatorBuilder: (context, index) => const SizedBox(height: 8),
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
                      complaint.complaintCode,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _priorityColor().withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      complaint.priority.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: _priorityColor(),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                complaint.issue,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: pn.text),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.person_outline, size: 14, color: pn.textMuted),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      complaint.customerName,
                      style: TextStyle(fontSize: 12, color: pn.textMuted),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  PnStatusBadge.fromString(complaint.status),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
