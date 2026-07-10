import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme.dart';
import '../widgets/ui.dart';
import 'driver_home_screen.dart';

/// Staff / driver login. Minimal: logo, Staff ID, Password, one button.
/// No signup, no forgot-password. DEMO credential: driver01 / pass123.
class StaffLoginScreen extends StatefulWidget {
  const StaffLoginScreen({super.key});
  @override
  State<StaffLoginScreen> createState() => _StaffLoginScreenState();
}

class _StaffLoginScreenState extends State<StaffLoginScreen> {
  final _id = TextEditingController();
  final _pass = TextEditingController();
  String? _error;
  bool _loading = false;

  @override
  void dispose() {
    _id.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    await Future.delayed(const Duration(milliseconds: 300));
    final staff = AuthService.instance.loginStaff(_id.text, _pass.text);
    if (!mounted) return;
    if (staff == null) {
      setState(() {
        _loading = false;
        _error = 'Invalid Staff ID or password.';
      });
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const DriverHomeScreen()),
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
                      child: const Icon(Icons.badge_rounded,
                          color: Colors.white, size: 30),
                    ),
                    const SizedBox(height: 18),
                    const Text('DRIVER LOGIN',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.3)),
                    const SizedBox(height: 6),
                    Text('Vidya TrackIt - Staff access',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 13)),
                    const SizedBox(height: 26),
                    AuthField(
                        controller: _id,
                        hint: 'Staff ID',
                        icon: Icons.badge_outlined),
                    const SizedBox(height: 14),
                    AuthField(
                        controller: _pass,
                        hint: 'Password',
                        icon: Icons.lock_outline_rounded,
                        obscure: true),
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          const Icon(Icons.error_outline_rounded,
                              color: kRed, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(_error!,
                                style: const TextStyle(
                                    color: kRed,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 22),
                    GradientButton(
                        label: 'Login',
                        loading: _loading,
                        onPressed: _login),
                    const SizedBox(height: 14),
                    Text('Demo credential: driver01 / pass123',
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
