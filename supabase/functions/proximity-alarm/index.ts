// ---------------------------------------------------------------------------
// Vidya TrackIt - proximity alarm (Supabase Edge Function, Deno)
//
// Runs every minute (pg_cron -> net.http_post, or a Cloudflare cron hitting
// this URL). Each run:
//   1. Loads every bus that reported a position in the last FRESH_SECONDS.
//   2. For each enabled alert subscription on that bus, computes distance to
//      the rider's stop and, when a route with ordered stops exists, how many
//      stops away the bus still is.
//   3. Fires an FCM v1 data message when within threshold_m OR within
//      lead_stops, respecting a COOLDOWN_MIN cooldown per rider (so the
//      evening return trip still alerts - the Firebase version fired only
//      once per calendar day).
//
// Env (supabase secrets set ...):
//   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY   (injected automatically)
//   FCM_PROJECT_ID, FCM_CLIENT_EMAIL, FCM_PRIVATE_KEY  (service account)
//   ALARM_SHARED_SECRET  optional: required in the x-alarm-secret header
// ---------------------------------------------------------------------------

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const FRESH_SECONDS = 90;   // ignore stale/parked buses - no ghost alarms
const COOLDOWN_MIN = 30;    // per-rider re-arm window

const sb = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  { auth: { persistSession: false } },
);

Deno.serve(async (req) => {
  const secret = Deno.env.get("ALARM_SHARED_SECRET");
  if (secret && req.headers.get("x-alarm-secret") !== secret) {
    return new Response("forbidden", { status: 403 });
  }
  try {
    const fired = await run();
    return Response.json({ ok: true, fired });
  } catch (e) {
    console.error(e);
    return Response.json({ ok: false, error: String(e) }, { status: 500 });
  }
});

async function run(): Promise<number> {
  const since = new Date(Date.now() - FRESH_SECONDS * 1000).toISOString();
  const { data: live, error: liveErr } = await sb
    .from("bus_locations")
    .select("bus_id, lat, lng, speed_kmph, recorded_at")
    .gte("recorded_at", since);
  if (liveErr) throw liveErr;
  if (!live?.length) return 0;

  const busIds = live.map((b) => b.bus_id);

  const { data: subs, error: subErr } = await sb
    .from("alert_subscriptions")
    .select(
      "profile_id, bus_id, stop_id, threshold_m, lead_stops, target_lat, target_lng, fcm_token, last_fired_at",
    )
    .eq("enabled", true)
    .in("bus_id", busIds);
  if (subErr) throw subErr;
  if (!subs?.length) return 0;

  // Stops per bus, ordered - used for the "2 stops before me" rule.
  const { data: buses } = await sb
    .from("buses").select("id, reg_no, route_id").in("id", busIds);
  const routeIds = (buses ?? []).map((b) => b.route_id).filter(Boolean);
  const { data: stops } = routeIds.length
    ? await sb.from("stops").select("id, route_id, name, lat, lng, seq")
        .in("route_id", routeIds).order("seq")
    : { data: [] as Stop[] };

  const stopsByRoute = new Map<string, Stop[]>();
  for (const s of (stops ?? []) as Stop[]) {
    const arr = stopsByRoute.get(s.route_id) ?? [];
    arr.push(s);
    stopsByRoute.set(s.route_id, arr);
  }
  const busById = new Map((buses ?? []).map((b) => [b.id, b]));
  const liveById = new Map(live.map((l) => [l.bus_id, l]));

  const now = Date.now();
  const cooled = (t: string | null) =>
    !t || now - new Date(t).getTime() > COOLDOWN_MIN * 60_000;

  let token: string | null = null;
  let fired = 0;

  for (const s of subs) {
    if (!s.fcm_token || !cooled(s.last_fired_at)) continue;
    const bus = liveById.get(s.bus_id);
    if (!bus) continue;

    const distance = haversine(bus.lat, bus.lng, s.target_lat, s.target_lng);
    const routeId = busById.get(s.bus_id)?.route_id as string | undefined;
    const routeStops = routeId ? stopsByRoute.get(routeId) ?? [] : [];
    const stopsAway = stopsAwayFor(routeStops, bus, s.stop_id);

    const byDistance = distance <= (s.threshold_m ?? 500);
    const byStops = stopsAway !== null && stopsAway <= (s.lead_stops ?? 2);
    if (!byDistance && !byStops) continue;

    token ??= await googleAccessToken();
    const body = stopsAway !== null && stopsAway > 0
      ? `Bus is ${stopsAway} stop${stopsAway === 1 ? "" : "s"} away (${Math.round(distance)} m)`
      : `Bus is ${Math.round(distance)} m from your stop`;

    const ok = await sendFcm(token, s.fcm_token, {
      title: "Your bus is arriving!",
      body,
      busId: s.bus_id,
      distance: String(Math.round(distance)),
      stopsAway: String(stopsAway ?? ""),
    });

    if (ok) {
      await sb.from("alert_subscriptions")
        .update({ last_fired_at: new Date().toISOString() })
        .eq("profile_id", s.profile_id);
      fired++;
    }
  }
  return fired;
}

type Stop = {
  id: string; route_id: string; name: string;
  lat: number; lng: number; seq: number;
};

// How many stops the bus still has to pass before the rider's stop.
// null when we cannot tell (no route configured).
function stopsAwayFor(
  stops: Stop[],
  bus: { lat: number; lng: number },
  riderStopId: string | null,
): number | null {
  if (!stops.length || !riderStopId) return null;
  const rider = stops.find((s) => s.id === riderStopId);
  if (!rider) return null;
  let nearest = stops[0];
  let best = Infinity;
  for (const s of stops) {
    const d = haversine(bus.lat, bus.lng, s.lat, s.lng);
    if (d < best) { best = d; nearest = s; }
  }
  const away = rider.seq - nearest.seq;
  return away < 0 ? null : away;   // bus already passed the stop
}

function haversine(la1: number, lo1: number, la2: number, lo2: number) {
  const R = 6371000, rad = (d: number) => (d * Math.PI) / 180;
  const dLa = rad(la2 - la1), dLo = rad(lo2 - lo1);
  const a = Math.sin(dLa / 2) ** 2 +
    Math.cos(rad(la1)) * Math.cos(rad(la2)) * Math.sin(dLo / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

// ---- FCM v1 (service-account JWT signed with WebCrypto) ----
async function sendFcm(
  accessToken: string,
  deviceToken: string,
  data: Record<string, string>,
): Promise<boolean> {
  const project = Deno.env.get("FCM_PROJECT_ID");
  const res = await fetch(
    `https://fcm.googleapis.com/v1/projects/${project}/messages:send`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        message: {
          token: deviceToken,
          data,                                  // data-only: app draws the alarm
          android: { priority: "HIGH" },
          apns: {
            headers: { "apns-priority": "10", "apns-push-type": "background" },
            payload: { aps: { "content-available": 1 } },
          },
        },
      }),
    },
  );
  if (!res.ok) console.error("FCM failed", res.status, await res.text());
  return res.ok;
}

async function googleAccessToken(): Promise<string> {
  const email = Deno.env.get("FCM_CLIENT_EMAIL")!;
  const pem = Deno.env.get("FCM_PRIVATE_KEY")!;
  const now = Math.floor(Date.now() / 1000);
  const claim = {
    iss: email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  };
  const unsigned = `${b64url(JSON.stringify({ alg: "RS256", typ: "JWT" }))}.${b64url(JSON.stringify(claim))}`;
  const key = await crypto.subtle.importKey(
    "pkcs8",
    pkcs8(pem),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5", key, new TextEncoder().encode(unsigned));
  const jwt = `${unsigned}.${b64urlBytes(new Uint8Array(sig))}`;

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body:
      "grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=" + jwt,
  });
  const json = await res.json();
  if (!json.access_token) throw new Error("token: " + JSON.stringify(json));
  return json.access_token as string;
}

function pkcs8(pem: string): ArrayBuffer {
  const body = pem
    .replace(/-----[A-Z ]+-----/g, "")
    .replace(/\\n/g, "")
    .replace(/\s/g, "");
  return Uint8Array.from(atob(body), (c) => c.charCodeAt(0)).buffer;
}
function b64url(s: string) { return b64urlBytes(new TextEncoder().encode(s)); }
function b64urlBytes(bytes: Uint8Array) {
  let bin = "";
  for (const b of bytes) bin += String.fromCharCode(b);
  return btoa(bin).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}
