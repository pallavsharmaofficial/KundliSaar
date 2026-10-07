# The street flyer

A note-sized handbill people pick up off the ground, built by
`build_flyer.py` into `build/`.

```bash
pip3 install qrcode
python3 tools/flyer/build_flyer.py
```

## What it is, and what it deliberately is not

The sheet is **123 × 189 mm** and Z-folds down to **123 × 63 mm**, which is
exactly one ten-rupee footprint. Folded, it reads as money on the pavement,
which is what gets it picked up.

It is **not currency and says so on its face**. No portrait, no Reserve Bank
legend, no denomination, no serial number, no security thread — and
`यह नोट नहीं है।` printed on the outside. Section 489E IPC covers documents
"so nearly resembling as to be calculated to deceive"; a voucher that
announces it is not a note sits outside that, and advertising is exactly what
the section was written for, so this is not a line worth standing near.

Saying it also does the commercial work. The reader is let in on the joke
instead of feeling tricked, and the brand does not start the relationship by
annoying someone.

The money *idiom* is drawn, not copied: the rosettes and the wavy ground are
guilloche curves generated mathematically, the way a geometric lathe draws
them.

## The fold, which decides the layout

Z-fold — panel 1 folds forward onto panel 2, panel 3 folds up behind it.
Front to back the stack is then `P1b P1f P2f P2b P3f P3b`, so the two faces
left showing are **panel 1's back and panel 3's back**, both on the reverse
sheet. That is why both money faces are printed on the back and the message
panels on the front. Putting them on the front sheet hides them on the
inside, which loses the entire point.

| | Front sheet | Back sheet |
| --- | --- | --- |
| Panel 1 | the hook and the QR | **money face** (outside) |
| Panel 2 | what you get | write-your-details card |
| Panel 3 | why trust it | **money reverse** (outside) |

## The QR

Points at `…/KundliSaar/get/` — a page in this repo, never the Play listing.
A Play URL is useless to a stranger during closed testing and can change; this
one is ours forever and can be re-pointed at a store chooser later without
reprinting anything. The page works today because CI builds the web app to
`/app/`, so a scan gets a working kundli with no install at all.

Error correction level Q, so a creased and street-dirtied print still scans.

## Printing

One flyer per A4. Two will not fit in any rotation — 123 × 2 = 246 > 210 side
by side, 189 × 2 = 378 > 297 stacked — so A4 is for the first test batch only.
For any real quantity take `flyer-a4.pdf` to a local press and ask for
123 × 189 mm, double sided, Z-fold. At that size a press runs several-up on
its own sheet and costs a fraction of what home ink does.

**Test-scan one printed copy before committing to a run.** Phone cameras and
cheap colour printing disagree more often than you would expect.
