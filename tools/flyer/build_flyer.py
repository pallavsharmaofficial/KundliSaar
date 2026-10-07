#!/usr/bin/env python3
"""Builds the street flyer: a zero-rupee note people pick up off the ground.

Geometry. A ten-rupee note is 123 x 63 mm. Three of those stacked make a
123 x 189 mm sheet that Z-folds down to exactly one note footprint.

It is a ZERO-rupee note. Denomination 0, which no issued note carries, a
kundli chart where a portrait would sit, and "यह नोट नहीं है" on its face.
All the banknote furniture -- guilloche frames and rosettes, microtext, a
latent panel, a serial, corner numerals -- is generated from maths in
note.py, not copied from anywhere.

Text is kept to a minimum on every panel: a note carries very little, and
a panel that reads as a leaflet stops reading as money.
"""
import base64
import pathlib
import subprocess
import sys

import qrcode
import note

ART = pathlib.Path(__file__).resolve().parent / 'art'


def artwork(stem: str, fallback: str) -> str:
    """Use a generated background from art/ when one is there, else fall back
    to the drawn furniture in note.py.

    Drop art/face.png and art/reverse.png in at 1453 x 744 px or larger (that
    is 123 x 63 mm at 300 dpi) and they are embedded at full resolution. The
    text and the QR are always laid over the top as live vector, never baked
    into the image, so they stay crisp at any size and can be edited."""
    for ext in ('png', 'jpg', 'jpeg', 'webp'):
        f = ART / f'{stem}.{ext}'
        if f.exists():
            mime = 'jpeg' if ext in ('jpg', 'jpeg') else ext
            b64 = base64.b64encode(f.read_bytes()).decode('ascii')
            return (f'<img class="noteart" alt="" '
                    f'src="data:image/{mime};base64,{b64}">')
    return fallback

HERE = pathlib.Path(__file__).resolve().parent
OUT = HERE / 'build'
OUT.mkdir(exist_ok=True)

# Must outlive every reprint, so it is a page we own and can re-point: web app
# today, a store chooser later. Never the Play listing, which is useless to a
# stranger during closed testing and can change.
TARGET = 'https://pallavsharmaofficial.github.io/KundliSaar/get/'

PANEL_W, PANEL_H = 123.0, 63.0


def qr_svg(data: str) -> str:
    """Error correction Q, so a creased and street-dirtied print still scans."""
    qr = qrcode.QRCode(error_correction=qrcode.constants.ERROR_CORRECT_Q,
                       box_size=1, border=2)
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
    return (f'<svg class="qr" viewBox="0 0 {n} {n}" shape-rendering="crispEdges">'
            f'<rect width="{n}" height="{n}" fill="#fff"/>'
            f'<g fill="#1a1208">{"".join(rects)}</g></svg>')


NOTE_FACE = f'''
<div class="panel note">
  {artwork("face", note.face())}
  <div class="n-brand">कुंडलीसार<span>KUNDLISAAR</span></div>
  <div class="n-value">
    <div class="n-big">शून्य</div>
    <div class="n-words">मुफ़्त जन्मकुंडली</div>
  </div>
  <div class="n-promise">धारक को पूरी जन्मकुंडली देने का वचन</div>
  <div class="n-disclaim">यह नोट नहीं है <b>·</b> NOT LEGAL TENDER</div>
</div>
'''

NOTE_REVERSE = f'''
<div class="panel note rev">
  {artwork("reverse", note.reverse())}
  <div class="r-hook">आपकी राशि वो नहीं है<br>जो आप सोचते हैं।</div>
  <div class="r-foot">खोलिए <b>·</b> स्कैन कीजिए</div>
</div>
'''

REVEAL = f'''
<div class="panel reveal">
  <div class="rv-qr">{qr_svg(TARGET)}</div>
  <div class="rv-text">
    <b>स्कैन कीजिए</b>
    <span>दो सेकंड में पूरी कुंडली</span>
    <span class="rv-free">बिलकुल मुफ़्त</span>
  </div>
</div>
'''

WHAT = '''
<div class="panel what">
  <div class="w-title">क्या मिलेगा</div>
  <ul>
    <li>कुंडली और सोलह वर्ग</li>
    <li>दशा — तारीख़ के साथ</li>
    <li>पंचांग और मुहूर्त</li>
    <li>योग, दोष और निवारण</li>
  </ul>
</div>
'''

HONEST = '''
<div class="panel honest">
  <div class="h-title">भरोसा क्यों</div>
  <ul>
    <li>गणना NASA JPL से मिलाई गई</li>
    <li>हर बात का कारण साथ में</li>
    <li>डराकर उपाय नहीं बेचते</li>
  </ul>
  <div class="h-foot">कुछ भी अपलोड नहीं होता</div>
</div>
'''

DETAILS = '''
<div class="panel details">
  <div class="d-title">सही जन्म समय सबसे ज़रूरी है</div>
  <div class="d-why">पूछकर यहीं लिख लीजिए</div>
  <div class="fields">
    <label><span>नाम</span><i></i></label>
    <label><span>तिथि</span><i></i></label>
    <label><span>समय</span><i></i></label>
    <label><span>स्थान</span><i></i></label>
  </div>
</div>
'''

CSS = '''
@page { size: A4 portrait; margin: 0; }
* { box-sizing: border-box; margin: 0; padding: 0; }
body { background: #fff;
  font-family: 'Mukta','Kohinoor Devanagari','Devanagari Sangam MN',sans-serif;
  -webkit-print-color-adjust: exact; print-color-adjust: exact; }
.sheet { width: 210mm; height: 297mm; page-break-after: always;
         display: flex; align-items: center; justify-content: center; }
.sheet:last-child { page-break-after: auto; }
.flyer { width: 123mm; height: 189mm; position: relative; }
.mark { position: absolute; background: #000; }
.mark.h { width: 4mm; height: .2mm; }
.mark.v { width: .2mm; height: 4mm; }
.fold { position: absolute; left: -7mm; width: 5mm; height: .2mm;
        background: repeating-linear-gradient(to right,#000 0 1mm,transparent 1mm 2mm); }
.fold.r { left: auto; right: -7mm; }
.foldlabel { position: absolute; right: -7mm; font: 2.4mm/1 sans-serif; color: #777; }
.panel { width: 123mm; height: 63mm; position: relative; overflow: hidden; }
.noteart { position: absolute; inset: 0; width: 100%; height: 100%;
           object-fit: cover; }

/* --- the note faces --- */
.note { background: #e9d3a8; }
.n-brand { position: absolute; top: 3.4mm; left: 0; right: 0; text-align: center;
           font-size: 5.1mm; font-weight: 700; color: #4a1f0c; letter-spacing: .2mm; }
.n-brand span { display: block; font-size: 1.9mm; font-weight: 700; color: #6d3f12;
                letter-spacing: 1.5mm; margin-top: .2mm; }
.n-value { position: absolute; top: 17mm; left: 26mm; width: 60mm; text-align: center; }
.n-big { font-size: 13.5mm; font-weight: 700; color: #4a1f0c; line-height: .92;
         letter-spacing: .3mm; }
.n-words { font-size: 4.8mm; font-weight: 700; color: #6d3f12; margin-top: .6mm; }
.n-promise { position: absolute; top: 40.5mm; left: 26mm; width: 60mm;
             text-align: center; font-size: 2.4mm; color: #3a1d08; opacity: 1; font-weight: 600; }
.n-disclaim { position: absolute; bottom: 6.4mm; left: 0; right: 0; text-align: center;
              font-size: 2.6mm; font-weight: 700; color: #4a1f0c; }
.n-disclaim b { color: #7a4a18; }
.rev .r-hook { position: absolute; top: 17mm; left: 24mm; width: 75mm;
               text-align: center; font-size: 6.4mm; font-weight: 700;
               color: #4a1f0c; line-height: 1.28; }
.rev .r-foot { position: absolute; bottom: 7.5mm; left: 0; right: 0;
               text-align: center; font-size: 3.1mm; font-weight: 700; color: #4a1f0c; }

/* --- inside panels: dark, so the fold reveals a change --- */
.reveal { background: #6B1D1D; color: #f7ecd9; display: flex; gap: 6mm;
          align-items: center; justify-content: center; }
.qr { width: 27mm; height: 27mm; background: #fff; padding: 1.3mm; border-radius: 1mm; }
.rv-text { display: flex; flex-direction: column; gap: .8mm; }
.rv-text b { font-size: 6.2mm; color: #f6d98a; }
.rv-text span { font-size: 3.4mm; opacity: .92; }
.rv-free { font-size: 4mm !important; font-weight: 600; color: #f6d98a; opacity: 1 !important; }

.what, .honest { background: #fbf2e1; color: #3a2512; padding: 6mm 9mm;
                 display: flex; flex-direction: column; justify-content: center; gap: 2mm; }
.honest { background: #6B1D1D; color: #f7ecd9; }
.w-title, .h-title { font-size: 5mm; font-weight: 700; color: #6B1D1D; }
.h-title { color: #f6d98a; }
.what ul, .honest ul { list-style: none; }
.what li, .honest li { font-size: 3.5mm; line-height: 1.62; padding-left: 4.5mm;
                       position: relative; }
.what li::before, .honest li::before { content: '\\2022'; position: absolute;
                                       left: 1mm; color: #b8860b; }
.honest li::before { color: #f6d98a; }
.h-foot { font-size: 2.9mm; opacity: .85; margin-top: 1mm; }

.details { background: #fff; color: #3a2512; padding: 6mm 9mm;
           display: flex; flex-direction: column; justify-content: center; gap: 2.4mm; }
.d-title { font-size: 4.4mm; font-weight: 700; color: #6B1D1D; }
.d-why { font-size: 3mm; color: #7a4a18; }
.fields { display: grid; grid-template-columns: 1fr 1fr; column-gap: 8mm; row-gap: 5mm; }
.fields label { display: flex; align-items: baseline; gap: 2mm; }
.fields span { font-size: 3mm; font-weight: 600; color: #7a4a18; white-space: nowrap; }
.fields i { flex: 1; height: .25mm; background: #3a2512; opacity: .45; }
'''

DEFS = '''<svg width="0" height="0" style="position:absolute"><defs>
<linearGradient id="paper" x1="0" y1="0" x2="1" y2="1">
<stop offset="0" stop-color="#eedcb4"/><stop offset=".5" stop-color="#e4cb9c"/>
<stop offset="1" stop-color="#ecd8b1"/></linearGradient></defs></svg>'''


def marks() -> str:
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


def sheet(panels, label):
    return (f'<div class="sheet"><div class="flyer">{marks()}'
            f'<div class="foldlabel" style="top:-1mm">{label}</div>'
            f'{"".join(panels)}</div></div>')


def main() -> int:
    # Z-fold: panel 1 folds forward onto panel 2, panel 3 folds up behind it.
    # Front to back the stack is P1b P1f P2f P2b P3f P3b, so the faces left
    # showing are panel 1's BACK and panel 3's BACK -- both on the reverse
    # sheet. That is where the note faces must go. On the front sheet they
    # would be hidden on the inside, which loses the whole point.
    front = sheet([REVEAL, WHAT, HONEST], 'INSIDE')
    back = sheet([NOTE_FACE, DETAILS, NOTE_REVERSE], 'OUTSIDE')

    chrome = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'

    def render(body, stem):
        page = ('<!doctype html><html lang="hi"><head><meta charset="utf-8">'
                '<link href="https://fonts.googleapis.com/css2?'
                'family=Mukta:wght@400;600;700&display=swap" rel="stylesheet">'
                f'<style>{CSS}</style></head><body>{DEFS}{body}</body></html>')
        h = OUT / f'{stem}.html'
        h.write_text(page, encoding='utf-8')
        pdf = OUT / f'{stem}.pdf'
        subprocess.run([chrome, '--headless', '--disable-gpu',
                        '--no-pdf-header-footer', f'--print-to-pdf={pdf}',
                        f'file://{h}'], check=True, capture_output=True, timeout=180)
        return pdf

    pdf = render(back + front, 'flyer-a4')
    render(back, 'flyer-outside')
    render(front, 'flyer-inside')
    print(f'QR target : {TARGET}')
    print(f'PDF       : {pdf}  ({pdf.stat().st_size // 1024} KB)')
    print('Sheet 123 x 189 mm, Z-folds to 123 x 63 mm (one note footprint).')
    print('Page 1 = OUTSIDE (both note faces), page 2 = INSIDE.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
