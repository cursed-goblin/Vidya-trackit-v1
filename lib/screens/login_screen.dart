import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme.dart';
import '../widgets/ui.dart';
import 'dashboard_screen.dart';

/// Student / passenger login. DEMO: accepts any non-empty credentials.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _user = TextEditingController(text: 'user');
  final _pass = TextEditingController(text: 'password');
  bool _loading = false;

  @override
  void dispose() {
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() => _loading = true);
    // DEMO login: always succeeds so the prototype is easy to show.
    AuthService.instance.loginStudentDemo();
    await Future.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;
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
                    Text('Student & Parent Login',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 13)),
                    const SizedBox(height: 26),
                    AuthField(
                        controller: _user,
                        hint: 'Username',
                        icon: Icons.person_outline_rounded),
                    const SizedBox(height: 14),
                    AuthField(
                        controller: _pass,
                        hint: 'Password',
                        icon: Icons.lock_outline_rounded,
                        obscure: true),
                    const SizedBox(height: 22),
                    GradientButton(
                        label: 'Login',
                        loading: _loading,
                        onPressed: _login),
                    const SizedBox(height: 14),
                    Text('Demo build - any username/password works',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.4),
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
