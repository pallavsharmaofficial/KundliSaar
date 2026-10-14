#!/usr/bin/env python3
"""Visiting card for Pandit Chanchal Sharma.

89 x 51 mm, ten to an A4, crop marks, front and back.

The design is deliberately empty. A card earns trust from three things --
a clear photograph, a phone number big enough to read without glasses, and
space around both. Heavy ornament reads as cheap and is what every other
pandit's card already does, so the border here is a thin rule with small
corner flourishes and nothing else.

Nothing on it promises an outcome. A card that states a name, a trade and a
number is believed; one that guarantees results is not.

Edit PHONE and the rest of the DETAILS block, then:
    python3 tools/card/build_card.py
Drop a photograph at art/photo.jpg (square, head and shoulders) and
backgrounds at art/front.png and art/back.png to use them instead of the
drawn border.
"""
import base64
import math
import pathlib
import subprocess
import sys

HERE = pathlib.Path(__file__).resolve().parent
ART = HERE / 'art'
OUT = HERE / 'build'
OUT.mkdir(exist_ok=True)

# ---------------------------------------------------------------- details
PHONE = '+91 XXXXX XXXXX'          # <- put the real number here
WHATSAPP = ''                      # only if it differs from PHONE
CITY = ''                          # e.g. 'जयपुर, राजस्थान' -- blank to omit

NAME_HI = 'पंडित चंचल शर्मा'
NAME_EN = 'Pt. Chanchal Sharma'
ALSO_HI = 'चेतन शर्मा'
TAGLINE_HI = 'ज्योतिष · कर्मकांड · कथा'
TAGLINE_EN = 'Astrology · Rituals · Katha'

SERVICES = [
    ('जन्म कुंडली निर्माण एवं विश्लेषण', 'Birth chart & reading'),
    ('राशिफल एवं ज्योतिष परामर्श', 'Horoscope & consultation'),
    ('विवाह मिलान एवं मुहूर्त', 'Matching & muhurta'),
    ('सत्यनारायण पूजा', 'Satyanarayan Puja'),
    ('श्रीमद् भागवत कथा', 'Bhagwat Katha'),
    ('श्री राम कथा', 'Ram Katha'),
]

W, H = 89.0, 51.0                  # the standard card
MAROON = '#6B1D1D'
GOLD = '#A8791F'
INK = '#3A2512'


def asset(*names):
    for n in names:
        for ext in ('png', 'jpg', 'jpeg', 'webp'):
            f = ART / f'{n}.{ext}'
            if f.exists():
                mime = 'jpeg' if ext in ('jpg', 'jpeg') else ext
                b64 = base64.b64encode(f.read_bytes()).decode('ascii')
                return f'data:image/{mime};base64,{b64}'
    return None


def flourish(x, y, flip_x, flip_y):
    """A small corner motif: three nested arcs and a leaf, in line only.
    Restrained on purpose -- it should be noticed second, after the name."""
    sx, sy = (-1 if flip_x else 1), (-1 if flip_y else 1)
    parts = []
    for i, r in enumerate((2.0, 2.9, 3.8)):
        pts = []
        for k in range(25):
            t = math.pi / 2 * k / 24
            pts.append(f'{x + sx * r * math.cos(t):.2f},'
                       f'{y + sy * r * math.sin(t):.2f}')
        parts.append(
            f'<polyline points="{" ".join(pts)}" fill="none" stroke="{GOLD}" '
            f'stroke-width="{0.22 - i * 0.04:.2f}" opacity="{0.9 - i * 0.2:.1f}"/>')
    parts.append(
        f'<path d="M {x + sx * 0.7} {y + sy * 3.4} '
        f'q {sx * 1.4} {sy * 0.25} {sx * 1.9} {sy * 1.7} '
        f'q {-sx * 1.5} {-sy * 0.3} {-sx * 1.9} {-sy * 1.7} Z" '
        f'fill="{GOLD}" opacity="0.45"/>')
    return ''.join(parts)


def border():
    """Two rules and four corners. Nothing else touches the field."""
    return (
        f'<svg class="art" viewBox="0 0 {W} {H}" preserveAspectRatio="none">'
        f'<rect width="{W}" height="{H}" fill="#FDF6E8"/>'
        f'<rect x="2.4" y="2.4" width="{W - 4.8}" height="{H - 4.8}" '
        f'fill="none" stroke="{MAROON}" stroke-width="0.34"/>'
        f'<rect x="3.3" y="3.3" width="{W - 6.6}" height="{H - 6.6}" '
        f'fill="none" stroke="{GOLD}" stroke-width="0.16"/>'
        + flourish(4.2, 4.2, False, False)
        + flourish(W - 4.2, 4.2, True, False)
        + flourish(4.2, H - 4.2, False, True)
        + flourish(W - 4.2, H - 4.2, True, True)
        + '</svg>'
    )


def art_or_border(stem):
    src = asset(stem)
    return f'<img class="art" alt="" src="{src}">' if src else border()


def front():
    photo = asset('photo')
    frame = (
        f'<div class="photo"><img src="{photo}" alt=""></div>' if photo
        else '<div class="photo empty"><span>फ़ोटो</span></div>'
    )
    city = f'<div class="city">{CITY}</div>' if CITY else ''
    return f'''
<div class="card">
  {art_or_border('front')}
  <div class="pad front">
    {frame}
    <div class="who">
      <div class="name">{NAME_HI}</div>
      <div class="name-en">{NAME_EN}</div>
      <div class="also">({ALSO_HI})</div>
      <div class="rule"></div>
      <div class="tag">{TAGLINE_HI}</div>
      <div class="phone">{PHONE}</div>
      {city}
    </div>
  </div>
</div>'''


def back():
    rows = ''.join(
        f'<li>{hi}</li>' for hi, _ in SERVICES
    )
    wa = (f'<span class="wa">WhatsApp {WHATSAPP}</span>'
          if WHATSAPP else '<span class="wa">WhatsApp</span>')
    return f'''
<div class="card">
  {art_or_border('back')}
  <div class="pad back">
    <div class="sv-title">सेवाएँ <i>Services</i></div>
    <ul class="sv">{rows}</ul>
    <div class="foot"><b>{PHONE}</b>{wa}</div>
  </div>
</div>'''


CSS = '''
@page { size: A4 portrait; margin: 0; }
* { box-sizing: border-box; margin: 0; padding: 0; }
body { background: #fff;
  font-family: 'Mukta','Kohinoor Devanagari','Devanagari Sangam MN',sans-serif;
  -webkit-print-color-adjust: exact; print-color-adjust: exact; }
.sheet { width: 210mm; height: 297mm; page-break-after: always;
         padding: 21mm 16mm; display: grid;
         grid-template-columns: 89mm 89mm; grid-template-rows: repeat(5, 51mm); }
.sheet:last-child { page-break-after: auto; }
.card { width: 89mm; height: 51mm; position: relative; overflow: hidden;
        outline: 0.1mm dashed rgba(0,0,0,.25); outline-offset: -0.05mm; }
.art { position: absolute; inset: 0; width: 100%; height: 100%;
       object-fit: cover; }
.pad { position: absolute; inset: 0; padding: 5.6mm 6mm; display: flex; }

/* ---- front ---- */
.front { align-items: center; gap: 5mm; padding: 5.6mm 7mm; }
.photo { width: 23mm; height: 29mm; flex: none; border-radius: 1.4mm;
         overflow: hidden; border: 0.3mm solid #A8791F; background: #F3E7CE; }
.photo img { width: 100%; height: 100%; object-fit: cover; display: block; }
.photo.empty { display: flex; align-items: center; justify-content: center; }
.photo.empty span { font-size: 2.6mm; color: #A8791F; }
.who { flex: 1; min-width: 0; }
.name { font-size: 6.4mm; font-weight: 700; color: #6B1D1D; line-height: 1.12; }
.name-en { font-size: 3mm; font-weight: 600; color: #A8791F;
           letter-spacing: .35mm; margin-top: .4mm; }
.also { font-size: 2.5mm; color: #3A2512; opacity: .72; margin-top: .3mm; }
.rule { width: 16mm; height: 0.3mm; background: #A8791F; margin: 1.8mm 0; }
.tag { font-size: 3mm; color: #3A2512; }
.phone { font-size: 5mm; font-weight: 700; color: #6B1D1D; margin-top: 1.9mm;
         letter-spacing: .25mm; }
.city { font-size: 2.5mm; color: #3A2512; opacity: .78; margin-top: .5mm; }

/* ---- back ---- */
.back { flex-direction: column; padding: 5mm 7mm; }
.sv-title { font-size: 3.6mm; font-weight: 700; color: #6B1D1D; flex: none; }
.sv-title i { font-size: 2.4mm; font-weight: 600; color: #A8791F;
              font-style: normal; letter-spacing: .3mm; }
/* A grid, not CSS columns: the column box was growing past the card and
   overflow:hidden then ate the footer -- which is the phone number, the one
   thing the card exists to carry. */
.sv { list-style: none; flex: 1; min-height: 0; margin: 1.2mm 0 0;
      display: grid; grid-template-columns: 1fr 1fr;
      grid-auto-rows: min-content; column-gap: 4mm; row-gap: 2.1mm;
      align-content: start; }
.sv li { padding-left: 2.6mm; position: relative; }
.sv li::before { content: '\\2022'; position: absolute; left: 0; color: #A8791F;
                 font-size: 2.4mm; }
.sv li { font-size: 2.85mm; font-weight: 600; color: #3A2512;
         line-height: 1.25; }
.foot { flex: none; border-top: 0.25mm solid rgba(168,121,31,.5);
        padding-top: 1.3mm; margin-top: 1mm; display: flex;
        align-items: baseline; justify-content: space-between; }
.foot b { font-size: 4.6mm; font-weight: 700; color: #6B1D1D;
          letter-spacing: .25mm; }
.wa { font-size: 2.5mm; color: #A8791F; font-weight: 600; }
'''


def sheet(card_html, mirror):
    """Ten up. The back sheet swaps its columns so a long-edge duplex flip
    lands each back on its own front."""
    cells = []
    for _ in range(5):
        row = [card_html, card_html]
        if mirror:
            row.reverse()
        cells.extend(row)
    return f'<div class="sheet">{"".join(cells)}</div>'


def main() -> int:
    def render(body, stem):
        page = ('<!doctype html><html lang="hi"><head><meta charset="utf-8">'
                '<link href="https://fonts.googleapis.com/css2?'
                'family=Mukta:wght@400;600;700&display=swap" rel="stylesheet">'
                f'<style>{CSS}</style></head><body>{body}</body></html>')
        html = OUT / f'{stem}.html'
        html.write_text(page, encoding='utf-8')
        out = OUT / f'{stem}.pdf'
        subprocess.run(
            ['/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
             '--headless', '--disable-gpu', '--no-pdf-header-footer',
             f'--print-to-pdf={out}', f'file://{html}'],
            check=True, capture_output=True, timeout=180)
        return out

    # Both sides for the press, and one file per side because a home printer
    # wants to be fed each side on its own.
    pdf = render(sheet(front(), False) + sheet(back(), True),
                 'visiting-card-a4')
    render(sheet(front(), False), 'card-front')
    render(sheet(back(), True), 'card-back')
    print(f'PDF   : {pdf}  ({pdf.stat().st_size // 1024} KB)')
    print('89 x 51 mm, ten per A4. Page 1 fronts, page 2 backs.')
    if PHONE.count('X'):
        print('NOTE  : the phone number is still a placeholder.')
    if not asset('photo'):
        print('NOTE  : no art/photo.jpg yet, so the frame is empty.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
