import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_animations/flutter_map_animations.dart';
import 'package:latlong2/latlong.dart';

import '../config.dart';
import '../models/bus_location.dart';
import '../models/proximity_alert.dart';
import '../services/auth_service.dart';
import '../services/rtdb_service.dart';
import '../theme.dart';

/// Passenger live map: OpenStreetMap tiles + a smoothly-animated live bus
/// marker fed from /liveLocations/{busId}, the user's home pin, a route line,
/// and a draggable bottom sheet with ETA + proximity-alert controls.
class LiveMapScreen extends StatefulWidget {
  final String busId;
  const LiveMapScreen({super.key, required this.busId});
  @override
  State<LiveMapScreen> createState() => _LiveMapScreenState();
}

class _LiveMapScreenState extends State<LiveMapScreen>
    with TickerProviderStateMixin {
  late final AnimatedMapController _map =
      AnimatedMapController(vsync: this, duration: const Duration(milliseconds: 700));

  // Smooth marker interpolation between the last two known positions.
  late final AnimationController _move =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
  LatLng? _from;
  LatLng? _to;
  double _bearing = 0;

  // Pulsing ring around the bus marker.
  late final AnimationController _pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1600))
    ..repeat();

  StreamSubscription<BusLocation?>? _busSub;
  BusLocation? _bus;
  Timer? _staleTimer;

  int _thresholdMeters = 500;
  bool _alertSet = false;

  final Distance _distance = const Distance();

  LatLng get _home {
    final s = AuthService.instance.student;
    return LatLng(s?.homeLat ?? kFallbackHomeLat, s?.homeLng ?? kFallbackHomeLng);
  }

  LatLng? get _busPos {
    if (_from == null || _to == null) return null;
    return _lerp(_from!, _to!, Curves.easeInOut.transform(_move.value));
  }

  @override
  void initState() {
    super.initState();
    _move.addListener(() => setState(() {}));
    // Re-evaluate "signal lost" every few seconds even without new data.
    _staleTimer = Timer.periodic(
        const Duration(seconds: 3), (_) => mounted ? setState(() {}) : null);

    // Seed with a one-time fetch, then subscribe to live updates.
    RtdbService.instance.fetchBus(widget.busId).then(_onBus);
    _busSub = RtdbService.instance.watchBus(widget.busId).listen(_onBus);
  }

  void _onBus(BusLocation? b) {
    if (b == null || !mounted) return;
    final next = LatLng(b.lat, b.lng);
    final prev = _to ?? next;
    if (prev != next) {
      _bearing = _distance.bearing(prev, next) * math.pi / 180.0;
    }
    setState(() {
      _from = prev;
      _to = next;
      _bus = b;
    });
    _move
      ..reset()
      ..forward();
  }

  void _recenter() {
    final bus = _busPos;
    if (bus == null) {
      _map.animateTo(dest: _home, zoom: 15);
      return;
    }
    _map.animatedFitCamera(
      cameraFit: CameraFit.bounds(
        bounds: LatLngBounds.fromPoints([bus, _home]),
        padding: const EdgeInsets.all(80),
      ),
    );
  }

  Future<void> _setAlert() async {
    final s = AuthService.instance.student;
    final alert = ProximityAlert(
      busId: widget.busId,
      userId: s?.id ?? 'demo_user',
      homeLat: _home.latitude,
      homeLng: _home.longitude,
      thresholdMeters: _thresholdMeters,
      enabled: true,
      fcmToken: gFcmToken ?? '',
      timezone: 'Asia/Kolkata',
    );
    await RtdbService.instance.setProximityAlert(alert);
    if (!mounted) return;
    setState(() => _alertSet = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: kGreen,
        content: Text(
            'Alert set - you will be notified when the bus is within ${_label(_thresholdMeters)}.'),
      ),
    );
  }

  @override
  void dispose() {
    _busSub?.cancel(); // stop listening when leaving the screen
    _staleTimer?.cancel();
    _move.dispose();
    _pulse.dispose();
    _map.dispose();
    super.dispose();
  }

  LatLng _lerp(LatLng a, LatLng b, double t) => LatLng(
        a.latitude + (b.latitude - a.latitude) * t,
        a.longitude + (b.longitude - a.longitude) * t,
      );

  String _label(int m) => m >= 1000 ? '${(m / 1000).toStringAsFixed(m % 1000 == 0 ? 0 : 1)} km' : '$m m';

  @override
  Widget build(BuildContext context) {
    final bus = _busPos;
    final stale = _bus?.isStale ?? true;
    final distanceM =
        bus == null ? null : _distance.as(LengthUnit.Meter, bus, _home);
    final speed = _bus?.speed ?? 0;
    final etaMin = (distanceM != null && speed > 5)
        ? ((distanceM / 1000) / speed * 60).ceil()
        : null;

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _map.mapController,
            options: MapOptions(
              initialCenter: _home,
              initialZoom: 14.5,
              interactionOptions:
                  const InteractionOptions(flags: InteractiveFlag.all),
            ),
            children: [
              TileLayer(
                urlTemplate: osmTileUrl(),
                userAgentPackageName: kAppPackageId,
                maxZoom: 19,
              ),
              if (bus != null)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: [bus, _home],
                      color: kPurple.withOpacity(0.7),
                      strokeWidth: 4,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _home,
                    width: 46,
                    height: 46,
                    alignment: Alignment.topCenter,
                    child: const _HomePin(),
                  ),
                  if (bus != null)
                    Marker(
                      point: bus,
                      width: 90,
                      height: 90,
                      child: _BusMarker(
                          pulse: _pulse, bearing: _bearing, stale: stale),
                    ),
                ],
              ),
              RichAttributionWidget(
                attributions: [
                  TextSourceAttribution('OpenStreetMap contributors'),
                ],
              ),
            ],
          ),

          // Top app bar
          _TopBar(onBack: () => Navigator.of(context).pop()),

          // Signal-lost banner
          if (stale)
            Positioned(
              top: 96,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: kAmber,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 10)
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.wifi_off_rounded,
                          color: Colors.white, size: 16),
                      SizedBox(width: 6),
                      Text('Signal lost - waiting for the bus',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ),

          // Speed / last-updated badge (bottom-left)
          Positioned(
            left: 16,
            bottom: 190,
            child: _SpeedBadge(
              speed: speed,
              updatedAgo: _bus == null ? null : _bus!.age,
            ),
          ),

          // Recenter (bottom-right)
          Positioned(
            right: 16,
            bottom: 190,
            child: FloatingActionButton(
              heroTag: 'recenter',
              backgroundColor: Colors.white,
              foregroundColor: kPurple,
              onPressed: _recenter,
              child: const Icon(Icons.center_focus_strong_rounded),
            ),
          ),

          // Draggable bottom sheet
          _BottomSheet(
            busNumber: AuthService.instance.student?.busNumber ?? 'KL-08 AV 4412',
            routeName: AuthService.instance.student?.routeName ?? 'Route 12',
            nextStop: AuthService.instance.student?.boardingStop ?? 'Punkunnam',
            etaMin: etaMin,
            distanceLabel: distanceM == null ? '--' : _label(distanceM.round()),
            threshold: _thresholdMeters,
            alertSet: _alertSet,
            onThreshold: (m) => setState(() {
              _thresholdMeters = m;
              _alertSet = false;
            }),
            onSetAlert: _setAlert,
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final VoidCallback onBack;
  const _TopBar({required this.onBack});
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: Row(
          children: [
            _circle(Icons.arrow_back_rounded, onBack),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.08), blurRadius: 10)
                  ],
                ),
                child: const Text('Live Bus Location',
                    style: TextStyle(
                        color: kHeading, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(width: 10),
            _circle(Icons.notifications_none_rounded, () {}),
            const SizedBox(width: 10),
            const CircleAvatar(
                radius: 23,
                backgroundColor: kPurple,
                child: Icon(Icons.person, color: Colors.white)),
          ],
        ),
      ),
    );
  }

  Widget _circle(IconData icon, VoidCallback onTap) => Material(
        color: Colors.white,
        shape: const CircleBorder(),
        elevation: 2,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(11),
            child: Icon(icon, color: kHeading, size: 22),
          ),
        ),
      );
}

class _HomePin extends StatelessWidget {
  const _HomePin();
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.location_on, color: kPurpleDark, size: 42),
      ],
    );
  }
}

class _BusMarker extends StatelessWidget {
  final Animation<double> pulse;
  final double bearing;
  final bool stale;
  const _BusMarker(
      {required this.pulse, required this.bearing, required this.stale});
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (context, _) {
        final t = pulse.value;
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 40 + t * 46,
              height: 40 + t * 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (stale ? kSub : kPurple).withOpacity(0.28 * (1 - t)),
              ),
            ),
            Transform.rotate(
              angle: bearing,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: stale ? kSub : kPurple,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.3), blurRadius: 8)
                  ],
                ),
                child: const Icon(Icons.navigation_rounded,
                    color: Colors.white, size: 22),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SpeedBadge extends StatelessWidget {
  final double speed;
  final Duration? updatedAgo;
  const _SpeedBadge({required this.speed, required this.updatedAgo});
  @override
  Widget build(BuildContext context) {
    String ago;
    if (updatedAgo == null) {
      ago = 'no data';
    } else if (updatedAgo!.inSeconds < 5) {
      ago = 'just now';
    } else if (updatedAgo!.inSeconds < 60) {
      ago = '${updatedAgo!.inSeconds}s ago';
    } else {
      ago = '${updatedAgo!.inMinutes}m ago';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${speed.toStringAsFixed(0)} km/h',
              style: const TextStyle(
                  color: kHeading, fontSize: 16, fontWeight: FontWeight.w800)),
          Text('Updated $ago',
              style: TextStyle(color: kSub, fontSize: 11)),
        ],
      ),
    );
  }
}

class _BottomSheet extends StatelessWidget {
  final String busNumber;
  final String routeName;
  final String nextStop;
  final int? etaMin;
  final String distanceLabel;
  final int threshold;
  final bool alertSet;
  final ValueChanged<int> onThreshold;
  final VoidCallback onSetAlert;
  const _BottomSheet({
    required this.busNumber,
    required this.routeName,
    required this.nextStop,
    required this.etaMin,
    required this.distanceLabel,
    required this.threshold,
    required this.alertSet,
    required this.onThreshold,
    required this.onSetAlert,
  });

  @override
  Widget build(BuildContext context) {
    final options = <(String, int)>[
      ('1 km', 1000),
      ('500 m', 500),
      ('250 m', 250),
      ('At stop', 100),
    ];
    return DraggableScrollableSheet(
      initialChildSize: 0.24,
      minChildSize: 0.14,
      maxChildSize: 0.62,
      builder: (context, controller) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 20)],
          ),
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                      color: kBorder,
                      borderRadius: BorderRadius.circular(3)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$routeName - $busNumber',
                            style: TextStyle(color: kSub, fontSize: 13)),
                        const SizedBox(height: 4),
                        Text('Next stop: $nextStop',
                            style: const TextStyle(
                                color: kHeading,
                                fontSize: 16,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(etaMin == null ? '--' : '$etaMin',
                          style: const TextStyle(
                              color: kPurple,
                              fontSize: 34,
                              fontWeight: FontWeight.w800,
                              height: 1)),
                      Text(etaMin == null ? 'ETA' : 'min away',
                          style: TextStyle(color: kSub, fontSize: 12)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text('Current distance: $distanceLabel',
                  style: TextStyle(color: kSub, fontSize: 12.5)),
              const Divider(height: 30),
              const Text('Set Proximity Alert',
                  style: TextStyle(
                      color: kHeading,
                      fontSize: 15,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('Get an alarm when the bus is within:',
                  style: TextStyle(color: kSub, fontSize: 12.5)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: options.map((o) {
                  final sel = o.$2 == threshold;
                  return GestureDetector(
                    onTap: () => onThreshold(o.$2),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 10),
                      decoration: BoxDecoration(
                        color: sel ? kPurple : kPurple.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(o.$1,
                          style: TextStyle(
                              color: sel ? Colors.white : kPurpleDark,
                              fontWeight: FontWeight.w700)),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: onSetAlert,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: alertSet ? kGreen : kPurple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: Icon(alertSet
                      ? Icons.check_circle_rounded
                      : Icons.notifications_active_rounded),
                  label: Text(alertSet ? 'Alert is set' : 'Set Proximity Alert',
                      style: const TextStyle(
                          fontSize: 15.5, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
