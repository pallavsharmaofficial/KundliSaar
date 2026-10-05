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

from PIL import Image, ImageDraw, ImageFilter, ImageFont

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
    """The card that shows when the link is shared.

    The wordmark is set in Yatra One, the app's own display face, so the card
    and the app look like the same thing. It stays in Latin: Pillow here is
    built without Raqm, and unshaped Devanagari puts the matras in the wrong
    place, which is worse than not setting it at all. The Hindi name travels
    in the page's own Open Graph title beside the image.
    """
    image = ground(width, inner=HALDI, outer=MAROON).resize((width, width))
    image = image.crop((0, (width - height) // 2, width, (width + height) // 2))
    draw = ImageDraw.Draw(image)
    chart_mark(draw, width * 0.165, height / 2, height * 0.28,
               max(2, round(height * 0.019)), PARCHMENT)

    def font(name, size):
        return ImageFont.truetype(os.path.join('assets', 'fonts', name), size)

    x = width * 0.33
    draw.text((x, height * 0.24), 'KundliSaar', font=font('YatraOne-Regular.ttf', 84),
              fill=PARCHMENT, anchor='ls')
    draw.line([x, height * 0.30, x + width * 0.14, height * 0.30],
              fill=PARCHMENT, width=5)
    draw.text((x, height * 0.45), 'Your kundli, computed on your own device',
              font=font('Mukta-SemiBold.ttf', 36), fill=PARCHMENT, anchor='ls')
    draw.text((x, height * 0.58),
              'Charts \u00b7 Dashas \u00b7 Panchang \u00b7 Milan \u00b7 Muhurta \u00b7 Hastrekha',
              font=font('Mukta-Regular.ttf', 27), fill=(246, 231, 205), anchor='ls')
    # A maroon pill, because gold on haldi disappears.
    label = 'Free \u00b7 Offline \u00b7 No account \u00b7 Hindi and English'
    pill = font('Mukta-SemiBold.ttf', 25)
    box = draw.textbbox((x, height * 0.72), label, font=pill, anchor='ls')
    draw.rounded_rectangle(
        [box[0] - 18, box[1] - 12, box[2] + 18, box[3] + 12],
        radius=26,
        fill=MAROON,
    )
    draw.text((x, height * 0.72), label, font=pill, fill=PARCHMENT, anchor='ls')
    return image


def feature_graphic(width=1024, height=500):
    """The banner Play shows at the top of the listing."""
    image = ground(width, inner=HALDI, outer=MAROON).resize((width, width))
    image = image.crop((0, (width - height) // 2, width, (width + height) // 2))
    draw = ImageDraw.Draw(image)
    chart_mark(draw, width * 0.17, height / 2, height * 0.30,
               max(2, round(height * 0.022)), PARCHMENT)

    def font(name, size):
        return ImageFont.truetype(os.path.join('assets', 'fonts', name), size)

    x = width * 0.34
    draw.text((x, height * 0.42), 'KundliSaar', font=font('YatraOne-Regular.ttf', 76),
              fill=PARCHMENT, anchor='ls')
    draw.text((x, height * 0.60), 'Kundli, panchang and muhurta',
              font=font('Mukta-SemiBold.ttf', 32), fill=PARCHMENT, anchor='ls')
    draw.text((x, height * 0.74), 'computed on your own phone',
              font=font('Mukta-Regular.ttf', 30), fill=(246, 231, 205), anchor='ls')
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
    os.makedirs(os.path.join('store', 'play'), exist_ok=True)
    feature_graphic().save(os.path.join('store', 'play', 'feature-graphic.png'))
    app_icon(512).save(os.path.join('store', 'play', 'icon-512.png'))
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
