// Runs supabase/scripts/setup.mjs against a stand-in for Supabase's
// Management API and Auth API, with the SQL endpoint backed by PGlite
// (Postgres in WASM), so the migrations go through the very path the real
// setup uses. Runs it twice to show a second run changes nothing.
//
//   PGLITE_DIR=/tmp/pglite/node_modules node supabase/tests/setup_test.mjs

import http from 'node:http';
import { spawn } from 'node:child_process';
import { createRequire } from 'node:module';
import { dirname, join } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import assert from 'node:assert/strict';

const here = dirname(fileURLToPath(import.meta.url));

async function loadPGlite() {
  try {
    return (await import('@electric-sql/pglite')).PGlite;
  } catch {
    const require = createRequire(join(process.env.PGLITE_DIR || '.', 'package.json'));
    const entry = require.resolve('@electric-sql/pglite').replace(/index\.cjs$/, 'index.js');
    return (await import(pathToFileURL(entry).href)).PGlite;
  }
}

const PGlite = await loadPGlite();
const db = new PGlite();
await db.exec(`
  create role anon nologin; create role authenticated nologin; create role service_role nologin bypassrls;
  create schema auth;
  create table auth.users (id uuid primary key default gen_random_uuid(), email text unique);
  create function auth.uid() returns uuid language sql stable as $$
    select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
  grant usage on schema public, auth to anon, authenticated, service_role;
`);

const state = { projects: [], orgs: [], status: {}, polls: 0, auth: null, secrets: null, invites: [], recovers: [] };
const send = (res, code, body) => {
  res.writeHead(code, { 'Content-Type': 'application/json' });
  res.end(body === undefined ? '' : JSON.stringify(body));
};

const server = http.createServer(async (req, res) => {
  let raw = '';
  for await (const c of req) raw += c;
  const body = raw ? JSON.parse(raw) : undefined;
  const u = new URL(req.url, 'http://x');
  const p = u.pathname;
  if (!/^\/auth\//.test(p) && req.headers.authorization !== 'Bearer test-token') return send(res, 401, { message: 'bad token' });
  try {
    if (req.method === 'GET' && p === '/v1/projects') return send(res, 200, state.projects);
    if (req.method === 'GET' && p === '/v1/organizations') return send(res, 200, state.orgs);
    if (req.method === 'POST' && p === '/v1/organizations') {
      const o = { id: 'org-slug', name: body.name };
      state.orgs.push(o);
      return send(res, 201, o);
    }
    if (req.method === 'POST' && p === '/v1/projects') {
      assert.equal(body.region, 'ap-south-1');
      assert.ok(body.db_pass && body.db_pass.length >= 20);
      assert.equal(body.organization_id, 'org-slug');
      const proj = { id: 'testref', name: body.name, region: body.region, status: 'COMING_UP' };
      state.projects.push(proj);
      return send(res, 201, proj);
    }
    let m;
    if (req.method === 'GET' && (m = p.match(/^\/v1\/projects\/(\w+)$/))) {
      // Healthy on the third look, as a new project comes up.
      const proj = state.projects.find((x) => x.id === m[1]);
      if (++state.polls >= 3) proj.status = 'ACTIVE_HEALTHY';
      return send(res, 200, proj);
    }
    if (req.method === 'POST' && p === '/v1/projects/testref/database/query') {
      const results = await db.exec(body.query);
      return send(res, 201, results.length ? results[results.length - 1].rows : []);
    }
    if (req.method === 'PATCH' && p === '/v1/projects/testref/config/auth') { state.auth = body; return send(res, 200, {}); }
    if (req.method === 'POST' && p === '/v1/projects/testref/secrets') { state.secrets = body; return send(res, 201); }
    if (req.method === 'GET' && p === '/v1/projects/testref/api-keys') {
      assert.equal(u.searchParams.get('reveal'), 'true');
      return send(res, 200, [{ name: 'anon', api_key: 'anon-key' }, { name: 'service_role', api_key: 'service-key' }]);
    }
    if (req.method === 'POST' && p === '/auth/v1/invite') {
      assert.equal(req.headers.apikey, 'service-key');
      state.invites.push(body.email);
      await db.query('insert into auth.users (email) values ($1)', [body.email]);
      return send(res, 200, {});
    }
    if (req.method === 'POST' && p === '/auth/v1/recover') { state.recovers.push(body.email); return send(res, 200, {}); }
    return send(res, 404, { message: `no route ${req.method} ${p}` });
  } catch (e) {
    return send(res, 400, { message: String(e.message || e) });
  }
}).listen(0);
const port = server.address().port;

function run(env) {
  return new Promise((resolve) => {
    const child = spawn(process.execPath, [join(here, '..', 'scripts', 'setup.mjs')], {
      env: {
        ...process.env,
        SUPABASE_ACCESS_TOKEN: 'test-token',
        SUPABASE_API_BASE: `http://localhost:${port}`,
        SUPABASE_PROJECT_HOST: `http://localhost:${port}`,
        GITHUB_OUTPUT: '',
        GITHUB_ACTIONS: '',
        POLL_MS: '10',
        ...env,
      },
    });
    let out = '';
    child.stdout.on('data', (d) => (out += d));
    child.stderr.on('data', (d) => (out += d));
    child.on('close', (code) => resolve({ code, out }));
  });
}

let passed = 0;
const ok = (name, fn) => { fn(); passed++; console.log(`ok   ${name}`); };

const first = await run({ OWNER_EMAIL: 'Owner@Example.com' });
if (first.code !== 0) console.log(first.out);
ok('first run succeeds', () => assert.equal(first.code, 0));
ok('creates an organisation and a Mumbai project', () => {
  assert.equal(state.orgs.length, 1);
  assert.equal(state.projects.length, 1);
});
const versions = (await db.query('select version from supabase_migrations.schema_migrations order by 1')).rows.map((r) => r.version);
ok('both migrations recorded', () => assert.deepEqual(versions, ['20261031000000', '20261101000000']));
const enumHasUpi = (await db.query(`select 1 from pg_enum e join pg_type t on t.oid = e.enumtypid
  where t.typname = 'lead_event_kind' and e.enumlabel = 'upi_click'`)).rows.length;
ok('the later migration ran too (upi_click exists)', () => assert.equal(enumHasUpi, 1));
ok('sign-in goes to the admin page and sign-up is off', () => {
  assert.equal(state.auth.site_url, 'https://pallavsharmaofficial.github.io/KundliSaar/admin/');
  assert.equal(state.auth.disable_signup, true);
});
ok('CORS is the site origin, without the path', () =>
  assert.deepEqual(state.secrets, [{ name: 'ALLOWED_ORIGINS', value: 'https://pallavsharmaofficial.github.io' }]));
ok('the owner is invited, lower-cased', () => assert.deepEqual(state.invites, ['owner@example.com']));
const owner = (await db.query(`select s.role, s.active from public.staff s join auth.users u on u.id = s.user_id
  where u.email = 'owner@example.com'`)).rows;
ok('and is the owner', () => assert.deepEqual(owner, [{ role: 'owner', active: true }]));
ok('the service key is never printed', () => assert.ok(!first.out.includes('service-key')));

const second = await run({ OWNER_EMAIL: 'owner@example.com' });
if (second.code !== 0) console.log(second.out);
ok('second run succeeds', () => assert.equal(second.code, 0));
ok('finds the project instead of making another', () => assert.equal(state.projects.length, 1));
ok('skips applied migrations', () => assert.match(second.out, /already applied[\s\S]*already applied/));
ok('an existing owner gets a reset link, not a second invite', () => {
  assert.deepEqual(state.invites, ['owner@example.com']);
  assert.deepEqual(state.recovers, ['owner@example.com']);
});
const staffCount = (await db.query('select count(*)::int as n from public.staff')).rows[0].n;
ok('still one staff row', () => assert.equal(staffCount, 1));

const bad = await run({ OWNER_EMAIL: "x'; drop table staff; --@a.b" });
ok('a malformed owner email is refused before anything runs', () => assert.notEqual(bad.code, 0));

server.close();
console.log(`\n${passed} passed, 0 failed`);
