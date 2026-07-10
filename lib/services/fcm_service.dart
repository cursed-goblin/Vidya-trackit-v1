import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'notifications_service.dart';

/// Runs in a background isolate when a data message arrives while the app is
/// backgrounded or terminated. Must be a top-level / static function annotated
/// with @pragma('vm:entry-point'). Registered from main().
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {}
  await initNotifications();
  final d = message.data;
  await showAlarmNotification(
    d['title'] ?? 'Your bus is arriving!',
    d['body'] ?? 'Get ready to head to your stop.',
  );
}

class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();

  /// Request permission, wire the foreground handler, and return the device
  /// FCM token (null if messaging isn't configured yet).
  Future<String?> init() async {
    final m = FirebaseMessaging.instance;
    await m.requestPermission(alert: true, badge: true, sound: true);

    // The Worker sends DATA messages, so we render them ourselves even in the
    // foreground (FCM does not auto-display data-only messages).
    FirebaseMessaging.onMessage.listen((msg) {
      final d = msg.data;
      showAlarmNotification(
        d['title'] ?? 'Your bus is arriving!',
        d['body'] ?? 'Get ready to head to your stop.',
      );
    });

    try {
      return await m.getToken();
    } catch (_) {
      return null;
    }
  }
}
