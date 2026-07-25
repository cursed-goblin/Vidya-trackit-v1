# tools/

## simulate_bus.py

Drives a fake bus along its route so you can test the rider map, the ETA, the
"2 stops before" alarm and the admin roster without a driver phone.

```bash
export SUPABASE_URL=https://<ref>.supabase.co
export SUPABASE_ANON_KEY=<anon key>
export DRIVER_EMAIL=driver1@vidya.demo
export DRIVER_PASSWORD=Trackit@123

python3 tools/simulate_bus.py --speed 40 --interval 3
```

It authenticates as the driver, so it exercises exactly the same RLS path as
the real app: `start_trip` -> repeated `record_location` -> `end_trip`. If a
permission error appears here, the phone would have hit it too.

Useful flags:

| Flag | Meaning |
| --- | --- |
| `--bus` | bus id, default `bus_12` |
| `--speed` | simulated km/h; raise it to reach stops faster |
| `--interval` | seconds between writes, default 5 (the app uses ~7) |
| `--loop` | restart at stop 1 when the route ends |

Standard library only - no `pip install` needed.
