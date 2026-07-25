import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'firebase_options.dart';
import 'screens/role_select_screen.dart';
import 'services/auth_service.dart';
import 'services/fcm_service.dart';
import 'services/location_service.dart';
import 'services/notifications_service.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ---- Supabase: data, auth, realtime ----
  if (kSupabaseUrl.isNotEmpty && kSupabaseAnonKey.isNotEmpty) {
    try {
      await Supabase.initialize(
        url: kSupabaseUrl,
        anonKey: kSupabaseAnonKey,
        realtimeClientOptions:
            const RealtimeClientOptions(logLevel: RealtimeLogLevel.error),
      );
      gSupabaseReady = true;
      // Keep the access token used by the background GPS isolate fresh.
      AuthService.instance.watchSession();
    } catch (e) {
      debugPrint('Supabase init failed: $e');
    }
  } else {
    debugPrint('SUPABASE_URL / SUPABASE_ANON_KEY not set - running UI only. '
        'See SUPABASE_SETUP.md');
  }

  // ---- Firebase: Cloud Messaging only ----
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    gFirebaseReady = true;
  } catch (e) {
    debugPrint('Firebase (FCM) not configured yet: $e');
  }

  await initNotifications();
  await initLocationService();

  if (gFirebaseReady) {
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
