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
| Yogas and doshas | Mangal, Kaal Sarpa, Kemadruma, Gaja Kesari, Budhaditya, the five Mahapurusha yogas, Raja yogas, Sade Sati — each one naming the rule in the chart that produced it |
| Panchang | Tithi, nakshatra, yoga, karana and vara with end times, sunrise, sunset, moonrise, moonset, Rahu Kaal, Gulika, Yamaganda, Abhijit, day and night choghadiya, horas |
| Matching | Ashtakoota to 36 gunas with every koota explained, plus Mangal dosha on both sides |
| Ask | Questions answered from the computed chart in Hindi or English, each answer showing the chart factors it read from |
| Learn | The nine grahas, twelve rashis and 27 nakshatras with deity, symbol, lord, gana, yoni and nadi |

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
between 1905 and 2051, which checks precession, nutation and the frame at once.

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

## What this app will not do

No predictions about death, illness, pregnancy, exams, court cases or
investments. No fear-based framing of doshas. No verdict on whether a marriage
should happen. Readings are presented as what the tradition says about a
configuration, with the classical source named, and a disclaimer travels with
them.

## Licence

MIT, see [LICENSE](LICENSE). Data and font credits are in
[assets/data/ATTRIBUTION.md](assets/data/ATTRIBUTION.md).
