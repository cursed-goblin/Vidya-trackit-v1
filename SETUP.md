# Setup

The backend walkthrough now lives in **[SUPABASE_SETUP.md](SUPABASE_SETUP.md)** -
database schema, RLS, Edge Functions, the alarm cron, and seed data.

This file covers only the app-side pieces.

## 1. Prerequisites

- Flutter 3.19+ (`flutter --version`)
- A Supabase project (free tier)
- A Firebase project - **for Cloud Messaging only**, no Realtime Database

## 2. Firebase Cloud Messaging

Supabase has no push service, so FCM is what wakes a phone whose app is closed.

```bash
dart pub global activate flutterfire_cli
flutterfire configure       # writes lib/firebase_options.dart (gitignored)
```

Download `google-services.json` into `android/app/`, and for iOS add
`GoogleService-Info.plist` plus an APNs key in the Firebase console.

For the alarm function you also need a **service account** key
(Firebase console -> Project settings -> Service accounts -> Generate key).
Its `project_id`, `client_email` and `private_key` become the `FCM_*` secrets
in SUPABASE_SETUP.md step 4.

## 3. Native config

Merge the snippets in `native_config/` into your platform files:

- `AndroidManifest.xml` - `ACCESS_FINE_LOCATION`, `ACCESS_BACKGROUND_LOCATION`,
  `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_LOCATION`, `POST_NOTIFICATIONS`,
  and the `foregroundServiceType="location"` attribute on the service.
- `Info.plist` - `NSLocationWhenInUseUsageDescription`,
  `NSLocationAlwaysAndWhenInUseUsageDescription`, and the `location` +
  `remote-notification` background modes.

### Full-screen alarm on Android 14+

The alarm notification uses `fullScreenIntent`. On Android 14 that permission
(`USE_FULL_SCREEN_INTENT`) is granted only to alarm/calling apps; everywhere
else the notification degrades to a heads-up banner. If you want the
lock-screen takeover, request the permission at runtime and fall back
gracefully - do not assume it fired.

### Alarm sound

`RawResourceAndroidNotificationSound('alarm')` needs
`android/app/src/main/res/raw/alarm.mp3`. If that file is missing the channel
falls back to the default sound, so ship the file or drop the argument.

## 4. Run

```bash
flutter pub get
flutter run \
  --dart-define=SUPABASE_URL=https://<project>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<anon key>
```

The anon key is safe to ship - RLS is what protects the data. The
**service-role key must never be in the app**; only the Edge Functions use it.

## 5. Smoke test the demo

1. Sign in on phone A as the driver, tap **Start Trip**. The status card should
   show coordinates updating and `Queued points: 0`.
2. Sign in on phone B as a rider on the same bus. The marker should move within
   a second or two of each driver update.
3. Tap **Set arrival alarm**, then drive (or move the driver phone) toward the
   rider's stop. The alarm fires when the bus is within the chosen distance or
   within the rider's `lead_stops` stops.
4. On the driver's roster screen, flip a few riders to **on bus** and confirm
   the admin screen counts match.

## Notes

- The old Firebase Realtime Database + Cloudflare Worker setup has been removed;
  see BUGS.md for why (unauthenticated writes, once-per-day alarms, and a
  location write path that could never have passed the documented rules).
- Location history is kept in `location_history`; add a retention job if you
  don't want it growing forever.
