import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
  String _mode = 'staff';
  bool _obscure = true;
  bool _loading = false;

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
    setState(() => _loading = true);
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
      _showError(result.error ?? 'Login failed');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: danger,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pn = Theme.of(context).extension<PnColors>()!;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.wifi_tethering, size: 64, color: primary),
              const SizedBox(height: 12),
              Text(
                _mode == 'staff' ? 'PowerNet Staff' : 'PowerNet Customer',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: pn.text,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _mode == 'staff'
                    ? 'Sign in to continue'
                    : 'Use your house ID or phone after approval',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: pn.textMuted),
              ),
              const SizedBox(height: 28),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'staff',
                    label: Text('Staff'),
                    icon: Icon(Icons.badge_outlined),
                  ),
                  ButtonSegment(
                    value: 'customer',
                    label: Text('Customer'),
                    icon: Icon(Icons.home_outlined),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: (selection) {
                  setState(() {
                    _mode = selection.first;
                    _usernameCtrl.clear();
                    _passwordCtrl.clear();
                  });
                },
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _usernameCtrl,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                enableSuggestions: false,
                textCapitalization: TextCapitalization.none,
                decoration: InputDecoration(
                  labelText: _mode == 'staff'
                      ? 'Username'
                      : 'House ID or phone',
                  prefixIcon: const Icon(Icons.person_outline),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordCtrl,
                obscureText: _obscure,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _canSubmit ? _submit() : null,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _canSubmit ? _submit : null,
                child: _loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : Text(_mode == 'staff' ? 'LOGIN' : 'CUSTOMER LOGIN'),
              ),
              if (_mode == 'customer') ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _loading
                      ? null
                      : () => context.push('/customer/signup'),
                  icon: const Icon(Icons.person_add_alt_1_outlined),
                  label: const Text('Create new customer request'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
