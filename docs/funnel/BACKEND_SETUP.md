# बैकएंड सेटअप — Backend setup for the "आपका अच्छा समय" funnel

पूरा सेटअप एक GitHub वर्कफ़्लो करता है। आपको सिर्फ़ तीन काम करने हैं, जिनमें लगभग 10 मिनट लगते हैं
और कोई पैसा नहीं। *One workflow does the whole setup; you do three things, about ten minutes, free.*

## 1. Supabase पर मुफ़्त अकाउंट और टोकन — Free account and a token

1. <https://supabase.com> खोलें → **Start your project** → अपने ईमेल या GitHub से साइन अप करें।
   ईमेल में आया लिंक खोलकर पुष्टि करें। (कार्ड की ज़रूरत नहीं।)
   *Sign up (no card needed) and confirm your email.*
2. <https://supabase.com/dashboard/account/tokens> खोलें → **Generate new token** → नाम
   `kundlisaar-github` → **Generate** → टोकन कॉपी करें (`sbp_…` से शुरू होता है)। यह एक ही बार
   दिखता है। *Create an access token and copy it; it is shown once.*

यह टोकन आपके Supabase खाते की चाबी है: इसे किसी चैट, WhatsApp या फ़ाइल में न डालें, सिर्फ़ अगले
कदम में GitHub में। *Treat the token like a password: only into GitHub, nowhere else.*

## 2. टोकन GitHub में डालें — Put the token in GitHub

GitHub पर repo खोलें → **Settings → Secrets and variables → Actions → New repository secret**:

- Name: `SUPABASE_ACCESS_TOKEN`
- Secret: ऊपर कॉपी किया टोकन

**Add secret** दबाएँ। बस। *That is the only secret; nothing else to copy.*

## 3. वर्कफ़्लो चलाएँ — Run the workflow

repo → **Actions → Supabase setup → Run workflow** → `owner_email` में **वही ईमेल** लिखें जिससे आपने
Supabase पर साइन अप किया → **Run workflow**।

लगभग 5–10 मिनट में यह अपने आप:

- Supabase प्रोजेक्ट `kundlisaar-funnel` बनाता है (मुफ़्त प्लान, Mumbai);
- डेटाबेस की टेबल, सुरक्षा नियम (RLS) और फ़ंक्शन लगाता है;
- तीनों सर्वर फ़ंक्शन (submit-lead, track, manage-staff) deploy करता है;
- लॉगिन के लिंक एडमिन पेज पर भेजता है और आम लोगों का साइन-अप बंद करता है (स्टाफ़ सिर्फ़ निमंत्रण से);
- आपके ईमेल पर निमंत्रण भेजता है और आपको **मालिक (owner)** बनाता है;
- वेबसाइट को प्रोजेक्ट से जोड़कर (`site/config.js`) साइट दोबारा deploy करता है।

फिर ईमेल में आया निमंत्रण फ़ोन पर खोलें → पासवर्ड बनाएँ → आप `…/KundliSaar/admin/` पर लॉगिन हैं।
*Open the invitation email, set a password, and you are signed in to the admin panel.*

वर्कफ़्लो दोबारा चलाना सुरक्षित है: वह सिर्फ़ वही करता है जो बाक़ी है। बाद में `owner_email` ख़ाली
छोड़ें। अपना डोमेन लें तो repo variable `PUBLIC_BASE_URL` में डालकर इसे फिर चलाएँ, ताकि लॉगिन
लिंक और CORS नए पते पर चलें। *Re-running is safe. After buying a domain, set PUBLIC_BASE_URL
and run it again.*

**अगर निमंत्रण ईमेल न आए / If the invite email does not arrive:** Supabase की मुफ़्त ईमेल सेवा
सिर्फ़ उसी ईमेल पर भेजती है जो Supabase टीम में है (आपका साइन-अप वाला ईमेल) और घंटे में कुछ ही
ईमेल। स्पैम फ़ोल्डर देखें, या Supabase dashboard → Authentication → Users → अपने ईमेल पर
**Send password recovery** दबाएँ।

## 4. स्टाफ़ जोड़ें — Add staff

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

## 5. मुफ़्त प्लान की सीमाएँ — What the free tier means for you

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

- **बचाव / Avoid it:** यह अपने आप होता है। *Supabase keep-alive* वर्कफ़्लो रोज़ एक बार प्रोजेक्ट को
  हल्का-सा पिंग करता है, इसलिए शांत हफ़्ते में भी प्रोजेक्ट नहीं रुकना चाहिए।
  *A daily keep-alive workflow pings the project, so a quiet week should not pause it.*
- **रुक जाए तो / If it pauses:** Supabase आपको ईमेल करेगा। Dashboard में प्रोजेक्ट खोलें →
  **Restore project** दबाएँ; कुछ मिनट में सब वापस। (बहुत लंबे समय — लगभग 90 दिन — तक रुका
  रहे तो restore का विकल्प चला जा सकता है, इसलिए ईमेल को अनदेखा न करें।)
- **पक्का हल / For certain:** जब बिक्री शुरू हो जाए, **Pro plan** (लगभग $25/महीना) पर जाएँ —
  pause नहीं होता और रोज़ का backup मिलता है।

## 6. निजी डेटा की ज़िम्मेदारी — Your duties under the DPDP Act

यह सिस्टम असली लोगों का नाम, फ़ोन, जन्म-विवरण और IP रखता है।

- स्टाफ़ को सिर्फ़ उतनी भूमिका दें जितनी ज़रूरी है (ज़्यादातर **कॉलर**)।
- हर पासवर्ड देखना, हर भुगतान, हर असाइनमेंट और हर CSV export `audit_log` टेबल में दर्ज होता है
  (Supabase → Table Editor → `audit_log`)।
- कोई व्यक्ति अपना डेटा मिटवाना चाहे तो लीड खोलें → **निजी डेटा मिटाएँ** (सिर्फ़ मालिक)। गिनती
  के लिए सिर्फ़ कोड, तारीख़ और फ़्लायर-स्रोत बचते हैं।
- वेबसाइट की Privacy पेज (`privacy.html#samay`) पर फ़ॉर्म क्या लेता है, क्यों, कितने समय तक
  और कैसे मिटवाएँ, यह लिखा जा चुका है। फ़ॉर्म में कुछ नया जोड़ें तो वहाँ भी जोड़ें।

## Developer notes

- Setup: `supabase/scripts/setup.mjs`, run by `.github/workflows/supabase-setup.yml` (tested by `supabase/tests/setup_test.mjs`).
- Schema, RLS and RPCs: `supabase/migrations/*.sql` (applied through the Management API's SQL endpoint and recorded in `supabase_migrations.schema_migrations`, so the CLI agrees).
- Functions: `supabase/functions/{submit-lead,track,manage-staff}`; shared rules in `_shared/`.
- Tests: see `supabase/tests/README.md`.
- Contract between landing page, backend and panel: `docs/funnel/CONTRACT.md`.
