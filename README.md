# Vidya TrackIt

Live college-bus tracking for **Vidya Engineering College** - students and
teachers watch their bus move on a real map and get an alarm a couple of stops
before it reaches them; drivers share their location with one tap; the transport
office manages riders and sees who actually boarded.

Built with Flutter + **Supabase** (Postgres, Auth, Realtime, Edge Functions) +
Firebase Cloud Messaging for push + OpenStreetMap. No paid plans, no map API
keys.

## Why Supabase Realtime

The live bus pin is a `postgres_changes` subscription on the `bus_locations`
table: the driver's app writes a row, every subscribed rider gets it in well
under a second, and no extra service sits in between. The free tier covers ~200
concurrent connections and 2M messages/month, which is comfortable for the
1-bus demo and the first pilot routes.

Push notifications still go through FCM - Supabase has no push service, and a
phone with the app closed can only be woken by FCM/APNs.

Scaling notes and the alternatives that were considered (Cloudflare Durable
Objects, Ably, Centrifugo, MQTT) are in **REALTIME_OPTIONS.md**.

## Features

- **Three roles** - rider (students *and* teachers), driver, transport office.
- **Driver:** one big Start/End Trip button; a foreground service streams GPS
  every ~7s with an offline retry queue, a 12-hour auto-stop, and a visible
  queue/error state so a silent failure can't masquerade as "broadcasting".
- **Rider:** live OpenStreetMap view with a smoothly-animated bus marker
  (rotated to heading), your stop pin, the route line, ETA, speed +
  last-updated badge, and an honest "signal lost" state.
- **Arrival alarm:** rings when the bus is within your chosen distance **or**
  within N stops of your stop (default 2). Stale positions are ignored and
  there's a 30-minute cooldown, so the evening return trip alarms too.
- **Admin:** add / remove riders, filter students vs teachers, and see who is
  on the bus vs not on the bus for the current trip.

## Project layout

```
lib/
  main.dart                 app entry + Supabase/FCM/notifications/service init
  config.dart               build-time credentials, fallbacks, runtime flags
  theme.dart                purple theme + OSM tile URL helper
  models/                   student, staff, bus_location, proximity_alert
  services/                 bus (Supabase), auth, admin, notifications, fcm,
                            location (background GPS service)
  widgets/ui.dart           shared buttons/cards/fields
  screens/                  role select, logins, dashboard, driver home,
                            live map, admin
supabase/
  schema.sql                tables, RLS, realtime publication, RPCs
  functions/proximity-alarm stop-aware alarm -> FCM (cron every minute)
  functions/admin-users     admin-only rider create/delete (service role)
native_config/              AndroidManifest, Info.plist additions, gradle notes
.github/workflows/          APK build
SUPABASE_SETUP.md           backend walkthrough   <-- start here
BUGS.md                     audit of the pre-migration code
REALTIME_OPTIONS.md         realtime comparison + scaling plan
```

## Quick start

Full walkthrough in **SUPABASE_SETUP.md**. TL;DR:

```bash
flutter pub get
flutterfire configure          # FCM only -> lib/firebase_options.dart

supabase db push               # or paste supabase/schema.sql in the SQL editor
supabase functions deploy proximity-alarm admin-users

flutter run \
  --dart-define=SUPABASE_URL=https://<project>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<anon key>
```

Accounts are created in Supabase (or from the admin screen) - there are no
hard-coded logins any more. Built without the two `--dart-define`s, the app
still opens in a read-only demo mode so the UI can be shown offline.

## Stack & cost

| | Service | Free tier | Cost |
|---|---|---|---|
| Database + Auth + Realtime + Functions | Supabase | 500MB DB, ~200 concurrent realtime | Free |
| Push notifications | Firebase Cloud Messaging | unlimited | Free |
| Maps + tiles | OpenStreetMap | fair use | Free |

> At ~1200 riders you will pass the free realtime concurrency ceiling. The two
> options then are Supabase Pro (~$25/mo) or a Cloudflare Durable Object
> fan-out layer in front of the same database - see REALTIME_OPTIONS.md.
