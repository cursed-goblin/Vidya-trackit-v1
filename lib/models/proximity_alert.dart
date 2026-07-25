/// A rider's alert subscription - one row in `public.alert_subscriptions`,
/// readable and writable only by that rider (RLS) or an admin.
///
/// The server fires when the bus is either within [thresholdMeters] of the
/// target stop, or within [leadStops] stops of it (the "alarm me two stops
/// early" rule), with a 30-minute cooldown so the return trip alerts too.
class ProximityAlert {
  final String busId;
  final String? stopId;
  final double targetLat;
  final double targetLng;
  final int thresholdMeters;
  final int leadStops;
  final bool enabled;
  final String? fcmToken;
  final String timezone;
  final DateTime? lastFiredAt;

  const ProximityAlert({
    required this.busId,
    required this.targetLat,
    required this.targetLng,
    this.stopId,
    this.thresholdMeters = 500,
    this.leadStops = 2,
    this.enabled = true,
    this.fcmToken,
    this.timezone = 'Asia/Kolkata',
    this.lastFiredAt,
  });

  factory ProximityAlert.fromJson(Map<String, dynamic> m) => ProximityAlert(
        busId: '${m['bus_id']}',
        stopId: m['stop_id'] as String?,
        targetLat: (m['target_lat'] as num).toDouble(),
        targetLng: (m['target_lng'] as num).toDouble(),
        thresholdMeters: (m['threshold_m'] as num?)?.toInt() ?? 500,
        leadStops: (m['lead_stops'] as num?)?.toInt() ?? 2,
        enabled: m['enabled'] == true,
        fcmToken: m['fcm_token'] as String?,
        timezone: '${m['timezone'] ?? 'Asia/Kolkata'}',
        lastFiredAt: DateTime.tryParse('${m['last_fired_at']}'),
      );

  Map<String, dynamic> toJson() => {
        'bus_id': busId,
        'stop_id': stopId,
        'target_lat': targetLat,
        'target_lng': targetLng,
        'threshold_m': thresholdMeters,
        'lead_stops': leadStops,
        'enabled': enabled,
        'fcm_token': fcmToken,
        'timezone': timezone,
        // last_fired_at is owned by the Edge Function, never by the client.
      };

  ProximityAlert copyWith({
    int? thresholdMeters,
    int? leadStops,
    bool? enabled,
    String? fcmToken,
  }) =>
      ProximityAlert(
        busId: busId,
        stopId: stopId,
        targetLat: targetLat,
        targetLng: targetLng,
        thresholdMeters: thresholdMeters ?? this.thresholdMeters,
        leadStops: leadStops ?? this.leadStops,
        enabled: enabled ?? this.enabled,
        fcmToken: fcmToken ?? this.fcmToken,
        timezone: timezone,
        lastFiredAt: lastFiredAt,
      );
}
