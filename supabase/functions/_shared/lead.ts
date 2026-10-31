// Validation and normalisation for the funnel's edge functions.
//
// Plain TypeScript with no Deno globals and only erasable type syntax, so the
// same file runs in the edge runtime and under `node --experimental-strip-types`
// in supabase/tests/lead_test.mjs. The rules are the ones in
// docs/funnel/CONTRACT.md; change them there first.

export type Json = null | boolean | number | string | Json[] | { [k: string]: Json };

/** The row written to `leads`, minus what the database fills in. */
export interface LeadRow {
  name: string;
  phone: string;
  birth_date: string;
  birth_time: string | null;
  time_approx: boolean;
  place_name: string;
  lat: number;
  lon: number;
  tz: string | null;
  utc_offset_min: number | null;
  kundli: Json;
  lang: string;
  src: string | null;
  utm_source: string | null;
  utm_medium: string | null;
  utm_campaign: string | null;
  referrer: string | null;
  landing_url: string | null;
  consent_version: string | null;
}

export type ValidationResult =
  | { ok: true; lead: LeadRow }
  | { ok: false; error: string };

export const TRACK_EVENTS = ['basis_open', 'pdf_download', 'whatsapp_click', 'call_click', 'upi_click'] as const;
export type TrackEvent = typeof TRACK_EVENTS[number];

// Larger bodies are refused before parsing: a real submission is a few KB.
export const MAX_BODY_BYTES = 64 * 1024;
// The kundli summary is shown in the admin panel; anything bigger than this
// is not a summary and is refused rather than stored.
const MAX_KUNDLI_BYTES = 16 * 1024;

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const CODE_RE = /^KS-\d{6}$/;

function isObject(v: unknown): v is Record<string, unknown> {
  return typeof v === 'object' && v !== null && !Array.isArray(v);
}

/** Trimmed string cut to `max` code points, or null when empty or not a string. */
export function cleanText(v: unknown, max: number): string | null {
  if (typeof v !== 'string') return null;
  // Control characters have no business in a name or a URL and break CSV export.
  const s = v.replace(/[\u0000-\u001f\u007f]/g, ' ').trim();
  if (!s) return null;
  const chars = Array.from(s);
  return chars.length > max ? chars.slice(0, max).join('') : s;
}

/**
 * An Indian mobile number as 10 digits, or null. Spaces (and dashes, which
 * people also type), a `+91`/`91` country code or a trunk `0` are stripped.
 */
export function normalizePhone(v: unknown): string | null {
  if (typeof v !== 'string' && typeof v !== 'number') return null;
  let s = String(v).replace(/[\s\-().]/g, '');
  if (s.startsWith('+91')) s = s.slice(3);
  else if (s.length === 12 && s.startsWith('91')) s = s.slice(2);
  else if (s.length === 11 && s.startsWith('0')) s = s.slice(1);
  return /^[6-9]\d{9}$/.test(s) ? s : null;
}

/** Today's calendar date in India, as YYYY-MM-DD. Visitors are in IST. */
export function todayIST(now: Date = new Date()): string {
  return new Date(now.getTime() + 330 * 60_000).toISOString().slice(0, 10);
}

/** A real calendar date between 1900-01-01 and today (IST), or null. */
export function validDate(v: unknown, now: Date = new Date()): string | null {
  if (typeof v !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(v)) return null;
  const d = new Date(v + 'T00:00:00Z');
  // Date rolls 2023-02-30 over to March; the round trip catches that.
  if (isNaN(d.getTime()) || d.toISOString().slice(0, 10) !== v) return null;
  if (v < '1900-01-01' || v > todayIST(now)) return null;
  return v;
}

/** HH:MM on a 24-hour clock, or null. */
export function validTime(v: unknown): string | null {
  if (typeof v !== 'string') return null;
  const m = /^([01]\d|2[0-3]):([0-5]\d)(?::[0-5]\d)?$/.exec(v.trim());
  return m ? `${m[1]}:${m[2]}` : null;
}

function finiteIn(v: unknown, lo: number, hi: number): number | null {
  const n = typeof v === 'string' && v.trim() !== '' ? Number(v) : v;
  return typeof n === 'number' && Number.isFinite(n) && n >= lo && n <= hi ? n : null;
}

/** Validates a `submit-lead` body and maps it to a `leads` row. */
export function validateSubmission(body: unknown, now: Date = new Date()): ValidationResult {
  if (!isObject(body)) return { ok: false, error: 'invalid' };

  // Consent first: without it nothing else in the body may even be kept.
  if (body.consent !== true) return { ok: false, error: 'consent' };

  const phone = normalizePhone(body.phone);
  if (!phone) return { ok: false, error: 'phone' };

  const name = cleanText(body.name, 1000);
  if (!name || Array.from(name).length > 80) return { ok: false, error: 'name' };

  const birth = isObject(body.birth) ? body.birth : null;
  if (!birth) return { ok: false, error: 'birth' };
  const birthDate = validDate(birth.date, now);
  if (!birthDate) return { ok: false, error: 'date' };

  const timeApprox = birth.timeApprox === true;
  const blankTime = birth.time === undefined || birth.time === null || birth.time === '';
  const birthTime = blankTime ? null : validTime(birth.time);
  // A visitor who does not know the time may leave it out, but only by
  // saying so; a garbled time is an error either way.
  if (!birthTime && !(blankTime && timeApprox)) return { ok: false, error: 'time' };

  const place = isObject(birth.place) ? birth.place : null;
  if (!place) return { ok: false, error: 'place' };
  const placeName = cleanText(place.name, 200);
  const lat = finiteIn(place.lat, -90, 90);
  const lon = finiteIn(place.lon, -180, 180);
  if (!placeName || lat === null || lon === null) return { ok: false, error: 'place' };
  const tz = cleanText(place.tz, 64);
  const offsetRaw = birth.utcOffsetMinutes;
  let utcOffset: number | null = null;
  if (offsetRaw !== undefined && offsetRaw !== null) {
    utcOffset = finiteIn(offsetRaw, -720, 840);
    if (utcOffset === null || !Number.isInteger(utcOffset)) return { ok: false, error: 'place' };
  }

  let kundli: Json = null;
  if (body.kundli !== undefined && body.kundli !== null) {
    if (!isObject(body.kundli)) return { ok: false, error: 'kundli' };
    const text = JSON.stringify(body.kundli);
    if (new TextEncoder().encode(text).length > MAX_KUNDLI_BYTES) return { ok: false, error: 'kundli' };
    kundli = JSON.parse(text) as Json;
  }

  const source = isObject(body.source) ? body.source : {};
  const lang = cleanText(body.lang, 8) === 'en' ? 'en' : 'hi';

  return {
    ok: true,
    lead: {
      name,
      phone,
      birth_date: birthDate,
      birth_time: birthTime,
      time_approx: timeApprox,
      place_name: placeName,
      lat,
      lon,
      tz,
      utc_offset_min: utcOffset,
      kundli,
      lang,
      src: cleanText(source.src, 64),
      utm_source: cleanText(source.utm_source, 100),
      utm_medium: cleanText(source.utm_medium, 100),
      utm_campaign: cleanText(source.utm_campaign, 100),
      referrer: cleanText(source.referrer, 500),
      landing_url: cleanText(source.landing_url, 500),
      consent_version: cleanText(body.consentVersion, 32),
    },
  };
}

/** True when the honeypot field was filled in, i.e. a bot wrote the body. */
export function isHoneypotFilled(body: unknown): boolean {
  if (!isObject(body)) return false;
  const w = body.website;
  return w !== undefined && w !== null && w !== '' && w !== false;
}

/** Validates a `track` body; null means "store nothing". */
export function validateTrack(body: unknown): { leadId: string; code: string; event: TrackEvent } | null {
  if (!isObject(body)) return null;
  const { leadId, code, event } = body;
  if (typeof leadId !== 'string' || !UUID_RE.test(leadId)) return null;
  if (typeof code !== 'string' || !CODE_RE.test(code)) return null;
  if (typeof event !== 'string' || !(TRACK_EVENTS as readonly string[]).includes(event)) return null;
  return { leadId: leadId.toLowerCase(), code, event: event as TrackEvent };
}

// ---------------------------------------------------------------------------
// Request metadata

const IPV4_RE = /^(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}$/;
const IPV6_RE = /^[0-9a-f:.]+$/i;

/** A string Postgres will accept as `inet`, or null. */
export function cleanIp(v: string | null | undefined): string | null {
  if (!v) return null;
  let s = v.trim();
  // "[::1]:443" and "1.2.3.4:5678" both turn up behind some proxies.
  const bracket = /^\[([^\]]+)\](?::\d+)?$/.exec(s);
  if (bracket) s = bracket[1];
  else if (/^[\d.]+:\d+$/.test(s)) s = s.slice(0, s.lastIndexOf(':'));
  if (IPV4_RE.test(s)) return s;
  if (s.includes(':') && IPV6_RE.test(s) && s.length <= 45) return s.toLowerCase();
  return null;
}

/** The visitor's IP: the first address in x-forwarded-for, else x-real-ip. */
export function clientIp(get: (name: string) => string | null): string | null {
  const xff = get('x-forwarded-for');
  if (xff) {
    const first = cleanIp(xff.split(',')[0]);
    if (first) return first;
  }
  return cleanIp(get('x-real-ip'));
}

// ---------------------------------------------------------------------------
// Codes and passwords

/** `n` decimal digits from the cryptographic RNG, without modulo bias. */
export function randomDigits(n: number): string {
  let out = '';
  const buf = new Uint8Array(n * 2);
  while (out.length < n) {
    crypto.getRandomValues(buf);
    for (const b of buf) {
      // 250 is the largest multiple of 10 below 256; rejecting the rest
      // keeps every digit equally likely.
      if (b < 250) out += String(b % 10);
      if (out.length === n) break;
    }
  }
  return out;
}

export function newLeadCode(): string {
  return 'KS-' + randomDigits(6);
}

export function newPdfPassword(): string {
  return randomDigits(6);
}

// No 0/O, 1/l/I: a temporary password is read out over the phone.
const TEMP_ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789';

/** A one-time staff password: 14 characters, about 81 bits. */
export function newTempPassword(length = 14): string {
  const limit = 256 - (256 % TEMP_ALPHABET.length);
  let out = '';
  const buf = new Uint8Array(length * 2);
  while (out.length < length) {
    crypto.getRandomValues(buf);
    for (const b of buf) {
      if (b < limit) out += TEMP_ALPHABET[b % TEMP_ALPHABET.length];
      if (out.length === length) break;
    }
  }
  return out;
}

export function isUuid(v: unknown): v is string {
  return typeof v === 'string' && UUID_RE.test(v);
}

export const STAFF_ROLES = ['owner', 'manager', 'caller'] as const;
export type StaffRole = typeof STAFF_ROLES[number];

export function isStaffRole(v: unknown): v is StaffRole {
  return typeof v === 'string' && (STAFF_ROLES as readonly string[]).includes(v);
}

export function isEmail(v: unknown): v is string {
  return typeof v === 'string' && v.length <= 254 && /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(v);
}
