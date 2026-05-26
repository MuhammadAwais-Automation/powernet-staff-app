import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../models/customer.dart';
import '../../providers/auth_provider.dart';
import '../../providers/customers_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/pn_status_badge.dart';

class CoCustomerListScreen extends StatefulWidget {
  const CoCustomerListScreen({super.key});

  @override
  State<CoCustomerListScreen> createState() => _CoCustomerListScreenState();
}

class _CoCustomerListScreenState extends State<CoCustomerListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _searchCtrl = TextEditingController();
  bool _showSearch = false;

  static const _statuses = ['all', 'active', 'suspended', 'disconnected'];
  static const _labels = ['All', 'Active', 'Suspended', 'Disconnected'];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _statuses.length, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _load() {
    final staff = context.read<AuthProvider>().currentStaff;
    if (staff != null) {
      context.read<CustomersProvider>().loadByAreas(staff.areaIds);
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Customer> _filtered(List<Customer> all, int tabIndex) {
    final status = _statuses[tabIndex];
    if (status == 'all') return all;
    return all.where((c) => c.status == status).toList();
  }

  @override
  Widget build(BuildContext context) {
    final pn = Theme.of(context).extension<PnColors>()!;
    return Scaffold(
      appBar: AppBar(
        title: _showSearch
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                style: TextStyle(color: pn.text),
                decoration: InputDecoration(
                   hintText: 'Search name, code, ONU…',
                  hintStyle: TextStyle(color: pn.textMuted),
                  border: InputBorder.none,
                ),
                onChanged: (v) {
                  final staff = context.read<AuthProvider>().currentStaff;
                  context
                      .read<CustomersProvider>()
                      .search(v, areaIds: staff?.areaIds);
                },
              )
            : const Text('Customers'),
        actions: [
          IconButton(
            icon: Icon(_showSearch ? Icons.close : Icons.search),
            onPressed: () {
              setState(() => _showSearch = !_showSearch);
              if (!_showSearch) {
                _searchCtrl.clear();
                context.read<CustomersProvider>().clearSearch();
              }
            },
          ),
          if (!_showSearch)
            IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
        bottom: _showSearch
            ? null
            : TabBar(
                controller: _tabs,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: _labels.map((l) => Tab(text: l)).toList(),
              ),
      ),
      body: Consumer<CustomersProvider>(
        builder: (context, provider, _) {
          if (provider.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.error != null) {
            return ErrorState(message: provider.error!, onRetry: _load);
          }

          if (_showSearch && _searchCtrl.text.isNotEmpty) {
            if (provider.searching) {
              return const Center(child: CircularProgressIndicator());
            }
            final results = provider.searchResults;
            if (results.isEmpty) {
              return const EmptyState(message: 'No results');
            }
            return _CustomerList(
              customers: results,
              pn: pn,
              onTap: (id) => context.push('/cable-operator/customers/$id'),
            );
          }

          return TabBarView(
            controller: _tabs,
            children: List.generate(_statuses.length, (i) {
              final items = _filtered(provider.customers, i);
              if (items.isEmpty) {
                return EmptyState(
                  message: i == 0
                      ? 'No customers in area'
                      : 'No ${_labels[i].toLowerCase()} customers',
                );
              }
              return RefreshIndicator(
                onRefresh: () async => _load(),
                child: _CustomerList(
                  customers: items,
                  pn: pn,
                  onTap: (id) => context.push('/cable-operator/customers/$id'),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}

class _CustomerList extends StatelessWidget {
  final List<Customer> customers;
  final PnColors pn;
  final void Function(String id) onTap;

  const _CustomerList({
    required this.customers,
    required this.pn,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: customers.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, i) => _CoCustomerTile(
        customer: customers[i],
        pn: pn,
        onTap: () => onTap(customers[i].id),
      ),
    );
  }
}

class _CoCustomerTile extends StatelessWidget {
  final Customer customer;
  final PnColors pn;
  final VoidCallback onTap;

  const _CoCustomerTile({
    required this.customer,
    required this.pn,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: primary.withValues(alpha: 0.12),
                child: Text(
                  customer.fullName.isNotEmpty
                      ? customer.fullName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: primary,
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
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      customer.displayId,
                      style: TextStyle(fontSize: 12, color: pn.textMuted),
                    ),
                    if (customer.onuNumber != null) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(Icons.router_outlined,
                              size: 12, color: pn.textMuted),
                          const SizedBox(width: 4),
                          Text(
                            customer.onuNumber!,
                            style:
                                TextStyle(fontSize: 12, color: pn.textMuted),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              PnStatusBadge.fromString(customer.status),
            ],
          ),
        ),
      ),
    );
  }
}
