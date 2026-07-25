#!/usr/bin/env python3
"""Drive a fake bus along its route so the rider map and the arrival alarm can
be tested from a laptop or a Codespace - no phone, no actual bus.

It signs in as the driver, calls start_trip, then walks the bus from stop 1 to
the last stop, pushing a position through record_location every few seconds
just like the Flutter foreground service does. Ctrl-C ends the trip cleanly.

Usage:
    export SUPABASE_URL=...            # https://<ref>.supabase.co
    export SUPABASE_ANON_KEY=...       # anon / publishable key
    export DRIVER_EMAIL=driver1@vidya.demo
    export DRIVER_PASSWORD=Trackit@123
    python3 tools/simulate_bus.py --speed 8 --interval 5

Options:
    --bus       bus id (default bus_12)
    --interval  seconds between position writes (default 5)
    --speed     how many simulated km/h to travel (default 30)
    --loop      restart from stop 1 when the route finishes
"""

import argparse
import json
import math
import os
import sys
import time
import urllib.error
import urllib.request
from datetime import datetime, timezone


def env(name):
    value = os.environ.get(name)
    if not value:
        sys.exit("Missing environment variable: " + name)
    return value.rstrip("/") if name == "SUPABASE_URL" else value


BASE = env("SUPABASE_URL")
ANON = env("SUPABASE_ANON_KEY")


def call(path, payload=None, token=None, method=None):
    """Minimal Supabase REST helper. `path` starts with a slash."""
    url = BASE + path
    data = json.dumps(payload).encode() if payload is not None else None
    request = urllib.request.Request(url, data=data, method=method or ("POST" if data else "GET"))
    request.add_header("apikey", ANON)
    request.add_header("Authorization", "Bearer " + (token or ANON))
    request.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(request) as response:
            body = response.read().decode()
            return json.loads(body) if body.strip() else None
    except urllib.error.HTTPError as error:
        detail = error.read().decode()
        raise SystemExit("HTTP {} on {}\n{}".format(error.code, path, detail))


def sign_in(email, password):
    result = call("/auth/v1/token?grant_type=password",
                  {"email": email, "password": password})
    return result["access_token"]


def haversine_m(a_lat, a_lng, b_lat, b_lng):
    radius = 6371000.0
    d_lat = math.radians(b_lat - a_lat)
    d_lng = math.radians(b_lng - a_lng)
    h = (math.sin(d_lat / 2) ** 2
         + math.cos(math.radians(a_lat)) * math.cos(math.radians(b_lat))
         * math.sin(d_lng / 2) ** 2)
    return radius * 2 * math.asin(math.sqrt(h))


def bearing_deg(a_lat, a_lng, b_lat, b_lng):
    lat1, lat2 = math.radians(a_lat), math.radians(b_lat)
    d_lng = math.radians(b_lng - a_lng)
    y = math.sin(d_lng) * math.cos(lat2)
    x = (math.cos(lat1) * math.sin(lat2)
         - math.sin(lat1) * math.cos(lat2) * math.cos(d_lng))
    return (math.degrees(math.atan2(y, x)) + 360) % 360


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--bus", default=os.environ.get("BUS_ID", "bus_12"))
    parser.add_argument("--interval", type=float, default=5.0)
    parser.add_argument("--speed", type=float, default=30.0,
                        help="simulated km/h")
    parser.add_argument("--loop", action="store_true")
    args = parser.parse_args()

    token = sign_in(env("DRIVER_EMAIL"), env("DRIVER_PASSWORD"))
    print("Signed in as", os.environ["DRIVER_EMAIL"])

    buses = call("/rest/v1/buses?select=route_id&id=eq." + args.bus, token=token)
    if not buses:
        raise SystemExit("No bus with id " + args.bus)
    route_id = buses[0]["route_id"]

    stops = call("/rest/v1/stops?select=name,lat,lng,seq&order=seq.asc"
                 "&route_id=eq." + str(route_id), token=token)
    if len(stops) < 2:
        raise SystemExit("Route needs at least two stops; run supabase/seed.sql")
    print("Route has {} stops: {}".format(
        len(stops), " -> ".join(s["name"] for s in stops)))

    call("/rest/v1/rpc/start_trip", {"p_bus": args.bus}, token=token)
    print("Trip started. Ctrl-C to end.\n")

    metres_per_tick = (args.speed * 1000 / 3600) * args.interval

    try:
        while True:
            for index in range(len(stops) - 1):
                origin, target = stops[index], stops[index + 1]
                leg_m = haversine_m(origin["lat"], origin["lng"],
                                    target["lat"], target["lng"])
                steps = max(1, int(leg_m / metres_per_tick))
                heading = bearing_deg(origin["lat"], origin["lng"],
                                      target["lat"], target["lng"])

                for step in range(steps + 1):
                    ratio = step / steps
                    lat = origin["lat"] + (target["lat"] - origin["lat"]) * ratio
                    lng = origin["lng"] + (target["lng"] - origin["lng"]) * ratio
                    call("/rest/v1/rpc/record_location", {
                        "p_bus": args.bus,
                        "p_lat": lat,
                        "p_lng": lng,
                        "p_speed": args.speed,
                        "p_heading": heading,
                        "p_recorded_at": datetime.now(timezone.utc).isoformat(),
                    }, token=token)
                    print("  {:>12} -> {:<12} {:5.1f}%  {:.5f},{:.5f}".format(
                        origin["name"], target["name"], ratio * 100, lat, lng))
                    time.sleep(args.interval)

                print("Arrived at", target["name"], "\n")

            if not args.loop:
                break
            print("Route complete - looping back to the first stop.\n")
    except KeyboardInterrupt:
        print("\nStopping...")
    finally:
        call("/rest/v1/rpc/end_trip", {"p_bus": args.bus}, token=token)
        print("Trip ended, live row cleared.")


if __name__ == "__main__":
    main()
