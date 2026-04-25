import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
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
    try {
      final ok = await auth.login(
        _usernameCtrl.text.trim().toLowerCase(),
        _passwordCtrl.text,
      );
      if (!mounted) return;
      if (ok) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      } else {
        _showError('Invalid credentials');
      }
    } catch (e) {
      if (!mounted) return;
      final lower = e.toString().toLowerCase();
      final msg = lower.contains('socket') || lower.contains('network')
          ? 'No internet connection'
          : 'Connection error, try again';
      _showError(msg);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.wifi_tethering, size: 64, color: primaryColor),
              const SizedBox(height: 12),
              const Text(
                'PowerNet Staff',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _usernameCtrl,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                enableSuggestions: false,
                textCapitalization: TextCapitalization.none,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  prefixIcon: Icon(Icons.person_outline),
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
                    icon: Icon(_obscure
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined),
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
                    : const Text('LOGIN'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
