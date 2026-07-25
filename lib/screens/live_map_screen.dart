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
import '../services/bus_service.dart';
import '../theme.dart';

/// Rider live map: OpenStreetMap tiles + a smoothly-animated live bus marker
/// fed from Supabase Realtime on `bus_locations`, the rider's stop pin, a route
/// line, and a bottom sheet with ETA + proximity-alert controls.
class LiveMapScreen extends StatefulWidget {
  final String busId;
  const LiveMapScreen({super.key, required this.busId});
  @override
  State<LiveMapScreen> createState() => _LiveMapScreenState();
}

class _LiveMapScreenState extends State<LiveMapScreen>
    with TickerProviderStateMixin {
  late final AnimatedMapController _map = AnimatedMapController(
      vsync: this, duration: const Duration(milliseconds: 700));

  // Smooth marker interpolation between the last two known positions.
  late final AnimationController _move = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1400));
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
  bool _saving = false;
  String? _error;

  final Distance _distance = const Distance();

  LatLng get _home {
    final s = AuthService.instance.student;
    return LatLng(
        s?.homeLat ?? kFallbackHomeLat, s?.homeLng ?? kFallbackHomeLng);
  }

  LatLng? get _busPos {
    if (_from == null || _to == null) return null;
    return _lerp(_from!, _to!, Curves.easeInOut.transform(_move.value));
  }

  @override
  void initState() {
    super.initState();
    _move.addListener(() => setState(() {}));
    // Re-evaluate "signal lost" periodically even without new data.
    _staleTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) setState(() {});
    });

    // Seed with a one-time fetch, then subscribe to live updates.
    BusService.instance.fetchBus(widget.busId).then(_onBus).catchError((e) {
      if (mounted) setState(() => _error = '$e');
    });
    _busSub = BusService.instance.watchBus(widget.busId).listen(
      _onBus,
      onError: (Object e) {
        if (mounted) setState(() => _error = 'Live updates paused: $e');
      },
    );

    // Reflect any alert the rider already has, so the button does not claim
    // "not set" for a subscription that is actually active.
    BusService.instance.loadMyAlert().then((a) {
      if (a == null || !mounted) return;
      setState(() {
        _thresholdMeters = a.thresholdMeters;
        _alertSet = a.enabled;
      });
    }).catchError((_) {});
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
    if (gFcmToken == null) {
      setState(() => _error =
          'Allow notifications for this app so the alarm can reach you.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await BusService.instance.setProximityAlert(ProximityAlert(
        busId: widget.busId,
        stopId: s?.stopId,
        targetLat: _home.latitude,
        targetLng: _home.longitude,
        thresholdMeters: _thresholdMeters,
        leadStops: s?.leadStops ?? 2,
        enabled: true,
        fcmToken: gFcmToken,
        timezone: 'Asia/Kolkata',
      ));
      if (!mounted) return;
      setState(() {
        _alertSet = true;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: kGreen,
          content: Text('Alarm set - you will be woken when the bus is '
              '${s?.leadStops ?? 2} stops away or within '
              '${_label(_thresholdMeters)}.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not save the alarm: $e';
      });
    }
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

  String _label(int m) => m >= 1000
      ? '${(m / 1000).toStringAsFixed(m % 1000 == 0 ? 0 : 1)} km'
      : '$m m';

  @override
  Widget build(BuildContext context) {
    final bus = _busPos;
    final stale = _bus?.isStale ?? true;
    final distanceM =
        bus == null ? null : _distance.as(LengthUnit.Meter, bus, _home);
    final speed = _bus?.speed ?? 0;
    // The old ETA hid itself whenever speed <= 5 km/h, so it went blank in
    // exactly the traffic where riders need it. Fall back to a 18 km/h city
    // average instead of showing nothing.
    final effectiveSpeed = speed > 8 ? speed : 18.0;
    final etaMin = (distanceM == null || stale)
        ? null
        : math.max(1, ((distanceM / 1000) / effectiveSpeed * 60).ceil());

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

          // Signal-lost / error banner
          if (stale || _error != null)
            Positioned(
              top: 96,
              left: 16,
              right: 16,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: _error != null ? kRed : kAmber,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 10)
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.wifi_off_rounded,
                          color: Colors.white, size: 16),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                            _error ??
                                (gSupabaseReady
                                    ? 'Signal lost - waiting for the bus'
                                    : 'Demo mode - backend not configured'),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600)),
                      ),
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
            busNumber: AuthService.instance.student?.busNumber ?? '--',
            routeName: AuthService.instance.student?.routeName ?? '--',
            nextStop: AuthService.instance.student?.boardingStop ?? '--',
            etaMin: etaMin,
            distanceLabel: distanceM == null ? '--' : _label(distanceM.round()),
            threshold: _thresholdMeters,
            alertSet: _alertSet,
            saving: _saving,
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
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.location_on, color: kPurpleDark, size: 42),
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
          Text('Updated $ago', style: TextStyle(color: kSub, fontSize: 11)),
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
  final bool saving;
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
    required this.saving,
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
                      color: kBorder, borderRadius: BorderRadius.circular(3)),
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
                        Text('Your stop: $nextStop',
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
              const Text('Arrival alarm',
                  style: TextStyle(
                      color: kHeading,
                      fontSize: 15,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('The alarm rings when the bus is a few stops away, or '
                  'within the distance you pick here:',
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
                  onPressed: saving ? null : onSetAlert,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: alertSet ? kGreen : kPurple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: Icon(alertSet
                      ? Icons.check_circle_rounded
                      : Icons.notifications_active_rounded),
                  label: Text(
                      saving
                          ? 'Saving...'
                          : (alertSet ? 'Alarm is set' : 'Set arrival alarm'),
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
