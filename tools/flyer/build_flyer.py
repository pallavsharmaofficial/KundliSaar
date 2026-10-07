#!/usr/bin/env python3
"""Builds the street flyer: a note-sized handbill people pick up off the ground.

Geometry. A 10-rupee note is 123 x 63 mm. Three panels of that stacked make a
123 x 189 mm sheet that Z-folds down to exactly one note footprint. Two of
those will NOT fit on an A4 in any rotation (246 > 210 side by side, 378 > 297
stacked), so A4 is one-up and only worth it for the first test batch; the press
sheet below is four-up and an order of magnitude cheaper per piece.

Deliberately NOT currency. No portrait, no RBI legend, no denomination, no
serial, no security thread, and it says so on its face. Section 489E IPC is
about documents "so nearly resembling as to be calculated to deceive", and a
voucher that announces it is not a note is outside that. The announcement is
also the joke, which is what stops the reader feeling tricked.
"""
import math
import pathlib
import subprocess
import sys

import qrcode
import qrcode.image.svg

HERE = pathlib.Path(__file__).resolve().parent
OUT = HERE / 'build'
OUT.mkdir(exist_ok=True)

# The QR must outlive every reprint, so it points at a page we own and can
# re-target: web app today, Play listing later, a store chooser after that.
# Never at the Play listing itself, which is useless during closed testing.
TARGET = 'https://pallavsharmaofficial.github.io/KundliSaar/get/'

PANEL_W, PANEL_H = 123.0, 63.0          # one note footprint
SHEET_W, SHEET_H = PANEL_W, PANEL_H * 3


def qr_svg(data: str) -> str:
    """QR as an inline SVG group, error correction Q so a street-dirtied or
    creased print still scans."""
    qr = qrcode.QRCode(
        version=None,
        error_correction=qrcode.constants.ERROR_CORRECT_Q,
        box_size=1,
        border=2,
    )
    qr.add_data(data)
    qr.make(fit=True)
    m = qr.get_matrix()
    n = len(m)
    rects = []
    for y, row in enumerate(m):
        x = 0
        while x < n:
            if row[x]:
                run = 1
                while x + run < n and row[x + run]:
                    run += 1
                rects.append(f'<rect x="{x}" y="{y}" width="{run}" height="1"/>')
                x += run
            else:
                x += 1
    return (
        f'<svg class="qr" viewBox="0 0 {n} {n}" shape-rendering="crispEdges">'
        f'<rect width="{n}" height="{n}" fill="#fff"/>'
        f'<g fill="#1a1208">{"".join(rects)}</g></svg>'
    )


def guilloche(cx, cy, rings=5, seed=0.0, scale=1.0) -> str:
    """An engine-turned rosette, the way a security printer's geometric lathe
    draws one: two coupled circles traced as one continuous line. Many fine
    rings rather than few fat ones -- at 0.12 mm the eye reads engraving, at
    0.25 mm it reads as a flower. Mathematical, so it imitates the IDIOM of
    printed money without reproducing any part of any note."""
    paths = []
    for ring in range(rings):
        big = (23 - ring * 3.4) * scale
        small = (3.0 + ring * 0.55) * scale
        k = 13 + ring * 7
        pts = []
        steps = 900
        for i in range(steps + 1):
            t = (i / steps) * 2 * math.pi
            r = big + small * math.cos(k * t + seed + ring * 0.8)
            pts.append(f'{cx + r * math.cos(t):.2f},{cy + r * math.sin(t):.2f}')
        paths.append(
            f'<polyline points="{" ".join(pts)}" fill="none" '
            f'stroke="#8a5a1c" stroke-width="0.12" '
            f'opacity="{0.42 - ring * 0.045:.2f}"/>'
        )
    return ''.join(paths)


def engine_field() -> str:
    """The fine wavy ground a note carries behind its type."""
    rows = []
    for j in range(32):
        y0 = j * 2.0
        pts = []
        for i in range(301):
            x = i / 300 * 123
            pts.append(f'{x:.2f},{y0 + 0.75 * math.sin(x * 0.32 + j * 0.55):.2f}')
        rows.append(
            f'<polyline points="{" ".join(pts)}" fill="none" stroke="#8a5a1c" '
            f'stroke-width="0.09" opacity="0.16"/>'
        )
    return ''.join(rows)


def lathe_border() -> str:
    """A fine wavy rule for the panel edge, same lathe idea, one line."""
    pts = []
    for i in range(1601):
        x = i / 1600 * 123
        pts.append(f'{x:.2f},{3 + 1.1 * math.sin(x * 0.9):.2f}')
    return (
        f'<polyline points="{" ".join(pts)}" fill="none" stroke="#8a5a1c" '
        f'stroke-width="0.25" opacity="0.5"/>'
    )


MONEY_FACE = f'''
<div class="panel money">
  <svg class="rosette" viewBox="0 0 123 63" preserveAspectRatio="none">
    <rect width="123" height="63" fill="url(#paper)"/>
    {engine_field()}
    {lathe_border()}
    <g transform="translate(0,57) scale(1,-1)">{lathe_border()}</g>
    {guilloche(19, 31.5, 5, 0.0, 0.78)}
    {guilloche(104, 31.5, 5, 1.7, 0.78)}
  </svg>
  <div class="money-inner">
    <div class="money-top">
      <span class="brand">कुंडलीसार</span>
      <span class="brand-en">KundliSaar</span>
    </div>
    <div class="money-mid">
      <div class="big">मुफ़्त</div>
      <div class="big-sub">जन्मकुंडली</div>
    </div>
    <div class="money-bottom">
      <span class="disclaim">यह नोट नहीं है।</span>
      <span class="disclaim-en">This is not currency.</span>
    </div>
  </div>
</div>
'''

MONEY_REVERSE = f'''
<div class="panel money reverse">
  <svg class="rosette" viewBox="0 0 123 63" preserveAspectRatio="none">
    <rect width="123" height="63" fill="url(#paper)"/>
    {engine_field()}
    {lathe_border()}
    <g transform="translate(0,57) scale(1,-1)">{lathe_border()}</g>
    {guilloche(18, 31.5, 5, 0.9, 0.62)}
    {guilloche(105, 31.5, 5, 2.4, 0.62)}
  </svg>
  <div class="money-inner">
    <div class="money-mid">
      <div class="rev-line">आपकी राशि वो नहीं है</div>
      <div class="rev-line">जो आप सोचते हैं।</div>
    </div>
    <div class="money-bottom">
      <span class="disclaim">पलटिए · Turn over</span>
    </div>
  </div>
</div>
'''

REVEAL = f'''
<div class="panel reveal">
  <div class="hook">आपकी राशि वो नहीं है<br>जो आप सोचते हैं।</div>
  <div class="hook-why">सूर्य राशि अंग्रेज़ी ज्योतिष की है।
    भारतीय परंपरा चंद्र राशि से चलती है — और वो अक्सर अलग निकलती है।</div>
  <div class="scan">
    {qr_svg(TARGET)}
    <div class="scan-text">
      <b>स्कैन कीजिए</b>
      <span>दो सेकंड में अपनी पूरी कुंडली</span>
      <span class="free">बिलकुल मुफ़्त · कोई खाता नहीं</span>
    </div>
  </div>
</div>
'''

WHAT = '''
<div class="panel what">
  <div class="what-title">क्या मिलेगा</div>
  <ul>
    <li>लग्न कुंडली और सोलह वर्ग कुंडलियाँ</li>
    <li>विंशोत्तरी दशा — कौन सी तारीख़ से कौन सी तारीख़ तक</li>
    <li>पूरा पंचांग, चौघड़िया, मुहूर्त</li>
    <li>योग, दोष — और उनका शास्त्रीय निवारण भी</li>
    <li>गुण मिलान, वर्षफल, फलादेश</li>
  </ul>
  <div class="what-foot">
    <span>गणना आपके फ़ोन पर होती है। कुछ भी अपलोड नहीं होता।</span>
    <span class="nofear">न डर, न महँगे उपाय। जो शास्त्र कहता है, वही — कारण के साथ।</span>
  </div>
</div>
'''

DETAILS = '''
<div class="panel details">
  <div class="det-head">
    <div class="det-title">कुंडली के लिए<br>यही चार चीज़ें चाहिए</div>
    QRSLOT
  </div>
  <div class="det-why">सही <b>जन्म समय</b> सबसे ज़रूरी है — पाँच मिनट के फ़र्क़ से
    दशा हफ़्तों आगे-पीछे हो जाती है। माँ या पिताजी से पूछकर यहीं लिख लीजिए,
    ताकि भूल न जाए।</div>
  <div class="fields">
    <label><span>नाम</span><i></i></label>
    <label><span>जन्म तिथि</span><i></i></label>
    <label><span>जन्म समय</span><i></i></label>
    <label><span>जन्म स्थान</span><i></i></label>
  </div>
  <div class="det-foot">लिख लिया? अब ऐप खोलकर भर दीजिए — बाक़ी सब वो कर देगा।</div>
</div>
'''


HONEST = f"""
<div class="panel honest">
  <div class="h-title">भरोसा क्यों करें</div>
  <ul>
    <li>ग्रह गणना <b>NASA JPL</b> के आँकड़ों से मिलाई गई — एक विकला तक।</li>
    <li>हर कथन के साथ <b>कारण</b>: किस ग्रह, किस भाव, किस नियम से।</li>
    <li>दोष के साथ उसका <b>शास्त्रीय निवारण</b> भी — डराकर उपाय नहीं बेचते।</li>
    <li>मृत्यु, बीमारी, मुक़दमा, परीक्षा — इन पर यह ऐप <b>भविष्यवाणी नहीं करता</b>।</li>
  </ul>
  <div class="h-now">
    <b>अभी चलाकर देखिए</b> — ऐप इंस्टॉल किए बिना, ब्राउज़र में ही।
  </div>
</div>
"""

CSS = '''
@page { size: A4 portrait; margin: 0; }
* { box-sizing: border-box; margin: 0; padding: 0; }
html, body { background: #fff; }
body {
  font-family: 'Mukta', 'Kohinoor Devanagari', 'Devanagari Sangam MN',
               'Noto Sans Devanagari', sans-serif;
  -webkit-print-color-adjust: exact; print-color-adjust: exact;
}
.sheet { width: 210mm; height: 297mm; position: relative;
         page-break-after: always; display: flex;
         align-items: center; justify-content: center; }
.sheet:last-child { page-break-after: auto; }
.flyer { width: 123mm; height: 189mm; position: relative; }

/* Crop and fold marks, outside the artwork so they cut away. */
.mark { position: absolute; background: #000; }
.mark.h { width: 4mm; height: 0.2mm; }
.mark.v { width: 0.2mm; height: 4mm; }
.fold { position: absolute; left: -7mm; width: 5mm; height: 0.2mm;
        background: repeating-linear-gradient(to right,#000 0 1mm,transparent 1mm 2mm); }
.fold.r { left: auto; right: -7mm; }
.foldlabel { position: absolute; right: -7mm; font: 2.4mm/1 sans-serif;
             color: #555; transform: translateY(-3.6mm); }

.panel { width: 123mm; height: 63mm; position: relative; overflow: hidden; }

/* --- the money-format face --- */
.money { background: #f4e3c4; }
.rosette { position: absolute; inset: 0; width: 100%; height: 100%; }
.money-inner { position: absolute; inset: 0; padding: 4mm 6mm;
               display: flex; flex-direction: column;
               justify-content: space-between; align-items: center; }
.money-top { display: flex; align-items: baseline; gap: 2.5mm; }
.brand { font-size: 6mm; font-weight: 700; color: #6B1D1D; letter-spacing: .2mm; }
.brand-en { font-size: 3mm; font-weight: 600; color: #8a5a1c;
            letter-spacing: 1.2mm; text-transform: uppercase; }
.money-mid { text-align: center; }
.big { font-size: 15mm; font-weight: 700; color: #6B1D1D; line-height: .95; }
.big-sub { font-size: 6.4mm; font-weight: 600; color: #8a5a1c; line-height: 1.1; }
.money-bottom { display: flex; flex-direction: column; align-items: center; gap: .4mm; }
.disclaim { font-size: 3.4mm; font-weight: 700; color: #6B1D1D;
            border: 0.35mm solid #8a5a1c; padding: .5mm 2mm; border-radius: 1mm; }
.disclaim-en { font-size: 2.3mm; color: #8a5a1c; letter-spacing: .3mm; }
.reverse .rev-line { font-size: 6.2mm; font-weight: 700; color: #6B1D1D;
                     line-height: 1.25; text-align: center; }

/* --- the reveal --- */
.reveal { background: #6B1D1D; color: #f7ecd9; padding: 5mm 6mm;
          display: flex; flex-direction: column; justify-content: space-between; }
.hook { font-size: 7.6mm; font-weight: 700; line-height: 1.18; color: #f6d98a; }
.hook-why { font-size: 3.1mm; line-height: 1.45; opacity: .88; max-width: 101mm;
            text-wrap: balance; }
.scan { display: flex; align-items: center; gap: 4mm; }
.qr { width: 21mm; height: 21mm; background: #fff; padding: 1.1mm;
      border-radius: 1mm; flex: none; }
.scan-text { display: flex; flex-direction: column; gap: .5mm; }
.scan-text b { font-size: 4.4mm; color: #f6d98a; }
.scan-text span { font-size: 3mm; opacity: .9; }
.scan-text .free { font-size: 3.2mm; font-weight: 600; color: #f6d98a; opacity: 1; }

/* --- what you get --- */
.what { background: #fbf4e6; color: #3a2512; padding: 4.5mm 6mm;
        display: flex; flex-direction: column; justify-content: space-between; }
.what-title { font-size: 4.6mm; font-weight: 700; color: #6B1D1D; }
.what ul { list-style: none; }
.what li { font-size: 3.15mm; line-height: 1.5; padding-left: 4mm; position: relative; }
.what li::before { content: '•'; position: absolute; left: 1mm; color: #b8860b; }
.what-foot { display: flex; flex-direction: column; gap: .6mm;
             border-top: 0.25mm solid #d9c3a0; padding-top: 1.4mm; }
.what-foot span { font-size: 2.7mm; line-height: 1.35; }
.nofear { color: #6B1D1D; font-weight: 600; }

/* --- the details card --- */
.details { background: #fff; color: #3a2512; padding: 4.5mm 6mm;
           display: flex; flex-direction: column; justify-content: space-between;
           border-top: 0.3mm dashed #c9ae86; border-bottom: 0.3mm dashed #c9ae86; }
.det-title { font-size: 4.4mm; font-weight: 700; color: #6B1D1D; }
.det-why { font-size: 2.8mm; line-height: 1.4; }
.fields { display: grid; grid-template-columns: 1fr 1fr;
          column-gap: 6mm; row-gap: 2.2mm; }
.fields label { display: flex; flex-direction: column; gap: .8mm; }
.fields span { font-size: 2.7mm; font-weight: 600; color: #8a5a1c; }
.fields i { display: block; height: 0.25mm; background: #3a2512; opacity: .45; }
.det-foot { font-size: 2.6mm; color: #6B1D1D; font-weight: 600; }

/* --- why trust it --- */
.honest { background: #6B1D1D; color: #f7ecd9; padding: 4.5mm 6mm;
          display: flex; flex-direction: column; justify-content: space-between; }
.h-title { font-size: 4.4mm; font-weight: 700; color: #f6d98a; }
.honest ul { list-style: none; }
.honest li { font-size: 2.95mm; line-height: 1.45; padding-left: 4mm;
             position: relative; }
.honest li::before { content: '\2022'; position: absolute; left: 1mm; color: #f6d98a; }
.honest b { color: #f6d98a; }
.h-now { font-size: 3mm; border-top: 0.25mm solid rgba(246,217,138,.45);
         padding-top: 1.4mm; }
/* A mini QR on the writing card too, so the back works on its own if that
   is the side someone happens to be looking at. */
.det-head { display: flex; align-items: flex-start;
            justify-content: space-between; gap: 4mm; }
.det-head .qr { width: 13mm; height: 13mm; padding: .7mm; }
'''

DEFS = '''
<svg width="0" height="0" style="position:absolute">
  <defs>
    <linearGradient id="paper" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#f6e7ca"/>
      <stop offset="0.5" stop-color="#f1dcb6"/>
      <stop offset="1" stop-color="#f5e4c6"/>
    </linearGradient>
  </defs>
</svg>
'''


def marks() -> str:
    """Crop marks at the four corners, fold marks at 63 and 126 mm."""
    out = []
    for x in ('-5mm', '123mm'):
        for y in ('0', '189mm'):
            out.append(f'<i class="mark h" style="left:{x};top:{y}"></i>')
    for x in ('0', '123mm'):
        for y in ('-5mm', '189mm'):
            out.append(f'<i class="mark v" style="left:{x};top:{y}"></i>')
    for y in (63, 126):
        out.append(f'<i class="fold" style="top:{y}mm"></i>')
        out.append(f'<i class="fold r" style="top:{y}mm"></i>')
    return ''.join(out)


def sheet(panels: list[str], label: str) -> str:
    return (
        f'<div class="sheet"><div class="flyer">{marks()}'
        f'<div class="foldlabel" style="top:0">{label}</div>'
        f'{"".join(panels)}</div></div>'
    )


def main() -> int:
    # Z-fold: panel 1 folds down over 2, panel 3 folds up behind 2. The two
    # faces left outside are therefore P1 front and P3 back -- so both of
    # those carry the money format, which is also how a real note has two
    # sides. The inside spread and the back two panels carry the message.
    # Z-fold: panel 1 folds forward onto panel 2, panel 3 folds up behind it.
    # Front-to-back the stack is then P1b P1f P2f P2b P3f P3b, so the two
    # faces left showing are P1's BACK and P3's BACK -- both on the reverse
    # sheet. That is where the money format has to go; putting it on the
    # front sheet would hide it on the inside, which is the whole point lost.
    details = DETAILS.replace('QRSLOT', qr_svg(TARGET))
    front = sheet([REVEAL, WHAT, HONEST], 'FRONT')
    back = sheet([MONEY_FACE, details, MONEY_REVERSE], 'BACK')
    chrome = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'

    def render(body: str, stem: str) -> pathlib.Path:
        page = (
            '<!doctype html><html lang="hi"><head><meta charset="utf-8">'
            '<link href="https://fonts.googleapis.com/css2?'
            'family=Mukta:wght@400;600;700&display=swap" rel="stylesheet">'
            f'<style>{CSS}</style></head><body>{DEFS}{body}</body></html>'
        )
        h = OUT / f'{stem}.html'
        h.write_text(page, encoding='utf-8')
        pdf = OUT / f'{stem}.pdf'
        subprocess.run(
            [chrome, '--headless', '--disable-gpu', '--no-pdf-header-footer',
             f'--print-to-pdf={pdf}', f'file://{h}'],
            check=True, capture_output=True, timeout=120,
        )
        return pdf

    # Both sides in one file for a press, and one file per side because a
    # home printer wants to be fed each side separately.
    pdf_path = render(front + back, 'flyer-a4')
    render(front, 'flyer-front')
    render(back, 'flyer-back')
    html_path = OUT / 'flyer-a4.html'
    print(f'QR target : {TARGET}')
    print(f'HTML      : {html_path}')
    print(f'PDF       : {pdf_path}  ({pdf_path.stat().st_size // 1024} KB)')
    print('Sheet 123 x 189 mm, Z-folds to 123 x 63 mm (one note footprint).')
    return 0


if __name__ == '__main__':
    sys.exit(main())
