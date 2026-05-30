import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/customer_auth_provider.dart';
import '../theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  // Modes: 'welcome', 'staff', 'customer'
  String _mode = 'welcome';
  bool _obscure = true;
  bool _loading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      _usernameCtrl.text.trim().isNotEmpty &&
      _passwordCtrl.text.isNotEmpty &&
      !_loading;

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    final auth = context.read<AuthProvider>();
    final customerAuth = context.read<CustomerAuthProvider>();

    final result = _mode == 'staff'
        ? await auth.login(
            _usernameCtrl.text.trim().toLowerCase(),
            _passwordCtrl.text,
          )
        : await customerAuth.login(
            _usernameCtrl.text.trim(),
            _passwordCtrl.text,
          );

    if (!mounted) return;
    setState(() => _loading = false);

    if (!result.ok) {
      setState(() {
        _errorMessage =
            result.error ?? 'Invalid credentials. Check and try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pn = Theme.of(context).extension<PnColors>()!;

    return Scaffold(
      body: Stack(
        children: [
          // Background Glows
          Positioned(
            left: -80,
            top: -80,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: pn.cyan.withValues(alpha: 0.06),
              ),
            ),
          ),
          Positioned(
            right: -80,
            bottom: -80,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: pn.accent.withValues(alpha: 0.05),
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _mode == 'welcome'
                      ? _buildWelcomeBody(pn)
                      : _buildLoginFormBody(pn),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeBody(PnColors pn) {
    return Column(
      key: const ValueKey('welcome-layout'),
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Brand Logo Header
        const SizedBox(height: 20),
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                'POWER',
                style: GoogleFonts.manrope(
                  fontSize: 38,
                  fontWeight: FontWeight.w900,
                  color: pn.text,
                  letterSpacing: -1.5,
                ),
              ),
              Text(
                'NET',
                style: GoogleFonts.manrope(
                  fontSize: 38,
                  fontWeight: FontWeight.w900,
                  color: pn.accent,
                  letterSpacing: -1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Future of Connectivity & Beyond',
          textAlign: TextAlign.center,
          style: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: pn.textSoft,
          ),
        ),
        const SizedBox(height: 48),

        Text(
          'Choose Portal Entry',
          style: GoogleFonts.manrope(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: pn.text,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Please select your role portal to continue login.',
          style: TextStyle(fontSize: 13, color: pn.textMuted),
        ),
        const SizedBox(height: 24),

        // Staff Portal Selection Card
        _buildRoleSelectionCard(
          title: 'Staff Portal',
          subtitle: 'For technicians, recoveries, and field agents.',
          icon: Icons.badge_outlined,
          iconBg: pn.softOrange,
          iconColor: pn.accent,
          borderGlowColor: pn.accent.withValues(alpha: 0.3),
          onTap: () {
            setState(() {
              _mode = 'staff';
              _usernameCtrl.clear();
              _passwordCtrl.clear();
              _errorMessage = null;
            });
          },
        ),
        const SizedBox(height: 14),

        // Customer Portal Selection Card
        _buildRoleSelectionCard(
          title: 'Customer Portal',
          subtitle: 'Manage active packages, pay bills, and tickets.',
          icon: Icons.home_outlined,
          iconBg: pn.softCyan,
          iconColor: pn.cyan,
          borderGlowColor: pn.cyan.withValues(alpha: 0.35),
          onTap: () {
            setState(() {
              _mode = 'customer';
              _usernameCtrl.clear();
              _passwordCtrl.clear();
              _errorMessage = null;
            });
          },
        ),
        const SizedBox(height: 40),

        // New Customer Signup Row
        Text(
          'New to PowerNet?',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: pn.textSoft,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => context.push('/customer/signup'),
          icon: Icon(
            Icons.person_add_alt_1_outlined,
            color: pn.accent,
            size: 18,
          ),
          label: Text(
            'Create new customer request',
            style: TextStyle(color: pn.text, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildLoginFormBody(PnColors pn) {
    final isStaff = _mode == 'staff';
    return Column(
      key: ValueKey('login-$_mode'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top Navigation Header / Back Button
        Row(
          children: [
            InkWell(
              onTap: () {
                setState(() {
                  _mode = 'welcome';
                  _errorMessage = null;
                });
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: pn.border),
                  color: pn.surface,
                ),
                child: Icon(
                  Icons.arrow_back_rounded,
                  color: pn.textSoft,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Text(
              isStaff ? 'Staff Portal' : 'Customer Portal',
              style: GoogleFonts.manrope(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: pn.text,
              ),
            ),
          ],
        ),
        const SizedBox(height: 36),

        // Brand banner mini
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              'POWER',
              style: GoogleFonts.manrope(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: pn.text,
                letterSpacing: -1.2,
              ),
            ),
            Text(
              'NET',
              style: GoogleFonts.manrope(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: pn.accent,
                letterSpacing: -1.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          isStaff
              ? 'Enter staff credentials to sync assigned tasks.'
              : 'Sign in using your verified house ID or registered phone number.',
          style: TextStyle(fontSize: 13, color: pn.textMuted),
        ),
        const SizedBox(height: 28),

        // Custom Error Message Alert Card (matches CSS .alert element)
        if (_errorMessage != null) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: pn.softRed,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: pn.danger.withValues(alpha: 0.35)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, color: pn.danger, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Authentication Error',
                        style: TextStyle(
                          color: pn.danger,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: pn.danger.withValues(alpha: 0.85),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],

        // Input username / house ID field
        Text(
          isStaff ? 'USERNAME' : 'HOUSE ID OR PHONE',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: pn.textSoft,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _usernameCtrl,
          textInputAction: TextInputAction.next,
          autocorrect: false,
          enableSuggestions: false,
          textCapitalization: TextCapitalization.none,
          keyboardType: TextInputType.text,
          style: TextStyle(
            color: pn.text,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
          decoration: InputDecoration(
            hintText: isStaff ? 'e.g. technician_ahmed' : 'e.g. house_102b',
            prefixIcon: Icon(
              Icons.person_outline_rounded,
              color: pn.textMuted,
              size: 20,
            ),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 20),

        // Input password field
        Text(
          'PASSWORD',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: pn.textSoft,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _passwordCtrl,
          obscureText: _obscure,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _canSubmit ? _submit() : null,
          style: TextStyle(
            color: pn.text,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
          decoration: InputDecoration(
            hintText: 'Enter account password',
            prefixIcon: Icon(
              Icons.lock_outline_rounded,
              color: pn.textMuted,
              size: 20,
            ),
            suffixIcon: IconButton(
              icon: Icon(
                _obscure
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: pn.textMuted,
                size: 20,
              ),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 32),

        // Submit Button
        ElevatedButton(
          onPressed: _canSubmit ? _submit : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: pn.accent,
            foregroundColor: pn.primary,
            disabledBackgroundColor: pn.accent.withValues(alpha: 0.4),
            disabledForegroundColor: pn.primary.withValues(alpha: 0.5),
            shadowColor: pn.accent.withValues(alpha: 0.25),
            elevation: 8,
          ),
          child: _loading
              ? SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation(pn.primary),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      isStaff ? 'SECURE STAFF LOGIN' : 'ACCESS CUSTOMER PORTAL',
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded, size: 18),
                  ],
                ),
        ),

        if (!isStaff) ...[
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Don\'t have an account?',
                style: TextStyle(color: pn.textMuted, fontSize: 13),
              ),
              TextButton(
                onPressed: () => context.push('/customer/signup'),
                child: Text(
                  'Register Request',
                  style: TextStyle(
                    color: pn.accent,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildRoleSelectionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required Color borderGlowColor,
    required VoidCallback onTap,
  }) {
    final pn = Theme.of(context).extension<PnColors>()!;
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: pn.border),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: Row(
            children: [
              // Icon Box
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderGlowColor),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 16),
              // Text Metadata
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.manrope(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: pn.text,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: pn.textSoft,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Arrow Indicator
              Icon(Icons.chevron_right_rounded, color: pn.accent, size: 24),
            ],
          ),
        ),
      ),
    );
  }
}
