import 'package:firebase_database/firebase_database.dart';
import '../config.dart';
import '../models/bus_location.dart';
import '../models/proximity_alert.dart';

/// Thin wrapper around Firebase Realtime Database for the paths this app uses:
///   /liveLocations/{busId}          (driver writes, map reads)
///   /proximityAlerts/{busId}/{userId} (student writes, Worker reads)
class RtdbService {
  RtdbService._();
  static final RtdbService instance = RtdbService._();

  FirebaseDatabase get _db => FirebaseDatabase.instance;
  DatabaseReference _busRef(String busId) => _db.ref('liveLocations/$busId');

  /// Overwrite the bus's latest position (called by the background service).
  Future<void> writeLocation(String busId, BusLocation loc) async {
    if (!gFirebaseReady) return;
    await _busRef(busId).set(loc.toMap());
  }

  /// Live stream of a bus's position for the map screen.
  Stream<BusLocation?> watchBus(String busId) {
    if (!gFirebaseReady) return const Stream.empty();
    return _busRef(busId).onValue.map((event) {
      final v = event.snapshot.value;
      if (v is Map) return BusLocation.fromMap(v);
      return null;
    });
  }

  /// One-time fetch used as an initial value before the stream warms up.
  Future<BusLocation?> fetchBus(String busId) async {
    if (!gFirebaseReady) return null;
    final snap = await _busRef(busId).get();
    final v = snap.value;
    if (v is Map) return BusLocation.fromMap(v);
    return null;
  }

  Future<void> setProximityAlert(ProximityAlert a) async {
    if (!gFirebaseReady) return;
    await _db.ref('proximityAlerts/${a.busId}/${a.userId}').update(a.toMap());
  }

  Future<void> disableProximityAlert(String busId, String userId) async {
    if (!gFirebaseReady) return;
    await _db.ref('proximityAlerts/$busId/$userId/enabled').set(false);
  }
}
