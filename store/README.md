# Store listings

Everything a submission needs, so the console is only copy and paste.

| File | Where it goes |
|---|---|
| `play/en-IN/title.txt` | Play Console → Main store listing → App name |
| `play/en-IN/short_description.txt` | Short description (80 characters) |
| `play/en-IN/full_description.txt` | Full description (4,000 characters) |
| `play/hi-IN/*` | The same three fields under the Hindi (hi-IN) translation |
| `appstore/en-IN/metadata.txt` | App Store Connect, field by field |

## Graphics

| Asset | Size | Source |
|---|---|---|
| App icon | 512 × 512 | `assets/branding/icon-512.png` |
| iOS icon | 1024 × 1024 | `assets/branding/icon-1024.png` |
| Feature graphic | 1024 × 500 | crop `site/og-image.png`, or rerun `tools/branding/make_icon.py` |
| Phone screenshots | 1080 × 1920, at least two | take from a device or an emulator |

Screenshots are the one thing that cannot be generated from the repository:
they have to come from a running app. Shoot the chart screen, the panchang,
the Ask screen with the swamiji mid-answer, and the palm tracer.

## Play data safety

Answer the form this way, because it is what the code does:

- **Does your app collect or share any of the required user data types?** No.
- **Is all of the user data collected by your app encrypted in transit?** Not
  applicable: no data leaves the device.
- **Do you provide a way for users to request that their data be deleted?**
  Yes, in the app: long-press a saved kundli to delete it, or clear app data.
- **Data types:** none. Birth details, charts and settings are written to the
  app's own storage and are never transmitted.
- **Permissions:** microphone (optional, only while the mic button is held),
  camera and photos (optional, only for the palm photo the user chooses).

## Content rating questionnaire

Everything "no": no violence, no sexual content, no profanity, no controlled
substances, no gambling, no user-generated content, no sharing of location or
personal information. Mention under "miscellaneous" that the app presents
traditional astrological material for cultural and entertainment purposes and
explicitly refuses medical, legal and financial questions.
