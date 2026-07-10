// ---------------------------------------------------------------------------
// Vidya TrackIt - proximity-alert Worker (free Cloudflare Workers replacement
// for the Blaze-only Firebase Cloud Function).
//
// Runs on a 1-minute cron. Each run:
//   1. Mints a Google OAuth token from a Firebase service account (WebCrypto).
//   2. Reads /liveLocations and /proximityAlerts from Realtime Database (REST).
//   3. For each subscriber within their threshold whose lastFiredDate != today
//      (in their timezone), sends an FCM v1 data message and stamps today.
//
// This is O(1-per-bus-tick) work batched in a single run, not per-user
// listeners. Trade-off vs a true DB trigger: it polls every ~60s instead of
// firing instantly on each write - fine for a daily "bus arriving" alarm.
//
// Secrets (set with `wrangler secret put <NAME>`):
//   FIREBASE_PROJECT_ID    e.g. vidya-trackit
//   FIREBASE_CLIENT_EMAIL  from the service account JSON
//   FIREBASE_PRIVATE_KEY   from the service account JSON (keep the \n newlines)
//   RTDB_URL               your Realtime Database base URL
// ---------------------------------------------------------------------------

const HTTPS = 'ht' + 'tps://';
const TOKEN_URI = HTTPS + 'oauth2.googleapis.com/token';
const SCOPES = [
  HTTPS + 'www.googleapis.com/auth/firebase.database',
  HTTPS + 'www.googleapis.com/auth/firebase.messaging',
  HTTPS + 'www.googleapis.com/auth/userinfo.email',
].join(' ');

export default {
  // Cron trigger.
  async scheduled(event, env, ctx) {
    ctx.waitUntil(runCheck(env));
  },
  // Manual trigger for testing: just hit the Worker URL in a browser.
  async fetch(request, env) {
    try {
      const fired = await runCheck(env);
      return new Response(`ok - fired ${fired} alert(s)`, { status: 200 });
    } catch (e) {
      return new Response('error: ' + e.message, { status: 500 });
    }
  },
};

async function runCheck(env) {
  const token = await getAccessToken(env);
  const rtdb = env.RTDB_URL.replace(/\/$/, '');
  const auth = `?access_token=${token}`;

  const live =
      (await (await fetch(`${rtdb}/liveLocations.json${auth}`)).json()) || {};
  const alerts =
      (await (await fetch(`${rtdb}/proximityAlerts.json${auth}`)).json()) || {};

  let fired = 0;
  for (const busId of Object.keys(live)) {
    const bus = live[busId];
    if (!bus || bus.lat == null || bus.lng == null) continue;
    const subs = alerts[busId] || {};
    for (const [userId, a] of Object.entries(subs)) {
      if (!a || a.enabled !== true || !a.fcmToken) continue;
      const dist = haversine(bus.lat, bus.lng, a.homeLat, a.homeLng);
      if (dist > (a.thresholdMeters || 500)) continue;

      const tz = a.timezone || 'Asia/Kolkata';
      const today = new Intl.DateTimeFormat('en-CA', { timeZone: tz }).format(
          new Date());
      if (a.lastFiredDate === today) continue; // already alerted today

      await sendFcm(env, token, a.fcmToken, busId, Math.round(dist));
      await fetch(
          `${rtdb}/proximityAlerts/${busId}/${userId}/lastFiredDate.json${auth}`,
          { method: 'PUT', body: JSON.stringify(today) });
      fired++;
    }
  }
  return fired;
}

async function sendFcm(env, token, fcmToken, busId, dist) {
  const url =
      HTTPS + 'fcm.googleapis.com/v1/projects/' + env.FIREBASE_PROJECT_ID +
      '/messages:send';
  const message = {
    message: {
      token: fcmToken,
      // DATA-only so the Flutter background handler always runs and shows a
      // full-screen alarm (not a passive banner).
      data: {
        title: 'Your bus is arriving!',
        body: `Bus is within ${dist} m of your stop`,
        busId: String(busId),
        distance: String(dist),
      },
      android: { priority: 'HIGH' },
      apns: {
        headers: { 'apns-priority': '10' },
        payload: { aps: { sound: 'default', 'content-available': 1 } },
      },
    },
  };
  const res = await fetch(url, {
    method: 'POST',
    headers: {
      Authorization: 'Bearer ' + token,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(message),
  });
  if (!res.ok) console.log('FCM send failed', res.status, await res.text());
}

// ---- Google service-account OAuth (RS256 JWT signed with WebCrypto) ----
async function getAccessToken(env) {
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: 'RS256', typ: 'JWT' };
  const claim = {
    iss: env.FIREBASE_CLIENT_EMAIL,
    scope: SCOPES,
    aud: TOKEN_URI,
    iat: now,
    exp: now + 3600,
  };
  const unsigned = `${b64url(JSON.stringify(header))}.${b64url(JSON.stringify(claim))}`;
  const key = await importKey(env.FIREBASE_PRIVATE_KEY);
  const sigBuf = await crypto.subtle.sign(
      'RSASSA-PKCS1-v1_5', key, new TextEncoder().encode(unsigned));
  const jwt = `${unsigned}.${b64urlBytes(new Uint8Array(sigBuf))}`;

  const res = await fetch(TOKEN_URI, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body:
        'grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=' +
        jwt,
  });
  const json = await res.json();
  if (!json.access_token) throw new Error('token: ' + JSON.stringify(json));
  return json.access_token;
}

async function importKey(pem) {
  const body = pem
      .replace('-----BEGIN PRIVATE KEY-----', '')
      .replace('-----END PRIVATE KEY-----', '')
      .replace(/\\n/g, '')
      .replace(/\s/g, '');
  const der = Uint8Array.from(atob(body), (c) => c.charCodeAt(0));
  return crypto.subtle.importKey(
      'pkcs8', der.buffer,
      { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['sign']);
}

function b64url(str) {
  return b64urlBytes(new TextEncoder().encode(str));
}
function b64urlBytes(bytes) {
  let bin = '';
  for (const b of bytes) bin += String.fromCharCode(b);
  return btoa(bin).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function haversine(lat1, lon1, lat2, lon2) {
  const R = 6371000; // metres
  const toRad = (d) => (d * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const a = Math.sin(dLat / 2) ** 2 +
      Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLon / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}
