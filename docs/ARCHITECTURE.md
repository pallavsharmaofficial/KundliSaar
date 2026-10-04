# Architecture

The same layering as SurSaar, for the same reason: the interesting part is a
pure Dart core that can be tested without a device.

```
lib/
  engine/            pure Dart, no Flutter import anywhere
    astro/           time, frames, the fitted series, ephemeris, ayanamsa,
                     houses, rise and set
    jyotish/         rashi, nakshatra, graha data, vargas, chart assembly,
                     dashas, panchang, yogas, matching
  ask/               template answers composed from a computed chart
  data/              LocalStore (shared_preferences, localStorage on web),
                     places gazetteer, profiles, time zones
  models/            saved profiles
  state/             flutter_bloc cubits for settings and profiles
  core/              theme, router, app shell
  widgets/           chart painters and shared panels
  screens/           home, birth form, chart, ask, panchang, matching, learn,
                     settings, about
  l10n/              Hindi and English ARB files
```

- **Persistence** is a JSON document store over `shared_preferences`, which is
  `localStorage` on the web. There is no account and no server.
- **Routing** is `go_router`, built per instance so tests can run several apps
  at once.
- **Place data** ships in the bundle (`assets/data/places.json`, built from
  GeoNames) so the birth form works with the radio off.
- **Time zones** resolve through the IANA database by zone name, never by a
  stored offset, so historical rules such as India's 1942–45 war time apply.
- **Charts** are drawn in code: North Indian, South Indian and a chakra wheel,
  all fed by the same placements.

## Tooling

- `tools/ephemeris/fit_ephemeris.py` regenerates the series and the test
  fixtures.
- `tools/gazetteer/build_gazetteer.py` rebuilds the place list.
- `.github/workflows/ci.yml` analyses and tests every push.
- `.github/workflows/deploy-pages.yml` builds the site and the web app and
  publishes them to GitHub Pages on `main`.
