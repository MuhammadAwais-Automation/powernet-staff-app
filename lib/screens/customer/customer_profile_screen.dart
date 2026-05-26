import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/customer_auth_provider.dart';
import '../../providers/customer_portal_provider.dart';
import '../../theme/app_theme.dart';

class CustomerProfileScreen extends StatelessWidget {
  const CustomerProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<CustomerAuthProvider>();
    final customer = auth.currentCustomer;
    final pn = Theme.of(context).extension<PnColors>()!;
    if (customer == null) return const SizedBox.shrink();

    return Scaffold(
      appBar: AppBar(title: const Text('My Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    customer.fullName,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: pn.text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    customer.customerCode,
                    style: TextStyle(color: pn.textMuted),
                  ),
                  const Divider(height: 24),
                  _Row(label: 'House ID', value: customer.displayHouseId),
                  _Row(label: 'CNIC', value: customer.cnic ?? '-'),
                  _Row(label: 'Phone', value: customer.phone ?? '-'),
                  _Row(label: 'WhatsApp', value: customer.whatsapp ?? '-'),
                  _Row(label: 'Area', value: customer.area?.name ?? '-'),
                  _Row(label: 'Package', value: customer.package?.name ?? '-'),
                  _Row(label: 'Status', value: customer.status),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: () async {
              context.read<CustomerPortalProvider>().clear();
              await auth.logout();
            },
            icon: const Icon(Icons.logout),
            label: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final pn = Theme.of(context).extension<PnColors>()!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(color: pn.textMuted, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: pn.text, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
