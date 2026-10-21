# Data and font credits

- **Ephemeris**: the planetary series in `lib/engine/astro/series_data.dart` were
  fitted to sampled geometry from NASA JPL's **DE440s** kernel, which is in the
  public domain. No third-party ephemeris code ships in this app.
- **Places**: `assets/data/places.json` is built from the GeoNames
  `cities15000` dump, licensed **CC BY 4.0**. Source: https://www.geonames.org
- **Time zones**: offsets come from the IANA time zone database through the
  Dart `timezone` package.
- **Fonts**: Mukta, Tiro Devanagari Hindi and Yatra One, all under the
  **SIL Open Font License 1.1**.
- **Hand models**: `assets/models/hand_detector.tflite` and
  `hand_landmarks_detector.tflite` are Google's MediaPipe palm detector and hand
  landmark network, taken unmodified from the `hand_landmarker.task` bundle
  published by Google (float16, version 1), under the **Apache License 2.0**
  (the model card says so; a copy of the licence is
  `assets/models/LICENSE-Apache-2.0.txt`). They run on the device and nothing is
  sent anywhere. SHA-256: detector `945f713b…27a7d`, landmarks `6acda74a…6d9b9`.
- **Model runtime**: `tflite_flutter` (Apache 2.0, TensorFlow authors), with
  Google's LiteRT on Android and TensorFlow Lite on iOS, both Apache 2.0. The
  `camera` plugin is BSD 3-Clause (the Flutter authors).
- **Model runtime in the browser**: **LiteRT.js** `@litertjs/core` 2.5.3 and its
  loader `@litertjs/wasm-utils` 2.5.3, from Google LLC, under the **Apache
  License 2.0** (npm registry, source https://github.com/google-ai-edge/LiteRT).
  It is the WebAssembly build of the same TensorFlow Lite kernels (XNNPACK on
  the CPU) that run on the phone, and loads the same two `.tflite` files from
  `assets/models/`. What is vendored, in `web/litert/`, is built by
  `vendor/litert_web/build.sh` and is served from this site's own origin, never
  from a CDN:
  - `litert_hand.js`: `@litertjs/core` and `@litertjs/wasm-utils` bundled with
    `vendor/litert_web/src/hand_runtime.js` (a small wrapper written for this
    app, MIT like the rest of it) by esbuild 0.25.10 (MIT, a build tool only).
    SHA-256 `537df13c…41ed6`.
  - `litert_wasm_internal.js` / `.wasm`, for browsers with relaxed SIMD.
    SHA-256 `.wasm` `7280cf44…65614`.
  - `litert_wasm_compat_internal.js` / `.wasm`, for browsers without it.
    SHA-256 `.wasm` `5255c8ad…1fa41c`.
  - `LICENSE-Apache-2.0.txt`, the licence text.

  The two `.wasm` files are unmodified from the npm package. They statically
  link LiteRT and TensorFlow Lite (Apache 2.0), XNNPACK, cpuinfo and
  pthreadpool (BSD 3-Clause), ruy, gemmlowp, FlatBuffers and Abseil (Apache
  2.0), FP16 and FXdiv (MIT) and Emscripten's runtime (MIT), all permissive;
  their notices are those of the LiteRT repository above. The threaded and JSPI
  builds in the same package are deliberately not shipped. Nothing here is
  AGPL or otherwise copyleft. Google's MediaPipe Tasks (`@mediapipe/tasks-vision`,
  also Apache 2.0) was looked at and not used; see `docs/ARCHITECTURE.md`.
- **Classical rules**: Brihat Parashara Hora Shastra, Phaladeepika and the
  Jaimini aphorisms are long out of copyright. Interpretations in this app are
  written for this project.
