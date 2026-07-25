import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
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
        // `publishableKey` supersedes the deprecated `anonKey` parameter. It
        // accepts both the legacy anon JWT (eyJ...) and the newer publishable
        // key (sb_publishable_...), so either value works here.
        publishableKey: kSupabaseAnonKey,
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
  //
  // No `options:` argument on purpose. Firebase reads its config from the
  // native files - android/app/google-services.json and
  // ios/Runner/GoogleService-Info.plist - both of which are gitignored.
  // Running `flutterfire configure` also generates lib/firebase_options.dart,
  // but importing it would make the whole project fail to compile for anyone
  // who has not run that command yet. The app must build and run without FCM;
  // the alarm simply falls back to a local notification while the app is open.
  try {
    await Firebase.initializeApp();
    gFirebaseReady = true;
  } catch (e) {
    debugPrint('Firebase (FCM) not configured yet - push alarms disabled: $e');
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
