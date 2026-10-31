// CORS and JSON responses shared by the edge functions.
//
// Like lead.ts this uses only web-standard APIs (Request, Response, Headers),
// so it runs in the edge runtime and in Node for the tests. The allowed
// origins are passed in rather than read from Deno.env for the same reason.

const ALLOW_HEADERS = 'authorization, x-client-info, apikey, content-type';

/** Parses ALLOWED_ORIGINS ("https://a.example, https://b.example"); unset means any. */
export function parseOrigins(env: string | undefined | null): string[] {
  const list = (env ?? '').split(',').map((s) => s.trim().replace(/\/+$/, '')).filter(Boolean);
  return list.length ? list : ['*'];
}

/** The Access-Control-Allow-Origin value for this request, or null if refused. */
export function allowedOrigin(origin: string | null, allowed: string[]): string | null {
  if (allowed.includes('*')) return '*';
  if (origin && allowed.includes(origin)) return origin;
  return null;
}

export function corsHeaders(req: Request, allowed: string[]): Headers {
  const h = new Headers({
    'Access-Control-Allow-Headers': ALLOW_HEADERS,
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Max-Age': '86400',
    Vary: 'Origin',
  });
  const o = allowedOrigin(req.headers.get('origin'), allowed);
  if (o) h.set('Access-Control-Allow-Origin', o);
  return h;
}

export function json(body: unknown, status: number, cors: Headers): Response {
  const h = new Headers(cors);
  h.set('Content-Type', 'application/json; charset=utf-8');
  h.set('Cache-Control', 'no-store');
  return new Response(JSON.stringify(body), { status, headers: h });
}

/**
 * The common start of every handler: answers the preflight, refuses other
 * methods and foreign origins. Returns a Response to send, or null to go on.
 * A request with no Origin header (curl, a server) is not a browser and CORS
 * does not apply to it; the anon key or the JWT is what gates those.
 */
export function preflight(req: Request, allowed: string[]): Response | null {
  const cors = corsHeaders(req, allowed);
  const origin = req.headers.get('origin');
  if (origin && !allowedOrigin(origin, allowed)) return json({ error: 'origin' }, 403, cors);
  if (req.method === 'OPTIONS') return new Response('ok', { status: 200, headers: cors });
  if (req.method !== 'POST') return json({ error: 'method' }, 405, cors);
  return null;
}

/** Reads a JSON body no larger than `max` bytes; null if too big or not JSON. */
export async function readJson(req: Request, max: number): Promise<unknown | null> {
  const declared = Number(req.headers.get('content-length') ?? '0');
  if (declared > max) return null;
  const buf = await req.arrayBuffer();
  if (buf.byteLength > max) return null;
  try {
    return JSON.parse(new TextDecoder().decode(buf));
  } catch {
    return null;
  }
}
