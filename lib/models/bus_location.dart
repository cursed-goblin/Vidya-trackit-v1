/// The latest known position of a bus.
///
/// Supabase: one row in `public.bus_locations`
///   { bus_id, trip_id, lat, lng, speed_kmph, heading, recorded_at }
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

  static double _d(dynamic v) =>
      v is num ? v.toDouble() : double.tryParse('$v') ?? 0;

  factory BusLocation.fromJson(Map<String, dynamic> m) {
    // A missing timestamp must read as OLD, not as now(): treating it as now
    // used to hide the "signal lost" banner for records that were stale.
    final ts = DateTime.tryParse('${m['recorded_at']}')?.toLocal() ??
        DateTime.fromMillisecondsSinceEpoch(0);
    return BusLocation(
      lat: _d(m['lat']),
      lng: _d(m['lng']),
      speed: _d(m['speed_kmph']),
      heading: _d(m['heading']),
      updatedAt: ts,
    );
  }

  Map<String, dynamic> toJson() => {
        'lat': lat,
        'lng': lng,
        'speed_kmph': speed,
        'heading': heading,
        'recorded_at': updatedAt.toUtc().toIso8601String(),
      };

  /// True when we haven't heard from the bus recently -> show "signal lost".
  bool get isStale => DateTime.now().difference(updatedAt).inSeconds > 30;

  Duration get age => DateTime.now().difference(updatedAt);
}
