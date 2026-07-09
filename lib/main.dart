import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() => runApp(const VidyaTrackItApp());

// ---- Brand palette ----
const kPurple = Color(0xFF7C3AED);
const kPurpleLight = Color(0xFF8B5CF6);
const kPurpleDark = Color(0xFF6D28D9);
const kBg1 = Color(0xFF1A0B2E);
const kAppBg = Color(0xFFF8FAFC);
const kHeading = Color(0xFF1E293B);
const kSub = Color(0xFF64748B);
const kGreen = Color(0xFF10B981);
const kBorder = Color(0xFFE2E8F0);

class VidyaTrackItApp extends StatelessWidget {
  const VidyaTrackItApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vidya TrackIt',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: kAppBg,
        colorScheme: ColorScheme.fromSeed(seedColor: kPurple),
      ),
      home: const LoginScreen(),
    );
  }
}

// =================== LOGIN ===================
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController(text: 'user');
  final _pass = TextEditingController(text: 'password');
  bool _obscure = true;

  void _login() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const DashboardScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0.7, -0.9),
            radius: 1.4,
            colors: [Color(0xFF3A1D6E), Color(0xFF241247), kBg1],
            stops: [0.0, 0.45, 1.0],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: _card(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _card() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          width: 360,
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 32),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF3A1E6C).withOpacity(0.90),
                const Color(0xFF1C0E36).withOpacity(0.93),
              ],
            ),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: Colors.white.withOpacity(0.18)),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.45), blurRadius: 60, offset: const Offset(0, 24)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [kPurpleLight, kPurpleDark]),
                  borderRadius: BorderRadius.circular(17),
                  boxShadow: [BoxShadow(color: kPurple.withOpacity(0.5), blurRadius: 24, offset: const Offset(0, 8))],
                ),
                child: const Icon(Icons.directions_bus_rounded, color: Colors.white, size: 30),
              ),
              const SizedBox(height: 12),
              const Text('VIDYA TRACKIT',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 4, fontSize: 15)),
              const SizedBox(height: 18),
              const Text('Welcome Back, Rahul',
                  style: TextStyle(color: Color(0xFFF5F3FF), fontSize: 23, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              const Text('Sign in to track your bus live', style: TextStyle(color: Color(0xFFC4B5FD), fontSize: 13)),
              const SizedBox(height: 22),
              _field('Email address', _email, Icons.email_outlined),
              const SizedBox(height: 16),
              _field('Password', _pass, Icons.lock_outline,
                  obscure: _obscure,
                  suffix: IconButton(
                    icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, color: Colors.white70, size: 20),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  )),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {},
                  child: const Text('Forget Password?', style: TextStyle(color: Color(0xFFC4B5FD), fontSize: 12)),
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: double.infinity,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [kPurpleLight, kPurpleDark]),
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [BoxShadow(color: kPurpleDark.withOpacity(0.5), blurRadius: 26, offset: const Offset(0, 10))],
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    onPressed: _login,
                    child: const Text('Login', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              RichText(
                text: const TextSpan(
                  style: TextStyle(color: Color(0xFFC4B5FD), fontSize: 13),
                  children: [
                    TextSpan(text: 'Are You New Member? '),
                    TextSpan(text: 'Sign UP', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white24),
                ),
                child: const Text('Demo login  \u2014  username  user   \u00b7   password  password',
                    textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 11)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController c, IconData icon, {bool obscure = false, Widget? suffix}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFFC4B5FD), fontSize: 12)),
        const SizedBox(height: 7),
        TextField(
          controller: c,
          obscureText: obscure,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            isDense: true,
            prefixIcon: Icon(icon, color: Colors.white70, size: 18),
            suffixIcon: suffix,
            filled: true,
            fillColor: Colors.white.withOpacity(0.06),
            contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.25)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: kPurpleLight, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

// =================== DASHBOARD ===================
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kAppBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Welcome back \ud83d\udc4b', style: TextStyle(color: kSub, fontSize: 13)),
                        SizedBox(height: 2),
                        Text('Rahul Menon', style: TextStyle(color: kHeading, fontSize: 20, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  _iconBtn(Icons.notifications_none_rounded, dot: true, onTap: () {}),
                  const SizedBox(width: 10),
                  _iconBtn(Icons.logout_rounded, onTap: () {
                    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
                  }),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  _sectionHeader('STUDENT PROFILE'),
                  _profileCard(),
                  const SizedBox(height: 22),
                  _sectionHeader('YOUR BUS TODAY'),
                  _routeCard(context),
                  const SizedBox(height: 14),
                  const Center(
                    child: Text.rich(TextSpan(children: [
                      TextSpan(text: 'Not your route?  ', style: TextStyle(color: kSub, fontSize: 13)),
                      TextSpan(text: 'Choose manually', style: TextStyle(color: kPurple, fontSize: 13, fontWeight: FontWeight.w600)),
                    ])),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconBtn(IconData icon, {bool dot = false, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: kBorder),
            ),
            child: Icon(icon, color: kHeading, size: 20),
          ),
          if (dot)
            Positioned(
              right: 9,
              top: 9,
              child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: kPurple, shape: BoxShape.circle)),
            ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(t, style: const TextStyle(color: kSub, fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
      );

  Widget _profileCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [kPurpleLight, kPurpleDark]),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text('RM', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Rahul Menon', style: TextStyle(color: kHeading, fontSize: 17, fontWeight: FontWeight.bold)),
                    SizedBox(height: 3),
                    Text('Computer Science \u00b7 Year 2', style: TextStyle(color: kSub, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: kBorder),
          const SizedBox(height: 14),
          Row(children: [_detailTile('TL ID', 'TL2024CS118'), _detailTile('Roll No', 'VEC-CS-118')]),
          const SizedBox(height: 12),
          Row(children: [_detailTile('Boarding Stop', 'Punkunnam'), _detailTile('Guardian', '+91 98\u2022\u2022\u2022\u202243')]),
        ],
      ),
    );
  }

  Widget _detailTile(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: kSub, fontSize: 11)),
          const SizedBox(height: 3),
          Text(value, style: const TextStyle(color: kHeading, fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _routeCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [kPurpleLight, kPurpleDark]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: kPurpleDark.withOpacity(0.35), blurRadius: 26, offset: const Offset(0, 12))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                child: const Text('AUTO-DETECTED', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
              ),
              const Spacer(),
              Row(children: [
                Container(width: 7, height: 7, decoration: const BoxDecoration(color: kGreen, shape: BoxShape.circle)),
                const SizedBox(width: 5),
                const Text('Live now', style: TextStyle(color: Colors.white, fontSize: 12)),
              ]),
            ],
          ),
          const SizedBox(height: 14),
          const Text('Route 12', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          const Text('Thrissur Town  \u2192  Vidya Engineering College',
              style: TextStyle(color: Color(0xFFEDE9FE), fontSize: 13)),
          const SizedBox(height: 4),
          const Text('Bus KL-08 AV 4412  \u00b7  Driver: Suresh K',
              style: TextStyle(color: Color(0xFFDDD6FE), fontSize: 12)),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MapScreen())),
              icon: const Icon(Icons.directions_bus_rounded, color: kPurpleDark, size: 20),
              label: const Text('Track this Bus', style: TextStyle(color: kPurpleDark, fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }
}

// =================== LIVE MAP ===================
class RoutePath {
  final List<Offset> pts;
  late final List<double> cum;
  late final double total;
  RoutePath(this.pts) {
    cum = [0];
    double acc = 0;
    for (int i = 1; i < pts.length; i++) {
      acc += (pts[i] - pts[i - 1]).distance;
      cum.add(acc);
    }
    total = acc == 0 ? 1 : acc;
  }
  Offset at(double f) {
    f = f.clamp(0.0, 1.0);
    final d = f * total;
    for (int i = 1; i < pts.length; i++) {
      if (d <= cum[i]) {
        final seg = cum[i] - cum[i - 1];
        final t = seg == 0 ? 0.0 : (d - cum[i - 1]) / seg;
        return Offset.lerp(pts[i - 1], pts[i], t)!;
      }
    }
    return pts.last;
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  final route = RoutePath(const [
    Offset(70, 720), Offset(70, 472), Offset(102, 470), Offset(228, 470),
    Offset(230, 300), Offset(232, 270), Offset(300, 270), Offset(300, 150),
  ]);
  static const double stopT = 0.55; // Punkunnam position along the route
  static const List<double> stopFracs = [0.0, 0.30, 0.55, 0.80, 1.0];

  late final AnimationController _bus;
  late final AnimationController _pulse;
  Timer? _tele;
  Timer? _buzz;

  int chosenDist = 500;
  bool armed = false;
  bool alarmActive = false;
  int eta = 8, speed = 32, lastSig = 3;
  final _rnd = math.Random();

  @override
  void initState() {
    super.initState();
    _bus = AnimationController(vsync: this, duration: const Duration(seconds: 22))
      ..addListener(_onBus)
      ..repeat();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();
    _tele = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final t = _bus.value;
      setState(() {
        eta = t < stopT ? math.max(0, ((stopT - t) * 18).ceil()) : math.max(0, ((1 - t + stopT) * 18).ceil());
        speed = 28 + _rnd.nextInt(12);
        lastSig = 1 + _rnd.nextInt(4);
      });
    });
  }

  void _onBus() {
    final t = _bus.value;
    final metersToStop = math.max(0.0, (stopT - t)) * 6000;
    if (armed && !alarmActive && t <= stopT && metersToStop <= chosenDist) {
      _fireAlarm();
    }
  }

  void _fireAlarm() {
    setState(() => alarmActive = true);
    _bus.stop();
    HapticFeedback.heavyImpact();
    SystemSound.play(SystemSoundType.alert);
    _buzz = Timer.periodic(const Duration(milliseconds: 600), (_) {
      HapticFeedback.heavyImpact();
      SystemSound.play(SystemSoundType.alert);
    });
  }

  void _stopAlarm() {
    _buzz?.cancel();
    setState(() {
      alarmActive = false;
      armed = false;
    });
    _bus.value = 0;
    _bus.repeat();
  }

  String distText(int d) => d == 0 ? 'the stop' : (d >= 1000 ? '1 km' : '$d m');

  @override
  void dispose() {
    _tele?.cancel();
    _buzz?.cancel();
    _bus.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: const Color(0xFFE8EDF3),
      body: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: Listenable.merge([_bus, _pulse]),
              builder: (_, __) => CustomPaint(
                painter: MapPainter(route: route, t: _bus.value, pulse: _pulse.value, stopFracs: stopFracs),
              ),
            ),
          ),
          _topBar(topPad),
          Positioned(left: 16, bottom: 322, child: _liveChip()),
          Positioned(right: 16, bottom: 322, child: _recenter()),
          Align(alignment: Alignment.bottomCenter, child: _sheet()),
          if (alarmActive) Positioned.fill(child: _alarmOverlay()),
        ],
      ),
    );
  }

  Widget _topBar(double topPad) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(14, topPad + 10, 14, 20),
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.white, Color(0x00FFFFFF)]),
        ),
        child: Row(
          children: [
            _circleBtn(Icons.chevron_left, () => Navigator.pop(context)),
            const Spacer(),
            const Text('Route 12 \u00b7 Live', style: TextStyle(color: kHeading, fontWeight: FontWeight.bold, fontSize: 16)),
            const Spacer(),
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [kPurpleLight, kPurpleDark]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text('RM', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _circleBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12)],
        ),
        child: Icon(icon, color: kHeading, size: 24),
      ),
    );
  }

  Widget _liveChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.94),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorder),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 7, height: 7, decoration: const BoxDecoration(color: kGreen, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            const Text('LIVE', style: TextStyle(color: kGreen, fontSize: 11, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 4),
          Text('$speed km/h \u00b7 updated ${lastSig}s ago', style: const TextStyle(color: kSub, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _recenter() {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 16)],
      ),
      child: const Icon(Icons.my_location, color: kPurpleDark, size: 22),
    );
  }

  Widget _sheet() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        boxShadow: [BoxShadow(color: Color(0x1F000000), blurRadius: 40, offset: Offset(0, -10))],
      ),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 26),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 42,
            height: 5,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(100)),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Route 12 \u00b7 KL-08 AV 4412', style: TextStyle(color: kSub, fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text.rich(TextSpan(children: [
                      TextSpan(text: '$eta', style: const TextStyle(color: kHeading, fontSize: 34, fontWeight: FontWeight.w800, height: 1)),
                      const TextSpan(text: ' min', style: TextStyle(color: kSub, fontSize: 15, fontWeight: FontWeight.w600)),
                    ])),
                  ],
                ),
              ),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('NEXT STOP', style: TextStyle(color: kSub, fontSize: 10.5, letterSpacing: 0.5)),
                  SizedBox(height: 3),
                  Text('Punkunnam', style: TextStyle(color: kPurpleDark, fontSize: 14, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Align(alignment: Alignment.centerLeft, child: Text('Alarm me when the bus is within:', style: TextStyle(color: kSub, fontSize: 12))),
          const SizedBox(height: 10),
          Row(children: [
            _distBtn('1 km', 1000),
            const SizedBox(width: 8),
            _distBtn('500 m', 500),
            const SizedBox(width: 8),
            _distBtn('250 m', 250),
            const SizedBox(width: 8),
            _distBtn('At stop', 0),
          ]),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: _alarmBtn()),
          const SizedBox(height: 12),
          const Text('Alarm rings + vibrates even if the app is in the background',
              textAlign: TextAlign.center, style: TextStyle(color: kSub, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _distBtn(String label, int d) {
    final on = chosenDist == d;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => chosenDist = d),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? const Color(0xFFEDE9FE) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: on ? kPurple : kBorder, width: 1.5),
          ),
          child: Text(label, style: TextStyle(color: on ? kPurpleDark : kSub, fontWeight: FontWeight.w600, fontSize: 13)),
        ),
      ),
    );
  }

  Widget _alarmBtn() {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: armed ? [kGreen, const Color(0xFF059669)] : [kPurpleLight, kPurpleDark]),
        borderRadius: BorderRadius.circular(100),
        boxShadow: [BoxShadow(color: (armed ? kGreen : kPurpleDark).withOpacity(0.45), blurRadius: 24, offset: const Offset(0, 12))],
      ),
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
        ),
        onPressed: () => setState(() => armed = !armed),
        icon: Icon(armed ? Icons.check_circle : Icons.notifications_active_outlined, color: Colors.white, size: 20),
        label: Text(armed ? 'Alarm Armed  (tap to cancel)' : 'Set Proximity Alarm',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
      ),
    );
  }

  Widget _alarmOverlay() {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(center: Alignment(0, -0.2), radius: 1.1, colors: [kPurpleDark, kBg1]),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _pulse,
            builder: (_, __) {
              return Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.12 + _pulse.value * 0.1)),
                child: Transform.rotate(
                  angle: math.sin(_pulse.value * math.pi * 4) * 0.25,
                  child: const Icon(Icons.notifications_active, color: Colors.white, size: 56),
                ),
              );
            },
          ),
          const SizedBox(height: 28),
          const Text('Your bus is arriving!', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 34),
            child: Text('Route 12 is within ${distText(chosenDist)} of Punkunnam \u2014 get ready to board \ud83d\ude8c',
                textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFDDD6FE), fontSize: 15, height: 1.5)),
          ),
          const SizedBox(height: 34),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
            ),
            onPressed: _stopAlarm,
            child: const Text('Stop Alarm', style: TextStyle(color: kPurpleDark, fontWeight: FontWeight.w800, fontSize: 16)),
          ),
        ],
      ),
    );
  }
}

class MapPainter extends CustomPainter {
  final RoutePath route;
  final double t;
  final double pulse;
  final List<double> stopFracs;
  MapPainter({required this.route, required this.t, required this.pulse, required this.stopFracs});

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 390.0;
    final sy = size.height / 800.0;
    Offset p(Offset o) => Offset(o.dx * sx, o.dy * sy);

    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFE8EDF3));

    final grid = Paint()..color = const Color(0xFFDBE2EA)..strokeWidth = 1;
    for (double x = 0; x <= 390; x += 40) {
      canvas.drawLine(p(Offset(x, 0)), p(Offset(x, 800)), grid);
    }
    for (double y = 0; y <= 800; y += 40) {
      canvas.drawLine(p(Offset(0, y)), p(Offset(390, y)), grid);
    }

    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(250 * sx, 120 * sy, 120 * sx, 90 * sy), Radius.circular(12 * sx)),
      Paint()..color = const Color(0xFFD6EBD9),
    );

    final road = Paint()..color = Colors.white..strokeCap = StrokeCap.round;
    road.strokeWidth = 16 * sx;
    canvas.drawLine(p(const Offset(-20, 300)), p(const Offset(410, 300)), road);
    canvas.drawLine(p(const Offset(120, -20)), p(const Offset(120, 820)), road);
    road.strokeWidth = 11 * sx;
    canvas.drawLine(p(const Offset(-20, 480)), p(const Offset(410, 480)), road);
    canvas.drawLine(p(const Offset(280, -20)), p(const Offset(280, 820)), road);

    final rp = Path();
    final first = p(route.pts.first);
    rp.moveTo(first.dx, first.dy);
    for (final pt in route.pts.skip(1)) {
      final q = p(pt);
      rp.lineTo(q.dx, q.dy);
    }
    canvas.drawPath(
      rp,
      Paint()
        ..color = kPurple.withOpacity(0.14)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14 * sx
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(
      rp,
      Paint()
        ..color = kPurple
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6 * sx
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    for (final f in stopFracs) {
      final c = p(route.at(f));
      canvas.drawCircle(c, 5 * sx, Paint()..color = Colors.white);
      canvas.drawCircle(c, 5 * sx, Paint()..color = kPurple..style = PaintingStyle.stroke..strokeWidth = 3 * sx);
    }

    _drawHome(canvas, p(route.pts.last), sx);

    final b = p(route.at(t));
    final pr = (18 + pulse * 20) * sx;
    canvas.drawCircle(b, pr, Paint()..color = kPurple.withOpacity((1 - pulse) * 0.35));
    canvas.drawCircle(b, 18 * sx, Paint()..color = kPurple);
    canvas.drawCircle(b, 18 * sx, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 3 * sx);
    _emoji(canvas, '\ud83d\ude8c', b, 16 * sx);
  }

  void _drawHome(Canvas canvas, Offset c, double s) {
    final head = c - Offset(0, 10 * s);
    final path = Path();
    path.moveTo(c.dx - 8 * s, c.dy - 4 * s);
    path.lineTo(c.dx, c.dy + 8 * s);
    path.lineTo(c.dx + 8 * s, c.dy - 4 * s);
    path.close();
    canvas.drawPath(path, Paint()..color = kPurpleDark);
    canvas.drawCircle(head, 12 * s, Paint()..color = kPurpleDark);
    canvas.drawCircle(head, 7 * s, Paint()..color = Colors.white);
    _emoji(canvas, '\ud83c\udfe0', head, 9 * s);
  }

  void _emoji(Canvas canvas, String e, Offset center, double fontSize) {
    final tp = TextPainter(
      text: TextSpan(text: e, style: TextStyle(fontSize: fontSize)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant MapPainter old) => old.t != t || old.pulse != pulse;
}
