import 'dart:async';
import 'package:flutter/material.dart';
import '../config.dart';
import '../services/auth_service.dart';
import '../services/location_service.dart';
import '../theme.dart';
import '../widgets/ui.dart';
import 'admin_screen.dart';
import 'role_select_screen.dart';

/// Driver home: assigned bus/route, the single Start/End Trip control, a live
/// status card for verifying the background service is pushing data, and the
/// boarding roster for the current trip.
class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});
  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  bool _tracking = false;
  bool _busy = false;
  Map<String, dynamic>? _last;
  StreamSubscription<Map<String, dynamic>?>? _sub;

  String get _busId => AuthService.instance.staff?.busId ?? kDemoBusId;

  @override
  void initState() {
    super.initState();
    _sub = TripController.instance.updates().listen((event) {
      if (event != null && mounted) setState(() => _last = event);
    });
    TripController.instance.isRunning().then((r) {
      if (mounted) setState(() => _tracking = r);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _toggle(String busId) async {
    setState(() => _busy = true);
    if (_tracking) {
      await TripController.instance.endTrip(busId);
      if (mounted) setState(() => _tracking = false);
    } else {
      final err = await TripController.instance.startTrip(busId);
      if (!mounted) return;
      if (err != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), backgroundColor: kRed),
        );
      } else {
        setState(() => _tracking = true);
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _logout() async {
    // Logout force-stops any active trip so a driver is never tracked off-shift.
    await TripController.instance.endTrip(_busId);
    await AuthService.instance.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const RoleSelectScreen()),
      (r) => false,
    );
  }

  String _fmtTime(int? ms) {
    if (ms == null) return '--';
    final t = DateTime.fromMillisecondsSinceEpoch(ms);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }

  @override
  Widget build(BuildContext context) {
    final staff = AuthService.instance.staff;
    final busId = _busId;
    final lat = (_last?['lat'] as num?)?.toStringAsFixed(5) ?? '--';
    final lng = (_last?['lng'] as num?)?.toStringAsFixed(5) ?? '--';
    final spd = (_last?['speed'] as num?)?.toStringAsFixed(1) ?? '--';
    final pending = (_last?['pending'] as num?)?.toInt() ?? 0;
    final error = '${_last?['error'] ?? ''}';

    return Scaffold(
      backgroundColor: kAppBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text('Driver Home',
            style: TextStyle(color: kHeading, fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            tooltip: 'Boarding roster',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => AdminScreen(busId: busId, canManage: false),
            )),
            icon: const Icon(Icons.how_to_reg_rounded, color: kSub),
          ),
          IconButton(
            tooltip: 'Logout',
            onPressed: _logout,
            icon: const Icon(Icons.logout_rounded, color: kSub),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Assigned bus / route
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: kBorder),
              ),
              child: Row(
                children: [
                  Container(
                    height: 46,
                    width: 46,
                    decoration: BoxDecoration(
                        color: kPurple.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(13)),
                    child: const Icon(Icons.directions_bus_rounded,
                        color: kPurple),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(staff?.busNumber ?? '--',
                            style: const TextStyle(
                                color: kHeading,
                                fontSize: 17,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: 3),
                        Text(staff?.routeName ?? '--',
                            style: const TextStyle(color: kSub, fontSize: 12.5)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 26),
            // The single Start/End Trip control.
            GestureDetector(
              onTap: _busy ? null : () => _toggle(busId),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                height: 190,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _tracking
                        ? [kRed, const Color(0xFFB91C1C)]
                        : [kPurpleLight, kPurpleDark],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                        color: (_tracking ? kRed : kPurple).withValues(alpha: 0.4),
                        blurRadius: 26,
                        offset: const Offset(0, 12)),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                        _tracking
                            ? Icons.stop_circle_rounded
                            : Icons.play_circle_fill_rounded,
                        color: Colors.white,
                        size: 62),
                    const SizedBox(height: 12),
                    Text(_tracking ? 'END TRIP' : 'START TRIP',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5)),
                    const SizedBox(height: 4),
                    Text(
                        _tracking
                            ? 'Sharing your live location'
                            : 'Tap to start sharing location',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 13)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 26),
            // Status card.
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: kBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('Live Status',
                          style: TextStyle(
                              color: kHeading,
                              fontSize: 15,
                              fontWeight: FontWeight.w700)),
                      const Spacer(),
                      StatusPill(
                        text: _tracking
                            ? (error.isEmpty ? 'Broadcasting' : 'Retrying')
                            : 'Idle',
                        color: !_tracking
                            ? kSub
                            : (error.isEmpty ? kGreen : kAmber),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _statRow('Latitude', lat),
                  _statRow('Longitude', lng),
                  _statRow('Speed', '$spd km/h'),
                  _statRow('Last updated',
                      _fmtTime((_last?['timestamp'] as num?)?.toInt())),
                  // Surfacing the queue and the last error means a driver can
                  // see "offline, 3 points queued" instead of assuming all is
                  // well while nothing reaches the server.
                  _statRow('Queued points', '$pending'),
                  if (error.isNotEmpty) _statRow('Last error', error),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statRow(String k, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: Row(
          children: [
            SizedBox(
                width: 120,
                child: Text(k, style: const TextStyle(color: kSub, fontSize: 13.5))),
            Expanded(
              child: Text(v,
                  style: const TextStyle(
                      color: kHeading,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
}
