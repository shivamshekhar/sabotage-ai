"""Draws the game's title logo, SABOTAGE.AI, for the title screen:

    assets/ui/title/logo.png     "SABOTAGE" in heavy stencil letters of lit steel with a hazard-yellow rim and a slab of shadow under them, sliced through by a glowing
                                 cyan cut (a sabotage: the two halves are knocked apart and throw sparks), and ".AI" under it in glitching cyan neon, with circuit traces

The lettering uses two free fonts (SIL Open Font License 1.1), downloaded into tmp/fonts/ the first time this runs and never checked in:
Black Ops One (Castle Type) and Orbitron (Matt McInerney). The picture made from them is what the game ships.

Usage (from the repo root; needs Pillow, numpy, opencv):
    python tools/art/generate_title_logo.py       writes assets/ui/title/logo.png and tmp/art_previews/logo.png (on a dark stage, for looking at only)
"""
import math
import os
import random
import urllib.request

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFont

import art_lib
from art_lib import S, lit, outline, solid, paste, glow, gradient_y, gradient_x, blur

OUT = os.path.join(art_lib.ROOT, "assets", "ui", "title")
FONT_DIR = os.path.join(art_lib.ROOT, "tmp", "fonts")
FONTS = {
    "BlackOpsOne-Regular.ttf": "https://github.com/google/fonts/raw/main/ofl/blackopsone/BlackOpsOne-Regular.ttf",
    "Orbitron[wght].ttf": "https://github.com/google/fonts/raw/main/ofl/orbitron/Orbitron%5Bwght%5D.ttf",
}

W, H = 900, 372                          # the logo's size in final pixels
WORD = "SABOTAGE"
WORD_WIDTH = 820                         # how wide the big word is (final px): its font size is found from it
WORD_SIZE = 150                          # the font size of the big word (set by main() from WORD_WIDTH)
WORD_Y = 24                              # where its top is
TAG = ".AI"
TAG_SIZE = 158
TAG_Y = 184

EDGE = (11, 14, 22)
CYAN = (58, 208, 255)
HAZARD = (255, 200, 30)
STEEL_LIP = (196, 214, 246)
STEEL_TOP = (120, 142, 186)
STEEL_BOT = (40, 52, 82)
SLAB = (18, 26, 46)

# CUT: the slash through the word: from the top point to the bottom point (final px); the left half is knocked up-left by KNOCK, the right half down-right.
CUT_TOP = (548, 8)
CUT_BOTTOM = (478, 190)
KNOCK = (-9.0, -6.0)


def font_path(name):
    os.makedirs(FONT_DIR, exist_ok=True)
    path = os.path.join(FONT_DIR, name)
    if not os.path.exists(path):
        print("downloading", name)
        urllib.request.urlretrieve(FONTS[name], path)
    return path


def u(v):
    return int(round(v * S))


def new_mask():
    return Image.new("L", (W * S, H * S), 0)


def new_layer():
    return Image.new("RGBA", (W * S, H * S), (0, 0, 0, 0))


def text_mask(text, font, y, center_x=None, x=None, spacing=0.0):
    """A mask of `text` in `font` with its top at y (final px), centred on center_x (or starting at x); `spacing` px extra between the letters."""
    m = new_mask()
    d = ImageDraw.Draw(m)
    widths = [font.getlength(ch) for ch in text]
    total = sum(widths) + u(spacing) * (len(text) - 1)
    left = u(x) if x is not None else u(center_x) - total / 2
    top_offset = font.getbbox(text)[1]
    for ch, w in zip(text, widths):
        d.text((left, u(y) - top_offset), ch, font=font, fill=255)
        left += w + u(spacing)
    return m


def shifted(mask, dx, dy):
    return ImageChops.offset(mask, u(dx), u(dy))


def half(mask, left_side):
    """The part of `mask` on one side of the cut line."""
    (x0, y0), (x1, y1) = CUT_TOP, CUT_BOTTOM
    far = 2000
    dx, dy = x1 - x0, y1 - y0
    length = math.hypot(dx, dy)
    ux, uy = dx / length, dy / length
    a = (x0 - ux * far, y0 - uy * far)
    b = (x1 + ux * far, y1 + uy * far)
    nx, ny = (-1, 0) if left_side else (1, 0)
    c = (b[0] + nx * far, b[1])
    d = (a[0] + nx * far, a[1])
    region = Image.new("L", mask.size, 0)
    ImageDraw.Draw(region).polygon([(u(a[0]), u(a[1])), (u(b[0]), u(b[1])), (u(c[0]), u(c[1])), (u(d[0]), u(d[1]))], fill=255)
    return ImageChops.multiply(mask, region)


def steel_piece(img, mask):
    """One piece of the big word: lit steel, a hazard-yellow rim inside the dark outline, a cyan edge glow."""
    glow(img, mask, CYAN, radii=(3, 9), strengths=(0.28, 0.16))
    paste(img, lit(mask, gradient_y(WORD_Y, WORD_Y + WORD_SIZE * 0.82, [(0, STEEL_LIP), (0.45, STEEL_TOP), (1, STEEL_BOT)]), radius=4.0, bump=1.7, spec=0.7, ambient=0.78))
    inner = mask.filter(__import__("PIL.ImageFilter", fromlist=["MinFilter"]).MinFilter(u(2.2) // 2 * 2 + 1))
    rim = ImageChops.subtract(mask, inner)
    paste(img, solid(rim, HAZARD, 0.9))
    paste(img, outline(mask, 3.2, EDGE))


def draw_word(font):
    img = new_layer()
    base = text_mask(WORD, font, WORD_Y, center_x=W / 2, spacing=4.0)
    # the slab of shadow under the letters: the word dragged down and to the right
    slab = new_mask()
    for k in range(1, 15):
        slab = ImageChops.lighter(slab, shifted(base, k * 0.55, k * 0.9))
    paste(img, lit(ImageChops.subtract(slab, base), gradient_y(WORD_Y, WORD_Y + WORD_SIZE + 14, [(0, (34, 46, 76)), (1, SLAB)]), radius=1.0, bump=0.6, spec=0.0, ambient=0.9))
    paste(img, outline(slab, 3.0, EDGE))
    left = shifted(half(base, True), *KNOCK)
    right = shifted(half(base, False), -KNOCK[0], -KNOCK[1])
    # the cut: a bright cyan seam in the gap between the halves, with a bloom
    (x0, y0), (x1, y1) = CUT_TOP, CUT_BOTTOM
    seam = new_mask()
    ImageDraw.Draw(seam).line([(u(x0 - (x1 - x0) * 0.3), u(y0 - (y1 - y0) * 0.3)), (u(x1 + (x1 - x0) * 0.3), u(y1 + (y1 - y0) * 0.3))], fill=255, width=u(9.0))
    reach = ImageChops.lighter(base, ImageChops.lighter(shifted(base, KNOCK[0], KNOCK[1]), shifted(base, -KNOCK[0], -KNOCK[1])))
    seam = ImageChops.multiply(seam, reach)
    glow(img, seam, (120, 235, 255), radii=(3, 9, 22), strengths=(1.0, 0.8, 0.6))
    paste(img, solid(seam, (60, 190, 255)))
    steel_piece(img, left)
    steel_piece(img, right)
    # the seam on top of the pieces' edges, its core nearly white
    core = new_mask()
    ImageDraw.Draw(core).line([(u(x0 - (x1 - x0) * 0.3), u(y0 - (y1 - y0) * 0.3)), (u(x1 + (x1 - x0) * 0.3), u(y1 + (y1 - y0) * 0.3))], fill=255, width=u(2.4))
    paste(img, solid(ImageChops.multiply(core, reach), (225, 252, 255), 0.95))
    # sparks along the cut
    rnd = random.Random(7)
    sparks = new_mask()
    sd = ImageDraw.Draw(sparks)
    for i in range(26):
        t = rnd.uniform(0.0, 1.05)
        px = x0 + (x1 - x0) * t + rnd.uniform(-4, 4)
        py = y0 + (y1 - y0) * t + rnd.uniform(-4, 4)
        ang = math.atan2(y1 - y0, x1 - x0) + math.pi / 2 * rnd.choice((-1, 1)) + rnd.uniform(-0.7, 0.7)
        ln = rnd.uniform(5, 22)
        sd.line([(u(px), u(py)), (u(px + math.cos(ang) * ln), u(py + math.sin(ang) * ln))], fill=255, width=u(rnd.uniform(1.0, 2.2)))
    glow(img, sparks, (140, 235, 255), radii=(2, 5), strengths=(0.9, 0.5))
    paste(img, solid(sparks, (235, 252, 255)))
    return img


def draw_tag(font):
    img = new_layer()
    base = text_mask(TAG, font, TAG_Y, x=W - 34 - font_width(TAG, font) / S - 2.0 * (len(TAG) - 1), spacing=2.0)
    # glitch: two colour-split ghosts behind it
    for dx, color in ((-5, (255, 60, 90)), (5, (60, 120, 255))):
        ghost = shifted(base, dx, 0)
        paste(img, solid(ghost, color, 0.45))
    # the letters, in bands: a few horizontal slices slip sideways
    rnd = random.Random(11)
    banded = new_mask()
    bands = [(TAG_Y + 20, TAG_Y + 25, 12), (TAG_Y + 58, TAG_Y + 62, -9), (TAG_Y + 104, TAG_Y + 109, 8)]
    banded.paste(base, (0, 0))
    for y0, y1, dx in bands:
        strip = base.crop((0, u(y0), W * S, u(y1)))
        gap = Image.new("L", strip.size, 0)
        banded.paste(gap, (0, u(y0)))
        banded.paste(ImageChops.offset(strip, u(dx), 0), (0, u(y0)))
    glow(img, banded, CYAN, radii=(3, 8, 20), strengths=(0.9, 0.6, 0.4))
    paste(img, lit(banded, gradient_y(TAG_Y, TAG_Y + TAG_SIZE * 0.78, [(0, (200, 250, 255)), (0.5, (70, 215, 255)), (1, (20, 120, 200))]), radius=3.0, bump=1.5, spec=0.8, ambient=0.85))
    paste(img, outline(banded, 2.6, EDGE))
    # scan lines through it
    lines = new_mask()
    ld = ImageDraw.Draw(lines)
    y = TAG_Y
    while y < TAG_Y + TAG_SIZE:
        ld.line([(0, u(y)), (W * S, u(y))], fill=90, width=u(1.0))
        y += 4.0
    paste(img, solid(ImageChops.multiply(lines, banded), EDGE, 0.55))
    return img


def font_width(text, font):
    return sum(font.getlength(ch) for ch in text)


def draw_traces():
    """Thin circuit traces with solder nodes, running out from the tag towards the left edge."""
    img = new_layer()
    mask = new_mask()
    d = ImageDraw.Draw(mask)
    nodes = []
    for y, x_end, bend in ((TAG_Y + 46, 40, 18), (TAG_Y + 78, 110, -16), (TAG_Y + 110, 70, 12)):
        x_start = 470.0
        pts = [(x_start, y), (x_start - 120, y), (x_start - 120 - abs(bend), y + bend), (x_end, y + bend)]
        d.line([(u(px), u(py)) for px, py in pts], fill=255, width=u(2.0), joint="curve")
        nodes.append(pts[-1])
        nodes.append(pts[1])
    for px, py in nodes:
        d.ellipse([u(px - 4.5), u(py - 4.5), u(px + 4.5), u(py + 4.5)], fill=255)
    fade = gradient_x(20, 500, [(0, (0, 0, 0)), (0.5, (255, 255, 255)), (1, (255, 255, 255))])
    yy, xx = np.mgrid[0:H * S, 0:W * S]
    alpha = (fade(xx, yy)[..., 0] / 255.0 * 0.7)
    m = (np.asarray(mask, np.float32) * alpha).astype(np.uint8)
    mask = Image.fromarray(m, "L")
    glow(img, mask, CYAN, radii=(2, 6), strengths=(0.5, 0.3))
    paste(img, solid(mask, (150, 235, 255), 0.9))
    return img


def main():
    os.makedirs(OUT, exist_ok=True)
    global WORD_SIZE
    probe = ImageFont.truetype(font_path("BlackOpsOne-Regular.ttf"), 100)
    WORD_SIZE = int(100 * (WORD_WIDTH - 4.0 * (len(WORD) - 1)) / sum(probe.getlength(ch) for ch in WORD))
    word_font = ImageFont.truetype(font_path("BlackOpsOne-Regular.ttf"), u(WORD_SIZE))
    tag_font = ImageFont.truetype(font_path("Orbitron[wght].ttf"), u(TAG_SIZE))
    try:
        tag_font.set_variation_by_axes([900])
    except Exception:
        pass
    logo = new_layer()
    logo.alpha_composite(draw_traces())
    logo.alpha_composite(draw_tag(tag_font))
    logo.alpha_composite(draw_word(word_font))
    final = logo.resize((W, H), Image.LANCZOS)
    final.save(os.path.join(OUT, "logo.png"), optimize=True)
    stage = Image.new("RGBA", (W + 40, H + 40), (12, 18, 34, 255))
    stage.alpha_composite(final, (20, 20))
    stage.save(art_lib.preview_path("logo.png"))
    print("done")


if __name__ == "__main__":
    main()
