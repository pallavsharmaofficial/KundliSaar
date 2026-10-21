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
  palm/              hastrekha by camera: hand models, guidance, capture,
                     crease search (see "Hastrekha by camera" below)
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

## Hastrekha by camera

`lib/palm/` finds a palm in the camera, tells the person what to fix, takes the
picture by itself and turns it into the inputs `lib/engine/jyotish/hastrekha.dart`
already reads. Everything runs on the phone: the photograph is never uploaded
and never written to storage. It is looked at as camera frames, and the one used
for the reading is held in memory until the person leaves the screen.

- **Models.** Google's MediaPipe hand detector and hand landmark network
  (Apache 2.0), two TensorFlow Lite files in `assets/models/` run through
  `tflite_flutter` in a worker isolate. The Dart around them (`mediapipe_hand.dart`,
  `hand_pipeline.dart`) is the MediaPipe graph written out: anchors, box decoding,
  the turn that makes a hand upright, and the landmark projection back. The web
  build has neither the runtime nor the models and keeps the hand tracer.
- **Guidance.** `palm_geometry.dart` measures the 21 points (how much of the
  frame the hand fills, whether it is cut off, how open the fingers are, which
  side faces the camera); `guidance.dart` turns that into one instruction at a
  time, in both languages. `capture_flow.dart` runs the count: well placed and
  steady for half a second, then 3, 2, 1, never a surprise.
- **Frames.** About eight looks a second, one at a time. A frame that arrives
  while the last is still being worked on is dropped, not queued.
- **What is measured.** The hand type comes from the landmarks (knuckle span and
  middle finger over palm length). The life, head and heart lines are searched
  for in the palm box (`crease_finder.dart`) and kept only when the evidence along
  them is continuous; anything less is reported as not clear and is never filled
  in. The fate and sun lines, breaks, chains, forks and the height of the mounts
  are not judged from a photograph.
- **Limits.** The hand models were checked against a dozen public photographs
  of palms and backs of hands, by eye, and the crease search against synthetic
  palms in the tests; neither has been tried across a population of phones or
  hands. Hands with henna or heavy rings are outside what the model was built
  for. A palm tilted away from the camera is not detected as tilted, and skews
  the hand type. The great lines are the least certain part: they are traced only
  where the evidence is continuous, they can be mistaken for another crease, and
  the photograph is shown with the traced lines on it so the person can see at a
  glance whether they sit on their own. Camera frames are assumed to need turning
  by the sensor's orientation with the screen held upright, which is what the
  camera plugin documents; that wants a check on a real device of each platform.

## Tooling

- `tools/ephemeris/fit_ephemeris.py` regenerates the series and the test
  fixtures.
- `tools/gazetteer/build_gazetteer.py` rebuilds the place list.
- `.github/workflows/ci.yml` analyses and tests every push.
- `.github/workflows/deploy-pages.yml` builds the site and the web app and
  publishes them to GitHub Pages on `main`.
