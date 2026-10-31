// Tests for the edge functions' shared validation, run under Node:
//
//   node --experimental-strip-types --test supabase/tests/lead_test.mjs
//
// (Node 22.6+; the flag lets Node import the .ts files as they are.)

import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  normalizePhone, validDate, validTime, validateSubmission, validateTrack, isHoneypotFilled,
  clientIp, cleanIp, cleanText, randomDigits, newLeadCode, newPdfPassword, newTempPassword,
  todayIST, isEmail,
} from '../functions/_shared/lead.ts';
import { parseOrigins, allowedOrigin, preflight, readJson } from '../functions/_shared/http.ts';

const NOW = new Date('2026-10-31T10:00:00Z');

function body(overrides = {}) {
  return {
    name: 'राम शर्मा',
    phone: '9876543210',
    birth: {
      date: '1990-05-17', time: '06:45', timeApprox: false,
      place: { name: 'Jaipur, Rajasthan', lat: 26.9124, lon: 75.7873, tz: 'Asia/Kolkata' },
      utcOffsetMinutes: 330,
    },
    kundli: { lagna: 'मेष', rashi: 'वृषभ', answer: ['…'] },
    source: { src: 'temple-hanuman-sec14', utm_source: '', referrer: '', landing_url: 'https://x/samay/?src=temple-hanuman-sec14' },
    consent: true,
    consentVersion: '2026-10-31',
    lang: 'hi',
    website: '',
    ...overrides,
  };
}
const birth = (o) => ({ ...body().birth, ...o });
const place = (o) => ({ ...body().birth.place, ...o });

test('phone: Indian mobiles in the forms people type them', () => {
  for (const p of ['9876543210', '98765 43210', '+91 98765 43210', '+919876543210',
    '09876543210', '919876543210', '98765-43210']) {
    assert.equal(normalizePhone(p), '9876543210', p);
  }
  assert.equal(normalizePhone('6000000000'), '6000000000');
});

test('phone: rejects landlines, short, long and junk', () => {
  for (const p of ['5876543210', '0123456789', '987654321', '98765432101', '+1 9876543210',
    'abcdefghij', '', null, undefined, '+91', '00919876543210']) {
    assert.equal(normalizePhone(p), null, String(p));
  }
});

test('date: real dates from 1900-01-01 to today in IST', () => {
  assert.equal(validDate('1990-05-17', NOW), '1990-05-17');
  assert.equal(validDate('1900-01-01', NOW), '1900-01-01');
  assert.equal(validDate('2026-10-31', NOW), '2026-10-31');
  assert.equal(validDate('1899-12-31', NOW), null);
  assert.equal(validDate('2026-11-01', NOW), null);
  assert.equal(validDate('2023-02-30', NOW), null);
  assert.equal(validDate('1990-5-17', NOW), null);
  assert.equal(validDate(19900517, NOW), null);
  // 20:00 UTC on 31 Oct is already 1 Nov in India.
  assert.equal(todayIST(new Date('2026-10-31T20:00:00Z')), '2026-11-01');
});

test('time: HH:MM, seconds dropped', () => {
  assert.equal(validTime('06:45'), '06:45');
  assert.equal(validTime('23:59:30'), '23:59');
  assert.equal(validTime('24:00'), null);
  assert.equal(validTime('6:45'), null);
  assert.equal(validTime('06:60'), null);
});

test('submission: the contract example is accepted and mapped', () => {
  const r = validateSubmission(body(), NOW);
  assert.equal(r.ok, true);
  assert.deepEqual(r.lead, {
    name: 'राम शर्मा', phone: '9876543210', birth_date: '1990-05-17', birth_time: '06:45',
    time_approx: false, place_name: 'Jaipur, Rajasthan', lat: 26.9124, lon: 75.7873,
    tz: 'Asia/Kolkata', utc_offset_min: 330, kundli: { lagna: 'मेष', rashi: 'वृषभ', answer: ['…'] },
    lang: 'hi', src: 'temple-hanuman-sec14', utm_source: null, utm_medium: null, utm_campaign: null,
    referrer: null, landing_url: 'https://x/samay/?src=temple-hanuman-sec14', consent_version: '2026-10-31',
  });
});

test('submission: each rule gives its error code', () => {
  const err = (b) => validateSubmission(b, NOW);
  assert.deepEqual(err(body({ consent: false })), { ok: false, error: 'consent' });
  assert.deepEqual(err(body({ consent: 'true' })), { ok: false, error: 'consent' });
  assert.deepEqual(err(body({ phone: '12345' })), { ok: false, error: 'phone' });
  assert.deepEqual(err(body({ name: '   ' })), { ok: false, error: 'name' });
  assert.deepEqual(err(body({ name: 'क'.repeat(81) })), { ok: false, error: 'name' });
  assert.equal(err(body({ name: 'क'.repeat(80) })).ok, true);
  assert.deepEqual(err(body({ birth: birth({ date: '2030-01-01' }) })), { ok: false, error: 'date' });
  assert.deepEqual(err(body({ birth: birth({ time: '25:00' }) })), { ok: false, error: 'time' });
  assert.deepEqual(err(body({ birth: birth({ place: place({ lat: 91 }) }) })), { ok: false, error: 'place' });
  assert.deepEqual(err(body({ birth: birth({ place: place({ lon: -181 }) }) })), { ok: false, error: 'place' });
  assert.deepEqual(err(body({ birth: birth({ place: place({ lat: 'x' }) }) })), { ok: false, error: 'place' });
  assert.deepEqual(err(body({ birth: birth({ place: place({ name: '' }) }) })), { ok: false, error: 'place' });
  assert.deepEqual(err(body({ birth: birth({ utcOffsetMinutes: 330.5 }) })), { ok: false, error: 'place' });
  assert.deepEqual(err(body({ birth: undefined })), { ok: false, error: 'birth' });
  assert.deepEqual(err(body({ kundli: 'x' })), { ok: false, error: 'kundli' });
  assert.deepEqual(err(body({ kundli: { big: 'x'.repeat(20000) } })), { ok: false, error: 'kundli' });
  assert.deepEqual(err(null), { ok: false, error: 'invalid' });
  assert.deepEqual(err([]), { ok: false, error: 'invalid' });
});

test('submission: unknown time is allowed only when marked approximate', () => {
  const ok = validateSubmission(body({ birth: birth({ time: '', timeApprox: true }) }), NOW);
  assert.equal(ok.ok, true);
  assert.equal(ok.lead.birth_time, null);
  assert.equal(ok.lead.time_approx, true);
  assert.equal(validateSubmission(body({ birth: birth({ time: '' }) }), NOW).ok, false);
});

test('submission: text is trimmed, cut and stripped of control characters', () => {
  const r = validateSubmission(body({
    name: '  राम\u0000 शर्मा \n', lang: 'xx',
    source: { src: 'a'.repeat(100), referrer: 'r'.repeat(600) },
  }), NOW);
  assert.equal(r.lead.name, 'राम  शर्मा');
  assert.equal(r.lead.lang, 'hi');
  assert.equal(r.lead.src.length, 64);
  assert.equal(r.lead.referrer.length, 500);
  assert.equal(cleanText(42, 10), null);
  assert.equal(validateSubmission(body({ lang: 'en' }), NOW).lead.lang, 'en');
});

test('honeypot', () => {
  assert.equal(isHoneypotFilled(body()), false);
  assert.equal(isHoneypotFilled(body({ website: undefined })), false);
  assert.equal(isHoneypotFilled(body({ website: 'http://spam' })), true);
  assert.equal(isHoneypotFilled(body({ website: 1 })), true);
});

test('track: only a well-formed id, code and known event', () => {
  const id = '3f1c2b9e-5d4a-4c7b-9e8f-0a1b2c3d4e5f';
  assert.deepEqual(validateTrack({ leadId: id.toUpperCase(), code: 'KS-482193', event: 'pdf_download' }),
    { leadId: id, code: 'KS-482193', event: 'pdf_download' });
  for (const e of ['basis_open', 'whatsapp_click', 'call_click']) {
    assert.ok(validateTrack({ leadId: id, code: 'KS-482193', event: e }));
  }
  assert.equal(validateTrack({ leadId: id, code: 'KS-48219', event: 'pdf_download' }), null);
  assert.equal(validateTrack({ leadId: 'nope', code: 'KS-482193', event: 'pdf_download' }), null);
  assert.equal(validateTrack({ leadId: id, code: 'KS-482193', event: 'drop_table' }), null);
  assert.equal(validateTrack(null), null);
});

test('client IP: first x-forwarded-for, else x-real-ip, only valid addresses', () => {
  const h = (o) => (n) => o[n] ?? null;
  assert.equal(clientIp(h({ 'x-forwarded-for': '203.0.113.7, 10.0.0.1' })), '203.0.113.7');
  assert.equal(clientIp(h({ 'x-forwarded-for': ' 2001:DB8::1 , 10.0.0.1' })), '2001:db8::1');
  assert.equal(clientIp(h({ 'x-real-ip': '198.51.100.2' })), '198.51.100.2');
  assert.equal(clientIp(h({ 'x-forwarded-for': 'garbage', 'x-real-ip': '198.51.100.2' })), '198.51.100.2');
  assert.equal(clientIp(h({})), null);
  assert.equal(cleanIp('1.2.3.4:5678'), '1.2.3.4');
  assert.equal(cleanIp('[::1]:443'), '::1');
  assert.equal(cleanIp('300.1.1.1'), null);
  assert.equal(cleanIp("1.1.1.1'; drop"), null);
});

test('codes and passwords: right shape, from the CSPRNG, roughly uniform', () => {
  assert.match(newLeadCode(), /^KS-\d{6}$/);
  assert.match(newPdfPassword(), /^\d{6}$/);
  assert.match(newTempPassword(), /^[A-HJ-NP-Za-km-z2-9]{14}$/);
  const counts = new Array(10).fill(0);
  const s = randomDigits(20000);
  assert.equal(s.length, 20000);
  for (const c of s) counts[+c]++;
  // Each digit expects 2000; a biased generator drifts far outside this.
  for (const n of counts) assert.ok(n > 1800 && n < 2200, `digit count ${n}`);
  const seen = new Set(Array.from({ length: 200 }, newPdfPassword));
  assert.ok(seen.size > 190, 'passwords repeat too often');
});

test('email check', () => {
  assert.ok(isEmail('a@b.in'));
  assert.ok(!isEmail('a@b'));
  assert.ok(!isEmail('a b@c.in'));
});

test('CORS: origin list, wildcard default, preflight and method', async () => {
  assert.deepEqual(parseOrigins(undefined), ['*']);
  assert.deepEqual(parseOrigins(' https://a.example/ , https://b.example'), ['https://a.example', 'https://b.example']);
  const allowed = parseOrigins('https://a.example');
  assert.equal(allowedOrigin('https://a.example', allowed), 'https://a.example');
  assert.equal(allowedOrigin('https://evil.example', allowed), null);
  assert.equal(allowedOrigin('https://evil.example', ['*']), '*');

  const req = (method, origin) => new Request('https://x/functions/v1/track', {
    method, headers: origin ? { origin } : {},
  });
  const opt = preflight(req('OPTIONS', 'https://a.example'), allowed);
  assert.equal(opt.status, 200);
  assert.equal(opt.headers.get('access-control-allow-origin'), 'https://a.example');
  assert.match(opt.headers.get('access-control-allow-headers'), /apikey/);
  assert.equal(preflight(req('POST', 'https://evil.example'), allowed).status, 403);
  assert.equal(preflight(req('GET', 'https://a.example'), allowed).status, 405);
  assert.equal(preflight(req('POST', 'https://a.example'), allowed), null);
  assert.equal(preflight(req('POST', null), allowed), null);
});

test('readJson: refuses oversized and malformed bodies', async () => {
  const mk = (b) => new Request('https://x', { method: 'POST', body: b });
  assert.deepEqual(await readJson(mk('{"a":1}'), 100), { a: 1 });
  assert.equal(await readJson(mk('{"a":'), 100), null);
  assert.equal(await readJson(mk('x'.repeat(200)), 100), null);
});
