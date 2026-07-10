# Vidya TrackIt - Proximity Worker (Cloudflare)

This free Cloudflare Worker replaces the Firebase **Blaze-only** Cloud Function.
It runs the proximity check on a 1-minute cron and sends FCM push notifications.

## Why this exists

Realtime-Database-triggered Cloud Functions require Firebase's paid **Blaze**
plan. The rest of the app (Auth, Realtime Database, Cloud Messaging) runs on
the **free Spark** plan. This Worker does the one server-side job Spark can't:
read the latest bus position + all subscribers once per tick and push to the
ones whose stop is within range.

**Trade-off:** Cloudflare's minimum cron interval is 1 minute, so the check
runs every ~60s instead of instantly on each bus write. For a once-per-day
"your bus is arriving" alarm this is fine.

## One-time setup

1. Install the CLI and log in:
   ```bash
   npm install -g wrangler
   wrangler login
   ```
2. In the Firebase console: **Project settings > Service accounts >
   Generate new private key**. You'll get a JSON file with `project_id`,
   `client_email`, and `private_key`.
3. From this folder, set the secrets:
   ```bash
   wrangler secret put FIREBASE_PROJECT_ID     # e.g. vidya-trackit
   wrangler secret put FIREBASE_CLIENT_EMAIL   # ...@....iam.gserviceaccount.com
   wrangler secret put FIREBASE_PRIVATE_KEY    # paste the full key incl. BEGIN/END
   wrangler secret put RTDB_URL                # your Realtime Database base URL
   ```
   `RTDB_URL` looks like `https://<project>-default-rtdb.<region>.firebasedatabase.app`
   (copy it from the Realtime Database page in the Firebase console).
4. Deploy:
   ```bash
   npm install
   npm run deploy
   ```
5. Test immediately (without waiting for the cron): open the deployed Worker
   URL in a browser - it returns `ok - fired N alert(s)`. Watch logs with
   `npm run tail`.

## Notes

- The Worker needs the service account only to (a) read/write Realtime Database
  over REST and (b) send FCM v1 messages. Keep the private key in Wrangler
  secrets, never in source.
- Free Workers plan: 100,000 requests/day + free Cron Triggers - far more than
  one bus needs.
- The daily reset is handled by `lastFiredDate` per subscriber timezone, so a
  user is alerted at most once per day and never spammed mid-trip.
