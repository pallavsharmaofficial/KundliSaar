# फ़्लायर — "आपका अच्छा समय कब आएगा?" / Flyers for the samay funnel

हर फ़्लायर पर एक ही बड़ा सवाल है, एक QR कोड है, और QR के नीचे वेब-पता छपा है।
QR स्कैन करने पर व्यक्ति `…/samay/?src=<कोड>` पेज पर पहुँचता है। `<कोड>` से पता चलता है
कि लीड किस जगह के फ़्लायर से आई (मंदिर, केमिस्ट, चाय की दुकान…)। पूरा फ़्लो
[`docs/funnel/CONTRACT.md`](../funnel/CONTRACT.md) में है।

Every flyer carries one big question, a QR code, and the web address printed under
the QR. The QR opens `<base>/samay/?src=<code>`; the code tells us which placement a
lead came from. The full flow is in [`docs/funnel/CONTRACT.md`](../funnel/CONTRACT.md).

---

## दोबारा बनाना / How to regenerate

```sh
cd tools/flyer
npm ci
node make_flyers.mjs --sources sources.csv          # सभी जगहों के लिए / every placement
node make_flyers.mjs --src sample                   # सिर्फ़ नमूना / just the sample
node make_flyers.mjs --src temple-hanuman-sec14,tea-stall-metro-gate
```

विकल्प / options:

| option | default | मतलब / meaning |
|---|---|---|
| `--base <url>` | `https://pallavsharmaofficial.github.io/KundliSaar` | साइट का पता; QR = `<base>/samay/?src=<code>` |
| `--src a,b,c` | — | एक या ज़्यादा कोड / one or more codes |
| `--sources file.csv` | — | CSV, कॉलम `code,label` |
| `--phone 9910144125` | `9910144125` | संपर्क नंबर / contact number (shown as `99101 44125`) |
| `--out <dir>` | `docs/flyers` | आउटपुट फ़ोल्डर |
| `--chrome <path>` | auto (`$PLAYWRIGHT_BROWSERS_PATH` or `/opt/pw-browsers/chromium-*/chrome-linux/chrome`) | Chromium का पता |
| `--preview` | off | layout warnings instead of errors; keeps PNG previews of the PDFs in a temp folder |

**कोड के नियम / code rules:** छोटे अक्षर, अंक और `-` ही; अधिकतम 24 अक्षर
(lowercase letters, digits and hyphens, at most 24 characters). नई जगह जोड़नी हो तो
`tools/flyer/sources.csv` में एक पंक्ति जोड़ें और कमांड फिर चलाएँ।
Add a row to `tools/flyer/sources.csv` for every new placement and run the command again.

हर बार चलने पर generator अपने-आप जाँचता है / every run checks, and fails if any check fails:

- हर आउटपुट का QR फिर से पढ़ा जाता है (jsQR) और ठीक वही URL मिलना चाहिए; PDF के लिए
  `pdftoppm` (अगर इंस्टॉल हो) से 150 dpi पर बनाकर भी पढ़ा जाता है।
  Every output's QR is decoded again from the rendered image (and, for PDFs, from a
  150 dpi rasterisation of the final PDF when poppler's `pdftoppm` is installed) and
  must read back exactly the expected URL.
- तीनों फ़ॉन्ट लोड हुए हों, कोई टेक्स्ट कटे नहीं, और A5 पर सारा टेक्स्ट ट्रिम से 5 mm अंदर हो।
  All three fonts loaded, nothing overflows, and on A5 every line of text sits at
  least 5 mm inside the trim.

---

## कौन-सी फ़ाइल किसलिए / What each file is for

हर कोड का फ़ोल्डर `docs/flyers/<code>/` / one folder per placement code:

| फ़ाइल / file | आकार / size | कहाँ इस्तेमाल / use |
|---|---|---|
| `a5-print.pdf` | A5 148×210 mm + 3 mm bleed (पेज 154×216 mm), crop marks | प्रेस में छपाई: हाथ में देने वाले पर्चे, अख़बार में डालने वाले पर्चे, काउंटर स्टैंडी। Offset/digital print, newspaper inserts, counter standees. |
| `a4-poster.pdf` | A4 210×297 mm, बिना bleed | नोटिस बोर्ड, दुकान की दीवार; किसी भी दुकान के प्रिंटर से। सवाल 2 मीटर से पढ़ा जा सके। Notice boards and shop walls; any office printer; question readable from 2 m. |
| `whatsapp-square.png` | 1080×1080 | WhatsApp ग्रुप, Facebook/Instagram पोस्ट। Groups and feed posts. |
| `whatsapp-status.png` | 1080×1920 | WhatsApp स्टेटस, Instagram स्टोरी। Status and stories. |
| `whatsapp-caption.txt` | text | तस्वीर के साथ भेजने वाला संदेश, जिसमें **क्लिक होने वाला** लिंक है। The message to send with the image. |

**ज़रूरी / important:** WhatsApp पर तस्वीर में छपा लिंक टैप नहीं होता। इसलिए तस्वीर भेजते
समय `whatsapp-caption.txt` का संदेश साथ में ज़रूर पेस्ट करें — "लिंक पर टैप करें" उसी लिंक की
बात करता है। A link inside an image is not tappable; always paste the caption text
(which has the real link) with the image.

हर फ़ाइल पर QR के नीचे बहुत छोटे अक्षरों में जगह का कोड छपा है (जैसे `temple-hanuman-sec14`)।
बाँटने से पहले मिलान करें कि सही बंडल सही जगह जा रहा है। The placement code is printed
in tiny type under the QR; check it before handing a bundle over, so a printer mix-up is
caught.

`sample/` सिर्फ़ नमूना है (`--src sample`), इसे बाँटें नहीं — इसकी लीड "sample" नाम से दर्ज होंगी।
`sample/` is for review only; leads from it are recorded under `src=sample`.

---

## प्रिंटर के लिए निर्देश / Printer instructions

**A5 पर्चा / A5 flyer (`a5-print.pdf`)**

- ट्रिम साइज़ / trim size: **148 × 210 mm (A5)**; फ़ाइल में चारों ओर **3 mm bleed** है
  (पेज 154 × 216 mm), कोनों पर crop marks हैं, PDF में TrimBox/BleedBox सेट है।
- काग़ज़ / paper: **130–170 gsm matte (art matte)** हाथ में देने के लिए; अख़बार में डालने के लिए
  90–130 gsm भी चलेगा। काउंटर स्टैंडी के लिए **300 gsm** (matte या matte lamination)।
  Glossy lamination से बचें — QR पर चमक आने से स्कैन मुश्किल होता है। Avoid gloss
  lamination over the QR; glare makes it hard to scan.
- रंग / colour: फ़ाइल RGB में है। प्रिंटर से कहें कि अपने standard CMYK profile
  (जैसे FOGRA39 / coated) में बदलें और **एक proof** दिखाएँ। मरून, सिंदूरी लाल और हल्दी-पीला
  सामान्य CMYK में ठीक छपते हैं; कोई हल्का पीला टेक्स्ट नहीं है। The file is RGB; ask
  the printer to convert to their standard CMYK profile (e.g. FOGRA39 coated) and show a
  proof. QR is pure black on white — ask for it to print as rich/100% K without dot gain
  softening.
- एक तरफ़ छपाई (4/0)। Single-sided (4/0).
- **proof पर QR को 2–3 अलग फ़ोन से हाथ की दूरी से स्कैन करके देखें**, फिर ही पूरा ऑर्डर दें।
  Scan the QR on the proof with two or three phones at arm's length before approving
  the run. QR is ≈ 42 mm including its white quiet zone (≈ 34 mm of code).
- फ़ॉन्ट PDF में embedded हैं। अगर किसी प्रेस का RIP फ़ॉन्ट पर शिकायत करे, तो उनसे PDF को
  300 dpi पर flatten/"print as image" करवाएँ। Fonts are embedded; if a RIP objects,
  have it flattened at 300 dpi.

**A4 पोस्टर / A4 poster (`a4-poster.pdf`)**

- किसी भी रंगीन लेज़र/इंकजेट प्रिंटर पर "Actual size / 100%" पर छापें ("Fit to page" नहीं)।
  Print at 100 % / actual size. किनारे पर सफ़ेद पट्टी आए तो कोई बात नहीं — सारा टेक्स्ट
  किनारे से 10 mm अंदर है। A white printer margin is fine; all text is ≥ 10 mm inside.
- बाहर या धूप में लगाना हो तो 170–250 gsm पर छापकर matte lamination करवाएँ।

### अनुमानित लागत / Rough print costs (India, late 2026)

ये **बाज़ार की मोटी रेंज** हैं, किसी प्रेस का कोटेशन नहीं; शहर, मात्रा और GST के हिसाब से
बदलेंगी। These are **rough market ranges, not quotes**; they vary by city, quantity and GST.

| काम / job | लगभग / approx. |
|---|---|
| A5, 130 gsm, एक तरफ़ रंगीन, **1,000 पर्चे** (offset/gang-run) | ₹1,200 – ₹2,500 |
| A5, 170 gsm matte, 1,000 पर्चे | ₹1,800 – ₹3,500 |
| A5, digital print, 1,000 पर्चे (जल्दी चाहिए तो) | ₹2,500 – ₹5,000 |
| 5,000+ पर्चे (offset) | ₹0.50 – ₹1.00 प्रति पर्चा |
| अख़बार में डलवाना (hawker/agency) | ₹0.50 – ₹1.50 प्रति पर्चा, छपाई अलग |
| A5 काउंटर स्टैंडी, 300 gsm + स्टैंड | ₹40 – ₹150 प्रति पीस |
| A4 रंगीन प्रिंट दुकान पर / lamination | ₹10 – ₹30 / ₹20 – ₹40 प्रति शीट |

---

## विज्ञापन के नियम / Keep it honest (ASCI)

यह विज्ञापन है, इसलिए शब्द बदलते समय ध्यान रखें: कोई गारंटी नहीं, डर नहीं, झूठी जल्दबाज़ी
("आज ही, वरना…") नहीं, "100% सटीक" जैसे दावे नहीं। NASA का लोगो या कोई NASA चित्र
इस्तेमाल न करें (सिर्फ़ सादा टेक्स्ट: "NASA JPL के सार्वजनिक खगोलीय आँकड़ों पर आधारित गणना")।
WhatsApp/Meta का लोगो भी नहीं — फ़ोन का सामान्य चिह्न ही है। छोटी पंक्ति
"ज्योतिषीय जानकारी मार्गदर्शन के लिए है; कोई गारंटी नहीं।" हर संस्करण पर रहनी चाहिए।

This is regulated advertising: no guarantees, no fear, no fake urgency, no "100 %
accurate". No NASA logo or imagery (plain-text attribution only), no WhatsApp/Meta logo
(a generic handset glyph is used). Keep the disclaimer line on every version. All
artwork (the rising-sun dial) is drawn in code in `tools/flyer/make_flyers.mjs`; fonts
are the repo's own OFL fonts in `assets/fonts/`.
