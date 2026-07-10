# Vidya TrackIt - Setup Guide

Live bus tracking for Vidya Engineering College, on a **100% free** stack:

| Piece | Service | Plan |
|---|---|---|
| Auth, live location store, config | Firebase Realtime Database | **Spark (free)** |
| Push notifications | Firebase Cloud Messaging | **Spark (free)** |
| Server-side proximity check + push trigger | Cloudflare Worker (cron) | **Workers Free** |
| Maps | OpenStreetMap + `flutter_map` | Free, no API key |

> **Why Cloudflare?** A Realtime-Database-triggered Cloud Function needs
> Firebase's paid Blaze plan. To stay free, that one job runs in a Cloudflare
> Worker on a 1-minute cron instead. Everything else is native Firebase.

---

## 1. Prerequisites

```bash
flutter --version      # Flutter 3.22+ / Dart 3.4+
dart pub global activate flutterfire_cli
npm install -g firebase-tools wrangler
```

## 2. Create the Firebase project (free Spark plan)

1. https://console.firebase.google.com -> **Add project** (skip Analytics if you like).
2. **Build > Realtime Database > Create Database** -> Start in **locked mode**.
3. Paste these rules (Rules tab). Drivers write their own bus; the Worker uses
   a service account (admin) so it bypasses rules; students read positions and
   write only their own alert:
   ```json
   {
     "rules": {
       "liveLocations": { ".read": true, ".write": "auth != null" },
       "proximityAlerts": {
         "$busId": {
           "$userId": { ".read": true, ".write": true }
         }
       }
     }
   }
   ```
   (Tighten these before real production use; they are demo-friendly.)

## 3. Wire Firebase into the app

From the project root:
```bash
flutterfire configure
```
Select your project and the Android (+ iOS) apps. This **overwrites**
`lib/firebase_options.dart` with real values and drops
`android/app/google-services.json` in place. Use the Android package id
**`com.vidya.vidya_trackit`** (matches the manifest).

Apply the native bits:
- Copy `native_config/AndroidManifest.xml` over `android/app/src/main/AndroidManifest.xml`
  (or merge the permissions + `<service>` block).
- Merge `native_config/Info.plist.additions.xml` into `ios/Runner/Info.plist`.
- Apply `native_config/GRADLE_SETUP.md` (Google Services plugin + desugaring).

## 4. Run

```bash
flutter pub get
flutter run
```
- **Student login:** any username/password (demo) -> dashboard -> Track this Bus.
- **Driver login:** `driver01` / `pass123` -> Start Trip (grant "Allow all the
  time" location + notifications).

Open both on two devices (or driver on phone, student on emulator) to see the
bus marker move live.

## 5. Deploy the proximity Worker

See `cloudflare-worker/README.md`. In short:
```bash
cd cloudflare-worker
npm install
wrangler login
wrangler secret put FIREBASE_PROJECT_ID
wrangler secret put FIREBASE_CLIENT_EMAIL
wrangler secret put FIREBASE_PRIVATE_KEY
wrangler secret put RTDB_URL
npm run deploy
```
Generate the service-account key at **Firebase console > Project settings >
Service accounts > Generate new private key**.

## 6. Build an APK

Push to GitHub and let the included workflow build it
(`.github/workflows/build-apk.yml`), or locally:
```bash
flutter build apk --release
```

---

## Data model (Realtime Database)

```
/liveLocations/{busId}          { lat, lng, speed, heading, timestamp }
/proximityAlerts/{busId}/{userId} {
    homeLat, homeLng, thresholdMeters, enabled,
    fcmToken, timezone, lastFiredDate    // lastFiredDate managed by the Worker
}
```

## Notes & limitations

- **Proximity timing:** the Worker cron runs every ~60s (Cloudflare minimum),
  so the arrival alarm can lag up to a minute - fine for a daily alert.
- **iOS Critical Alerts:** a full-screen, bypass-silent-mode alarm on iOS needs
  Apple's *Critical Alerts* entitlement (a manual request to Apple). Without it
  the alert still arrives as a normal high-priority push/banner. Android gets
  the full-screen alarm via `USE_FULL_SCREEN_INTENT`.
- **Demo credentials** (`driver01`/`pass123`, any student login) are hard-coded
  in `lib/services/auth_service.dart` for the prototype. Replace with Firebase
  Auth for production.
- No Firebase config values are committed; `lib/firebase_options.dart` ships as
  a placeholder until you run `flutterfire configure`.
