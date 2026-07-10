/// A student's proximity-alert subscription. Written once to the Firebase
/// Realtime Database at /proximityAlerts/{busId}/{userId} when the student taps
/// "Set Proximity Alert" on the live map bottom sheet. The Cloudflare Worker
/// reads these and fires FCM pushes.
class ProximityAlert {
  final String busId;
  final String userId;
  final double homeLat;
  final double homeLng;
  final int thresholdMeters;
  final bool enabled;
  final String fcmToken;
  final String timezone; // e.g. Asia/Kolkata - used for the daily reset

  const ProximityAlert({
    required this.busId,
    required this.userId,
    required this.homeLat,
    required this.homeLng,
    required this.thresholdMeters,
    required this.enabled,
    required this.fcmToken,
    required this.timezone,
  });

  /// Value stored at /proximityAlerts/{busId}/{userId}. busId/userId are the
  /// path keys so they are not duplicated inside the value.
  Map<String, dynamic> toMap() => {
        'homeLat': homeLat,
        'homeLng': homeLng,
        'thresholdMeters': thresholdMeters,
        'enabled': enabled,
        'fcmToken': fcmToken,
        'timezone': timezone,
        // lastFiredDate is managed by the Worker, not the client.
      };
}
