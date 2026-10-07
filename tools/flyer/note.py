#!/usr/bin/env python3
"""The note itself: banknote furniture drawn from maths, not copied.

Everything here is generated -- guilloche rosettes and borders off a geometric
lathe, microtext, a latent-image panel, a serial, corner numerals. It is a
ZERO-rupee note: denomination 0, which no issued note carries, with a kundli
chart where a portrait would sit, and it says on its face that it is not one.
India has distributed zero-rupee notes in the millions before (5th Pillar's
anti-corruption campaign), so the form is well established.

No portrait, no Reserve Bank legend, no real denomination, no emblem, no
governor's signature, no security thread, nothing lifted from any issued note.
"""
import math

BROWN = '#6d3f12'
DEEP = '#4a1f0c'
INK = '#3a1d08'


def rosette(cx, cy, seed, scale, op=0.62):
    """Two lathe passes at opposed phase. The crossing lines make the fine
    mesh a real note shows; one pass on its own reads as a flower."""
    return (lathe(cx, cy, 7, seed, scale, 0.085, op)
            + lathe(cx, cy, 7, seed + math.pi / 2.3, scale * 0.97, 0.085, op)
            + lathe(cx, cy, 4, seed + 1.1, scale * 0.46, 0.09, op * 0.9))


def ribbons(w, h, seed=0.0):
    """The wide banded curves that sweep across a note behind the type,
    each one a hatched band rather than a single line."""
    out = []
    for b in range(2):
        for k in range(22):
            pts = []
            for i in range(201):
                x = i / 200 * w
                base = h * (0.34 + 0.3 * b) + 5.5 * math.sin(
                    x * 0.026 + seed + b * 2.1)
                out_y = base + (k - 11) * 0.34 * math.cos(x * 0.011 + b)
                pts.append(f'{x:.2f},{out_y:.2f}')
            out.append(
                f'<polyline points="{" ".join(pts)}" fill="none" '
                f'stroke="{BROWN}" stroke-width="0.055" opacity="0.17"/>')
    return ''.join(out)


def watermark(cx, cy, rx, ry):
    """The pale oval a note leaves for its watermark: the engraving stops
    and the paper shows through."""
    return (f'<ellipse cx="{cx}" cy="{cy}" rx="{rx}" ry="{ry}" '
            f'fill="url(#wm)"/>'
            f'<ellipse cx="{cx}" cy="{cy}" rx="{rx}" ry="{ry}" fill="none" '
            f'stroke="{BROWN}" stroke-width="0.16" opacity="0.5"/>')


def lathe(cx, cy, rings, seed, scale, width=0.11, op=0.62):
    """A guilloche rosette: two coupled circles traced as one line, the way a
    geometric lathe draws one. Hairline weight, many rings -- that is what
    makes the eye read engraving rather than decoration."""
    out = []
    for ring in range(rings):
        big = (22 - ring * 2.9) * scale
        small = (2.6 + ring * 0.48) * scale
        k = 14 + ring * 8
        pts = []
        for i in range(901):
            t = i / 900 * 2 * math.pi
            r = big + small * math.cos(k * t + seed + ring * 0.7)
            pts.append(f'{cx + r * math.cos(t):.2f},{cy + r * math.sin(t):.2f}')
        out.append(
            f'<polyline points="{" ".join(pts)}" fill="none" stroke="{BROWN}" '
            f'stroke-width="{width}" opacity="{op - ring * 0.055:.2f}"/>'
        )
    return ''.join(out)


def wave_field(w, h, rows, amp, freq, width=0.09, op=0.24):
    out = []
    step = h / rows
    for j in range(rows + 1):
        y0 = j * step
        pts = []
        for i in range(241):
            x = i / 240 * w
            pts.append(f'{x:.2f},{y0 + amp * math.sin(x * freq + j * 0.6):.2f}')
        out.append(
            f'<polyline points="{" ".join(pts)}" fill="none" stroke="{BROWN}" '
            f'stroke-width="{width}" opacity="{op}"/>'
        )
    return ''.join(out)


def border(w, h, inset):
    """A guilloche frame: a braided pair of sine rules round the perimeter."""
    out = []
    for phase, op in ((0.0, 0.72), (math.pi, 0.6)):
        for side in range(4):
            pts = []
            span = w - 2 * inset if side % 2 == 0 else h - 2 * inset
            for i in range(321):
                u = i / 320 * span
                v = 0.85 * math.sin(u * 0.55 + phase)
                if side == 0:
                    pts.append(f'{inset + u:.2f},{inset + v:.2f}')
                elif side == 1:
                    pts.append(f'{w - inset + v:.2f},{inset + u:.2f}')
                elif side == 2:
                    pts.append(f'{inset + u:.2f},{h - inset + v:.2f}')
                else:
                    pts.append(f'{inset + v:.2f},{inset + u:.2f}')
            out.append(
                f'<polyline points="{" ".join(pts)}" fill="none" '
                f'stroke="{BROWN}" stroke-width="0.17" opacity="{op}"/>'
            )
    return ''.join(out)


def microtext(x, y, w, text='KUNDLISAAR', size=0.62):
    """The line of type too small to read without a glass, which is one of the
    strongest things the eye uses to judge a note as a note."""
    rep = (text + ' · ') * 40
    return (
        f'<text x="{x}" y="{y}" font-size="{size}" fill="{BROWN}" opacity="0.78" '
        f'font-family="Helvetica,Arial,sans-serif" letter-spacing="0.12" '
        f'textLength="{w}" lengthAdjust="spacingAndGlyphs">{rep[:150]}</text>'
    )


def kundli_vignette(cx, cy, s):
    """A North Indian chart where the portrait would be. Square, both
    diagonals, and the rotated inner square -- the diamond everyone in India
    recognises instantly."""
    h = s / 2
    g = (
        f'<g transform="translate({cx},{cy})" fill="none" stroke="{DEEP}" '
        f'stroke-width="0.34" opacity="0.95">'
        f'<rect x="{-h}" y="{-h}" width="{s}" height="{s}"/>'
        f'<line x1="{-h}" y1="{-h}" x2="{h}" y2="{h}"/>'
        f'<line x1="{h}" y1="{-h}" x2="{-h}" y2="{h}"/>'
        f'<path d="M 0 {-h} L {h} 0 L 0 {h} L {-h} 0 Z"/>'
        f'</g>'
    )
    halo = lathe(cx, cy, 4, 0.4, s / 34.0, width=0.09, op=0.42)
    return halo + g


def latent(x, y, w, h):
    """The tilt panel. Dense diagonal hatching with a 0 ghosted inside it."""
    lines = []
    for i in range(int(w / 0.55) + 1):
        ox = i * 0.55
        lines.append(
            f'<line x1="{x + ox:.2f}" y1="{y}" x2="{x + ox - h:.2f}" '
            f'y2="{y + h}" stroke="{BROWN}" stroke-width="0.08" opacity="0.62"/>'
        )
    return (
        f'<g>{"".join(lines)}'
        f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="none" '
        f'stroke="{BROWN}" stroke-width="0.14" opacity="0.72"/>'
        f'<text x="{x + w / 2}" y="{y + h * 0.78}" font-size="{h * 0.8}" '
        f'fill="{BROWN}" opacity="0.6" text-anchor="middle" '
        f'font-family="Georgia,serif">0</text></g>'
    )


def corner_zero(x, y, size, anchor='start', op=1.0):
    return (
        f'<text x="{x}" y="{y}" font-size="{size}" fill="{DEEP}" '
        f'text-anchor="{anchor}" opacity="{op}" font-family="Georgia,serif" '
        f'font-weight="bold">0</text>'
    )


def ground(w, h):
    """Paper, the engine-turned field, then the iris wash. A note's colour
    travels across the sheet; a single flat tone is the clearest tell that
    something is not one."""
    return (
        f'<rect width="{w}" height="{h}" fill="url(#paper)"/>'
        + wave_field(w, h, 60, 0.45, 0.52)
        + wave_field(w, h, 22, 1.3, 0.19, width=0.065, op=0.15)
        + wave_field(w, h, 34, 0.8, 0.31, width=0.06, op=0.12)
        + f'<rect width="{w}" height="{h}" fill="url(#iris)" '
          f'style="mix-blend-mode:multiply"/>'
    )


def face(w=123.0, h=63.0):
    """The side that lies face up on the pavement."""
    return f'''<svg class="noteart" viewBox="0 0 {w} {h}" preserveAspectRatio="none">
  {ground(w, h)}
  {watermark(101, 32, 13.5, 19)}
  {border(w, h, 2.2)}
  {border(w, h, 3.6)}
  {border(w, h, 5.2)}
  {rosette(21, 32, 0.0, 0.76)}
  {latent(88.5, 8.0, 5.0, 10.0)}
  {microtext(30, 57.6, 64)}
</svg>'''


def reverse(w=123.0, h=63.0):
    """The side that shows when the folded packet is turned over."""
    return f'''<svg class="noteart" viewBox="0 0 {w} {h}" preserveAspectRatio="none">
  {ground(w, h)}
  {border(w, h, 2.2)}
  {border(w, h, 3.6)}
  {border(w, h, 5.2)}
  {rosette(19, 32, 1.3, 0.62)}
  {rosette(104, 32, 2.1, 0.62)}
  {microtext(26, 58.4, 71)}
</svg>'''


def furniture(face_side: bool, w=123.0, h=63.0) -> str:
    """The printed furniture, as a transparent layer over whichever background
    is in use.

    It has to be separate: a generated background replaces the drawn art
    wholesale, and the corner numerals, serial and kundli vignette would go
    with it. They are what make the panel read as a denominated note rather
    than as decorative paper, so they are drawn over the top either way.
    """
    parts = [f'<svg class="furniture" viewBox="0 0 {w} {h}" '
             f'preserveAspectRatio="none">']
    if face_side:
        parts.append(corner_zero(11.5, 18.0, 10.5))
        parts.append(corner_zero(w - 10.5, h - 8.0, 8.0, 'end', 0.85))
        # Over the watermark oval on the right, where a portrait would be.
        parts.append(kundli_vignette(101, 33, 20))
        parts.append(
            f'<text x="12" y="{h - 3.4}" font-size="2.2" fill="{INK}" '
            f'opacity="0.8" font-family="Helvetica,Arial,sans-serif" '
            f'letter-spacing="0.4">KS 0000000</text>')
        parts.append(
            f'<text x="{w - 12}" y="{h - 3.4}" font-size="2.2" fill="{INK}" '
            f'opacity="0.8" text-anchor="end" '
            f'font-family="Helvetica,Arial,sans-serif" '
            f'letter-spacing="0.4">KS 0000000</text>')
    else:
        parts.append(corner_zero(11.5, 17.0, 8.5, 'start', 0.9))
        parts.append(corner_zero(w - 10.5, h - 7.5, 8.5, 'end', 0.9))
    parts.append('</svg>')
    return ''.join(parts)
