-- ---------------------------------------------------------------------------
-- Demo seed: 1 bus, 1 route with 8 stops, 5 students + 2 teachers.
-- Create the auth users first (Dashboard > Authentication > Add user, or the
-- admin API), then paste their UUIDs below.
-- ---------------------------------------------------------------------------
insert into public.routes (id, name)
values ('11111111-1111-1111-1111-111111111111',
        'Route 12 - Thrissur Town to Vidya Engineering College')
on conflict do nothing;

insert into public.stops (route_id, name, lat, lng, seq) values
  ('11111111-1111-1111-1111-111111111111', 'Town Centre',  10.5210, 76.2100, 1),
  ('11111111-1111-1111-1111-111111111111', 'Market Road',  10.5240, 76.2120, 2),
  ('11111111-1111-1111-1111-111111111111', 'Rail Gate',    10.5276, 76.2144, 3),
  ('11111111-1111-1111-1111-111111111111', 'Hospital Jn',  10.5320, 76.2180, 4),
  ('11111111-1111-1111-1111-111111111111', 'Bridge Stop',  10.5375, 76.2225, 5),
  ('11111111-1111-1111-1111-111111111111', 'Temple Road',  10.5430, 76.2270, 6),
  ('11111111-1111-1111-1111-111111111111', 'Tech Park',    10.5490, 76.2320, 7),
  ('11111111-1111-1111-1111-111111111111', 'Campus Gate',  10.5560, 76.2380, 8)
on conflict do nothing;

insert into public.buses (id, reg_no, route_id)
values ('bus_12', 'KL-08 AV 4412', '11111111-1111-1111-1111-111111111111')
on conflict (id) do update set reg_no = excluded.reg_no;

-- Example: promote yourself to admin after signing up once.
-- update public.profiles set role = 'admin', rider_type = null
--  where id = '<your-auth-uid>';

-- Example: attach the driver to the bus.
-- update public.buses set driver_id = '<driver-auth-uid>' where id = 'bus_12';
