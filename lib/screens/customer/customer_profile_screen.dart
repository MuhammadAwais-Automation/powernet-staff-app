import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/customer_auth_provider.dart';
import '../../providers/customer_portal_provider.dart';
import '../../theme/app_theme.dart';

class CustomerProfileScreen extends StatelessWidget {
  const CustomerProfileScreen({super.key});

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<CustomerAuthProvider>();
    final customer = auth.currentCustomer;
    final pn = Theme.of(context).extension<PnColors>()!;
    if (customer == null) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: pn.background,
      appBar: AppBar(title: const Text('My Profile'), elevation: 0),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Glass Avatar Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: pn.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: pn.border),
                boxShadow: [
                  BoxShadow(
                    color: pn.text.withValues(alpha: 0.04),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: pn.cyan.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: pn.cyan.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        _getInitials(customer.fullName),
                        style: GoogleFonts.manrope(
                          color: pn.accent,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          customer.fullName,
                          style: GoogleFonts.manrope(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: pn.text,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          customer.customerCode,
                          style: TextStyle(fontSize: 12, color: pn.textSoft),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: pn.softGreen,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: pn.success.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Text(
                            customer.status.toUpperCase(),
                            style: TextStyle(
                              color: pn.success,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Customer Details List Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: pn.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: pn.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Verification Details',
                    style: GoogleFonts.manrope(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: pn.text,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12.0),
                    child: Divider(),
                  ),
                  _Row(
                    label: 'House ID',
                    value: customer.displayHouseId,
                    icon: Icons.home_work_outlined,
                    pn: pn,
                  ),
                  _Row(
                    label: 'CNIC Number',
                    value: customer.cnic ?? '—',
                    icon: Icons.badge_outlined,
                    pn: pn,
                  ),
                  _Row(
                    label: 'Phone Contact',
                    value: customer.phone ?? '—',
                    icon: Icons.phone_outlined,
                    pn: pn,
                  ),
                  _Row(
                    label: 'WhatsApp',
                    value: customer.whatsapp ?? '—',
                    icon: Icons.chat_outlined,
                    pn: pn,
                  ),
                  _Row(
                    label: 'Assigned Area',
                    value: customer.area?.name ?? '—',
                    icon: Icons.my_location_rounded,
                    pn: pn,
                  ),
                  _Row(
                    label: 'Active Package',
                    value: customer.package?.name ?? '—',
                    icon: Icons.wifi_tethering,
                    pn: pn,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Logout Action Button
            OutlinedButton.icon(
              onPressed: () async {
                context.read<CustomerPortalProvider>().clear();
                await auth.logout();
              },
              style: OutlinedButton.styleFrom(
                backgroundColor: pn.softRed,
                foregroundColor: pn.danger,
                side: BorderSide(color: pn.danger.withValues(alpha: 0.2)),
              ),
              icon: Icon(Icons.logout_rounded, color: pn.danger, size: 20),
              label: const Text('Logout Session'),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final PnColors pn;

  const _Row({
    required this.label,
    required this.value,
    required this.icon,
    required this.pn,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: pn.cyan.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: pn.cyan, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: pn.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    color: pn.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
