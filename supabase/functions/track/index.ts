// track: records what a visitor did after submitting (opened "on what basis",
// downloaded the PDF, tapped WhatsApp or call). Called with the anon key.
// The answer is always { ok: true }, so the endpoint cannot be used to find
// out whether a lead id or code exists.

import { createClient } from 'npm:@supabase/supabase-js@2';
import { cleanText, clientIp, validateTrack } from '../_shared/lead.ts';
import { corsHeaders, json, parseOrigins, preflight, readJson } from '../_shared/http.ts';

// A page reloaded in a loop should not fill the table: beyond this many of
// one event for one lead in an hour, further ones are dropped.
const MAX_SAME_EVENT_PER_HOUR = 20;

const allowed = parseOrigins(Deno.env.get('ALLOWED_ORIGINS'));
const db = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, {
  auth: { persistSession: false, autoRefreshToken: false },
});

Deno.serve(async (req) => {
  const early = preflight(req, allowed);
  if (early) return early;
  const cors = corsHeaders(req, allowed);
  const ok = () => json({ ok: true }, 200, cors);

  const t = validateTrack(await readJson(req, 4096));
  if (!t) return ok();

  try {
    // The id and the code must name the same live lead; knowing one is not
    // enough to write events against it.
    const { data: lead, error } = await db.from('leads').select('id')
      .eq('id', t.leadId).eq('code', t.code).is('deleted_at', null).maybeSingle();
    if (error) throw error;
    if (!lead) return ok();

    const hourAgo = new Date(Date.now() - 3_600_000).toISOString();
    const { count, error: cErr } = await db.from('lead_events').select('id', { count: 'exact', head: true })
      .eq('lead_id', lead.id).eq('event', t.event).gte('created_at', hourAgo);
    if (cErr) throw cErr;
    if ((count ?? 0) >= MAX_SAME_EVENT_PER_HOUR) return ok();

    const { error: iErr } = await db.from('lead_events').insert({
      lead_id: lead.id,
      event: t.event,
      ip: clientIp((n) => req.headers.get(n)),
      user_agent: cleanText(req.headers.get('user-agent'), 500),
    });
    if (iErr) throw iErr;
  } catch (e) {
    console.error('track failed:', (e as { message?: string })?.message ?? e);
  }
  return ok();
});
