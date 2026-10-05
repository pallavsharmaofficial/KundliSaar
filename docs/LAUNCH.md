# Launching

The app is free on every platform, with no advertising, no subscription and
nothing to buy inside it. This is what is already done and what still needs a
human.

## Already done in this repository

- **Icons** for Android (legacy, adaptive and monochrome), iOS, and the web,
  generated from `tools/branding/make_icon.py`. The mark is the North Indian
  kundli itself; below about sixty pixels the small renders drop the diagonals
  so the shape still reads at favicon size.
- **Splash screens** for Android (including the Android 12 style) and iOS, in
  light and dark.
- **Web app manifest** with name, description, categories, maskable icons and
  three shortcuts, so the app installs to a phone's home screen from the
  browser.
- **Page metadata**: title, description, canonical link, Open Graph and Twitter
  cards with a generated social image, `robots.txt` and `sitemap.xml`.
- **Android**: app label in English and Hindi, microphone, camera and photo
  permissions with the hardware marked not required, the `<queries>` entries
  that Android 11 and later need for speech and text to speech, `minSdk` 23,
  R8 shrinking with rules for the plugins, and release signing wired to
  `android/key.properties`.
- **iOS**: display name, Hindi and English localisations, the four usage
  descriptions, and the encryption declaration.
- **Privacy policy** and **terms** published at `/privacy.html` and
  `/terms.html`, linked from the site footer and from the app's About screen.
- **Store listings** in English and Hindi, inside `store/`, with the Play data
  safety answers and the content rating notes written out.

## What still needs you

1. **A signing key for Android.** Make it once and keep it safe: losing it
   means never updating the listing again.

   ```bash
   keytool -genkey -v -keystore ~/kundlisaar-upload.jks \
     -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```

   Then write `android/key.properties`, which git ignores:

   ```properties
   storePassword=…
   keyPassword=…
   keyAlias=upload
   storeFile=/Users/you/kundlisaar-upload.jks
   ```

   Build the bundle with `flutter build appbundle --release`.

2. **A Google Play developer account** — a one-time 25 USD registration. Play
   also asks for a public support email address; use a personal one, not a
   company address.

3. **An Apple Developer account** for the App Store — 99 USD a year, and the
   only real cost of launching. The web app needs none of this and reaches an
   iPhone through the browser in the meantime.

4. **Screenshots.** The one asset that cannot come out of this repository.
   Two or more at 1080 × 1920: the chart screen, the panchang, the Ask screen
   with the swamiji mid-answer, and the palm tracer.

5. **A decision on the art lane**, which is the only thing between this and a
   first store release feeling finished.

## Checks before each release

```bash
flutter analyze
flutter test
flutter build web --release --base-href "/KundliSaar/app/"
flutter build appbundle --release
```

CI runs the first two on every push, and the Pages workflow runs all of them
plus the deployment on `main`.

## Versioning

`pubspec.yaml` holds `version: x.y.z+build`. The build number must rise with
every upload to either store; the version name is what people see.
