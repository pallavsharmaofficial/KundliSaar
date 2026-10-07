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
    return (
        f'<rect width="{w}" height="{h}" fill="url(#paper)"/>'
        + wave_field(w, h, 44, 0.55, 0.42)
        + wave_field(w, h, 15, 1.4, 0.17, width=0.07, op=0.13)
    )


def face(w=123.0, h=63.0):
    """The side that lies face up on the pavement."""
    return f'''<svg class="noteart" viewBox="0 0 {w} {h}" preserveAspectRatio="none">
  {ground(w, h)}
  {border(w, h, 2.4)}
  {border(w, h, 4.0)}
  {lathe(21, 34, 6, 0.0, 0.70, 0.1, 0.5)}
  {latent(100.5, 9.5, 5.4, 11.0)}
  {kundli_vignette(100, 38, 19)}
  {corner_zero(8.5, 15.5, 9.5)}
  {corner_zero(w - 7.5, h - 6.0, 7.0, 'end', 0.75)}
  {microtext(30, 57.6, 64)}
  <text x="30" y="60.6" font-size="2.1" fill="{INK}" opacity="0.95"
        font-family="Helvetica,Arial,sans-serif" letter-spacing="0.35">KS 0000000</text>
</svg>'''


def reverse(w=123.0, h=63.0):
    """The side that shows when the folded packet is turned over."""
    return f'''<svg class="noteart" viewBox="0 0 {w} {h}" preserveAspectRatio="none">
  {ground(w, h)}
  {border(w, h, 2.4)}
  {border(w, h, 4.0)}
  {lathe(17, 32, 6, 1.3, 0.56, 0.09, 0.4)}
  {lathe(106, 32, 6, 2.1, 0.56, 0.09, 0.4)}
  {corner_zero(8.5, 14.5, 7.5, 'start', 0.8)}
  {corner_zero(w - 7.5, h - 5.5, 7.5, 'end', 0.8)}
  {microtext(26, 58.4, 71)}
</svg>'''
