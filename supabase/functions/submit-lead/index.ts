// submit-lead: stores a visitor's details from the landing page and returns
// the lead code and the PDF password. Called with the anon key, so
// verify_jwt is off in config.toml; everything here runs as the service role
// and the anon key itself can read or write nothing (see the migration).
// Contract: docs/funnel/CONTRACT.md.

import { createClient } from 'npm:@supabase/supabase-js@2';
import {
  MAX_BODY_BYTES, cleanText, clientIp, isHoneypotFilled, newLeadCode, newPdfPassword,
  validateSubmission,
} from '../_shared/lead.ts';
import { corsHeaders, json, parseOrigins, preflight, readJson } from '../_shared/http.ts';

const RATE_PER_HOUR = 8;
const DEDUPE_DAYS = 30;

const allowed = parseOrigins(Deno.env.get('ALLOWED_ORIGINS'));
const db = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, {
  auth: { persistSession: false, autoRefreshToken: false },
});

Deno.serve(async (req) => {
  const early = preflight(req, allowed);
  if (early) return early;
  const cors = corsHeaders(req, allowed);

  const body = await readJson(req, MAX_BODY_BYTES);
  if (body === null) return json({ error: 'invalid' }, 400, cors);

  // A bot filled the hidden field: look successful, keep nothing, so it has
  // no signal to adapt to.
  if (isHoneypotFilled(body)) {
    return json({ leadId: crypto.randomUUID(), code: newLeadCode(), password: newPdfPassword() }, 200, cors);
  }

  const v = validateSubmission(body);
  if (!v.ok) return json({ error: v.error }, 400, cors);
  const lead = v.lead;
  const ip = clientIp((n) => req.headers.get(n));
  const userAgent = cleanText(req.headers.get('user-agent'), 500);

  try {
    // Same phone + birth date + birth time within 30 days is the same person
    // downloading again: give back the code and password they already have.
    const since = new Date(Date.now() - DEDUPE_DAYS * 86_400_000).toISOString();
    let dq = db.from('leads').select('id, code')
      .eq('phone', lead.phone).eq('birth_date', lead.birth_date)
      .is('deleted_at', null).gte('created_at', since)
      .order('created_at', { ascending: false }).limit(1);
    dq = lead.birth_time === null ? dq.is('birth_time', null) : dq.eq('birth_time', lead.birth_time);
    const { data: dup, error: dupErr } = await dq;
    if (dupErr) throw dupErr;
    if (dup && dup.length) {
      const { data: sec, error: secErr } = await db.from('lead_secrets')
        .select('pdf_password').eq('lead_id', dup[0].id).single();
      if (secErr) throw secErr;
      return json({ leadId: dup[0].id, code: dup[0].code, password: sec.pdf_password }, 200, cors);
    }

    // Only new leads count against the limit; a re-download above does not.
    if (ip) {
      const hourAgo = new Date(Date.now() - 3_600_000).toISOString();
      const { count, error } = await db.from('leads').select('id', { count: 'exact', head: true })
        .eq('ip', ip).gte('created_at', hourAgo);
      if (error) throw error;
      if ((count ?? 0) >= RATE_PER_HOUR) return json({ error: 'rate' }, 429, cors);
    }

    const password = newPdfPassword();
    // Codes are random, so a clash is possible but rare; the unique index
    // catches it and we draw again.
    for (let attempt = 0; attempt < 6; attempt++) {
      const code = newLeadCode();
      const { data: id, error } = await db.rpc('funnel_create_lead', {
        lead: { ...lead, code, ip, user_agent: userAgent },
        password,
      });
      if (!error) return json({ leadId: id, code, password }, 200, cors);
      if (error.code !== '23505') throw error;
    }
    throw new Error('could not draw a unique lead code');
  } catch (e) {
    // Log the failure, never the visitor's details.
    console.error('submit-lead failed:', (e as { message?: string })?.message ?? e);
    return json({ error: 'server' }, 500, cors);
  }
});
