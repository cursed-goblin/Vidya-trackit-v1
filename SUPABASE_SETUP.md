# Vidya TrackIt on Supabase

This replaces Firebase Realtime Database with Supabase (Postgres + Realtime +
Edge Functions). Firebase is kept **only** for Cloud Messaging, because
Supabase has no push-notification service - a background alarm on a phone that
is not running the app needs FCM (Android) / APNs (iOS).

| Concern | Before | Now |
| --- | --- | --- |
| Live location | RTDB `/liveLocations/{busId}` | `public.bus_locations` + Supabase Realtime |
| Alert subscriptions | RTDB `/proximityAlerts/...` | `public.alert_subscriptions` (RLS: own row only) |
| Proximity check | Cloudflare Worker cron | `supabase/functions/proximity-alarm` (pg_cron, 1 min) |
| Auth | hard-coded `driver01 / pass123` | Supabase Auth + `profiles.role` |
| Roles | none | `rider` (student / teacher) · `driver` · `admin` |
| Push | FCM | FCM (unchanged) |

## 1. Create the project

1. Create a free Supabase project (region: Mumbai / Singapore for India).
2. SQL Editor -> paste `supabase/schema.sql` -> Run.
3. SQL Editor -> paste `supabase/seed.sql` -> Run (demo bus, route, 8 stops).
4. Database -> Extensions -> enable `pg_cron` and `pg_net`.
5. Database -> Replication -> confirm `bus_locations` is in the
   `supabase_realtime` publication (the schema does this for you).

## 2. Wire up the app

```bash
flutter pub get
flutter run \
  --dart-define=SUPABASE_URL=https://<ref>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<anon-key>
```

The anon key is meant to be public; every table is protected by RLS. Never put
the **service-role** key in the app.

For release builds add the same `--dart-define` flags, or commit a
`--dart-define-from-file=env.json` that is git-ignored.

## 3. Users and roles

1. Authentication -> Users -> add users (email + password).
2. A `profiles` row must exist per user. Either sign up through the app (the
   admin screen creates the profile) or insert manually:

```sql
insert into public.profiles (id, role, rider_type, full_name, roll_no)
values ('<uid>', 'rider', 'student', 'Aparna R', 'VEC-CS-118');

insert into public.rider_bus (profile_id, bus_id, stop_id, lead_stops)
values ('<uid>', 'bus_12',
        (select id from public.stops where name = 'Rail Gate'), 2);
```

3. Make one user an admin and point the bus at the driver:

```sql
update public.profiles set role = 'admin', rider_type = null where id = '<uid>';
update public.buses set driver_id = '<driver-uid>' where id = 'bus_12';
```

Students and teachers share the `rider` role and differ only by
`profiles.rider_type`, so the app treats them identically while the admin can
filter and count them separately - exactly the behaviour asked for.

## 4. Proximity alarm function

```bash
supabase functions deploy proximity-alarm
supabase secrets set FCM_PROJECT_ID=... FCM_CLIENT_EMAIL=... \
  FCM_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n..." \
  ALARM_SHARED_SECRET=$(openssl rand -hex 16)
```

Then schedule it (SQL editor, uncomment the block at the bottom of
`schema.sql`):

```sql
select cron.schedule('proximity-alarm', '* * * * *', $$
  select net.http_post(
    url := 'https://<ref>.supabase.co/functions/v1/proximity-alarm',
    headers := jsonb_build_object(
      'Content-Type','application/json',
      'Authorization','Bearer <service-role-key>',
      'x-alarm-secret','<the secret above>'),
    body := '{}'::jsonb) $$);
```

The function only looks at buses that reported in the last 90 seconds, and
re-arms per rider after 30 minutes, so the evening trip alarms too.

## 5. What is still Firebase

Keep `firebase_core` + `firebase_messaging` and `google-services.json` /
`GoogleService-Info.plist` for push only. `firebase_database` is gone; you can
delete the Realtime Database and its rules, and the old
`cloudflare-worker/` directory once the Edge Function is live.
