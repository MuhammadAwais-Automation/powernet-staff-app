import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<AuthProvider>().refreshProfile();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final pn = Theme.of(context).extension<PnColors>()!;
    final auth = context.watch<AuthProvider>();
    final staff = auth.currentStaff;

    if (staff == null) return const Scaffold(body: SizedBox.shrink());

    // Resolve Role Theme Palette
    final role = staff.normalizedRole;
    Color rolePrimary;
    Color roleAccent;
    List<Color> gradientColors;

    switch (role) {
      case 'technician':
        rolePrimary = const Color(0xFF1E3A8A); // Royal Navy
        roleAccent = const Color(0xFF3B82F6); // Royal Blue
        gradientColors = [const Color(0xFF1E3A8A), const Color(0xFF0F172A)];
        break;
      case 'recovery_agent':
        rolePrimary = const Color(0xFFEA580C); // Sunset Orange
        roleAccent = const Color(0xFFF97316); // Coral Orange
        gradientColors = [const Color(0xFFEA580C), const Color(0xFF9A3412)];
        break;
      case 'field_agent':
        rolePrimary = const Color(0xFF059669); // Emerald Green
        roleAccent = const Color(0xFF10B981); // Mint Green
        gradientColors = [const Color(0xFF059669), const Color(0xFF064E3B)];
        break;
      default:
        rolePrimary = const Color(0xFF475569); // Slate Grey
        roleAccent = const Color(0xFF64748B); // Cool Grey
        gradientColors = [const Color(0xFF475569), const Color(0xFF1E293B)];
    }

    return Scaffold(
      backgroundColor: pn.surfaceMuted,
      appBar: AppBar(
        title: const Text(
          'Profile Details',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: pn.surfaceMuted,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, size: 18, color: pn.text),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        children: [
          _HeaderCard(
            name: staff.fullName,
            roleLabel: staff.roleLabel,
            gradientColors: gradientColors,
            roleAccent: roleAccent,
          ),
          const SizedBox(height: 20),
          _DetailsCard(staff: staff, pn: pn, roleColor: rolePrimary),
          const SizedBox(height: 20),
          _AreaCard(staff: staff, pn: pn, roleColor: rolePrimary, role: role),
          const SizedBox(height: 28),
          _SignOutButton(auth: auth),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final String name;
  final String roleLabel;
  final List<Color> gradientColors;
  final Color roleAccent;

  const _HeaderCard({
    required this.name,
    required this.roleLabel,
    required this.gradientColors,
    required this.roleAccent,
  });

  String get _initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: gradientColors[0].withValues(alpha: 0.15),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.15),
                width: 3,
              ),
            ),
            child: CircleAvatar(
              radius: 46,
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              child: CircleAvatar(
                radius: 41,
                backgroundColor: Colors.white,
                child: Text(
                  _initials,
                  style: TextStyle(
                    color: gradientColors[0],
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.25,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Text(
              roleLabel.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailsCard extends StatelessWidget {
  final dynamic staff;
  final PnColors pn;
  final Color roleColor;

  const _DetailsCard({
    required this.staff,
    required this.pn,
    required this.roleColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: pn.border.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Personal Information',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: pn.text,
                letterSpacing: 0.1,
              ),
            ),
            const SizedBox(height: 20),
            _DetailRow(
              icon: Icons.person_outline,
              label: 'Full Name',
              value: staff.fullName,
              pn: pn,
              iconColor: roleColor,
            ),
            const Divider(height: 28, thickness: 0.8),
            _DetailRow(
              icon: Icons.alternate_email_outlined,
              label: 'Username',
              value: staff.username ?? '—',
              pn: pn,
              iconColor: roleColor,
            ),
            const Divider(height: 28, thickness: 0.8),
            _DetailRow(
              icon: Icons.phone_outlined,
              label: 'Phone Number',
              value: staff.phone ?? '—',
              pn: pn,
              iconColor: roleColor,
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final PnColors pn;
  final Color iconColor;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.pn,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: pn.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 3),
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
      ],
    );
  }
}

class _AreaCard extends StatelessWidget {
  final dynamic staff;
  final PnColors pn;
  final Color roleColor;
  final String role;

  const _AreaCard({
    required this.staff,
    required this.pn,
    required this.roleColor,
    required this.role,
  });

  String _getAssignedAreaText() {
    switch (role) {
      case 'technician':
        return 'Aapko is assigned service area ki complaints aur maintenance activities solve karne ka ikhtiyar diya gaya hai. Aapke queue console par is area ke open issues show ho rahe hain.';
      case 'recovery_agent':
        return 'Aapko is assigned service area ki recoveries aur bills collection jama karne ka ikhtiyar diya gaya hai. Sirf is area ke customers ka pending data aapke recovery console par show ho raha hai.';
      case 'field_agent':
        return 'Aapko is assigned service area ke new connections, user verification, aur customer onboarding operations handle karne ka ikhtiyar diya gaya hai.';
      default:
        return 'Aapko assigned service area ke mutabiq field activities aur operations manage karne ka ikhtiyar diya gaya hai.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final areaName = staff.areaName;
    final areaId = staff.areaId;
    final hasArea = areaName != null && areaId != null;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: pn.border.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Assigned Service Area',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: pn.text,
                    letterSpacing: 0.1,
                  ),
                ),
                const Spacer(),
                if (hasArea)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: pn.success.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: pn.success.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Text(
                      'ACTIVE',
                      style: TextStyle(
                        color: pn.success,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            if (hasArea) ...[
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: roleColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.my_location_rounded,
                      color: roleColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          areaName,
                          style: TextStyle(
                            color: pn.text,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'ID: $areaId',
                          style: TextStyle(
                            color: pn.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: pn.surfaceMuted,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: pn.border.withValues(alpha: 0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.verified_user_outlined,
                      size: 16,
                      color: roleColor,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _getAssignedAreaText(),
                        style: TextStyle(
                          color: pn.text,
                          fontSize: 11.5,
                          height: 1.45,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: pn.danger.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: pn.danger.withValues(alpha: 0.15)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.report_problem_outlined,
                      color: pn.danger,
                      size: 22,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Area Not Assigned',
                            style: TextStyle(
                              color: pn.danger,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'Aapko abhi tak koi service area assign nahi kiya gaya hai. Operations aur complaints dekhne ke liye please apne administrator se rabta karein.',
                            style: TextStyle(
                              color: pn.text,
                              fontSize: 12,
                              height: 1.4,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SignOutButton extends StatelessWidget {
  final AuthProvider auth;

  const _SignOutButton({required this.auth});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFDC2626),
          side: const BorderSide(color: Color(0xFFDC2626), width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          elevation: 0,
        ),
        icon: const Icon(Icons.logout_rounded, size: 20),
        label: const Text(
          'Sign Out',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 15,
            letterSpacing: 0.2,
          ),
        ),
        onPressed: () async {
          await auth.logout();
          if (context.mounted) context.go('/login');
        },
      ),
    );
  }
}
