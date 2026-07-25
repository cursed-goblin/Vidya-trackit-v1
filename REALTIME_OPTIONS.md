# Realtime transport: free options for 15 buses / 1200 riders

Load to plan for: 15 drivers writing a GPS point every ~7 s (about **2-3
writes/second**) and up to **1200 riders** subscribed, but each rider only
needs *their own* bus, and only during the ~40 minutes their bus is running.
Realistic concurrency at peak: 300-600 sockets.

| Option | Free tier | Fits 15 buses? | Fits 1200 riders? | Notes |
| --- | --- | --- | --- | --- |
| **Supabase Realtime** (this PR) | 200 concurrent connections, 2M messages/month | Yes | Pilot yes, full rollout needs Pro ($25/mo, 500+ connections) | Zero extra infra: the same client, RLS-checked, one channel per bus |
| **Cloudflare Durable Objects + WebSockets** | Workers free plan, 100k requests/day; WebSocket *hibernation* means idle sockets are not billed | Yes | Yes - best fan-out per rupee | One DO per bus = natural sharding; you already have a Worker in this repo. More code to own (auth, presence, reconnect) |
| **Cloudflare Realtime (Calls/SFU)** | Free while in beta | Not designed for this | No | It is a WebRTC media/SFU product for audio-video. Wrong tool for GPS fan-out - use Durable Objects instead |
| **Ably** | 6M messages/month, 200 peak connections | Yes | Pilot only | Excellent reconnect/history, but same 200-connection ceiling |
| **Pusher Channels** | 200 connections, 200k messages/day | Yes | No | Message cap is the binding limit |
| **Firebase Realtime DB** (current code) | 100 simultaneous connections, 10 GB/month egress | Yes | No - 100 connections is the hard stop | Also forces Blaze for Cloud Functions |
| **Plain polling** (PostgREST every 5 s) | - | Yes | No - 1200 riders = ~240 req/s | Only viable as a fallback when the socket drops |
| **Self-hosted Centrifugo / Socket.IO on Oracle Cloud Always Free** | 4 ARM vCPU / 24 GB VM, free forever | Yes | Yes, comfortably | Cheapest at scale but you run and patch the server |

## Recommendation

1. **Pilot (1 bus, or up to ~150 riders): Supabase Realtime only.** It is in
   this PR, it is one line in the client, and RLS already guards the data.
2. **Full rollout (15 buses, 1200 riders): keep Postgres as the source of
   truth, move fan-out to Cloudflare Durable Objects.** The driver still calls
   `record_location`; a Worker relays each write to `DO:bus_<id>`, and riders
   hold a hibernating WebSocket to that one object. Postgres write volume stays
   at 3/s and rider fan-out costs nothing.
3. **Keep the alarm server-side either way.** A phone with the app swiped away
   cannot evaluate geofences, so the Edge Function + FCM path is what actually
   wakes the student - the socket is only for the live map.
4. Cloudflare **Realtime** (the WebRTC product) is not the right fit; if you
   want everything on Cloudflare, it is Workers + Durable Objects you want.

## Fallback that costs nothing

If the socket is down for more than 15 seconds the app should poll
`bus_locations` once every 10 s (already easy with the same client). At 1200
riders that is only a burst, not a steady load, because it only happens on
reconnects.
