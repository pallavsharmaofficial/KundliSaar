# "आपका अच्छा समय" lead funnel — the contract between its parts

This is the one place the landing page, the backend and the admin panel agree
on names. Change it here first.

## The flow

1. A printed flyer asks: **"क्या आप जानना चाहते हैं — आपका अच्छा समय कब आएगा?"**
   and carries a QR code to `BASE_URL/samay/?src=<placement-code>`.
2. The landing page (`site/samay/`) explains, takes the birth details and a
   phone number, with consent, and computes the kundli **in the browser** with
   the app's own engine compiled to JavaScript.
3. It sends the details and a summary of the computed kundli to the
   `submit-lead` edge function, which stores them with the visitor's IP and
   browser, and returns a lead code and a per-lead PDF password.
4. The page shows the rashi, lagna, nakshatra and the plain answer to "when
   is my good time", with an optional "on what basis" section.
5. The visitor downloads the full kundli PDF, encrypted with the per-lead
   password. The page then says: **"पासवर्ड के लिए 9910144125 पर संपर्क करें"**
   and offers WhatsApp and call buttons carrying the lead code.
6. Staff work the leads in the admin panel (`site/admin/`): call, reveal the
   password (logged), sell the report or a consultation, record payment.

## Where things live

| Part | Path |
|---|---|
| Landing page | `site/samay/index.html`, `site/samay/samay.css`, `site/samay/samay.js` |
| Engine bridge (Dart → JS) | `tools/funnel/funnel_main.dart` → built to `samay/funnel.js` |
| Public config (written at deploy) | `site/config.js` → `window.KS_CONFIG` |
| Backend | `supabase/migrations/*.sql`, `supabase/functions/<name>/index.ts` |
| Admin panel | `site/admin/index.html`, `site/admin/admin.js`, `site/admin/admin.css` |
| Flyers | `tools/flyer/` (generator), output in `docs/flyers/` |

## Public config

`site/config.js` (generated in the deploy workflow from repository variables;
a checked-in default has empty values, and the pages must say "not set up yet"
rather than break):

```js
window.KS_CONFIG = {
  supabaseUrl: "https://<ref>.supabase.co",   // repo variable SUPABASE_URL
  supabaseAnonKey: "<anon key>",              // repo variable SUPABASE_ANON_KEY (public by design)
  baseUrl: "https://pallavsharmaofficial.github.io/KundliSaar", // repo variable PUBLIC_BASE_URL
  contactPhone: "9910144125",
  whatsappPhone: "919910144125",
};
```

Edge function URL: `${supabaseUrl}/functions/v1/<name>`, called with headers
`apikey: <anon key>` and `Authorization: Bearer <anon key>`.

## Edge function `submit-lead` (POST, JSON)

Request:

```json
{
  "name": "राम शर्मा",
  "phone": "9876543210",
  "birth": {
    "date": "1990-05-17",
    "time": "06:45",
    "timeApprox": false,
    "place": { "name": "Jaipur, Rajasthan", "lat": 26.9124, "lon": 75.7873, "tz": "Asia/Kolkata" },
    "utcOffsetMinutes": 330
  },
  "kundli": {
    "lagna": "मेष", "rashi": "वृषभ", "nakshatra": "रोहिणी", "pada": 2,
    "mahadasha": { "lord": "शुक्र", "end": "2031-03-01" },
    "antardasha": { "lord": "राहु", "end": "2027-11-12" },
    "answer": ["अभी आपका समय मिला-जुला है…", "इससे बेहतर समय नवंबर 2027 से…", "एक आसान उपाय: …"],
    "grahas": [ { "graha": "सूर्य", "sign": "वृषभ", "degree": 2.41, "house": 2 } ]
  },
  "source": {
    "src": "temple-hanuman-sec14", "utm_source": "", "utm_medium": "", "utm_campaign": "",
    "referrer": "", "landing_url": "https://…/samay/?src=temple-hanuman-sec14"
  },
  "consent": true,
  "consentVersion": "2026-10-31",
  "lang": "hi",
  "website": ""
}
```

- `website` is a honeypot: humans leave it empty. Non-empty → respond 200 with
  a fake-looking success and store nothing.
- `phone`: Indian mobile, 10 digits starting 6–9, after stripping spaces, `+91`
  or a leading `0`. Reject otherwise (400, `{"error":"phone"}`).
- `consent` must be `true` (400, `{"error":"consent"}`).
- Name 1–80 chars; date between 1900-01-01 and today; place lat/lon in range.
- Rate limit: at most 8 new leads per IP per hour (429, `{"error":"rate"}`).
- Same phone + same birth date + same birth time within 30 days → return the
  **existing** lead's code and password (re-downloads keep one password).

Response 200:

```json
{ "leadId": "uuid", "code": "KS-482193", "password": "604917" }
```

- `code`: `KS-` + 6 random digits, unique.
- `password`: 6 random digits from a cryptographic RNG.

The IP is the first address in `x-forwarded-for` (else `x-real-ip`); also store
`user-agent`.

## Edge function `track` (POST, JSON)

```json
{ "leadId": "uuid", "code": "KS-482193", "event": "pdf_download" }
```

`event` ∈ `basis_open`, `pdf_download`, `whatsapp_click`, `call_click`, `upi_click`.

The PDF password costs **₹199**, paid by UPI (the page's button carries the
lead code in the payment note) or on the call.
`leadId` and `code` must match the same lead or nothing is stored. Always
answer `{ "ok": true }` (204/200), never reveal whether a lead exists.

## Database (Postgres, Supabase)

- `leads` — one row per visitor who submitted: id uuid, code (unique), created_at,
  updated_at, name, phone, birth_date, birth_time, time_approx, place_name, lat,
  lon, tz, utc_offset_min, kundli jsonb, lang, src, utm_source, utm_medium,
  utm_campaign, referrer, landing_url, ip inet, user_agent, consent_at,
  consent_version, status (`new`, `contacted`, `interested`, `paid`,
  `not_interested`, `invalid`), assigned_to (staff), amount_paid (rupees,
  integer), paid_at, deleted_at (soft delete, for erasure requests).
- `lead_secrets` — lead_id, pdf_password. Never readable directly by staff;
  only through `reveal_password(lead_id)`, which checks the role and writes
  the audit log.
- `lead_events` — lead_id, event, created_at, ip, user_agent.
- `lead_activity` — lead_id, actor, kind (`note`, `status`, `call`, `payment`,
  `assign`), text, created_at: the history a caller sees.
- `staff` — user_id (auth.users), name, role (`owner`, `manager`, `caller`),
  active.
- `audit_log` — actor, action, lead_id, detail jsonb, at.

Roles:

| Can | owner | manager | caller |
|---|---|---|---|
| See leads | all | all | assigned to them + unassigned |
| Update status / notes / payment | all | all | the ones they can see |
| Reveal password | yes | yes | the ones they can see |
| Assign leads | yes | yes | take an unassigned one for themselves |
| Export CSV, stats by source | yes | yes | no |
| Manage staff, delete (erase) a lead | yes | no | no |

The anon role reads and writes nothing directly; only the edge functions,
with the service role, insert leads and events.
