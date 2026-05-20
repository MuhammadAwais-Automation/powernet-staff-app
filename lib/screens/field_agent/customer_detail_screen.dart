import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/customers_repository.dart';
import '../../data/complaints_repository.dart';
import '../../models/customer.dart';
import '../../models/complaint.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/pn_status_badge.dart';

class CustomerDetailScreen extends StatefulWidget {
  final String customerId;
  const CustomerDetailScreen({super.key, required this.customerId});

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen>
    with SingleTickerProviderStateMixin {
  final CustomersRepository _custRepo = CustomersRepository();
  final ComplaintsRepository _compRepo = ComplaintsRepository();

  Customer? _customer;
  List<Complaint> _complaints = [];
  bool _loading = true;
  String? _error;
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final cust = await _custRepo.fetchById(widget.customerId);
      final allComplaints = await _compRepo.fetchAll();
      _customer = cust;
      _complaints =
          allComplaints.where((c) => c.customerId == widget.customerId).toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      setState(() => _loading = false);
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
        title: Text(_customer?.fullName ?? 'Customer'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Info'),
            Tab(text: 'Complaints'),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ErrorState(message: _error!, onRetry: _load)
              : _customer == null
                  ? const EmptyState(message: 'Customer not found')
                  : TabBarView(
                      controller: _tabs,
                      children: [
                        _InfoTab(customer: _customer!, pn: pn),
                        _ComplaintsTab(complaints: _complaints, pn: pn),
                      ],
                    ),
    );
  }
}

class _InfoTab extends StatelessWidget {
  final Customer customer;
  final PnColors pn;
  const _InfoTab({required this.customer, required this.pn});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Section(
          title: 'BASIC INFO',
          children: [
            _Row(label: 'Name', value: customer.fullName, pn: pn),
            _Row(label: 'Code', value: customer.customerCode, pn: pn),
            if (customer.username != null)
              _Row(label: 'Username', value: customer.username!, pn: pn),
            Row(
              children: [
                Text('Status',
                    style: TextStyle(color: pn.textMuted, fontSize: 13)),
                const Spacer(),
                PnStatusBadge.fromString(customer.status),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        _Section(
          title: 'CONTACT',
          children: [
            _CopyRow(
              label: 'Phone',
              value: customer.phone ?? '—',
              pn: pn,
              canCopy: customer.phone != null,
            ),
            if (customer.cnic != null)
              _Row(label: 'CNIC', value: customer.cnic!, pn: pn),
          ],
        ),
        const SizedBox(height: 12),
        _Section(
          title: 'CONNECTION',
          children: [
            if (customer.area != null)
              _Row(label: 'Area', value: customer.area!.name, pn: pn),
            if (customer.addressValue != null)
              _Row(label: 'Address', value: customer.addressValue!, pn: pn),
            if (customer.connectionDate != null)
              _Row(label: 'Connected', value: customer.connectionDate!, pn: pn),
            if (customer.onuNumber != null)
              _Row(label: 'ONU', value: customer.onuNumber!, pn: pn),
            _Row(label: 'IPTV', value: customer.iptv ? 'Yes' : 'No', pn: pn),
          ],
        ),
        if (customer.dueAmount != null && customer.dueAmount! > 0) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFDC2626).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: const Color(0xFFDC2626).withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: Color(0xFFDC2626)),
                const SizedBox(width: 10),
                Text(
                  'Due: Rs. ${customer.dueAmount!.toStringAsFixed(0)}',
                  style: const TextStyle(
                    color: Color(0xFFDC2626),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
        if (customer.remarks != null && customer.remarks!.isNotEmpty) ...[
          const SizedBox(height: 12),
          _Section(
            title: 'REMARKS',
            children: [
              Text(customer.remarks!,
                  style:
                      TextStyle(fontSize: 13, color: pn.text, height: 1.5)),
            ],
          ),
        ],
      ],
    );
  }
}

class _ComplaintsTab extends StatelessWidget {
  final List<Complaint> complaints;
  final PnColors pn;
  const _ComplaintsTab({required this.complaints, required this.pn});

  @override
  Widget build(BuildContext context) {
    if (complaints.isEmpty) {
      return const EmptyState(message: 'No complaints for this customer');
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: complaints.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final c = complaints[i];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(c.complaintCode,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                    const Spacer(),
                    PnStatusBadge.fromString(c.status),
                  ],
                ),
                const SizedBox(height: 6),
                Text(c.issue,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: pn.text)),
                const SizedBox(height: 6),
                Text(_formatDate(c.openedAt),
                    style: TextStyle(fontSize: 11, color: pn.textMuted)),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatDate(String iso) {
    try {
      final d = DateTime.parse(iso).toLocal();
      return '${d.day}/${d.month}/${d.year}';
    } catch (_) {
      return iso;
    }
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final pn = Theme.of(context).extension<PnColors>()!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: pn.textMuted,
                    letterSpacing: 0.5)),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final PnColors pn;
  const _Row({required this.label, required this.value, required this.pn});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label, style: TextStyle(color: pn.textMuted, fontSize: 13)),
          const Spacer(),
          Flexible(
            child: Text(value,
                textAlign: TextAlign.end,
                style: TextStyle(
                    color: pn.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

class _CopyRow extends StatelessWidget {
  final String label;
  final String value;
  final PnColors pn;
  final bool canCopy;
  const _CopyRow(
      {required this.label,
      required this.value,
      required this.pn,
      this.canCopy = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label, style: TextStyle(color: pn.textMuted, fontSize: 13)),
          const Spacer(),
          Text(value,
              style: TextStyle(
                  color: pn.text,
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
          if (canCopy) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Copied'),
                      duration: Duration(seconds: 1)),
                );
              },
              child: Icon(Icons.copy, size: 16, color: pn.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}
