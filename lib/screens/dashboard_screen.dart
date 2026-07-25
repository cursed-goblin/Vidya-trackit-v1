import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme.dart';
import '../widgets/ui.dart';
import 'live_map_screen.dart';
import 'role_select_screen.dart';

/// Student dashboard: profile + assigned bus, with a button into the live map.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AuthService.instance.student ??
        (AuthService.instance..loginStudentDemo()).student!;
    return Scaffold(
      backgroundColor: kAppBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Welcome back,',
                            style: TextStyle(color: kSub, fontSize: 14)),
                        Text(s.name,
                            style: const TextStyle(
                                color: kHeading,
                                fontSize: 24,
                                fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Logout',
                    onPressed: () {
                      AuthService.instance.logout();
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                            builder: (_) => const RoleSelectScreen()),
                        (r) => false,
                      );
                    },
                    icon: const Icon(Icons.logout_rounded, color: kSub),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _Card(
                title: 'Student Details',
                icon: Icons.school_rounded,
                rows: [
                  ('Name', s.name),
                  ('Roll No', s.rollNo),
                  ('Department', s.department),
                  ('Boarding Stop', s.boardingStop),
                  ('Guardian', s.guardianMasked),
                ],
              ),
              const SizedBox(height: 16),
              _Card(
                title: 'Assigned Bus',
                icon: Icons.directions_bus_rounded,
                rows: [
                  ('Bus Number', s.busNumber),
                  ('Route', s.routeName),
                ],
                trailing: const StatusPill(text: 'On route', color: kGreen),
              ),
              const SizedBox(height: 24),
              GradientButton(
                label: 'Track this Bus',
                icon: Icons.my_location_rounded,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => LiveMapScreen(busId: s.busId),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<(String, String)> rows;
  final Widget? trailing;
  const _Card(
      {required this.title,
      required this.icon,
      required this.rows,
      this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kBorder),
        boxShadow: [
          BoxShadow(
              color: kHeading.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 38,
                width: 38,
                decoration: BoxDecoration(
                    color: kPurple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(11)),
                child: Icon(icon, color: kPurple, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        color: kHeading,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 14),
          ...rows.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 120,
                      child: Text(r.$1,
                          style: const TextStyle(color: kSub, fontSize: 13.5)),
                    ),
                    Expanded(
                      child: Text(r.$2,
                          style: const TextStyle(
                              color: kHeading,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
