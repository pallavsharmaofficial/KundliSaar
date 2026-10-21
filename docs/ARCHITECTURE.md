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
  the turn that makes a hand upright, and the landmark projection back. The
  browser runs the same two files through the same Dart (see "In the browser"
  below).
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

### In the browser

The web build does the same job with the same Dart and the same two model files;
only the thing that runs a network, and the thing that supplies frames, differ.

- **Runtime.** Google's **LiteRT.js** (Apache 2.0): the WebAssembly build of the
  TensorFlow Lite kernels the phone runs. Its files are vendored into
  `web/litert/` (rebuilt by `vendor/litert_web/build.sh`, credited in
  `assets/data/ATTRIBUTION.md`) and fetched from the site's own origin, relative
  to the page's base href, so it works under `/KundliSaar/app/`. No CDN. The
  models are the same `assets/models/*.tflite`, now declared for web as well.
- **Why that and not MediaPipe Tasks.** `@mediapipe/tasks-vision` runs the same
  networks, but inside its own C++ graph: its crops and box arithmetic are not
  `mediapipe_hand.dart`'s, and its result is landmarks, world landmarks and a
  left/right label with a score, with neither the hand-presence probability nor
  the crop the landmark network saw, which the guidance reads its brightness and
  sharpness from. Two pipelines over one network would disagree by some pixels,
  and a hand type sits within a few hundredths of a cut-off often enough for that
  to change a reading between phone and browser. LiteRT.js leaves everything above
  the network as it is. It is also smaller (one 9.4 MB WebAssembly file against
  12.6 to 13.5 MB each) and needs no second copy of the models. (Tasks was read
  and sized, not run: it needs a WebGL canvas that Node cannot give a test.)
- **The seam.** `tensor_model.dart`'s `TensorModel`. `web_model.dart` holds a
  `ModelRunner` (shapes, names, a synchronous `run`) and `RunnerTensorModel`, which
  adapts it and refuses outputs of the wrong size or that are not numbers.
  `web_litert.dart` is the few lines of `dart:js_interop` behind it, calling
  `vendor/litert_web/src/hand_runtime.js`, which reaches LiteRT's compiled model
  directly because its public `run()` is asynchronous (it also serves WebGPU) and
  the pipeline is synchronous. The CPU build is used, not WebGPU, so that the
  arithmetic is the phone's.
- **No cross-origin isolation.** Only the non-threaded builds are shipped. Their
  memory is an ordinary `ArrayBuffer`, so no COOP/COEP headers are needed and
  GitHub Pages serves them as they are. The threaded build would have needed the
  headers and is left out.
- **Tracker and camera.** `hand_tracker_web.dart` runs `HandPipeline` on the page's
  own thread (a web page has no worker isolate to give it), after the same
  `frame_scan.dart` steps the phone's worker uses, and leaves the same gap between
  looks. `camera_source_web.dart` asks the browser for the camera with
  `getUserMedia`, shows it in a `<video>`, and copies a frame to a canvas ten
  times a second. Frames are handed over as the camera saw them, never mirrored;
  a webcam preview is mirrored on screen and the drawn hand is turned to match.
- **Loading.** Nothing is fetched until the person taps "Open the camera": then
  the camera is asked for first (so the browser's question follows the tap, and a
  refusal costs no download), then about 17 MB comes down once. A refusal, a
  browser without WebAssembly, an insecure page, or a failed download all end at
  the hand tracer, `/hastrekha/manual`, which is unchanged.
- **Held to the phone's numbers.** `test/palm/web_parity_test.dart` runs the
  browser's runtime under Node against TensorFlow Lite's C library, output by
  output and landmark by landmark; against a recording of the phone path kept in
  `test/palm/fixtures/phone_path.json`; and the Dart that the browser runs,
  compiled to JavaScript, against the same recording.

## Tooling

- `tools/ephemeris/fit_ephemeris.py` regenerates the series and the test
  fixtures.
- `tools/gazetteer/build_gazetteer.py` rebuilds the place list.
- `vendor/litert_web/build.sh` rebuilds `web/litert/` from the pinned LiteRT.js.
- `.github/workflows/ci.yml` analyses and tests every push.
- `.github/workflows/deploy-pages.yml` builds the site and the web app and
  publishes them to GitHub Pages on `main`.
