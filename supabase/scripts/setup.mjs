// Sets up (or brings up to date) the funnel's Supabase project with nothing
// but the owner's Supabase access token. Run by .github/workflows/supabase-setup.yml.
//
// Every step can run again safely:
//   1. find the project by name, or create it (free plan, Mumbai) and wait
//      until it is healthy;
//   2. apply the migrations in supabase/migrations that have not been applied,
//      through the Management API's SQL endpoint, recording each in the same
//      table the Supabase CLI uses, so `supabase db push` agrees;
//   3. point sign-in links at the admin panel and turn off public sign-ups
//      (staff are invited, nobody signs themselves up);
//   4. set the functions' CORS secret;
//   5. if OWNER_EMAIL is given, invite that person (or send a reset link if
//      they exist) and make them the owner;
//   6. write the project ref, URL and anon key to $GITHUB_OUTPUT.
//
// Keys other than the anon key are masked in the log: this repository is
// public, and so are its Actions logs.
//
// Env: SUPABASE_ACCESS_TOKEN (required), OWNER_EMAIL, SITE_BASE,
// PROJECT_NAME, PROJECT_REGION, SUPABASE_API_BASE (tests only),
// SUPABASE_PROJECT_HOST (tests only: replaces https://<ref>.supabase.co).

import { appendFileSync, readFileSync, readdirSync } from 'node:fs';
import { randomBytes } from 'node:crypto';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const TOKEN = process.env.SUPABASE_ACCESS_TOKEN;
const API = (process.env.SUPABASE_API_BASE || 'https://api.supabase.com').replace(/\/$/, '');
const NAME = process.env.PROJECT_NAME || 'kundlisaar-funnel';
const REGION = process.env.PROJECT_REGION || 'ap-south-1';
const SITE = (process.env.SITE_BASE || 'https://pallavsharmaofficial.github.io/KundliSaar').replace(/\/$/, '');
const OWNER = (process.env.OWNER_EMAIL || '').trim().toLowerCase();
const POLL_MS = Number(process.env.POLL_MS || 10000);

const log = (...a) => console.log(...a);
const mask = (v) => { if (v && process.env.GITHUB_ACTIONS) console.log(`::add-mask::${v}`); };
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

if (!TOKEN) {
  console.error('SUPABASE_ACCESS_TOKEN is not set.');
  process.exit(1);
}
if (OWNER && !/^[^\s@'"\\]+@[^\s@'"\\]+\.[a-z]{2,}$/i.test(OWNER)) {
  console.error(`OWNER_EMAIL does not look like an email address: ${OWNER}`);
  process.exit(1);
}

/** A call to the Management API, retried on the 5xx and 429 a new project gives. */
async function api(method, path, body, { tries = 6, ok404 = false } = {}) {
  for (let i = 1; ; i++) {
    const r = await fetch(API + path, {
      method,
      headers: { Authorization: `Bearer ${TOKEN}`, 'Content-Type': 'application/json' },
      body: body === undefined ? undefined : JSON.stringify(body),
    });
    if (ok404 && r.status === 404) return null;
    if (r.ok) {
      const text = await r.text();
      return text ? JSON.parse(text) : null;
    }
    const text = await r.text();
    if ((r.status >= 500 || r.status === 429) && i < tries) {
      log(`  ${method} ${path} → ${r.status}, trying again…`);
      await sleep(Math.min(POLL_MS, 5000) * i);
      continue;
    }
    throw new Error(`${method} ${path} → ${r.status}: ${text.slice(0, 400)}`);
  }
}

function sql(ref, query) {
  return api('POST', `/v1/projects/${ref}/database/query`, { query });
}

const lit = (s) => `'${String(s).replace(/'/g, "''")}'`;

// ---------------------------------------------------------------- 1. project

async function ensureProject() {
  const projects = (await api('GET', '/v1/projects')) || [];
  let p = projects.find((x) => x.name === NAME);
  if (p) {
    log(`Project "${NAME}" found: ${p.id} (${p.region}, ${p.status}).`);
    if (p.status === 'INACTIVE' || p.status === 'PAUSED') {
      log('It is paused; restoring it.');
      await api('POST', `/v1/projects/${p.id}/restore`, {});
    }
  } else {
    let orgs = (await api('GET', '/v1/organizations')) || [];
    if (!orgs.length) {
      log('No organisation yet; creating "KundliSaar".');
      orgs = [await api('POST', '/v1/organizations', { name: 'KundliSaar' })];
    }
    const dbPass = randomBytes(24).toString('base64url');
    mask(dbPass);
    log(`Creating project "${NAME}" in ${REGION} under organisation ${orgs[0].name}…`);
    p = await api('POST', '/v1/projects', {
      name: NAME,
      organization_id: orgs[0].id,
      region: REGION,
      db_pass: dbPass,
    });
    log(`Created ${p.id}. The database password was generated and is not needed again.`);
  }
  const ref = p.id;
  for (let i = 0; i < 90; i++) {
    const now = await api('GET', `/v1/projects/${ref}`);
    if (now.status === 'ACTIVE_HEALTHY') {
      log('Project is healthy.');
      return ref;
    }
    if (i % 3 === 0) log(`  waiting for the project (${now.status})…`);
    await sleep(POLL_MS);
  }
  throw new Error('The project did not become healthy within 15 minutes; run the workflow again.');
}

// ---------------------------------------------------------------- 2. migrations

async function migrate(ref) {
  // The SQL endpoint can answer before Postgres takes queries on a new project.
  for (let i = 0; ; i++) {
    try { await sql(ref, 'select 1'); break; } catch (e) {
      if (i > 20) throw e;
      log('  database not taking queries yet…');
      await sleep(POLL_MS);
    }
  }
  await sql(ref, `create schema if not exists supabase_migrations;
    create table if not exists supabase_migrations.schema_migrations
      (version text primary key, statements text[], name text);`);
  const rows = (await sql(ref, 'select version from supabase_migrations.schema_migrations')) || [];
  const done = new Set(rows.map((r) => r.version));
  const dir = join(here, '..', 'migrations');
  const files = readdirSync(dir).filter((f) => /^\d+_.+\.sql$/.test(f)).sort();
  for (const f of files) {
    const [version, ...rest] = f.replace(/\.sql$/, '').split('_');
    if (done.has(version)) { log(`Migration ${f}: already applied.`); continue; }
    log(`Migration ${f}: applying…`);
    await sql(ref, readFileSync(join(dir, f), 'utf8'));
    await sql(ref, `insert into supabase_migrations.schema_migrations (version, name)
      values (${lit(version)}, ${lit(rest.join('_'))}) on conflict (version) do nothing`);
  }
}

// ---------------------------------------------------------------- 3–4. settings

async function configure(ref) {
  const admin = `${SITE}/admin/`;
  await api('PATCH', `/v1/projects/${ref}/config/auth`, {
    site_url: admin,
    uri_allow_list: `${admin},${admin}**`,
    disable_signup: true,
  });
  log(`Sign-in links go to ${admin}; public sign-up is off.`);
  const origin = new URL(SITE).origin;
  await api('POST', `/v1/projects/${ref}/secrets`, [{ name: 'ALLOWED_ORIGINS', value: origin }]);
  log(`Functions accept requests from ${origin}.`);
}

// ---------------------------------------------------------------- 5. owner

async function keys(ref) {
  const list = (await api('GET', `/v1/projects/${ref}/api-keys?reveal=true`)) || [];
  const anon = list.find((k) => k.name === 'anon')?.api_key;
  const service = list.find((k) => k.name === 'service_role')?.api_key;
  if (!anon || !service) throw new Error('Could not read the project API keys.');
  mask(service);
  return { anon, service };
}

async function makeOwner(ref, service) {
  const host = process.env.SUPABASE_PROJECT_HOST || `https://${ref}.supabase.co`;
  const auth = (path, body) => fetch(`${host}/auth/v1${path}`, {
    method: 'POST',
    headers: { apikey: service, Authorization: `Bearer ${service}`, 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  const existing = (await sql(ref, `select id from auth.users where lower(email) = ${lit(OWNER)}`)) || [];
  const redirect = `${SITE}/admin/`;
  if (existing.length) {
    const r = await auth(`/recover?redirect_to=${encodeURIComponent(redirect)}`, { email: OWNER });
    log(r.ok
      ? `${OWNER} already has a login; a password-reset email was sent.`
      : `${OWNER} already has a login; the reset email could not be sent (${r.status}). Use "forgot password" on the admin page.`);
  } else {
    const r = await auth(`/invite?redirect_to=${encodeURIComponent(redirect)}`, { email: OWNER });
    if (!r.ok) {
      throw new Error(`Inviting ${OWNER} failed (${r.status}): ${(await r.text()).slice(0, 300)}. ` +
        "Supabase's built-in email reaches only the people in your Supabase organisation; use the email you signed up to Supabase with.");
    }
    log(`An invitation email was sent to ${OWNER}. Open it on your phone to set your password.`);
  }
  await sql(ref, `insert into public.staff (user_id, name, role, active)
    select id, 'Owner', 'owner', true from auth.users where lower(email) = ${lit(OWNER)}
    on conflict (user_id) do update set role = 'owner', active = true`);
  const check = (await sql(ref, `select s.role from public.staff s join auth.users u on u.id = s.user_id
    where lower(u.email) = ${lit(OWNER)}`)) || [];
  if (!check.length || check[0].role !== 'owner') throw new Error('The owner row was not written.');
  log(`${OWNER} is the owner.`);
}

// ---------------------------------------------------------------- main

const ref = await ensureProject();
await migrate(ref);
await configure(ref);
const { anon, service } = await keys(ref);
if (OWNER) await makeOwner(ref, service);
else log('No OWNER_EMAIL given; skipping the owner step.');

const url = `https://${ref}.supabase.co`;
if (process.env.GITHUB_OUTPUT) {
  appendFileSync(process.env.GITHUB_OUTPUT, `ref=${ref}\nurl=${url}\nanon=${anon}\n`);
}
log(`Done. Project ${ref}, ${url}.`);
