# बैकएंड सेटअप — Backend setup for the "आपका अच्छा समय" funnel

यह गाइड उस मालिक के लिए है जो डेवलपर नहीं है। हर कदम एक बार करना है।
*This guide is for the owner, not a developer. Each step is done once.*

What you get at the end:

- a free **Supabase** project (database + login + edge functions) in Mumbai,
- the landing page `…/samay/` saving leads into it,
- the staff panel at `https://pallavsharmaofficial.github.io/KundliSaar/admin/`,
- you as the **owner**, able to add callers and managers.

Time needed: about 30 minutes.

---

## 1. Supabase प्रोजेक्ट बनाएँ — Create the Supabase project

1. <https://supabase.com> पर जाएँ → **Start your project** → GitHub या ईमेल से साइन अप करें।
2. **New project** दबाएँ:
   - **Name:** `kundlisaar`
   - **Database Password:** **Generate a password** दबाएँ और इसे तुरंत किसी सुरक्षित जगह
     (password manager) में सेव करें। *This is the DB password; you need it in step 3.*
   - **Region:** **South Asia (Mumbai)** — `ap-south-1`. भारत के लोगों का डेटा भारत के पास
     रहता है और पेज तेज़ चलता है। *Keep Indian visitors' data close and fast.*
   - **Plan:** Free.
3. **Create new project** दबाएँ और 2–3 मिनट इंतज़ार करें।

## 2. ये पाँच चीज़ें ढूँढें — Find these five values

Supabase dashboard में अपना प्रोजेक्ट खोलें। (Menu names change over time; if one is
not where described, use the search box at the top of the dashboard.)

| क्या / What | कहाँ / Where | कैसा दिखता है / Looks like |
|---|---|---|
| **Project ref** | Project Settings → General → *Project ID / Reference ID* | `abcdefghijklmnopqrst` (20 letters) |
| **Project URL** | Project Settings → Data API (or API) → *Project URL* | `https://abcdefghijklmnopqrst.supabase.co` |
| **anon key** | Project Settings → API Keys → *anon / public* (legacy tab if shown) | a long text starting `eyJ…` |
| **DB password** | the one you saved in step 1 (forgot it? Project Settings → Database → *Reset database password*) | |
| **Access token** | your account (top-right avatar) → **Account preferences → Access Tokens** → *Generate new token*, name it `github-deploy` | starts `sbp_…` |

**anon key सार्वजनिक है** — यह वेबसाइट में दिखती है, और डेटाबेस इस तरह बना है कि इससे कोई
लीड पढ़ी नहीं जा सकती। *The anon key is public by design.*

**Access token, DB password और "service_role" key कभी किसी को न दें, कहीं पेस्ट न करें**
(सिर्फ़ नीचे GitHub secrets में)। *Never share these; service_role can read everything.*

## 3. GitHub में secrets और variables डालें — Add them to GitHub

GitHub पर repository **KundliSaar** खोलें → **Settings → Secrets and variables → Actions**.

**Secrets** टैब → **New repository secret** (तीन बार):

| Name | Value |
|---|---|
| `SUPABASE_ACCESS_TOKEN` | the `sbp_…` access token |
| `SUPABASE_PROJECT_REF` | the 20-letter project ref |
| `SUPABASE_DB_PASSWORD` | the database password |

**Variables** टैब → **New repository variable** (चार बार):

| Name | Value |
|---|---|
| `SUPABASE_URL` | `https://<ref>.supabase.co` |
| `SUPABASE_ANON_KEY` | the anon key |
| `PUBLIC_BASE_URL` | `https://pallavsharmaofficial.github.io/KundliSaar` |
| `ALLOWED_ORIGINS` | `https://pallavsharmaofficial.github.io` |

`ALLOWED_ORIGINS` में सिर्फ़ डोमेन होता है, कोई `/KundliSaar` या आख़िरी `/` नहीं। कई हों तो
कॉमा से अलग करें। *Origin only, no path; comma-separate several (e.g. a custom domain later).*

## 4. Deploy चलाएँ — Run the deploy

1. GitHub → **Actions** टैब → बाएँ **Deploy the funnel backend to Supabase** → **Run workflow** → **Run workflow**.
   यह डेटाबेस की टेबल बनाता है और तीन edge functions (`submit-lead`, `track`,
   `manage-staff`) डालता है। *Creates the tables and deploys the functions.*
2. फिर **Deploy website and web app to GitHub Pages** को भी **Run workflow** करें, ताकि
   वेबसाइट को नया URL और anon key मिल जाए (`config.js`)।
3. दोनों हरे ✔ हों तो ठीक है। लाल ✘ हो तो उस run को खोलकर आख़िरी लाल step का संदेश पढ़ें —
   ज़्यादातर secret का नाम या value गलत होती है।
   *Green is done. If red, open the run; usually a secret is misnamed or mistyped.*

बाद में `supabase/` में कोई भी बदलाव `main` पर आएगा तो यह अपने-आप चलेगा।
*After this it runs by itself when `supabase/` changes on main.*

## 5. Login की सेटिंग — Auth settings (one time)

Supabase dashboard → **Authentication**:

1. **Sign In / Providers** (or *Settings*) → **Allow new users to sign up** को **बंद** करें।
   स्टाफ़ आप ही जोड़ेंगे। (बंद न भी हो तो भी कोई अजनबी लीड नहीं देख सकता, पर बंद रखना साफ़ है।)
   *Turn off public sign-ups; you add staff yourself.*
2. **URL Configuration**:
   - **Site URL:** `https://pallavsharmaofficial.github.io/KundliSaar/admin/`
   - **Redirect URLs:** add the same URL.
   इससे "पासवर्ड भूल गए" का लिंक सीधे स्टाफ़ पैनल पर खुलता है।
   *So password-reset links open the staff panel.*

## 6. पहला मालिक बनाएँ — Make yourself the owner

1. **Authentication → Users → Add user → Create new user**: अपना ईमेल और एक मज़बूत पासवर्ड,
   **Auto Confirm User** पर ✔ लगाएँ → **Create user**.
2. बाएँ **SQL Editor** → **New query** → यह पेस्ट करें, अपना ईमेल डालकर → **Run**:

   ```sql
   insert into staff(user_id,name,role) select id,'Owner','owner' from auth.users where email='you@example.com';
   ```

   "Success. 1 row" आना चाहिए। "0 rows" आए तो ईमेल की स्पेलिंग जाँचें।
3. `https://pallavsharmaofficial.github.io/KundliSaar/admin/` खोलें और लॉगिन करें।
   अगर "बैकएंड अभी सेट नहीं हुआ है" दिखे, तो step 4.2 (website deploy) दोबारा चलाएँ।

## 7. स्टाफ़ जोड़ें — Add staff

स्टाफ़ पैनल → **स्टाफ़ / Staff** टैब → **नया स्टाफ़ जोड़ें**:

- नाम, ईमेल और भूमिका चुनें:
  - **कॉलर / Caller** — अपनी और बिना-असाइन लीड्स देखता है, कॉल करता है, पासवर्ड बताता है,
    भुगतान दर्ज करता है।
  - **मैनेजर / Manager** — सारी लीड्स, असाइन करना, डैशबोर्ड, CSV export।
  - **मालिक / Owner** — ऊपर का सब, और स्टाफ़ जोड़ना-हटाना, लीड का डेटा मिटाना।
- **कैसे:** "अस्थायी पासवर्ड" चुनें (आसान)। पैनल एक पासवर्ड **सिर्फ़ एक बार** दिखाएगा — उसे
  कॉल या WhatsApp पर निजी तौर पर भेजें, और कहें कि पहली बार लॉगिन करके **खाता → पासवर्ड बदलें**
  करें। *A one-time password is shown once; send it privately.*
- "ईमेल से निमंत्रण" तभी चुनें जब आपने Supabase में अपना SMTP (ईमेल सेवा) लगाया हो —
  Supabase की मुफ़्त ईमेल सेवा सिर्फ़ प्रोजेक्ट टीम के ईमेल पर और घंटे में बहुत कम ईमेल भेजती है।
  यही बात "पासवर्ड भूल गए" ईमेल पर भी लागू है; किसी स्टाफ़ का पासवर्ड भूल जाए तो आप
  Authentication → Users में उसका पासवर्ड बदल सकते हैं।
  *Built-in email is heavily limited; use temporary passwords, or set up custom SMTP
  (Authentication → Emails → SMTP) if you want email invites and resets to work reliably.*

कोई स्टाफ़ छोड़ दे तो **बंद करें / Deactivate** — उसकी लॉगिन बंद हो जाती है और उसकी खुली
लीड्स वापस पूल में आ जाती हैं। *Deactivate leavers; their open leads return to the pool.*

## 8. मुफ़्त प्लान की सीमाएँ — What the free tier means for you

(Numbers as of late 2026; check <https://supabase.com/pricing> for the current ones.)

| सीमा / Limit | मतलब / In practice |
|---|---|
| Database 500 MB | एक लीड लगभग 3–5 KB की है → लगभग **1 लाख लीड्स** तक आराम से। |
| Edge function calls ~500,000 / month | हर विज़िटर 2–5 calls करता है → महीने में **1 लाख+ विज़िटर**। |
| Auth 50,000 monthly users | स्टाफ़ के लिए बहुत ज़्यादा। |
| Egress ~5 GB / month | स्टाफ़ पैनल और फ़ॉर्म के लिए काफ़ी। |
| No automatic backups on Free | महीने में एक बार **CSV डाउनलोड** करके सुरक्षित रखें (वह भी निजी डेटा है — संभाल कर)। |

### एक हफ़्ते बिना इस्तेमाल पर प्रोजेक्ट रुक जाता है — Pausing after a week idle

Supabase मुफ़्त प्रोजेक्ट को **7 दिन तक कोई गतिविधि न हो** तो *pause* कर देता है। तब फ़ॉर्म
लीड सेव नहीं करेगा (विज़िटर को गलती दिखेगी) और स्टाफ़ पैनल नहीं खुलेगा। डेटा मिटता नहीं।

- **बचाव / Avoid it:** जब तक फ़्लायर बँट रहे हैं, लीड्स आती रहेंगी और प्रोजेक्ट जागा रहेगा।
  फ़्लायर बंद हों तो भी हफ़्ते में कम से कम एक बार स्टाफ़ पैनल खोलकर लीड्स देख लें।
- **रुक जाए तो / If it pauses:** Supabase आपको ईमेल करेगा। Dashboard में प्रोजेक्ट खोलें →
  **Restore project** दबाएँ; कुछ मिनट में सब वापस। (बहुत लंबे समय — लगभग 90 दिन — तक रुका
  रहे तो restore का विकल्प चला जा सकता है, इसलिए ईमेल को अनदेखा न करें।)
- **पक्का हल / For certain:** जब बिक्री शुरू हो जाए, **Pro plan** (लगभग $25/महीना) पर जाएँ —
  pause नहीं होता और रोज़ का backup मिलता है।

## 9. निजी डेटा की ज़िम्मेदारी — Your duties under the DPDP Act

यह सिस्टम असली लोगों का नाम, फ़ोन, जन्म-विवरण और IP रखता है।

- स्टाफ़ को सिर्फ़ उतनी भूमिका दें जितनी ज़रूरी है (ज़्यादातर **कॉलर**)।
- हर पासवर्ड देखना, हर भुगतान, हर असाइनमेंट और हर CSV export `audit_log` टेबल में दर्ज होता है
  (Supabase → Table Editor → `audit_log`)।
- कोई व्यक्ति अपना डेटा मिटवाना चाहे तो लीड खोलें → **निजी डेटा मिटाएँ** (सिर्फ़ मालिक)। गिनती
  के लिए सिर्फ़ कोड, तारीख़ और फ़्लायर-स्रोत बचते हैं।
- वेबसाइट की **Privacy** पेज पर बताएँ कि फ़ॉर्म क्या लेता है और क्यों — मौजूदा पेज कहता है कि
  ऐप कुछ भी इकट्ठा नहीं करता, जो ऐप के लिए सही है पर इस फ़ॉर्म के लिए नहीं।

## Developer notes

- Schema, RLS and RPCs: `supabase/migrations/20261031000000_funnel.sql` (bootstrap SQL at the bottom).
- Functions: `supabase/functions/{submit-lead,track,manage-staff}`; shared rules in `_shared/`.
- Tests: see `supabase/tests/README.md`.
- Contract between landing page, backend and panel: `docs/funnel/CONTRACT.md`.
