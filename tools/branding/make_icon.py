"""Draws the KundliSaar icon and the images the stores and the web need.

The mark is the North Indian kundli itself: a square with its diagonals and
the rhombus joining the midpoints, which is the shape every Indian household
recognises as a horoscope. It sits on a haldi-to-sindoor ground, with the
lagna house marked by a small sun. Nothing here is a photograph or a font, so
it scales from a 16 pixel favicon to a 1024 pixel store icon without help.

    python3 tools/branding/make_icon.py
"""
import math
import os

from PIL import Image, ImageDraw, ImageFilter

HALDI = (227, 160, 8)
SINDOOR = (193, 39, 45)
MAROON = (107, 29, 29)
PARCHMENT = (253, 246, 232)
GOLD = (184, 134, 11)
INDIGO = (31, 42, 94)

OUT = os.path.join('assets', 'branding')


def lerp(a, b, t):
    return tuple(round(x + (y - x) * t) for x, y in zip(a, b))


def ground(size, inner=HALDI, outer=SINDOOR):
    """A radial wash from haldi at the centre to sindoor at the corners."""
    image = Image.new('RGB', (size, size), outer)
    draw = ImageDraw.Draw(image)
    steps = 160
    radius = size * 0.78
    for i in range(steps, 0, -1):
        t = i / steps
        r = radius * t
        draw.ellipse(
            [size / 2 - r, size / 2 - r, size / 2 + r, size / 2 + r],
            fill=lerp(inner, outer, t ** 1.6),
        )
    return image


def chart_mark(draw, cx, cy, half, stroke, colour, sun=True, diagonals=True):
    """The kundli: square, both diagonals, and the rhombus of the midpoints."""
    left, top, right, bottom = cx - half, cy - half, cx + half, cy + half
    # A plain square, as the chart is actually drawn: rounding the corners
    # leaves notches where the diagonals meet them.
    draw.rectangle([left, top, right, bottom], outline=colour, width=stroke)
    if diagonals:
        draw.line([left, top, right, bottom], fill=colour, width=stroke)
        draw.line([right, top, left, bottom], fill=colour, width=stroke)
    draw.polygon(
        [(cx, top), (right, cy), (cx, bottom), (left, cy)],
        outline=colour,
        width=stroke,
    )
    if sun:
        # The lagna house, the one a chart is read from, carries a sun. It is
        # a plain disc: rays turn to mud below about forty pixels.
        r = half * 0.155
        y = cy - half * 0.47
        draw.ellipse([cx - r, y - r, cx + r, y + r], fill=colour)


def app_icon(size=1024, diagonals=True):
    image = ground(size)
    draw = ImageDraw.Draw(image)
    half = size * 0.285
    # A soft shadow under the mark, so it holds on a bright ground.
    shadow = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    chart_mark(ImageDraw.Draw(shadow), size / 2, size / 2 + size * 0.012, half,
               max(2, round(size * 0.028)), (90, 20, 20, 105),
               diagonals=diagonals)
    image = Image.alpha_composite(
        image.convert('RGBA'),
        shadow.filter(ImageFilter.GaussianBlur(size * 0.012)),
    )
    draw = ImageDraw.Draw(image)
    chart_mark(draw, size / 2, size / 2, half, max(2, round(size * 0.025)),
               PARCHMENT, diagonals=diagonals)
    return image.convert('RGB')


def foreground(size=1024):
    """Android adaptive foreground: the mark alone, inside the safe circle."""
    image = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    chart_mark(draw, size / 2, size / 2, size * 0.215,
               max(2, round(size * 0.024)), PARCHMENT + (255,))
    return image


def monochrome(size=1024):
    """Android themed icons want one flat colour on transparent."""
    image = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    chart_mark(draw, size / 2, size / 2, size * 0.215,
               max(2, round(size * 0.026)), (255, 255, 255, 255))
    return image


def splash(size=768, colour=MAROON):
    """The launch mark: the chart alone on transparent, for the splash."""
    image = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    chart_mark(ImageDraw.Draw(image), size / 2, size / 2, size * 0.30,
               max(2, round(size * 0.022)), colour + (255,))
    return image


def maskable(size=512):
    """Web install icon: the mark smaller, so a circular mask cannot clip it."""
    image = ground(size)
    draw = ImageDraw.Draw(image)
    chart_mark(draw, size / 2, size / 2, size * 0.215,
               max(2, round(size * 0.026)), PARCHMENT)
    return image


def social_card(width=1200, height=630):
    """The card that shows when the site is shared."""
    image = ground(width, inner=HALDI, outer=MAROON).resize((width, width))
    image = image.crop((0, (width - height) // 2, width, (width + height) // 2))
    draw = ImageDraw.Draw(image)
    chart_mark(draw, width * 0.21, height / 2, height * 0.30,
               max(2, round(height * 0.020)), PARCHMENT)
    # The wordmark is drawn as a rule and blocks rather than set in a font, so
    # the card needs no font file and cannot render differently elsewhere.
    x = width * 0.40
    draw.rounded_rectangle([x, height * 0.33, x + width * 0.40, height * 0.40],
                           radius=height * 0.02, fill=PARCHMENT)
    draw.rounded_rectangle([x, height * 0.45, x + width * 0.30, height * 0.50],
                           radius=height * 0.015,
                           fill=(253, 246, 232, 180))
    draw.rounded_rectangle([x, height * 0.55, x + width * 0.34, height * 0.59],
                           radius=height * 0.012, fill=GOLD)
    return image


def main():
    os.makedirs(OUT, exist_ok=True)
    app_icon().save(os.path.join(OUT, 'icon-1024.png'))
    foreground().save(os.path.join(OUT, 'icon-foreground.png'))
    monochrome().save(os.path.join(OUT, 'icon-monochrome.png'))
    maskable().save(os.path.join(OUT, 'icon-maskable-512.png'))
    app_icon(512).save(os.path.join(OUT, 'icon-512.png'))
    app_icon(192).save(os.path.join(OUT, 'icon-192.png'))
    splash(colour=MAROON).save(os.path.join(OUT, 'splash-light.png'))
    splash(colour=PARCHMENT).save(os.path.join(OUT, 'splash-dark.png'))
    social_card().save(os.path.join('site', 'og-image.png'))
    # Optical sizing: below about sixty pixels the diagonals turn to mesh, so
    # the small renders keep the square, the rhombus and the sun only.
    for small in (16, 32, 48):
        app_icon(512, diagonals=False).resize((small, small), Image.LANCZOS).save(
            os.path.join(OUT, 'icon-%d.png' % small))
    app_icon(1024).resize((96, 96), Image.LANCZOS).save(
        os.path.join(OUT, 'icon-96.png'))
    print('wrote icons to %s and site/og-image.png' % OUT)


if __name__ == '__main__':
    main()
