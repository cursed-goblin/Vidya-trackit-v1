import 'package:flutter/material.dart';

import '../config.dart';
import '../services/auth_service.dart';
import '../theme.dart';
import '../widgets/ui.dart';
import 'dashboard_screen.dart';

/// Rider login - students and teachers use the same form and the same role.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    // Without backend credentials the app still opens in demo mode so the UI
    // can be shown; it just cannot read or write anything.
    if (!gSupabaseReady) {
      AuthService.instance.loginStudentDemo();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      );
      return;
    }

    final err = await AuthService.instance.signIn(_email.text, _pass.text);
    if (!mounted) return;
    if (err != null) {
      setState(() {
        _loading = false;
        _error = err;
      });
      return;
    }
    if (AuthService.instance.student == null) {
      setState(() {
        _loading = false;
        _error = 'This account is not set up as a rider yet.';
      });
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const DashboardScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: kDarkAuthGradient),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 24),
              child: GlassCard(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      height: 60,
                      width: 60,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [kPurpleLight, kPurpleDark]),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(Icons.directions_bus_rounded,
                          color: Colors.white, size: 32),
                    ),
                    const SizedBox(height: 18),
                    const Text('VIDYA TRACKIT',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.3)),
                    const SizedBox(height: 6),
                    Text('Student & teacher login',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 13)),
                    const SizedBox(height: 26),
                    AuthField(
                        controller: _email,
                        hint: 'Email',
                        icon: Icons.mail_outline_rounded,
                        keyboardType: TextInputType.emailAddress),
                    const SizedBox(height: 14),
                    AuthField(
                        controller: _pass,
                        hint: 'Password',
                        icon: Icons.lock_outline_rounded,
                        obscure: true),
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      Text(_error!,
                          style: const TextStyle(
                              color: kRed,
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                    ],
                    const SizedBox(height: 22),
                    GradientButton(
                        label: 'Login',
                        loading: _loading,
                        onPressed: _login),
                    const SizedBox(height: 14),
                    Text(gSupabaseReady
                        ? 'Accounts are created by the transport office'
                        : 'Demo mode - backend not configured',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 11.5)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
