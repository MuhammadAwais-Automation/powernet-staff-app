import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/bill.dart';
import '../../providers/customer_auth_provider.dart';
import '../../providers/customer_portal_provider.dart';
import '../../theme/app_theme.dart';

class CustomerBillsScreen extends StatefulWidget {
  const CustomerBillsScreen({super.key});

  @override
  State<CustomerBillsScreen> createState() => _CustomerBillsScreenState();
}

class _CustomerBillsScreenState extends State<CustomerBillsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final customer = context.read<CustomerAuthProvider>().currentCustomer;
      if (customer != null) {
        context.read<CustomerPortalProvider>().load(customer);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CustomerPortalProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('My Bills')),
      body: RefreshIndicator(
        onRefresh: provider.refreshActive,
        child: provider.loading && provider.bills.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : provider.bills.isEmpty
            ? const _EmptyBills()
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemBuilder: (context, index) =>
                    _BillCard(bill: provider.bills[index]),
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 10),
                itemCount: provider.bills.length,
              ),
      ),
    );
  }
}

class _EmptyBills extends StatelessWidget {
  const _EmptyBills();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: const [
        SizedBox(height: 120),
        Icon(Icons.receipt_long_outlined, size: 48, color: primary),
        SizedBox(height: 12),
        Center(child: Text('No bills yet')),
      ],
    );
  }
}

class _BillCard extends StatelessWidget {
  final Bill bill;
  const _BillCard({required this.bill});

  @override
  Widget build(BuildContext context) {
    final pn = Theme.of(context).extension<PnColors>()!;
    final paid = bill.paidAmount ?? 0;
    final remaining = bill.remaining.clamp(0, double.infinity);
    final color = bill.status == 'paid'
        ? pn.success
        : bill.status == 'overdue'
        ? pn.danger
        : pn.warning;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    bill.month,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: pn.text,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    bill.status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _Amount(label: 'Total', value: bill.amount, color: pn.text),
                _Amount(label: 'Paid', value: paid, color: pn.success),
                _Amount(
                  label: 'Remaining',
                  value: remaining.toDouble(),
                  color: color,
                ),
              ],
            ),
            if (bill.receiptNo != null || bill.paidAt != null) ...[
              const SizedBox(height: 10),
              Text(
                '${bill.receiptNo ?? 'No receipt'}${bill.paidAt == null ? '' : ' - ${bill.paidAt}'}',
                style: TextStyle(color: pn.textMuted, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Amount extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  const _Amount({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          const SizedBox(height: 3),
          Text(
            'Rs.${value.toStringAsFixed(0)}',
            style: TextStyle(fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }
}
