import 'package:flutter/material.dart';

import '../config.dart';
import '../services/auth_service.dart';
import '../theme.dart';
import '../widgets/ui.dart';
import 'admin_screen.dart';
import 'driver_home_screen.dart';

/// Staff login (driver and admin share this form).
///
/// Credentials are real Supabase Auth users now - the old hard-coded
/// `driver01 / pass123` is gone. Where the user lands is decided by
/// `profiles.role`, not by which button they tapped.
class StaffLoginScreen extends StatefulWidget {
  final String title;
  const StaffLoginScreen({super.key, this.title = 'STAFF LOGIN'});
  @override
  State<StaffLoginScreen> createState() => _StaffLoginScreenState();
}

class _StaffLoginScreenState extends State<StaffLoginScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  String? _error;
  bool _loading = false;

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

    final auth = AuthService.instance;
    final err = await auth.signIn(_email.text, _pass.text);
    if (!mounted) return;
    if (err != null) {
      setState(() {
        _loading = false;
        _error = err;
      });
      return;
    }

    if (auth.isAdmin) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) =>
            AdminScreen(busId: auth.staff?.busId ?? kDemoBusId),
      ));
    } else if (auth.isDriver) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const DriverHomeScreen()),
      );
    } else {
      setState(() {
        _loading = false;
        _error = 'This account is not a driver or admin.';
      });
    }
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
                    Text(widget.title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.3)),
                    const SizedBox(height: 6),
                    Text('Vidya TrackIt - staff access',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
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
                    Text('Accounts are created by the transport office',
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
