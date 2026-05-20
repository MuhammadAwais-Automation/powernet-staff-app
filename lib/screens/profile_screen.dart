import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final pn = Theme.of(context).extension<PnColors>()!;
    final auth = context.watch<AuthProvider>();
    final staff = auth.currentStaff;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: staff == null
          ? const SizedBox.shrink()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _Avatar(name: staff.fullName, pn: pn),
                const SizedBox(height: 20),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _Row(label: 'Name', value: staff.fullName, pn: pn),
                        _Row(label: 'Username', value: staff.username ?? '—', pn: pn),
                        _Row(label: 'Role', value: staff.roleLabel, pn: pn),
                        _Row(label: 'Phone', value: staff.phone ?? '—', pn: pn),
                        if (staff.areaName != null)
                          _Row(label: 'Area', value: staff.areaName!, pn: pn),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                      side: const BorderSide(color: Color(0xFFDC2626)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.logout),
                    label: const Text('Sign Out',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    onPressed: () async {
                      await auth.logout();
                      if (context.mounted) context.go('/login');
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String name;
  final PnColors pn;
  const _Avatar({required this.name, required this.pn});

  String get _initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: const Color(0xFFF05A2B),
            child: Text(
              _initials,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
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
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(label,
              style: TextStyle(color: pn.textMuted, fontSize: 13)),
          const Spacer(),
          Text(value,
              style: TextStyle(
                  color: pn.text,
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
