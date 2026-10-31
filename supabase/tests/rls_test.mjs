// Runs the funnel migration in PGlite (Postgres compiled to WASM) against a
// small stand-in for Supabase's auth schema and roles, then checks that each
// role sees and can do exactly what docs/funnel/CONTRACT.md says.
//
// PGlite is not a dependency of the app, so install it anywhere outside the
// repo and point PGLITE_DIR at that folder:
//
//   mkdir -p /tmp/pglite && (cd /tmp/pglite && npm i @electric-sql/pglite)
//   PGLITE_DIR=/tmp/pglite node supabase/tests/rls_test.mjs

import { readFileSync, readdirSync } from 'node:fs';
import { createRequire } from 'node:module';
import { dirname, join } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import assert from 'node:assert/strict';

const here = dirname(fileURLToPath(import.meta.url));

async function loadPGlite() {
  try {
    return (await import('@electric-sql/pglite')).PGlite;
  } catch {
    const dir = process.env.PGLITE_DIR;
    if (!dir) throw new Error('PGlite not found: set PGLITE_DIR (see the top of this file)');
    const require = createRequire(join(dir, 'package.json'));
    const entry = require.resolve('@electric-sql/pglite').replace(/index\.cjs$/, 'index.js');
    return (await import(pathToFileURL(entry).href)).PGlite;
  }
}

// What a hosted Supabase project has before any migration of ours: the auth
// schema with auth.uid() reading the JWT's subject, the three API roles, and
// default privileges that hand anon and authenticated every new table and
// function in public (which is why the migration has to revoke).
const SUPABASE_STUB = `
  create role anon nologin;
  create role authenticated nologin;
  create role service_role nologin bypassrls;
  create schema auth;
  create table auth.users (id uuid primary key default gen_random_uuid(), email text unique);
  create function auth.uid() returns uuid language sql stable as $$
    select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid
  $$;
  grant usage on schema public, auth to anon, authenticated, service_role;
  grant execute on function auth.uid() to anon, authenticated, service_role;
  alter default privileges in schema public grant all on tables to anon, authenticated, service_role;
  alter default privileges in schema public grant all on sequences to anon, authenticated, service_role;
  alter default privileges in schema public grant all on functions to anon, authenticated, service_role;
`;

const PGlite = await loadPGlite();
const db = new PGlite();
await db.exec(SUPABASE_STUB);
// Every migration, in order, as `supabase db push` applies them.
for (const f of readdirSync(join(here, '../migrations')).filter((n) => n.endsWith('.sql')).sort()) {
  await db.exec(readFileSync(join(here, '../migrations', f), 'utf8'));
}

// ---------------------------------------------------------------------------
// Session helpers: run statements as a role with a given auth.uid().

async function as(role, uid, fn) {
  await db.exec('reset role');
  await db.query(`select set_config('request.jwt.claim.sub', $1, false)`, [uid ?? '']);
  await db.exec(`set role ${role}`);
  try {
    return await fn();
  } finally {
    await db.exec('reset role');
    await db.query(`select set_config('request.jwt.claim.sub', '', false)`);
  }
}
const q = async (sql, params) => (await db.query(sql, params)).rows;

async function fails(promise, pattern) {
  try {
    await promise;
  } catch (e) {
    if (pattern) assert.match(String(e.message), pattern);
    return;
  }
  assert.fail(`expected an error matching ${pattern}`);
}

let passed = 0;
let failed = 0;
async function test(name, fn) {
  try {
    await fn();
    passed++;
    console.log(`ok   ${name}`);
  } catch (e) {
    failed++;
    console.log(`FAIL ${name}\n     ${e.message}`);
  }
}

// ---------------------------------------------------------------------------
// Fixtures

const users = {};
for (const who of ['owner', 'manager', 'caller1', 'caller2', 'outsider', 'former']) {
  const [{ id }] = await q(`insert into auth.users (email) values ($1) returning id`, [`${who}@example.com`]);
  users[who] = id;
}
await q(`insert into staff (user_id, name, role) values
  ($1, 'Owner', 'owner'), ($2, 'Manager', 'manager'),
  ($3, 'Caller One', 'caller'), ($4, 'Caller Two', 'caller')`,
  [users.owner, users.manager, users.caller1, users.caller2]);
await q(`insert into staff (user_id, name, role, active) values ($1, 'Former', 'manager', false)`,
  [users.former]);

// Leads are created the way the edge function creates them: as service_role.
async function makeLead(code, extra = {}) {
  return as('service_role', null, async () => {
    const lead = {
      code, name: 'राम ' + code, phone: '98765' + code.slice(-5), birth_date: '1990-05-17',
      birth_time: '06:45', time_approx: false, place_name: 'Jaipur', lat: 26.9, lon: 75.8,
      tz: 'Asia/Kolkata', utc_offset_min: 330, kundli: { rashi: 'वृषभ' }, lang: 'hi',
      src: 'temple-a', ip: '203.0.113.7', user_agent: 'Test/1.0', consent_version: '2026-10-31',
      ...extra,
    };
    const [{ id }] = await q(`select funnel_create_lead($1::jsonb, $2) as id`,
      [JSON.stringify(lead), 'pw' + code.slice(-4)]);
    await q(`insert into lead_events (lead_id, event, ip) values ($1, 'pdf_download', '203.0.113.7')`, [id]);
    return id;
  });
}
const L1 = await makeLead('KS-100001');                      // unassigned
const L2 = await makeLead('KS-100002', { src: 'shop-b' });   // caller1's
const L3 = await makeLead('KS-100003');                      // caller2's
await q(`update leads set assigned_to = $1 where id = $2`, [users.caller1, L2]);
await q(`update leads set assigned_to = $1 where id = $2`, [users.caller2, L3]);

const visibleCodes = async () => (await q(`select code from leads order by code`)).map((r) => r.code);
const yearRange = [`2000-01-01T00:00:00Z`, `2100-01-01T00:00:00Z`];

// ---------------------------------------------------------------------------
// anon: the public key on the landing page

await test('anon cannot select leads', () =>
  as('anon', null, () => fails(q(`select * from leads`), /permission denied/)));
await test('anon cannot select lead_secrets, events, activity, staff, audit_log', () =>
  as('anon', null, async () => {
    for (const t of ['lead_secrets', 'lead_events', 'lead_activity', 'staff', 'audit_log']) {
      await fails(q(`select * from ${t}`), /permission denied/);
    }
  }));
await test('anon cannot insert a lead or an event', () =>
  as('anon', null, async () => {
    await fails(q(`insert into leads (code) values ('KS-999999')`), /permission denied/);
    await fails(q(`insert into lead_events (lead_id, event) values ($1, 'pdf_download')`, [L1]), /permission denied/);
  }));
await test('anon cannot execute any funnel function', () =>
  as('anon', null, async () => {
    await fails(q(`select reveal_password($1)`, [L1]), /permission denied/);
    await fails(q(`select lead_stats(now() - interval '1 day', now())`), /permission denied/);
    await fails(q(`select funnel_create_lead('{}'::jsonb, 'x')`), /permission denied/);
    await fails(q(`select staff_user_id_by_email('owner@example.com')`), /permission denied/);
    await fails(q(`select erase_lead($1)`, [L1]), /permission denied/);
  }));

// ---------------------------------------------------------------------------
// A signed-in user who is not staff (anyone can sign up to a Supabase project
// unless sign-ups are turned off, so this must hold too)

await test('non-staff user sees no leads and no staff', () =>
  as('authenticated', users.outsider, async () => {
    assert.deepEqual(await visibleCodes(), []);
    assert.equal((await q(`select * from staff`)).length, 0);
    assert.equal((await q(`select * from lead_events`)).length, 0);
  }));
await test('non-staff user cannot read lead_secrets or write tables', () =>
  as('authenticated', users.outsider, async () => {
    await fails(q(`select * from lead_secrets`), /permission denied/);
    await fails(q(`update leads set status = 'paid'`), /permission denied/);
    await fails(q(`insert into staff (user_id, name, role) values ($1, 'Me', 'owner')`, [users.outsider]), /permission denied/);
    await fails(q(`delete from leads`), /permission denied/);
  }));
await test('non-staff user is refused by every RPC', () =>
  as('authenticated', users.outsider, async () => {
    await fails(q(`select reveal_password($1)`, [L1]), /not_staff/);
    await fails(q(`select take_lead($1)`, [L1]), /not_staff/);
    await fails(q(`select lead_stats(now() - interval '1 day', now())`), /not_staff/);
    await fails(q(`select funnel_create_lead('{}'::jsonb, 'x')`), /permission denied/);
  }));
await test('deactivated staff member sees nothing and is refused', () =>
  as('authenticated', users.former, async () => {
    assert.deepEqual(await visibleCodes(), []);
    await fails(q(`select reveal_password($1)`, [L1]), /not_staff/);
  }));

// ---------------------------------------------------------------------------
// caller

await test('caller sees only assigned-to-them and unassigned leads', () =>
  as('authenticated', users.caller1, async () => {
    assert.deepEqual(await visibleCodes(), ['KS-100001', 'KS-100002']);
    const ev = await q(`select lead_id from lead_events`);
    assert.ok(ev.every((r) => r.lead_id !== L3), 'saw an event of another caller\'s lead');
  }));
await test('caller cannot read lead_secrets or update leads directly', () =>
  as('authenticated', users.caller1, async () => {
    await fails(q(`select * from lead_secrets`), /permission denied/);
    await fails(q(`update leads set status = 'paid' where id = $1`, [L2]), /permission denied/);
  }));
await test('caller can reveal the password of a lead they see', () =>
  as('authenticated', users.caller1, async () => {
    const [{ pw }] = await q(`select reveal_password($1) as pw`, [L2]);
    assert.equal(pw, 'pw0002');
  }));
await test('caller is refused another caller\'s password, and the attempt is logged', async () => {
  const [{ pw }] = await as('authenticated', users.caller1, () => q(`select reveal_password($1) as pw`, [L3]));
  assert.equal(pw, null);
  const log = await q(`select actor, action from audit_log where lead_id = $1`, [L3]);
  assert.deepEqual(log, [{ actor: users.caller1, action: 'reveal_password_denied' }]);
});
await test('successful reveal is in audit_log with the actor', async () => {
  const log = await q(`select actor, action, detail->>'code' as code from audit_log where lead_id = $1`, [L2]);
  assert.deepEqual(log, [{ actor: users.caller1, action: 'reveal_password', code: 'KS-100002' }]);
});
await test('caller cannot read audit_log, stats, assign or erase', () =>
  as('authenticated', users.caller1, async () => {
    assert.equal((await q(`select * from audit_log`)).length, 0);
    await fails(q(`select lead_stats($1, $2)`, yearRange), /forbidden/);
    await fails(q(`select assign_lead($1, $2)`, [L1, users.caller1]), /forbidden/);
    await fails(q(`select erase_lead($1)`, [L1]), /forbidden/);
  }));
await test('caller cannot change status of a lead they do not see', () =>
  as('authenticated', users.caller1, () =>
    fails(q(`select set_lead_status($1, 'contacted', null)`, [L3]), /lead_not_found/)));
await test('caller takes an unassigned lead; the other caller then loses sight of it', async () => {
  await as('authenticated', users.caller1, () => q(`select take_lead($1)`, [L1]));
  const [{ assigned_to }] = await q(`select assigned_to from leads where id = $1`, [L1]);
  assert.equal(assigned_to, users.caller1);
  await as('authenticated', users.caller2, async () => {
    assert.deepEqual(await visibleCodes(), ['KS-100003']);
    await fails(q(`select take_lead($1)`, [L1]), /lead_not_found/);
    await fails(q(`select add_note($1, 'hi')`, [L1]), /lead_not_found/);
    assert.equal((await q(`select * from lead_activity where lead_id = $1`, [L1])).length, 0);
  });
});
await test('caller changes status, adds a note, logs a call and records a payment', async () => {
  const before = (await q(`select updated_at from leads where id = $1`, [L1]))[0].updated_at;
  await as('authenticated', users.caller1, async () => {
    await q(`select set_lead_status($1, 'contacted', 'बात हुई')`, [L1]);
    await q(`select add_note($1, 'Call back Sunday')`, [L1]);
    await q(`select log_call($1, null)`, [L1]);
    await q(`select record_payment($1, 500, 'UPI')`, [L1]);
    await fails(q(`select record_payment($1, 0, null)`, [L1]), /bad_amount/);
    await fails(q(`select add_note($1, '   ')`, [L1]), /empty_note/);
  });
  const [l] = await q(`select status, amount_paid, paid_at, updated_at from leads where id = $1`, [L1]);
  assert.equal(l.status, 'paid');
  assert.equal(l.amount_paid, 500);
  assert.ok(l.paid_at);
  assert.ok(l.updated_at > before, 'updated_at did not move');
  const kinds = (await q(`select kind, actor from lead_activity where lead_id = $1 order by id`, [L1]));
  assert.deepEqual(kinds.map((k) => k.kind), ['assign', 'status', 'note', 'call', 'payment']);
  assert.ok(kinds.every((k) => k.actor === users.caller1));
});

// ---------------------------------------------------------------------------
// manager

await test('manager sees every live lead and can reveal any password', () =>
  as('authenticated', users.manager, async () => {
    assert.deepEqual(await visibleCodes(), ['KS-100001', 'KS-100002', 'KS-100003']);
    const [{ pw }] = await q(`select reveal_password($1) as pw`, [L3]);
    assert.equal(pw, 'pw0003');
  }));
await test('manager assigns, but only to active staff', async () => {
  await as('authenticated', users.manager, async () => {
    await q(`select assign_lead($1, $2)`, [L3, users.caller1]);
    await fails(q(`select assign_lead($1, $2)`, [L3, users.former]), /no_such_staff/);
    await fails(q(`select assign_lead($1, $2)`, [L3, users.outsider]), /no_such_staff/);
  });
  const [{ assigned_to }] = await q(`select assigned_to from leads where id = $1`, [L3]);
  assert.equal(assigned_to, users.caller1);
});
await test('manager gets stats; manager cannot erase or read audit_log', () =>
  as('authenticated', users.manager, async () => {
    const [{ s }] = await q(`select lead_stats($1, $2) as s`, yearRange);
    assert.deepEqual(s.totals, { leads: 3, downloads: 3, contacted: 1, paid: 1, revenue: 500 });
    const bySrc = Object.fromEntries(s.by_src.map((r) => [r.src, r.leads]));
    assert.deepEqual(bySrc, { 'temple-a': 2, 'shop-b': 1 });
    assert.equal(s.by_status.paid, 1);
    assert.equal(s.by_day.length, 1);
    await fails(q(`select erase_lead($1)`, [L1]), /forbidden/);
    assert.equal((await q(`select * from audit_log`)).length, 0);
  }));

// ---------------------------------------------------------------------------
// owner

await test('owner erases a lead: personal fields blanked, counts kept', async () => {
  await as('authenticated', users.owner, () => q(`select erase_lead($1)`, [L2]));
  const [l] = await q(`select * from leads where id = $1`, [L2]);
  for (const f of ['name', 'phone', 'birth_date', 'birth_time', 'place_name', 'lat', 'lon',
    'kundli', 'ip', 'user_agent', 'landing_url', 'assigned_to']) {
    assert.equal(l[f], null, `${f} was not blanked`);
  }
  assert.equal(l.code, 'KS-100002');
  assert.equal(l.src, 'shop-b');
  assert.ok(l.created_at && l.deleted_at);
  assert.equal((await q(`select * from lead_secrets where lead_id = $1`, [L2])).length, 0);
  const ev = await q(`select ip, user_agent from lead_events where lead_id = $1`, [L2]);
  assert.ok(ev.every((e) => e.ip === null && e.user_agent === null));
  const act = await q(`select text from lead_activity where lead_id = $1`, [L2]);
  assert.ok(act.every((a) => a.text === null));
});
await test('erased lead disappears from every staff list but still counts', async () => {
  await as('authenticated', users.owner, async () => {
    assert.deepEqual(await visibleCodes(), ['KS-100001', 'KS-100003']);
    const [{ pw }] = await q(`select reveal_password($1) as pw`, [L2]);
    assert.equal(pw, null);
    const [{ s }] = await q(`select lead_stats($1, $2) as s`, yearRange);
    assert.equal(s.totals.leads, 3);
    await fails(q(`select erase_lead($1)`, [L2]), /lead_not_found/);
  });
});
await test('owner reads the audit log, with who did what', () =>
  as('authenticated', users.owner, async () => {
    const actions = (await q(`select action from audit_log order by id`)).map((r) => r.action);
    for (const a of ['reveal_password', 'reveal_password_denied', 'record_payment', 'assign_lead', 'erase_lead']) {
      assert.ok(actions.includes(a), `missing ${a}`);
    }
  }));
await test('CSV export is logged for managers and refused for callers', async () => {
  await as('authenticated', users.manager, () => q(`select log_export(12, '{"status":"new"}'::jsonb)`));
  await as('authenticated', users.caller1, () => fails(q(`select log_export(1, null)`), /forbidden/));
  await as('anon', null, () => fails(q(`select log_export(1, null)`), /permission denied/));
  const rows = await q(`select actor, detail from audit_log where action = 'export_csv'`);
  assert.deepEqual(rows, [{ actor: users.manager, detail: { rows: 12, filters: { status: 'new' } } }]);
});
await test('nobody, not even the owner, reads lead_secrets directly', () =>
  as('authenticated', users.owner, () => fails(q(`select * from lead_secrets`), /permission denied/)));
await test('stats exclude leads outside the range', () =>
  as('authenticated', users.owner, async () => {
    const [{ s }] = await q(`select lead_stats('2001-01-01', '2001-02-01') as s`);
    assert.deepEqual(s.totals, { leads: 0, downloads: 0, contacted: 0, paid: 0, revenue: 0 });
    assert.deepEqual(s.by_src, []);
  }));

// ---------------------------------------------------------------------------
// service_role: the edge functions

await test('service role finds staff by email and lead codes stay unique', () =>
  as('service_role', null, async () => {
    const [{ id }] = await q(`select staff_user_id_by_email('Owner@Example.com') as id`);
    assert.equal(id, users.owner);
    await fails(q(`select funnel_create_lead($1::jsonb, 'x')`,
      [JSON.stringify({ code: 'KS-100001', name: 'x', phone: '9999999999' })]), /duplicate key|unique/);
    await fails(q(`select funnel_create_lead($1::jsonb, 'x')`,
      [JSON.stringify({ code: 'bad', name: 'x' })]), /check constraint/);
  }));

console.log(`\n${passed} passed, ${failed} failed`);
process.exit(failed ? 1 : 0);
