-- ---------------------------------------------------------------------------
-- 003_grant_role_helpers.sql
--
-- Follow-up to 002_harden_grants.sql.
--
-- 002 revoked EXECUTE on the helper functions from PUBLIC to silence the
-- Supabase security advisor. That was too broad: three helpers are called by
-- ordinary signed-in clients, not just from inside other SECURITY DEFINER
-- functions.
--
--   is_admin()      AuthService calls it after login to decide whether to show
--                   the admin screen.
--   my_role()       Same, for the rider/driver split.
--   drives_bus(text) Referenced by RLS policies, which evaluate it as the
--                   invoking role rather than the function owner.
--
-- Symptom before this file: sign-in fails with
--   PostgrestException(code: 42501, message: permission denied for function
--   is_admin)
--
-- anon is deliberately left without EXECUTE. All three read the caller's own
-- profile row via auth.uid(), so they return nothing useful without a session
-- and there is no reason to leave them probeable by unauthenticated traffic.
-- ---------------------------------------------------------------------------

grant execute on function public.is_admin() to authenticated;
grant execute on function public.my_role() to authenticated;
grant execute on function public.drives_bus(text) to authenticated;

revoke execute on function public.is_admin() from anon;
revoke execute on function public.my_role() from anon;
revoke execute on function public.drives_bus(text) from anon;

-- Verify:
--   select p.proname,
--          has_function_privilege('authenticated', p.oid, 'execute') as auth_ok,
--          has_function_privilege('anon', p.oid, 'execute')          as anon_ok
--     from pg_proc p
--     join pg_namespace n on n.oid = p.pronamespace
--    where n.nspname = 'public'
--      and p.proname in ('is_admin', 'my_role', 'drives_bus');
--
-- Expected: auth_ok = true, anon_ok = false for all three.
