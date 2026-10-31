// manage-staff: the owner adds staff, changes their role and switches them
// off. Creating auth users needs the service role, which must never reach a
// browser, so the admin panel calls this function with the owner's own JWT
// and the function checks that JWT belongs to an active owner.
//
// POST { action: 'list' }
// POST { action: 'invite', email, name, role, method?: 'password' | 'invite', redirectTo? }
// POST { action: 'set_role', user_id, role }
// POST { action: 'deactivate', user_id }
// POST { action: 'reactivate', user_id }

import { createClient } from 'npm:@supabase/supabase-js@2';
import { cleanText, isEmail, isStaffRole, isUuid, newTempPassword } from '../_shared/lead.ts';
import { corsHeaders, json, parseOrigins, preflight, readJson } from '../_shared/http.ts';

// Long enough to mean "until switched back on"; Supabase takes a duration.
const BAN_FOREVER = '876000h';

const allowed = parseOrigins(Deno.env.get('ALLOWED_ORIGINS'));
const db = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, {
  auth: { persistSession: false, autoRefreshToken: false },
});

type Body = Record<string, unknown>;

class Refusal extends Error {
  status: number;
  constructor(code: string, status = 400) {
    super(code);
    this.status = status;
  }
}

async function audit(actor: string, action: string, detail: Record<string, unknown>) {
  const { error } = await db.from('audit_log').insert({ actor, action, detail });
  if (error) throw error;
}

async function activeOwnerCount(): Promise<number> {
  const { count, error } = await db.from('staff').select('user_id', { count: 'exact', head: true })
    .eq('role', 'owner').eq('active', true);
  if (error) throw error;
  return count ?? 0;
}

async function staffRow(userId: string) {
  const { data, error } = await db.from('staff').select('user_id, name, role, active')
    .eq('user_id', userId).maybeSingle();
  if (error) throw error;
  if (!data) throw new Refusal('no_such_staff', 404);
  return data as { user_id: string; name: string; role: string; active: boolean };
}

async function list() {
  const { data: staff, error } = await db.from('staff')
    .select('user_id, name, role, active, created_at').order('created_at');
  if (error) throw error;
  // Emails live in auth.users, which only the service role can read. A
  // team is small enough for one page.
  const { data: users, error: uErr } = await db.auth.admin.listUsers({ page: 1, perPage: 1000 });
  if (uErr) throw uErr;
  const byId = new Map(users.users.map((u) => [u.id, u]));
  return {
    staff: (staff ?? []).map((s) => ({
      ...s,
      email: byId.get(s.user_id)?.email ?? null,
      last_sign_in_at: byId.get(s.user_id)?.last_sign_in_at ?? null,
    })),
  };
}

async function invite(actor: string, b: Body) {
  const email = typeof b.email === 'string' ? b.email.trim().toLowerCase() : '';
  const name = cleanText(b.name, 80);
  const role = b.role;
  if (!isEmail(email)) throw new Refusal('email');
  if (!name) throw new Refusal('name');
  if (!isStaffRole(role)) throw new Refusal('role');
  const method = b.method === 'invite' ? 'invite' : 'password';

  // Someone who already has an account (signed up, or was staff before) is
  // added as they are, with no new password.
  const { data: existingId, error: lookErr } = await db.rpc('staff_user_id_by_email', { email });
  if (lookErr) throw lookErr;
  let userId = existingId as string | null;
  let tempPassword: string | null = null;
  let created = false;

  if (userId) {
    const { data: already } = await db.from('staff').select('user_id').eq('user_id', userId).maybeSingle();
    if (already) throw new Refusal('already_staff', 409);
  } else if (method === 'invite') {
    // Needs working email: Supabase's built-in mailer only delivers to the
    // project's own team members, so 'password' is the default.
    const redirectTo = typeof b.redirectTo === 'string' && /^https:\/\//.test(b.redirectTo) ? b.redirectTo : undefined;
    const { data, error } = await db.auth.admin.inviteUserByEmail(email, { redirectTo, data: { name } });
    if (error) throw new Refusal('invite_failed: ' + error.message, 502);
    userId = data.user.id;
    created = true;
  } else {
    tempPassword = newTempPassword();
    const { data, error } = await db.auth.admin.createUser({
      email, password: tempPassword, email_confirm: true, user_metadata: { name },
    });
    if (error) throw new Refusal('create_failed: ' + error.message, 502);
    userId = data.user.id;
    created = true;
  }

  const { error: insErr } = await db.from('staff').insert({ user_id: userId, name, role, active: true });
  if (insErr) {
    // Do not leave an account behind that is not staff.
    if (created) await db.auth.admin.deleteUser(userId!);
    throw insErr;
  }
  await audit(actor, 'staff_invite', { user_id: userId, email, role, method: created ? method : 'existing' });
  // The temporary password is returned this once and stored nowhere.
  return { user_id: userId, existing: !created, tempPassword };
}

async function setRole(actor: string, b: Body) {
  if (!isUuid(b.user_id)) throw new Refusal('user_id');
  if (!isStaffRole(b.role)) throw new Refusal('role');
  const target = await staffRow(b.user_id);
  if (target.role === b.role) return { ok: true };
  if (target.role === 'owner' && target.active && (await activeOwnerCount()) <= 1) {
    throw new Refusal('last_owner', 409);
  }
  const { error } = await db.from('staff').update({ role: b.role }).eq('user_id', b.user_id);
  if (error) throw error;
  await audit(actor, 'staff_set_role', { user_id: b.user_id, from: target.role, to: b.role });
  return { ok: true };
}

async function setActive(actor: string, b: Body, active: boolean) {
  if (!isUuid(b.user_id)) throw new Refusal('user_id');
  if (!active && b.user_id === actor) throw new Refusal('self', 409);
  const target = await staffRow(b.user_id);
  if (!active && target.role === 'owner' && target.active && (await activeOwnerCount()) <= 1) {
    throw new Refusal('last_owner', 409);
  }
  const { error } = await db.from('staff').update({ active }).eq('user_id', b.user_id);
  if (error) throw error;
  // RLS already shuts an inactive member out; the ban also stops them
  // signing in at all.
  const { error: banErr } = await db.auth.admin.updateUserById(b.user_id, {
    ban_duration: active ? 'none' : BAN_FOREVER,
  });
  if (banErr) console.error('manage-staff ban failed:', banErr.message);

  let released = 0;
  if (!active) {
    // Their open leads go back to the pool so another caller can pick them up.
    const { data, error: relErr } = await db.from('leads').update({ assigned_to: null })
      .eq('assigned_to', b.user_id).in('status', ['new', 'contacted', 'interested']).select('id');
    if (relErr) throw relErr;
    released = data?.length ?? 0;
  }
  await audit(actor, active ? 'staff_reactivate' : 'staff_deactivate', { user_id: b.user_id, released });
  return { ok: true, released };
}

Deno.serve(async (req) => {
  const early = preflight(req, allowed);
  if (early) return early;
  const cors = corsHeaders(req, allowed);

  try {
    const token = (req.headers.get('authorization') ?? '').replace(/^Bearer\s+/i, '');
    const { data: auth, error: authErr } = await db.auth.getUser(token);
    if (authErr || !auth?.user) return json({ error: 'auth' }, 401, cors);
    const actor = auth.user.id;

    const { data: me, error: meErr } = await db.from('staff').select('role, active')
      .eq('user_id', actor).maybeSingle();
    if (meErr) throw meErr;
    if (!me || !me.active || me.role !== 'owner') return json({ error: 'forbidden' }, 403, cors);

    const body = (await readJson(req, 8192)) as Body | null;
    if (!body || typeof body !== 'object') return json({ error: 'invalid' }, 400, cors);

    switch (body.action) {
      case 'list': return json(await list(), 200, cors);
      case 'invite': return json(await invite(actor, body), 200, cors);
      case 'set_role': return json(await setRole(actor, body), 200, cors);
      case 'deactivate': return json(await setActive(actor, body, false), 200, cors);
      case 'reactivate': return json(await setActive(actor, body, true), 200, cors);
      default: return json({ error: 'action' }, 400, cors);
    }
  } catch (e) {
    if (e instanceof Refusal) return json({ error: e.message }, e.status, cors);
    console.error('manage-staff failed:', (e as { message?: string })?.message ?? e);
    return json({ error: 'server' }, 500, cors);
  }
});
