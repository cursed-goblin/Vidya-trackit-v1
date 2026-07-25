import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import 'bus_service.dart';

const String kTrackingChannelId = 'bustrack_tracking';
const int kTrackingNotificationId = 8412;

// Write cadence. A position is sent when it is at least [kMinWriteGap] old AND
// the bus moved [kMinMoveMetres], or when [kMaxWriteGap] has passed (heartbeat
// so riders can still see "bus is parked" rather than "signal lost").
const Duration kMinWriteGap = Duration(seconds: 7);
const Duration kMaxWriteGap = Duration(seconds: 45);
const double kMinMoveMetres = 20;
const Duration kMaxTripLength = Duration(hours: 12);

/// Register (but do NOT start) the background service. Called once from main().
Future<void> initLocationService() async {
  final service = FlutterBackgroundService();
  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onServiceStart,
      autoStart: false,
      isForegroundMode: true,
      notificationChannelId: kTrackingChannelId,
      initialNotificationTitle: 'Vidya TrackIt',
      initialNotificationContent: 'Preparing to share live location...',
      foregroundServiceNotificationId: kTrackingNotificationId,
      foregroundServiceTypes: [AndroidForegroundType.location],
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onServiceStart,
      onBackground: onIosBackground,
    ),
  );
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async => true;

/// Entry point for the background isolate.
///
/// It talks to Supabase over plain HTTPS (PostgREST RPC) instead of
/// initialising a full client in the isolate, and reads the bus id + access
/// token from SharedPreferences, which the UI writes BEFORE starting the
/// service. That removes the old 400 ms race where the isolate could keep a
/// hard-coded bus id.
@pragma('vm:entry-point')
void onServiceStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  String busId = prefs.getString(kPrefBusId) ?? kDemoBusId;

  final rpcUri = Uri.parse('$kSupabaseUrl/rest/v1/rpc/record_location');
  final queue = <Map<String, dynamic>>[];
  DateTime lastWrite = DateTime.fromMillisecondsSinceEpoch(0);
  Position? lastSent;
  StreamSubscription<Position>? sub;
  Timer? cutoff;
  String lastError = '';

  Future<void> stop() async {
    cutoff?.cancel();
    await sub?.cancel();
    service.stopSelf();
  }

  // Hard cutoff owned by a timer, not by the GPS callback: if the GPS stream
  // stalls, the old code never stopped the service at all.
  cutoff = Timer(kMaxTripLength, stop);

  service.on('setBus').listen((event) async {
    final b = event?['busId'];
    if (b is String && b.isNotEmpty) {
      busId = b;
      await prefs.setString(kPrefBusId, b);
    }
  });
  service.on('stopService').listen((_) => stop());

  // Flush oldest-first and keep anything that failed, so a network drop no
  // longer silently loses the trail (the old queue only ever wrote the newest
  // point and cleared everything).
  Future<void> flush() async {
    final token = prefs.getString(kPrefAccessToken) ?? '';
    if (kSupabaseUrl.isEmpty || kSupabaseAnonKey.isEmpty || token.isEmpty) {
      lastError = 'not signed in';
      return;
    }
    while (queue.isNotEmpty) {
      final p = queue.first;
      try {
        final res = await http.post(
          rpcUri,
          headers: {
            'apikey': kSupabaseAnonKey,
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'p_bus': busId,
            'p_lat': p['lat'],
            'p_lng': p['lng'],
            'p_speed': p['speed'],
            'p_heading': p['heading'],
            'p_recorded_at': p['recorded_at'],
          }),
        ).timeout(const Duration(seconds: 12));
        if (res.statusCode >= 200 && res.statusCode < 300) {
          queue.removeAt(0);
          lastError = '';
        } else {
          // 401/403 means the token expired or this driver is not assigned to
          // the bus - surface it instead of failing silently forever.
          lastError = 'server ${res.statusCode}';
          return;
        }
      } catch (e) {
        lastError = 'offline';
        return;
      }
    }
  }

  void startStream() {
    sub?.cancel();
    sub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen(
      (pos) async {
        final now = DateTime.now();
        final moved = lastSent == null
            ? double.infinity
            : Geolocator.distanceBetween(lastSent!.latitude,
                lastSent!.longitude, pos.latitude, pos.longitude);
        final gap = now.difference(lastWrite);
        final due = gap >= kMaxWriteGap ||
            (gap >= kMinWriteGap && moved >= kMinMoveMetres);
        if (!due) return;

        lastWrite = now;
        lastSent = pos;

        // Heading is noise below walking speed - freeze it so the marker does
        // not spin while the bus is stopped.
        final kmph = (pos.speed * 3.6).clamp(0, 200).toDouble();
        final payload = <String, dynamic>{
          'lat': pos.latitude,
          'lng': pos.longitude,
          'speed': kmph,
          'heading': kmph < 5 || pos.heading < 0 ? 0.0 : pos.heading,
          'recorded_at': now.toUtc().toIso8601String(),
          'timestamp': now.millisecondsSinceEpoch,
        };

        queue.add(payload);
        if (queue.length > 60) queue.removeAt(0);
        await flush();

        service.invoke('update', {
          ...payload,
          'pending': queue.length,
          'error': lastError,
        });

        if (service is AndroidServiceInstance) {
          final hh = now.hour.toString().padLeft(2, '0');
          final mm = now.minute.toString().padLeft(2, '0');
          service.setForegroundNotificationInfo(
            title: lastError.isEmpty
                ? 'Vidya TrackIt - sharing live location'
                : 'Vidya TrackIt - retrying ($lastError)',
            content: 'Bus $busId - last update $hh:$mm',
          );
        }
      },
      // The old stream had no error handler: losing permission or turning GPS
      // off killed it silently while the notification claimed all was well.
      onError: (Object e) {
        lastError = 'gps: $e';
        service.invoke('update', {'error': lastError});
        if (service is AndroidServiceInstance) {
          service.setForegroundNotificationInfo(
            title: 'Vidya TrackIt - location unavailable',
            content: 'Check that GPS and permissions are on',
          );
        }
        Timer(const Duration(seconds: 10), startStream);
      },
      cancelOnError: true,
    );
  }

  startStream();
}

/// Controls trip lifecycle from the Driver Home UI.
class TripController {
  TripController._();
  static final TripController instance = TripController._();

  final FlutterBackgroundService _service = FlutterBackgroundService();

  Future<bool> isRunning() => _service.isRunning();
  Stream<Map<String, dynamic>?> updates() => _service.on('update');

  /// Returns null on success, or a user-facing error string.
  Future<String?> startTrip(String busId) async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return 'Please turn on location services to start a trip.';
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      return 'Location permission is required to share the bus location.';
    }

    // Android 10+ / iOS "Always": only meaningful after fine location, and
    // requested here (on Start Trip) rather than at app launch.
    await Permission.locationAlways.request();
    await Permission.notification.request();
    if (!await Permission.ignoreBatteryOptimizations.isGranted) {
      await Permission.ignoreBatteryOptimizations.request();
    }

    // Open the trip server-side first: this also verifies that the signed-in
    // driver really is assigned to this bus, so a failure is reported before
    // the notification starts claiming we are broadcasting.
    try {
      await BusService.instance.startTrip(busId);
    } catch (e) {
      return 'Could not start the trip: $e';
    }

    // Hand the isolate everything it needs BEFORE it starts (no more race).
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kPrefBusId, busId);

    await _service.startService();
    _service.invoke('setBus', {'busId': busId});
    return null;
  }

  Future<void> endTrip(String busId) async {
    if (await _service.isRunning()) {
      _service.invoke('stopService');
    }
    try {
      await BusService.instance.endTrip(busId);
    } catch (_) {
      // The trip is closed server-side by the next start_trip() anyway.
    }
  }
}
