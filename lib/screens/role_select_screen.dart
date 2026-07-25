import 'package:flutter/material.dart';
import '../theme.dart';
import 'login_screen.dart';
import 'staff_login_screen.dart';

/// First screen: rider (student / teacher), driver, or transport office.
class RoleSelectScreen extends StatelessWidget {
  const RoleSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: kDarkAuthGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 26),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _Logo(),
                const SizedBox(height: 48),
                _RoleCard(
                  icon: Icons.school_rounded,
                  title: 'Student / Teacher',
                  subtitle: 'Track your bus and set arrival alerts',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  ),
                ),
                const SizedBox(height: 16),
                _RoleCard(
                  icon: Icons.directions_bus_rounded,
                  title: 'Driver',
                  subtitle: 'Share your live location on your route',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) =>
                            const StaffLoginScreen(title: 'DRIVER LOGIN')),
                  ),
                ),
                const SizedBox(height: 16),
                _RoleCard(
                  icon: Icons.admin_panel_settings_rounded,
                  title: 'Transport office',
                  subtitle: 'Manage riders and see who is on the bus',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) =>
                            const StaffLoginScreen(title: 'ADMIN LOGIN')),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 78,
          width: 78,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [kPurpleLight, kPurpleDark]),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                  color: kPurple.withValues(alpha: 0.5),
                  blurRadius: 26,
                  offset: const Offset(0, 10)),
            ],
          ),
          child: const Icon(Icons.directions_bus_rounded,
              color: Colors.white, size: 40),
        ),
        const SizedBox(height: 18),
        const Text('VIDYA TRACKIT',
            style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5)),
        const SizedBox(height: 6),
        Text('Vidya Engineering College - Bus Tracker',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.65), fontSize: 13)),
      ],
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Row(
            children: [
              Container(
                height: 52,
                width: 52,
                decoration: BoxDecoration(
                  color: kPurple.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: kPurpleLight, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16.5,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 12.5)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: Colors.white.withValues(alpha: 0.5)),
            ],
          ),
        ),
      ),
    );
  }
}
