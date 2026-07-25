-- ===========================================================================
-- Applied after schema.sql. Fixes what the Supabase security advisor flags on
-- a fresh install: every SECURITY DEFINER function is exposed through
-- /rest/v1/rpc to the anon role by default.
--
-- The functions all check auth.uid() internally, so an anonymous call would
-- have failed anyway - but the endpoints should not be reachable at all.
-- ===========================================================================

-- Pin the search_path (linter 0011).
create or replace function public.distance_m(
  lat1 double precision, lng1 double precision,
  lat2 double precision, lng2 double precision)
returns double precision language sql immutable
set search_path = pg_catalog, public as $$
  select 6371000 * 2 * asin(sqrt(
    power(sin(radians(lat2 - lat1) / 2), 2) +
    cos(radians(lat1)) * cos(radians(lat2)) *
    power(sin(radians(lng2 - lng1) / 2), 2)));
$$;

-- Nothing callable by anon (linter 0028).
revoke execute on function public.record_location(text, double precision, double precision, double precision, double precision, timestamptz) from anon, public;
revoke execute on function public.start_trip(text)             from anon, public;
revoke execute on function public.end_trip(text)               from anon, public;
revoke execute on function public.mark_boarding(uuid, boolean) from anon, public;
revoke execute on function public.bus_roster(text)             from anon, public;
revoke execute on function public.drives_bus(text)             from anon, public;
revoke execute on function public.is_admin()                   from anon, public;
revoke execute on function public.my_role()                    from anon, public;

-- Internal helpers are only needed by the RLS policies, which run as the
-- definer - no API caller should be able to invoke them directly.
revoke execute on function public.drives_bus(text) from authenticated;
revoke execute on function public.is_admin()       from authenticated;
revoke execute on function public.my_role()        from authenticated;

-- The app calls these with a signed-in user's JWT.
grant execute on function public.record_location(text, double precision, double precision, double precision, double precision, timestamptz) to authenticated;
grant execute on function public.start_trip(text)             to authenticated;
grant execute on function public.end_trip(text)               to authenticated;
grant execute on function public.mark_boarding(uuid, boolean) to authenticated;
grant execute on function public.bus_roster(text)             to authenticated;

-- Edge Functions run as service_role.
grant execute on function public.record_location(text, double precision, double precision, double precision, double precision, timestamptz) to service_role;
grant execute on function public.start_trip(text)             to service_role;
grant execute on function public.end_trip(text)               to service_role;
grant execute on function public.mark_boarding(uuid, boolean) to service_role;
grant execute on function public.bus_roster(text)             to service_role;

-- Extensions needed by the alarm cron.
create extension if not exists pg_cron with schema pg_catalog;
create extension if not exists pg_net  with schema extensions;
