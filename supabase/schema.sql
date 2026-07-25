-- ===========================================================================
-- Vidya TrackIt - Supabase schema (Postgres + RLS + Realtime)
-- Run this once in the Supabase SQL editor on a fresh project.
-- Replaces the Firebase Realtime Database layout:
--   /liveLocations/{busId}            -> public.bus_locations
--   /proximityAlerts/{busId}/{userId} -> public.alert_subscriptions
-- ===========================================================================

-- ---------- enums ----------
do $$ begin
  create type app_role  as enum ('rider', 'driver', 'admin');
exception when duplicate_object then null; end $$;

do $$ begin
  create type rider_kind as enum ('student', 'teacher');
exception when duplicate_object then null; end $$;

-- ---------- profiles ----------
-- One row per auth user. Students and teachers share role='rider' and are
-- distinguished by rider_type, which is what the admin screens filter on.
create table if not exists public.profiles (
  id          uuid primary key references auth.users (id) on delete cascade,
  role        app_role   not null default 'rider',
  rider_type  rider_kind,
  full_name   text       not null,
  roll_no     text,
  department  text,
  phone       text,
  guardian_phone text,
  active      boolean    not null default true,
  created_at  timestamptz not null default now(),
  constraint rider_type_required
    check (role <> 'rider' or rider_type is not null)
);

-- ---------- routes / stops / buses ----------
create table if not exists public.routes (
  id    uuid primary key default gen_random_uuid(),
  name  text not null
);

create table if not exists public.stops (
  id        uuid primary key default gen_random_uuid(),
  route_id  uuid not null references public.routes (id) on delete cascade,
  name      text not null,
  lat       double precision not null,
  lng       double precision not null,
  seq       int  not null,                    -- 1 = first stop of the trip
  unique (route_id, seq)
);

create table if not exists public.buses (
  id         text primary key,               -- e.g. 'bus_12'
  reg_no     text not null,                  -- e.g. 'KL-08 AV 4412'
  route_id   uuid references public.routes (id) on delete set null,
  driver_id  uuid references public.profiles (id) on delete set null,
  active     boolean not null default true
);

-- Which bus / stop a rider belongs to (one row per rider).
create table if not exists public.rider_bus (
  profile_id       uuid primary key references public.profiles (id) on delete cascade,
  bus_id           text not null references public.buses (id) on delete cascade,
  stop_id          uuid references public.stops (id) on delete set null,
  lead_stops       int  not null default 2,   -- alarm this many stops early
  home_lat         double precision,
  home_lng         double precision
);
create index if not exists rider_bus_bus_idx on public.rider_bus (bus_id);

-- ---------- trips ----------
create table if not exists public.trips (
  id          uuid primary key default gen_random_uuid(),
  bus_id      text not null references public.buses (id) on delete cascade,
  driver_id   uuid references public.profiles (id) on delete set null,
  started_at  timestamptz not null default now(),
  ended_at    timestamptz
);
create index if not exists trips_open_idx on public.trips (bus_id) where ended_at is null;

-- Presence log: who is actually on the bus. Driver (or a QR scan) writes it.
create table if not exists public.boardings (
  id          uuid primary key default gen_random_uuid(),
  trip_id     uuid not null references public.trips (id) on delete cascade,
  profile_id  uuid not null references public.profiles (id) on delete cascade,
  boarded_at  timestamptz not null default now(),
  exited_at   timestamptz,
  unique (trip_id, profile_id)
);

-- ---------- live location (one row per bus, upserted) ----------
create table if not exists public.bus_locations (
  bus_id       text primary key references public.buses (id) on delete cascade,
  trip_id      uuid references public.trips (id) on delete set null,
  lat          double precision not null,
  lng          double precision not null,
  speed_kmph   double precision not null default 0,
  heading      double precision not null default 0,
  recorded_at  timestamptz not null default now()
);

-- Optional history for reports; safe to skip / prune with a cron.
create table if not exists public.location_history (
  id          bigserial primary key,
  bus_id      text not null,
  trip_id     uuid,
  lat         double precision not null,
  lng         double precision not null,
  speed_kmph  double precision not null default 0,
  recorded_at timestamptz not null default now()
);
create index if not exists location_history_bus_time_idx
  on public.location_history (bus_id, recorded_at desc);

-- ---------- alert subscriptions ----------
create table if not exists public.alert_subscriptions (
  profile_id     uuid primary key references public.profiles (id) on delete cascade,
  bus_id         text not null references public.buses (id) on delete cascade,
  stop_id        uuid references public.stops (id) on delete set null,
  threshold_m    int  not null default 500,
  lead_stops     int  not null default 2,
  target_lat     double precision not null,
  target_lng     double precision not null,
  enabled        boolean not null default true,
  fcm_token      text,
  timezone       text not null default 'Asia/Kolkata',
  last_fired_at  timestamptz,                  -- cooldown, NOT once-per-day
  updated_at     timestamptz not null default now()
);
create index if not exists alert_bus_idx on public.alert_subscriptions (bus_id) where enabled;

-- ===========================================================================
-- Helper functions
-- ===========================================================================
create or replace function public.my_role() returns app_role
language sql stable security definer set search_path = public as $$
  select role from public.profiles where id = auth.uid();
$$;

create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce(public.my_role() = 'admin', false);
$$;

-- Buses the caller may write to (their assigned bus as a driver).
create or replace function public.drives_bus(p_bus text) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.buses b
                 where b.id = p_bus and b.driver_id = auth.uid());
$$;

-- Metres between two lat/lng pairs (haversine, no PostGIS needed).
create or replace function public.distance_m(
  lat1 double precision, lng1 double precision,
  lat2 double precision, lng2 double precision)
returns double precision language sql immutable as $$
  select 6371000 * 2 * asin(sqrt(
    power(sin(radians(lat2 - lat1) / 2), 2) +
    cos(radians(lat1)) * cos(radians(lat2)) *
    power(sin(radians(lng2 - lng1) / 2), 2)));
$$;

-- ---------- trip lifecycle + location write (called by the driver app) ----------
create or replace function public.start_trip(p_bus text)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_id uuid;
begin
  if not public.drives_bus(p_bus) and not public.is_admin() then
    raise exception 'not the assigned driver for %', p_bus;
  end if;
  update public.trips set ended_at = now()
    where bus_id = p_bus and ended_at is null;
  insert into public.trips (bus_id, driver_id) values (p_bus, auth.uid())
    returning id into v_id;
  return v_id;
end $$;

create or replace function public.end_trip(p_bus text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.drives_bus(p_bus) and not public.is_admin() then
    raise exception 'not the assigned driver for %', p_bus;
  end if;
  update public.trips set ended_at = now()
    where bus_id = p_bus and ended_at is null;
  delete from public.bus_locations where bus_id = p_bus;  -- stop showing a ghost bus
end $$;

-- Single entry point for GPS writes: validates the driver, upserts the live
-- row and appends history in one round trip.
create or replace function public.record_location(
  p_bus text, p_lat double precision, p_lng double precision,
  p_speed double precision default 0, p_heading double precision default 0,
  p_recorded_at timestamptz default now())
returns void language plpgsql security definer set search_path = public as $$
declare v_trip uuid;
begin
  if not public.drives_bus(p_bus) and not public.is_admin() then
    raise exception 'not the assigned driver for %', p_bus;
  end if;
  select id into v_trip from public.trips
    where bus_id = p_bus and ended_at is null
    order by started_at desc limit 1;

  insert into public.bus_locations
      (bus_id, trip_id, lat, lng, speed_kmph, heading, recorded_at)
  values (p_bus, v_trip, p_lat, p_lng, p_speed, p_heading, p_recorded_at)
  on conflict (bus_id) do update set
      trip_id = excluded.trip_id,
      lat = excluded.lat, lng = excluded.lng,
      speed_kmph = excluded.speed_kmph, heading = excluded.heading,
      recorded_at = excluded.recorded_at;

  insert into public.location_history
      (bus_id, trip_id, lat, lng, speed_kmph, recorded_at)
  values (p_bus, v_trip, p_lat, p_lng, p_speed, p_recorded_at);
end $$;

-- ---------- admin helpers ----------
-- Roster for a bus with an on-board flag, used by the admin screen.
create or replace function public.bus_roster(p_bus text)
returns table (
  profile_id uuid, full_name text, rider_type rider_kind,
  roll_no text, stop_name text, on_bus boolean)
language sql stable security definer set search_path = public as $$
  with trip as (
    select id from public.trips
     where bus_id = p_bus and ended_at is null
     order by started_at desc limit 1)
  select p.id, p.full_name, p.rider_type, p.roll_no, s.name,
         exists (select 1 from public.boardings b
                  where b.profile_id = p.id
                    and b.trip_id = (select id from trip)
                    and b.exited_at is null)
    from public.rider_bus rb
    join public.profiles p on p.id = rb.profile_id
    left join public.stops s on s.id = rb.stop_id
   where rb.bus_id = p_bus and p.active
   order by p.rider_type, p.full_name;
$$;

create or replace function public.mark_boarding(p_profile uuid, p_on boolean)
returns void language plpgsql security definer set search_path = public as $$
declare v_bus text; v_trip uuid;
begin
  select bus_id into v_bus from public.rider_bus where profile_id = p_profile;
  if v_bus is null then raise exception 'rider has no bus'; end if;
  if not public.drives_bus(v_bus) and not public.is_admin() then
    raise exception 'not allowed'; end if;
  select id into v_trip from public.trips
    where bus_id = v_bus and ended_at is null order by started_at desc limit 1;
  if v_trip is null then raise exception 'no active trip'; end if;

  if p_on then
    insert into public.boardings (trip_id, profile_id) values (v_trip, p_profile)
    on conflict (trip_id, profile_id) do update set exited_at = null;
  else
    update public.boardings set exited_at = now()
      where trip_id = v_trip and profile_id = p_profile and exited_at is null;
  end if;
end $$;

-- ===========================================================================
-- Row Level Security
-- ===========================================================================
alter table public.profiles            enable row level security;
alter table public.routes              enable row level security;
alter table public.stops               enable row level security;
alter table public.buses               enable row level security;
alter table public.rider_bus           enable row level security;
alter table public.trips               enable row level security;
alter table public.boardings           enable row level security;
alter table public.bus_locations       enable row level security;
alter table public.location_history    enable row level security;
alter table public.alert_subscriptions enable row level security;

-- profiles: you see yourself; admins see and manage everyone.
drop policy if exists profiles_self_read on public.profiles;
create policy profiles_self_read on public.profiles
  for select using (id = auth.uid() or public.is_admin());
drop policy if exists profiles_self_update on public.profiles;
create policy profiles_self_update on public.profiles
  for update using (id = auth.uid() or public.is_admin())
  with check (id = auth.uid() or public.is_admin());
drop policy if exists profiles_admin_write on public.profiles;
create policy profiles_admin_write on public.profiles
  for insert with check (public.is_admin());
drop policy if exists profiles_admin_delete on public.profiles;
create policy profiles_admin_delete on public.profiles
  for delete using (public.is_admin());

-- reference data: readable by any signed-in user, writable by admins only.
do $$
declare t text;
begin
  foreach t in array array['routes','stops','buses','rider_bus'] loop
    execute format('drop policy if exists %1$s_read on public.%1$s', t);
    execute format('create policy %1$s_read on public.%1$s for select to authenticated using (true)', t);
    execute format('drop policy if exists %1$s_admin on public.%1$s', t);
    execute format('create policy %1$s_admin on public.%1$s for all using (public.is_admin()) with check (public.is_admin())', t);
  end loop;
end $$;

-- live location: any signed-in user may read (the map). Writes only happen
-- through record_location(), so no direct insert/update policy is granted.
drop policy if exists bus_locations_read on public.bus_locations;
create policy bus_locations_read on public.bus_locations
  for select to authenticated using (true);

drop policy if exists trips_read on public.trips;
create policy trips_read on public.trips for select to authenticated using (true);

drop policy if exists boardings_read on public.boardings;
create policy boardings_read on public.boardings
  for select to authenticated using (
    profile_id = auth.uid() or public.is_admin()
    or exists (select 1 from public.trips t join public.buses b on b.id = t.bus_id
                where t.id = trip_id and b.driver_id = auth.uid()));

drop policy if exists history_admin_read on public.location_history;
create policy history_admin_read on public.location_history
  for select using (public.is_admin());

-- alert subscriptions: strictly your own row (the Firebase version let anyone
-- overwrite anyone's alert).
drop policy if exists alerts_own on public.alert_subscriptions;
create policy alerts_own on public.alert_subscriptions
  for all using (profile_id = auth.uid() or public.is_admin())
  with check (profile_id = auth.uid() or public.is_admin());

-- ===========================================================================
-- Realtime
-- ===========================================================================
alter table public.bus_locations replica identity full;
alter publication supabase_realtime add table public.bus_locations;

-- ===========================================================================
-- Scheduled proximity check (calls the Edge Function every minute).
-- Requires pg_cron + pg_net (enable both under Database > Extensions) and
-- Vault entries for the project URL and service-role key.
-- ===========================================================================
-- select cron.schedule('proximity-alarm', '* * * * *', $$
--   select net.http_post(
--     url := 'https://<project-ref>.supabase.co/functions/v1/proximity-alarm',
--     headers := jsonb_build_object(
--       'Content-Type','application/json',
--       'Authorization','Bearer <service-role-key>'),
--     body := '{}'::jsonb) $$);
