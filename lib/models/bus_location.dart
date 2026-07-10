/// The latest known position of a bus. Mirrors the Firebase Realtime Database
/// node at /liveLocations/{busId} = { lat, lng, speed, heading, timestamp }.
class BusLocation {
  final double lat;
  final double lng;
  final double speed; // km/h
  final double heading; // degrees, 0 = north
  final DateTime updatedAt;

  const BusLocation({
    required this.lat,
    required this.lng,
    required this.speed,
    required this.heading,
    required this.updatedAt,
  });

  factory BusLocation.fromMap(Map<dynamic, dynamic> m) {
    double d(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
    final tsRaw = m['timestamp'];
    final ms = tsRaw is num ? tsRaw.toInt() : int.tryParse('$tsRaw') ?? 0;
    return BusLocation(
      lat: d(m['lat']),
      lng: d(m['lng']),
      speed: d(m['speed']),
      heading: d(m['heading']),
      updatedAt: ms > 0
          ? DateTime.fromMillisecondsSinceEpoch(ms)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'lat': lat,
        'lng': lng,
        'speed': speed,
        'heading': heading,
        'timestamp': updatedAt.millisecondsSinceEpoch,
      };

  /// True when we haven't heard from the bus recently -> show "signal lost".
  bool get isStale => DateTime.now().difference(updatedAt).inSeconds > 30;

  Duration get age => DateTime.now().difference(updatedAt);
}
