# Vidya TrackIt

Live school-bus tracking for **Vidya Engineering College** - students see their
bus move on a real map and get an alarm when it's near their stop; drivers share
their location with one tap.

Built with Flutter + Firebase (free Spark plan) + a free Cloudflare Worker +
OpenStreetMap. No paid plans, no map API keys.

## Features

- **Role picker** -> Student/Parent or Staff/Driver login.
- **Driver:** one big Start/End Trip button; a foreground service streams GPS to
  Realtime Database every ~7s, with a 12-hour auto-stop safety cut-off.
- **Student:** live OpenStreetMap view with a smoothly-animated bus marker
  (rotated to heading), your home pin, the route line, speed + last-updated
  badge, recenter, and a "signal lost" state when data goes stale.
- **Proximity alarm:** pick a distance (1 km / 500 m / 250 m / at stop); a
  Cloudflare Worker checks positions on a cron and pushes a full-screen alarm
  via FCM when the bus arrives - once per day per user.

## Project layout

```
lib/
  main.dart                 app entry + Firebase/notifications/service init
  config.dart               bus id, fallbacks, runtime flags
  theme.dart                purple theme + OSM tile URL helper
  models/                   student, staff, bus_location, proximity_alert
  services/                 rtdb, auth, notifications, fcm, location (bg service)
  widgets/ui.dart           shared buttons/cards/fields
  screens/                  role select, logins, dashboard, driver home, live map
cloudflare-worker/          cron proximity check + FCM push (free Blaze alt)
native_config/              AndroidManifest, Info.plist additions, gradle notes
.github/workflows/          APK build
SETUP.md                    full setup walkthrough  <-- start here
```

## Quick start

See **SETUP.md**. TL;DR:
```bash
flutter pub get
flutterfire configure      # writes real lib/firebase_options.dart
flutter run
```
Driver demo login: `driver01` / `pass123`. Student login: anything (demo).

## Stack & cost

| | Service | Cost |
|---|---|---|
| Auth / Realtime DB / Push | Firebase Spark | Free |
| Proximity cron + push trigger | Cloudflare Workers | Free |
| Maps | OpenStreetMap | Free |

> The one paid feature we avoided - a Realtime-Database-triggered Cloud Function
> (needs Firebase Blaze) - is replaced by the Cloudflare Worker. Trade-off: the
> check runs every ~1 min instead of instantly. See SETUP.md > Notes.
