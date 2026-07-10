import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'config.dart';
import 'firebase_options.dart';
import 'screens/role_select_screen.dart';
import 'services/fcm_service.dart';
import 'services/location_service.dart';
import 'services/notifications_service.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase powers Realtime Database + Cloud Messaging. If you haven't run
  // `flutterfire configure` yet the placeholder options throw here; we catch
  // it so the demo UI (screens + OSM map) still runs.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    gFirebaseReady = true;
  } catch (e) {
    debugPrint('Firebase not configured yet (run flutterfire configure): $e');
  }

  await initNotifications();
  await initLocationService();

  if (gFirebaseReady) {
    // Background/terminated data messages -> full-screen alarm notification.
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    gFcmToken = await FcmService.instance.init();
  }

  runApp(const VidyaTrackItApp());
}

class VidyaTrackItApp extends StatelessWidget {
  const VidyaTrackItApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vidya TrackIt',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const RoleSelectScreen(),
    );
  }
}
