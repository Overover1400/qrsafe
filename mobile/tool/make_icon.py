# -*- coding: utf-8 -*-
"""Draw the QRSafe app icon: a scanner frame around a QR glyph, on teal.

Writes two files:
  icon.png             full-bleed square, used for the legacy launcher icon
  icon_foreground.png  transparent, inset for Android's adaptive-icon safe zone
"""
import os

from PIL import Image, ImageDraw

SIZE = 1024
OUT = '/home/admin/projects/qrsafe/mobile/assets/icon'

TOP = (0x3F, 0xC9, 0xC0)
BOTTOM = (0x0E, 0x7C, 0x8A)
WHITE = (255, 255, 255, 255)


def gradient(size):
    """Vertical teal gradient, drawn a row at a time."""
    img = Image.new('RGBA', (size, size))
    draw = ImageDraw.Draw(img)
    for y in range(size):
        t = y / (size - 1)
        colour = tuple(
            int(round(TOP[i] + (BOTTOM[i] - TOP[i]) * t)) for i in range(3)
        )
        draw.line([(0, y), (size, y)], fill=colour + (255,))
    return img


def draw_glyph(draw, cx, cy, scale):
    """Scanner brackets + a QR glyph, centred on (cx, cy)."""
    def s(v):
        return v * scale

    # --- corner brackets ---
    half = s(332)          # half the frame's edge
    arm = s(200)           # how far each arm runs from the corner
    thick = s(60)
    radius = s(30)
    left, top = cx - half, cy - half
    right, bottom = cx + half, cy + half

    arms = [
        (left, top, left + arm, top + thick),
        (left, top, left + thick, top + arm),
        (right - arm, top, right, top + thick),
        (right - thick, top, right, top + arm),
        (left, bottom - thick, left + arm, bottom),
        (left, bottom - arm, left + thick, bottom),
        (right - arm, bottom - thick, right, bottom),
        (right - thick, bottom - arm, right, bottom),
    ]
    for box in arms:
        draw.rounded_rectangle(box, radius=radius, fill=WHITE)

    # --- QR glyph ---
    box = s(300)                  # the glyph's own square
    origin_x, origin_y = cx - box / 2, cy - box / 2
    marker = s(104)
    stroke = s(26)
    module = s(36)

    def at(mx, my, w, h, r, **kw):
        draw.rounded_rectangle(
            (origin_x + s(mx), origin_y + s(my),
             origin_x + s(mx) + w, origin_y + s(my) + h),
            radius=r, **kw
        )

    for mx, my in [(0, 0), (196, 0), (0, 196)]:
        at(mx, my, marker, marker, s(16), outline=WHITE, width=int(stroke))
        inner = s(34)
        at(mx + 35, my + 35, inner, inner, s(6), fill=WHITE)

    for mx, my in [(140, 36), (36, 140), (140, 140), (232, 140),
                   (140, 232), (232, 232), (196, 196)]:
        at(mx, my, module, module, s(6), fill=WHITE)


def main():
    os.makedirs(OUT, exist_ok=True)

    full = gradient(SIZE)
    draw_glyph(ImageDraw.Draw(full), SIZE / 2, SIZE / 2, 1.0)
    full.convert('RGB').save(os.path.join(OUT, 'icon.png'))

    # Adaptive foreground: the launcher masks the outer third away, so the
    # glyph is drawn smaller on a transparent canvas.
    fg = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    draw_glyph(ImageDraw.Draw(fg), SIZE / 2, SIZE / 2, 0.62)
    fg.save(os.path.join(OUT, 'icon_foreground.png'))

    for name in ('icon.png', 'icon_foreground.png'):
        path = os.path.join(OUT, name)
        print(name, os.path.getsize(path), 'bytes', Image.open(path).size)


if __name__ == '__main__':
    main()
