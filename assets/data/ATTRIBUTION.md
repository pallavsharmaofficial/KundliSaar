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
- **Classical rules**: Brihat Parashara Hora Shastra, Phaladeepika and the
  Jaimini aphorisms are long out of copyright. Interpretations in this app are
  written for this project.
