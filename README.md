# KundliSaar · कुंडलीसार

A free Vedic kundli app that computes everything **on your device**, in **Hindi
and English**, and explains what it computed instead of handing you a verdict.

- **Live site:** https://pallavsharmaofficial.github.io/KundliSaar/
- **Web app:** https://pallavsharmaofficial.github.io/KundliSaar/app/

No account, no server, no upload. Birth details never leave the phone or the
browser tab they were typed into.

## What it does today

| Area | What ships |
|---|---|
| Chart | Lagna chart in North Indian, South Indian and chakra styles; planets with sign, degree, house, nakshatra, pada, dignity, retrograde and combustion |
| Divisional charts | All sixteen vargas, D1 to D60, by the Parashari rules |
| Periods | Vimshottari to three levels with the balance at birth, plus the Yogini cycle |
| Strengths | Full **shadbala** with all six parts in rupas against each graha's own minimum, and **ashtakavarga** — every bhinnashtakavarga plus the sarvashtakavarga, which always totals 337 |
| Transits | **Gochar** from the natal Moon with the bindus of each sign being crossed, transit aspects on natal grahas, Sade Sati with the dates each phase ends, and the next Jupiter and Saturn returns |
| Muhurta | A **finder** that scores every choghadiya slot across a date range against the rules for ten named activities, and shows what moved each score |
| Year chart | **Varshphal**: the solar return to the arc-minute, Muntha, and the lord of the year chosen from the five contenders by shadbala |
| Festivals | A computed **festival and vrat calendar** for any year — each date from the tithi running at the moment the rule asks for: sunrise, midday, pradosh or nishita, with Bhadra moving Holika Dahan |
| Palmistry | **Hastrekha**: trace your own lines over a palm outline, optionally on a photo of your hand, and the classical rules read the geometry you drew, naming the measurement behind every sentence |
| Panchang | Tithi, nakshatra, yoga, karana and vara with end times, sunrise, sunset, moonrise, moonset, Rahu Kaal, Gulika, Yamaganda, Abhijit, day and night choghadiya, horas |
| Matching | Ashtakoota to 36 gunas with every koota explained, plus Mangal dosha on both sides |
| Baby names | **Namkaran**: the syllable from the pada of the janma nakshatra, with example names |
| Numbers | **Ank Jyotish**: mulank, bhagyank, Chaldean namank, the Lo Shu grid, and what each number's graha is read for |
| Prashna | A horary chart for the moment a question is asked, with the leaning and every factor behind it |
| Today | A daily reading from the transiting Moon, the tara, the running dasha and the heavier transits |
| Remedies | **Upay** chosen from this chart — mantra with its japa count, fasting day, daan, yantra, gemstone with the warning that belongs on it, and one thing to do today that costs nothing |
| Ask | Questions answered from the computed chart in Hindi or English, **by voice or by typing**, each answer showing the chart factors it read from and readable aloud |
| Learn | The nine grahas, twelve rashis and 27 nakshatras with deity, symbol, lord, gana, yoni and nadi |

## The two things that are drawn rather than downloaded

A **swamiji** sits on the Ask screen, drawn entirely in code: he breathes, blinks,
tilts his head while the microphone is open, closes his eyes while the chart is
read, and moves his mouth to the voice when an answer is spoken. No animation
file, no likeness of anyone, a few kilobytes, and it takes the app's colours.

Waiting is spent on the **27 nakshatras**. The loader draws each mansion's own
symbol star by star — Ashwini's horse head, Rohini's cart, Revati's fish —
names it and its deity, and walks on to the next while the work finishes.

## The engine

The astrology is plain Dart with no Flutter, no platform code and no network,
so the same engine serves Android, iOS and the browser and can be tested to the
arc-second in CI.

Positions come from our **own Poisson series**, fitted to sampled geometry from
NASA JPL's public-domain **DE440s** kernel by `tools/ephemeris/fit_ephemeris.py`.
No third-party ephemeris code ships here, which keeps the project MIT and keeps
it off the AGPL path that the Swiss Ephemeris would require.

Measured against the kernel over 1900–2070:

| Body | Worst longitude error in the test fixtures |
|---|---|
| Sun | under 2″ |
| Moon | under 8″ |
| Mercury, Venus, Jupiter, Saturn | under 3″ |
| Mars | under 4″ |

Independently, the Sun lands within 0.4″ of 0° at six March equinox instants
between 1905 and 2051, which checks precession, nutation and the frame at once,
and Gandhi's published chart reproduces sign for sign.

See [docs/ENGINE.md](docs/ENGINE.md) for how the series are built and
[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the app layering.

## Running it

```bash
flutter pub get
flutter gen-l10n
flutter test
flutter run -d chrome
```

Regenerating the ephemeris tables needs Python with `skyfield` and takes about
half an hour:

```bash
python3 -m venv .venv && .venv/bin/pip install skyfield
.venv/bin/python tools/ephemeris/fit_ephemeris.py \
  --out lib/engine/astro/series_data.dart \
  --fixtures test/fixtures/ephemeris_fixtures.json
python3 tools/gazetteer/build_gazetteer.py
```

## Voice

Questions can be spoken and answers read back, in Hindi or English, through the
platform's own recogniser and voice — the browser's on the web. Nothing is
recorded or uploaded by this app, and every screen works with the microphone
switched off.

## What this app will not do

No predictions about death, illness, pregnancy, exams, court cases or
investments. No fear-based framing of doshas. No verdict on whether a marriage
should happen. Readings are presented as what the tradition says about a
configuration, with the classical source named, and a disclaimer travels with
them.

## Launching it

Icons, splash screens, the web manifest, store listings in both languages, the
privacy policy and the terms are all in the repository; see
[docs/LAUNCH.md](docs/LAUNCH.md) for what is done and the few things that still
need a human — a signing key, the store accounts, and screenshots.

## Licence

MIT, see [LICENSE](LICENSE). Data and font credits are in
[assets/data/ATTRIBUTION.md](assets/data/ATTRIBUTION.md).
