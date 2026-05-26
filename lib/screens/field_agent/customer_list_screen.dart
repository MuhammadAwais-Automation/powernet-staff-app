import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../models/customer.dart';
import '../../providers/auth_provider.dart';
import '../../providers/customers_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/pn_status_badge.dart';

class FieldAgentCustomerListScreen extends StatefulWidget {
  const FieldAgentCustomerListScreen({super.key});

  @override
  State<FieldAgentCustomerListScreen> createState() =>
      _FieldAgentCustomerListScreenState();
}

class _FieldAgentCustomerListScreenState
    extends State<FieldAgentCustomerListScreen> {
  final _searchCtrl = TextEditingController();
  bool _showSearch = false;

  @override
  void initState() {
    super.initState();
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
    _searchCtrl.dispose();
    super.dispose();
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
                  hintText: 'Search name, code, phone…',
                  hintStyle: TextStyle(color: pn.textMuted),
                  border: InputBorder.none,
                ),
                onChanged: (v) {
                  final staff = context.read<AuthProvider>().currentStaff;
                  context.read<CustomersProvider>().search(v, areaIds: staff?.areaIds);
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
      ),
      body: Consumer<CustomersProvider>(
        builder: (context, provider, _) {
          if (provider.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.error != null) {
            return ErrorState(message: provider.error!, onRetry: _load);
          }

          final items = _showSearch && _searchCtrl.text.isNotEmpty
              ? provider.searchResults
              : provider.customers;

          if (provider.searching) {
            return const Center(child: CircularProgressIndicator());
          }

          if (items.isEmpty) {
            return EmptyState(
              message: _showSearch ? 'No results' : 'No customers in area',
            );
          }

          return RefreshIndicator(
            onRefresh: () async => _load(),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, i) => _CustomerTile(
                customer: items[i],
                pn: pn,
                onTap: () => context.push('/field-agent/customers/${items[i].id}'),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CustomerTile extends StatelessWidget {
  final Customer customer;
  final PnColors pn;
  final VoidCallback onTap;

  const _CustomerTile({
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
                    if (customer.phone != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        customer.phone!,
                        style: TextStyle(fontSize: 12, color: pn.textMuted),
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
