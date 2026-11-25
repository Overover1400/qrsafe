# -*- coding: utf-8 -*-
"""Draw the two images the Play Store listing requires.

  play/icon-512.png        512x512, 32-bit PNG, no alpha channel
  play/feature-1024x500.png  the graphic shown at the top of the listing

The glyph is the one from make_icon.py, imported rather than copied so the
listing and the launcher can never drift apart.
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_icon import TOP, BOTTOM, draw_glyph  # noqa: E402

OUT = '/home/admin/projects/qrsafe/mobile/play'
FONT_BOLD = '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'
FONT = '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'


def gradient(width, height):
    """The same top-to-bottom teal gradient the launcher icon uses."""
    img = Image.new('RGB', (width, height))
    draw = ImageDraw.Draw(img)
    for y in range(height):
        t = y / (height - 1)
        colour = tuple(
            int(round(TOP[i] + (BOTTOM[i] - TOP[i]) * t)) for i in range(3)
        )
        draw.line([(0, y), (width, y)], fill=colour)
    return img


def icon_512():
    """Play wants exactly 512x512 with no alpha, so it is drawn and flattened."""
    size = 1024
    img = gradient(size, size)
    draw_glyph(ImageDraw.Draw(img, 'RGBA'), size / 2, size / 2, 1.0)
    img = img.resize((512, 512), Image.LANCZOS)
    path = os.path.join(OUT, 'icon-512.png')
    img.save(path)
    return path


def feature_graphic():
    """1024x500. Play crops the edges on some surfaces, so nothing sits near them."""
    width, height = 1024, 500
    img = gradient(width, height)
    draw = ImageDraw.Draw(img, 'RGBA')

    # A soft highlight so the flat gradient does not read as a plain block.
    glow = Image.new('RGBA', (width, height), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse(
        (-260, -360, 520, 420), fill=(255, 255, 255, 26)
    )
    img.paste(Image.alpha_composite(img.convert('RGBA'), glow).convert('RGB'))

    draw = ImageDraw.Draw(img, 'RGBA')
    draw_glyph(draw, 256, height / 2, 0.30)

    text_left = 452
    text_width = width - text_left - 72   # keep clear of the cropped edge

    def fitted(path, text, start):
        """Largest size at or below `start` that still fits the text column."""
        for size in range(start, 12, -2):
            font = ImageFont.truetype(path, size)
            if draw.textlength(text, font=font) <= text_width:
                return font
        return ImageFont.truetype(path, 12)

    lines = [
        ('QRSafe', FONT_BOLD, 96, 196, (255, 255, 255)),
        ('Scan, create and share QR codes', FONT, 34, 254,
         (255, 255, 255, 226)),
        ('No ads. No tracking.', FONT, 34, 306, (255, 255, 255, 190)),
    ]
    for text, path, size, baseline, fill in lines:
        draw.text((text_left, baseline), text, font=fitted(path, text, size),
                  fill=fill, anchor='ls')

    path = os.path.join(OUT, 'feature-1024x500.png')
    img.save(path)
    return path


def main():
    os.makedirs(OUT, exist_ok=True)
    for path in (icon_512(), feature_graphic()):
        with Image.open(path) as img:
            print(os.path.basename(path), img.size, img.mode,
                  os.path.getsize(path), 'bytes')


if __name__ == '__main__':
    main()
