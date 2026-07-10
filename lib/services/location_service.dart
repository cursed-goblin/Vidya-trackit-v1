import 'dart:async';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

const String kTrackingChannelId = 'bustrack_tracking';
const int kTrackingNotificationId = 8412;

/// Register (but do NOT start) the Android/iOS background service. Called once
/// from main(). The service only actually runs between Start Trip and End Trip.
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

/// Entry point for the background isolate. Streams GPS and writes the latest
/// position to /liveLocations/{busId} on a ~7s throttle.
@pragma('vm:entry-point')
void onServiceStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (_) {}
  final db = FirebaseDatabase.instance;

  String busId = 'bus_12';
  final startedAt = DateTime.now();
  DateTime lastWrite = DateTime.fromMillisecondsSinceEpoch(0);
  final List<Map<String, dynamic>> queue = [];

  service.on('setBus').listen((event) {
    final b = event?['busId'];
    if (b is String && b.isNotEmpty) busId = b;
  });
  service.on('stopService').listen((event) => service.stopSelf());

  const settings = LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 15,
  );

  StreamSubscription<Position>? sub;
  sub = Geolocator.getPositionStream(locationSettings: settings).listen(
    (pos) async {
      // Safety auto-stop after 12h if a driver forgets to end the trip.
      if (DateTime.now().difference(startedAt).inHours >= 12) {
        await sub?.cancel();
        service.stopSelf();
        return;
      }

      // Time throttle: write to Firebase ~every 7s, not on every GPS tick.
      final now = DateTime.now();
      if (now.difference(lastWrite).inSeconds < 7) return;
      lastWrite = now;

      final payload = <String, dynamic>{
        'lat': pos.latitude,
        'lng': pos.longitude,
        'speed': (pos.speed * 3.6).clamp(0, 200).toDouble(), // m/s -> km/h
        'heading': pos.heading < 0 ? 0.0 : pos.heading,
        'timestamp': now.millisecondsSinceEpoch,
      };

      // Queue + flush: keep the last few readings and retry on the next tick
      // if a write fails (network drop), rather than dropping them silently.
      queue.add(payload);
      if (queue.length > 20) queue.removeAt(0);
      try {
        final latest = queue.last;
        await db.ref('liveLocations/$busId').set(latest);
        queue.clear();
      } catch (_) {
        // stays queued; retried next tick
      }

      // Push status to the Driver Home status card.
      service.invoke('update', payload);

      if (service is AndroidServiceInstance) {
        final hh = now.hour.toString().padLeft(2, '0');
        final mm = now.minute.toString().padLeft(2, '0');
        service.setForegroundNotificationInfo(
          title: 'Vidya TrackIt - sharing live location',
          content: 'Bus $busId - last update $hh:$mm',
        );
      }
    },
  );
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

    // Android 10+: background location is a separate request that only makes
    // sense after fine location is granted. On iOS this maps to the "Always"
    // prompt, requested here (on Start Trip) not at app launch.
    await Permission.locationAlways.request();
    await Permission.notification.request();
    if (!await Permission.ignoreBatteryOptimizations.isGranted) {
      await Permission.ignoreBatteryOptimizations.request();
    }

    await _service.startService();
    await Future.delayed(const Duration(milliseconds: 400));
    _service.invoke('setBus', {'busId': busId});
    return null;
  }

  Future<void> endTrip() async {
    if (await _service.isRunning()) {
      _service.invoke('stopService');
    }
  }
}
