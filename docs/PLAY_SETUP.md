# Getting on Google Play, and keeping it updated

Everything here that a machine can do is done. This is the part that needs
your hands on the Play Console, in the order it has to happen.

## The timeline, honestly

Your developer account is a **personal** account, so Google requires a closed
test with **at least 12 testers opted in continuously for 14 days** before you
may even apply for production. That is policy, not a queue you can jump.

| Day | What happens |
|---|---|
| Today | Create the app, fill the listing, upload the first bundle, start **internal testing**. The app installs on real phones through a link, straight away. |
| Today | Start **closed testing** and get 12 testers opted in. The clock starts the day the twelfth one joins, so do this first. |
| +14 days | Apply for production access. Google asks what you learned from the test; answer it properly. |
| +15 to +21 | Review. First reviews for a new account run long. |
| Then | Live on Play. |

Internal testing has no tester minimum and no waiting period, so people can
be using the app tonight — just not through a public listing.

## 1. Create the app

Play Console → **Create app**.

- App name: `KundliSaar: Kundli & Panchang` (from `store/play/en-IN/title.txt`)
- Default language: English (India). Add Hindi as a translation afterwards.
- App or game: App. Free or paid: **Free** (this cannot be changed to paid later).
- Declarations: tick both.

## 2. Upload the first bundle by hand

Google's API refuses to publish to an app that has never had a release, so the
first one goes up through the browser. Afterwards CI does every update.

The signed bundle is at `build/app/outputs/bundle/release/app-release.aab`
after `flutter build appbundle --release`, or download the `app-release-aab`
artifact from the **Release to Google Play** workflow run.

Testing → Internal testing → Create new release → upload it. Let Play turn on
**Play App Signing** when it offers: it means a lost upload key can be reset.

## 3. Fill the listing

Everything is written already, in `store/`:

| Console field | File |
|---|---|
| App name | `store/play/en-IN/title.txt` |
| Short description | `store/play/en-IN/short_description.txt` |
| Full description | `store/play/en-IN/full_description.txt` |
| Hindi translation | the same three under `store/play/hi-IN/` |
| App icon | `store/play/icon-512.png` |
| Feature graphic | `store/play/feature-graphic.png` |
| Phone screenshots | `store/screenshots/` |
| Release notes | `store/whatsnew/` |

Then the forms on the left, all of which `store/README.md` has the answers for:

- **Privacy policy**: `https://pallavsharmaofficial.github.io/KundliSaar/privacy.html`
- **Data safety**: no data collected, no data shared. Say that deletion is in
  the app, because it is: long-press a saved kundli.
- **Ads**: the app contains no ads.
- **Content rating**: answer the questionnaire; everything is no. Under the
  free-text part, say the app presents traditional astrological material for
  cultural purposes and refuses medical, legal and financial questions.
- **Target audience**: 18 and over. Do not opt into the children's programme.
- **Government apps, financial features, health**: no to all three.
- **Support email**: a personal address, which Play shows publicly.

## 4. Closed testing, which is the slow part

Testing → Closed testing → create a track.

The least painful way to hold 12 testers is a **Google Group**: make one, add
the twelve addresses, give the group address to Play as the tester list. Then
people joining or leaving never breaks the opt-in count.

Each tester must open the opt-in link and **install the app**, and stay opted
in for the whole fourteen days. Someone who uninstalls resets nothing, but
someone who leaves the track does.

Ask them for real feedback in writing. Google reads your answers about what
the test found, and a test with no findings looks like a test that did not
happen.

## 5. Turn on CI publishing

One-time setup so every later release is a button in GitHub.

1. **Google Cloud**: console.cloud.google.com → new project → APIs & Services
   → enable **Google Play Android Developer API**.
2. **Service account**: IAM & Admin → Service accounts → Create. No roles
   needed in Cloud. Open it → Keys → Add key → **JSON** → download.
3. **Play Console**: Users and permissions → Invite user → paste the service
   account's email → App permissions: this app → grant **Release to testing
   tracks** and **Release to production**. No account-level permissions.
4. **GitHub**: the repository's Settings → Secrets and variables → Actions →
   New secret named `PLAY_SERVICE_ACCOUNT_JSON`, with the whole JSON file
   pasted as the value. Or from a terminal:

   ```bash
   gh secret set PLAY_SERVICE_ACCOUNT_JSON \
     --repo pallavsharmaofficial/KundliSaar < ~/Downloads/service-account.json
   ```

The signing secrets (`ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`,
`ANDROID_KEY_ALIAS`) are already set.

## 6. Releasing after that

Actions → **Release to Google Play** → Run workflow → pick the track. It
analyses, tests, builds the signed bundle, keeps it as an artifact and pushes
it to Play. A `v*` tag does the same to the internal track.

Raise `version:` in `pubspec.yaml` before each upload — Play rejects a build
number it has seen before.

## Your signing key

`~/keystores/kundlisaar-upload.jks`, with its password in
`~/keystores/kundlisaar-upload.txt`. Both are outside the repository and
`android/key.properties` is gitignored. Copy the pair somewhere offline
tonight.
