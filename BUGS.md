# Bug + risk audit (commit 6f18f2d)

Ordered by severity. "Fixed here" = addressed by the Supabase migration in
this branch.

## Blockers - the app cannot work as shipped

1. **Nobody is ever signed in, so every database write is denied.**
   `AuthService` is a local object with a hard-coded `driver01 / pass123` and no
   Firebase Auth call, yet the RTDB rules require `auth != null` to write
   `/liveLocations`. Result: `Start Trip` appears to work, the foreground
   notification runs, and every write silently fails with PERMISSION_DENIED
   (the `catch (_) {}` in `location_service.dart` swallows it). *Fixed here:*
   real Supabase Auth + `record_location()` RPC, and write errors are surfaced
   to the driver's status card.

2. **`/proximityAlerts` is world-writable.** Any anonymous client could read
   every student's home coordinates and FCM token, or overwrite another
   student's alert. That is a child-safety issue, not just a bug. *Fixed here:*
   `alert_subscriptions` RLS allows only `profile_id = auth.uid()`.

3. **`busId` race in the background isolate.** `startTrip()` calls
   `startService()`, waits a fixed 400 ms, then `invoke('setBus')`. If the
   isolate is slower than 400 ms (cold start on a mid-range Android is often
   1-2 s) the listener is not registered yet, the message is dropped, and the
   isolate keeps its hard-coded default `'bus_12'` - so a second driver
   overwrites bus 12's position. *Fixed here:* the bus id and access token are
   written to `SharedPreferences` **before** the service starts and read inside
   the isolate.

## High - wrong behaviour users will notice

4. **The alarm can fire for a bus that is not running.** The Worker reads
   `/liveLocations` with no freshness check, so yesterday's final position (or a
   bus parked at the depot near a student's home) keeps matching the geofence.
   *Fixed here:* only positions newer than 90 s are considered, and `end_trip()`
   deletes the live row.

5. **Only one alarm per student per calendar day.** `lastFiredDate` is compared
   to today's date, so the return trip in the evening never alarms. *Fixed
   here:* a 30-minute `last_fired_at` cooldown instead.

6. **The alarm is a radius, not "2 stops before".** The stated requirement is a
   stop-based alert; the code only does straight-line distance to a single home
   point, and there is no `stops` concept anywhere. *Fixed here:* `stops` table
   with `seq`, `rider_bus.lead_stops`, and stop-count logic in the Edge
   Function (distance still works as a fallback when no route is configured).

7. **ETA uses straight-line distance and hides itself under 5 km/h.** At a red
   light or in traffic the ETA blanks out to `--`, and the number is optimistic
   because it ignores the road. Use the remaining stop sequence, or keep the
   last non-zero speed with an average-speed floor.

8. **No admin app at all.** Nothing can add/remove students, tell students from
   teachers, or show who is on the bus - all of which are in the requirement.
   *Fixed here:* `profiles.rider_type`, `boardings`, `bus_roster()` and an
   admin screen.

## Medium - reliability / lifecycle

9. **The "retry queue" in `onServiceStart` does nothing.** It appends the
   payload, writes only `queue.last`, and clears the whole queue on success; on
   failure the older readings can never be sent because only the newest is ever
   written. Either drop the queue or actually flush it oldest-first. *Fixed
   here:* real flush loop, oldest first, capped at 60 points.

10. **The 12-hour auto-stop only runs when a GPS fix arrives.** If the stream
    stalls (tunnel, GPS off, OEM battery killer) the check never executes and
    the service runs forever. *Fixed here:* a `Timer` owns the cutoff.

11. **`Geolocator.getPositionStream` has no `onError`.** A `LocationServiceDisabled`
    or permission revocation mid-trip kills the stream silently; the foreground
    notification stays up and the driver believes they are broadcasting. *Fixed
    here:* error handler restarts the stream and updates the notification.

12. **`Firebase.initializeApp()` in the isolate is called without options.**
    That works on Android via `google-services.json` but throws on iOS, where
    the whole write path is then dead. (Moot now - the isolate talks to
    PostgREST over plain HTTPS.)

13. **No throttle on *distance*, only on time.** A parked bus with GPS jitter
    still writes every 7 s for 12 h - about 6k writes and a lot of battery.
    Skip writes when the bus moved < 20 m and the last write was < 60 s ago.

14. **`disableProximityAlert` is never called.** Nothing in the UI turns an
    alert off, so `enabled` stays `true` forever once set. The bottom sheet's
    `_alertSet` is also local state: leave the screen and it resets to `false`
    even though the subscription still exists. *Fixed here:* the subscription is
    loaded on open and can be toggled off.

15. **`_staleTimer` rebuilds the whole map every 3 s** just to re-evaluate
    `isStale`, and `_move.addListener(() => setState(() {}))` rebuilds it again
    on every animation frame. On a low-end phone this is the main battery cost
    of the passenger screen. Wrap the marker in an `AnimatedBuilder` /
    `ValueListenableBuilder` instead of rebuilding the `FlutterMap` subtree.

16. **Missing `alarm` sound resource.** Both the channel and the notification
    reference `RawResourceAndroidNotificationSound('alarm')`, but
    `android/app/src/main/res/raw/alarm.mp3` is not in the repo. Android falls
    back to silence on some OEMs rather than the default tone. Ship the file or
    drop the `sound:` argument.

17. **`fullScreenIntent: true` needs `USE_FULL_SCREEN_INTENT`,** which on
    Android 14+ is only granted to alarm/calling apps; otherwise the "alarm"
    degrades to a heads-up notification. Also add `SCHEDULE_EXACT_ALARM` if you
    ever move to a local alarm, and verify `POST_NOTIFICATIONS` is requested
    before the first alarm (currently requested only inside
    `initNotifications`).

## Low / cleanup

18. `dashboard_screen.dart` calls `(AuthService.instance..loginStudentDemo())`
    inside `build()` - a side effect in a build method that logs a demo user in
    if state was lost. *Fixed here:* the profile is loaded from Supabase.

19. The public Worker `fetch` handler runs the full check with no auth, so
    anyone with the URL can trigger FCM sends. *Fixed here:*
    `x-alarm-secret` header.

20. `BusLocation.fromMap` falls back to `DateTime.now()` when the timestamp is
    missing, which makes a stale record look fresh and suppresses the
    "signal lost" banner. Treat a missing timestamp as stale.

21. `speed` is clamped to 200 km/h but `heading` is only floored at 0 -
    `Position.heading` is unreliable below ~2 m/s, so the marker spins while
    the bus is stopped. Freeze the bearing under 5 km/h.

22. Two divergent branches exist (`main`, `master`) with different heads; the
    Flutter build artefacts in `.dart_tool/` and `.flutter-plugins-dependencies`
    are committed and should be git-ignored.

23. `firebase.json` + RTDB rules stay in the tree after the migration; delete
    them (and the Realtime Database itself) once the Edge Function is live so
    nobody points a client at the old, world-writable paths.
