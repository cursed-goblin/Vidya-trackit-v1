// ---------------------------------------------------------------------------
// Vidya TrackIt - admin user management (Supabase Edge Function, Deno)
//
// Creating or deleting an auth user needs the service-role key, which must
// never live in the app. The admin screen calls this function instead; the
// caller's JWT is verified and their profiles.role must be 'admin'.
//
// POST { action: 'create', email, password, full_name, rider_type,
//        roll_no?, department?, guardian_phone?, bus_id, stop_id?, lead_stops? }
// POST { action: 'delete', profile_id }
// ---------------------------------------------------------------------------

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const url = Deno.env.get("SUPABASE_URL")!;
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;

const admin = createClient(url, serviceKey, { auth: { persistSession: false } });

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("method", { status: 405 });

  const authHeader = req.headers.get("Authorization") ?? "";
  const caller = createClient(url, anonKey, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false },
  });
  const { data: me } = await caller.auth.getUser();
  if (!me?.user) return Response.json({ error: "unauthenticated" }, { status: 401 });

  const { data: profile } = await admin
    .from("profiles").select("role").eq("id", me.user.id).maybeSingle();
  if (profile?.role !== "admin") {
    return Response.json({ error: "admin only" }, { status: 403 });
  }

  const body = await req.json();
  try {
    if (body.action === "create") return Response.json(await create(body));
    if (body.action === "delete") return Response.json(await remove(body));
    return Response.json({ error: "unknown action" }, { status: 400 });
  } catch (e) {
    console.error(e);
    return Response.json({ error: String(e) }, { status: 400 });
  }
});

async function create(b: Record<string, unknown>) {
  const { data, error } = await admin.auth.admin.createUser({
    email: String(b.email),
    password: String(b.password),
    email_confirm: true,
  });
  if (error) throw error;
  const id = data.user!.id;

  const { error: pErr } = await admin.from("profiles").insert({
    id,
    role: "rider",
    rider_type: b.rider_type ?? "student",
    full_name: b.full_name,
    roll_no: b.roll_no ?? null,
    department: b.department ?? null,
    guardian_phone: b.guardian_phone ?? null,
  });
  if (pErr) {
    await admin.auth.admin.deleteUser(id); // don't leave an orphan auth user
    throw pErr;
  }

  if (b.bus_id) {
    const { error: rErr } = await admin.from("rider_bus").insert({
      profile_id: id,
      bus_id: b.bus_id,
      stop_id: b.stop_id ?? null,
      lead_stops: b.lead_stops ?? 2,
    });
    if (rErr) throw rErr;
  }
  return { ok: true, profile_id: id };
}

async function remove(b: Record<string, unknown>) {
  const id = String(b.profile_id);
  // profiles / rider_bus / alert_subscriptions cascade from auth.users.
  const { error } = await admin.auth.admin.deleteUser(id);
  if (error) throw error;
  return { ok: true };
}
