"""Draws the warning signs that stand before a deadly pit (PitSigns places them): a signboard on a short post, one tile (70x70) in the style of the
level tiles (navy steel, a hazard-striped yellow frame, the same lit bevels), showing what is in the pit:

    sign_pit_poison     a green skull over crossbones   (toxic waste: the puffer fish's poison)
    sign_pit_fire       a flame                         (lava: the fireballs)
    sign_pit_nuclear    the yellow and black radiation trefoil   (nuclear waste: the eels' radiation)
    sign_pit_piranha    the game's own robot piranha leaping half out of cartoon waves   (the piranha tank: the bites)

Usage (from the repo root; needs Pillow, numpy, opencv):
    python tools/art/generate_pit_signs.py      writes levels/common/tiles/data_center/signage/sign_pit_*.png
                                                (and tmp/art_previews/pit_signs.png, all four side by side, for looking at only)

The post stands on the bottom edge of the tile, so the sign sits on the ground tile below it like a signboard planted in the floor. The board fills
most of the tile so the picture reads at the size the game shows it.
"""
import math
import os

import numpy as np
from PIL import Image, ImageChops, ImageDraw

import art_lib
from art_lib import S, lit, outline, solid, paste, glow, rrect_mask, poly_mask, gradient_y, blur

ROOT = art_lib.ROOT
OUT = os.path.join(ROOT, "levels", "common", "tiles", "data_center", "signage")
FISH = os.path.join(ROOT, "levels", "common", "pit_hazards", "piranha_tank", "pit_piranha_tank_fish_wide.png")

# ICON_SHARE: how big a picture is on its board, compared with its first design (0.85 = 85%).
ICON_SHARE = 0.85

T = 70                      # a tile, in final pixels
W = T * S                   # the drawing size

# the tile palette (generate_tiles.py)
EDGE = (11, 14, 22)
STEEL_LIP = (84, 102, 140)
STEEL_BOT = (26, 33, 50)
HAZARD_DARK = (214, 140, 10)
BLACK = (24, 26, 34)

# the board and the post, in units of final pixels
BOARD = (3, 6.5, 67, 52)     # left, top, right, bottom of the board (the two warning lights stand on top of it, in the rows above)
FRAME = 4.5                  # the width of its hazard-striped frame
FACE = (BOARD[0] + FRAME, BOARD[1] + FRAME, BOARD[2] - FRAME, BOARD[3] - FRAME)
POST = (32.0, 51.0, 38.0, 65.0)
PLATE = (22.0, 63.0, 48.0, 68.5)
CENTRE = (35.0, 25.5)        # where the pictures were first designed (their middle); ICON_DROP moves them to the middle of the face
ICON_DROP = (FACE[1] + FACE[3]) / 2.0 - CENTRE[1]

# The two red warning lights on the top corners: LIGHT_X are their middles (px from the tile's left), LIGHT_TOP / LIGHT_BOTTOM the lamp's top and bottom, ROD the
# very small rod joining a lamp to the board (its half width). The game makes them glow and dim in turn (see GlowPulse and the registry's `glows`).
LIGHT_X = (10.0, 60.0)
LIGHT_TOP = 0.6
LIGHT_BOTTOM = 4.6
ROD = 1.0


def u(v):
    return int(round(v * S))


def new_mask():
    return Image.new("L", (W, W), 0)


def new_layer():
    return Image.new("RGBA", (W, W), (0, 0, 0, 0))


def poly(points):
    return poly_mask([(u(x), u(y)) for x, y in points], (W, W))


def disc(cx, cy, r):
    m = new_mask()
    ImageDraw.Draw(m).ellipse([u(cx - r), u(cy - r), u(cx + r), u(cy + r)], fill=255)
    return m


def ellipse(cx, cy, rx, ry):
    m = new_mask()
    ImageDraw.Draw(m).ellipse([u(cx - rx), u(cy - ry), u(cx + rx), u(cy + ry)], fill=255)
    return m


def rrect(box, r):
    return rrect_mask((W, W), [u(box[0]), u(box[1]), u(box[2]), u(box[3])], u(r))


def thick_line(a, b, width):
    m = new_mask()
    ImageDraw.Draw(m).line([(u(a[0]), u(a[1])), (u(b[0]), u(b[1]))], fill=255, width=u(width))
    return m


def smooth(mask, radius=0.9):
    """Round off the corners of a polygon mask (blur, then cut again)."""
    return blur(mask, radius).point(lambda v: 255 if v > 128 else 0)


def add(a, b):
    return ImageChops.lighter(a, b)


def sub(a, b):
    return ImageChops.subtract(a, b)


def pie(cx, cy, r, centre_angle, span):
    m = new_mask()
    ImageDraw.Draw(m).pieslice([u(cx - r), u(cy - r), u(cx + r), u(cy + r)], centre_angle - span / 2.0, centre_angle + span / 2.0, fill=255)
    return m


def stripes_mask():
    """Diagonal hazard stripes over the whole tile (the frame clips them)."""
    m = new_mask()
    d = ImageDraw.Draw(m)
    step = 9.0
    k = -T
    while k < 2 * T:
        d.polygon([(u(k), 0), (u(k + step / 2), 0), (u(k + step / 2 + T), W), (u(k + T), W)], fill=255)
        k += step
    return m


# ---------------------------------------------------------------------------------------------------------------------------
# the board and the post
# ---------------------------------------------------------------------------------------------------------------------------
def draw_stand(img):
    """The post, its foot plate and the board with its frame; returns the mask of the board's face (where the picture goes)."""
    post = rrect(POST, 1.5)
    paste(img, lit(post, lambda xx, yy: np.dstack([np.interp(xx / S, [POST[0], POST[2]], [r, g]) for r, g in zip((96, 120, 168), (40, 50, 74))]), radius=1.4, bump=2.4, spec=0.4))
    paste(img, outline(post, 0.9, EDGE))
    plate = rrect(PLATE, 2.0)
    paste(img, lit(plate, gradient_y(PLATE[1], PLATE[3], [(0, STEEL_LIP), (1, STEEL_BOT)]), radius=1.6, bump=2.2, spec=0.4))
    paste(img, outline(plate, 0.9, EDGE))
    for bx in (PLATE[0] + 4.5, PLATE[2] - 4.5):
        paste(img, lit(disc(bx, (PLATE[1] + PLATE[3]) / 2.0, 1.2), (150, 168, 200), radius=0.5, bump=2.4, spec=0.9))
    # the two warning lights: a lens on a very small rod above each top corner
    for lx in LIGHT_X:
        rod = rrect((lx - ROD, LIGHT_BOTTOM - 0.5, lx + ROD, BOARD[1] + 1.0), 0.4)
        paste(img, lit(rod, (150, 160, 184), radius=0.5, bump=2.0, spec=0.5))
        paste(img, outline(rod, 0.6, EDGE))
        lens = rrect((lx - 3.6, LIGHT_TOP, lx + 3.6, LIGHT_BOTTOM), 2.3)
        paste(img, lit(lens, gradient_y(LIGHT_TOP, LIGHT_BOTTOM, [(0, (255, 120, 110)), (1, (150, 22, 30))]), radius=1.2, bump=2.2, spec=0.8, ambient=0.8))
        paste(img, outline(lens, 0.8, EDGE))
    # the board: a hazard-yellow frame with black stripes, around a dark face
    outer = rrect(BOARD, 5.5)
    paste(img, lit(outer, gradient_y(BOARD[1], BOARD[3], [(0, (255, 226, 110)), (1, HAZARD_DARK)]), radius=2.4, bump=2.2, spec=0.5))
    face = rrect(FACE, 2.8)
    ring = sub(outer, face)
    paste(img, solid(ImageChops.multiply(stripes_mask(), ring), BLACK, 0.9))
    paste(img, outline(outer, 1.0, EDGE))
    paste(img, lit(face, lambda xx, yy: np.dstack([np.interp(yy / S, [BOARD[1], BOARD[3]], [a, b]) for a, b in zip((26, 34, 54), (12, 16, 28))]), radius=1.2, bump=1.2, spec=0.15, ambient=0.8))
    paste(img, outline(face, 0.8, EDGE))
    return face


def scaled(layer, k, drop=0.0, about=CENTRE):
    """`layer` grown by `k` about the point `about` (final px) and moved down by `drop` px."""
    big = layer.resize((int(W * k), int(W * k)), Image.LANCZOS) if k != 1.0 else layer
    out = new_layer()
    ox = int(round(u(about[0]) - u(about[0]) * k))
    oy = int(round(u(about[1]) - u(about[1]) * k + u(drop)))
    out.alpha_composite(big, (max(ox, 0), max(oy, 0)), (max(-ox, 0), max(-oy, 0)))
    return out


# ---------------------------------------------------------------------------------------------------------------------------
# the pictures. Each draws on its own layer (so it can be grown) and returns the factor to grow it by.
# ---------------------------------------------------------------------------------------------------------------------------
def icon_nuclear(img):
    cx, cy = CENTRE
    glow(img, disc(cx, cy, 14.2), (255, 200, 40), radii=(1.5, 4.0), strengths=(0.55, 0.35))
    paste(img, solid(disc(cx, cy, 15.5), BLACK))
    disk = disc(cx, cy, 14.2)
    paste(img, lit(disk, gradient_y(cy - 14, cy + 14, [(0, (255, 226, 80)), (1, (240, 170, 20))]), radius=1.6, bump=1.4, spec=0.5, ambient=0.85))
    blades = new_mask()
    for a in (-90.0, 30.0, 150.0):
        blades = add(blades, pie(cx, cy, 11.3, a, 60.0))
    blades = sub(blades, disc(cx, cy, 4.3))
    paste(img, solid(blades, BLACK))
    paste(img, solid(disc(cx, cy, 2.9), BLACK))
    return 1.15 * ICON_SHARE


def icon_fire(img):
    cx, cy = CENTRE
    outer = poly([(cx + 1.0, cy - 17.0), (cx + 5.0, cy - 9.0), (cx + 10.5, cy - 3.0), (cx + 12.0, cy + 5.0), (cx + 9.0, cy + 12.0), (cx + 2.0, cy + 16.0),
                  (cx - 6.0, cy + 14.0), (cx - 11.5, cy + 7.0), (cx - 11.0, cy - 1.0), (cx - 7.0, cy - 5.0), (cx - 6.0, cy + 1.5), (cx - 2.0, cy - 4.0),
                  (cx - 2.5, cy - 11.0)])
    outer = smooth(outer, 1.1)
    glow(img, outer, (255, 110, 30), radii=(1.5, 4.0), strengths=(0.55, 0.35))
    paste(img, lit(outer, gradient_y(cy - 17, cy + 16, [(0, (255, 214, 70)), (0.5, (255, 130, 28)), (1, (214, 50, 24))]), radius=2.4, bump=1.6, spec=0.5, ambient=0.8))
    paste(img, outline(outer, 0.8, BLACK))
    inner = smooth(poly([(cx + 1.2, cy - 5.0), (cx + 5.0, cy + 1.0), (cx + 6.0, cy + 7.0), (cx + 2.0, cy + 12.5), (cx - 3.5, cy + 11.0), (cx - 5.5, cy + 6.0),
                         (cx - 2.5, cy + 1.5), (cx - 1.0, cy + 4.0)]), 1.0)
    paste(img, lit(inner, gradient_y(cy - 5, cy + 13, [(0, (255, 252, 190)), (1, (255, 196, 40))]), radius=1.6, bump=1.2, spec=0.4, ambient=0.9))
    return 1.15 * ICON_SHARE


def bone(img, a, b, width, knob):
    """A bone from `a` to `b`: a shaft with two knobs at each end."""
    d = (b[0] - a[0], b[1] - a[1])
    length = math.hypot(*d)
    n = (-d[1] / length, d[0] / length)
    shape = thick_line(a, b, width)
    for end in (a, b):
        for side in (-1.0, 1.0):
            shape = add(shape, disc(end[0] + n[0] * side * knob * 0.62, end[1] + n[1] * side * knob * 0.62, knob))
    shape = smooth(shape, 0.5)
    paste(img, lit(shape, gradient_y(min(a[1], b[1]) - knob, max(a[1], b[1]) + knob, [(0, (190, 255, 170)), (1, (60, 170, 80))]), radius=1.4, bump=1.8, spec=0.6, ambient=0.78))
    paste(img, outline(shape, 0.8, BLACK))


def icon_poison(img):
    cx = CENTRE[0]
    glow(img, add(ellipse(cx, 18.0, 13.0, 12.0), thick_line((cx - 16, 31), (cx + 16, 41), 5)), (60, 255, 90), radii=(1.5, 4.0), strengths=(0.4, 0.3))
    # the crossbones, behind the skull
    bone(img, (cx - 16.5, 29.0), (cx + 16.5, 42.5), 3.4, 2.5)
    bone(img, (cx + 16.5, 29.0), (cx - 16.5, 42.5), 3.4, 2.5)
    # the skull: a round cranium, cheekbones, a narrower jaw
    cranium = ellipse(cx, 18.0, 12.5, 11.8)
    cheeks = rrect((cx - 9.5, 22.0, cx + 9.5, 32.0), 4.0)
    skull = smooth(add(cranium, cheeks), 0.7)
    paste(img, lit(skull, gradient_y(6.0, 34, [(0, (190, 255, 160)), (0.55, (110, 225, 110)), (1, (50, 160, 70))]), radius=2.2, bump=1.8, spec=0.6, ambient=0.78))
    paste(img, outline(skull, 1.0, BLACK))
    # eye sockets (big, a little slanted), the nose, the teeth
    for side in (-1.0, 1.0):
        socket = smooth(poly([(cx + side * 2.0, 15.5), (cx + side * 9.0, 14.4), (cx + side * 9.6, 20.0), (cx + side * 6.2, 23.2), (cx + side * 2.6, 21.0)]), 0.9)
        paste(img, solid(socket, BLACK))
        paste(img, solid(disc(cx + side * 6.0 + 0.6, 17.2, 0.8), (140, 255, 150), 0.75))
    paste(img, solid(poly([(cx, 21.6), (cx - 2.2, 25.8), (cx, 25.0), (cx + 2.2, 25.8)]), BLACK))
    paste(img, solid(rrect((cx - 7.2, 28.0, cx + 7.2, 28.7), 0.3), BLACK, 0.85))
    for tx in (-4.6, -2.3, 0.0, 2.3, 4.6):
        paste(img, solid(rrect((cx + tx - 0.3, 28.0, cx + tx + 0.3, 31.6), 0.3), BLACK, 0.85))
    return ICON_SHARE


def waves(top, amplitude, radius, phase):
    """A cartoon wave: a body of water whose top edge is a row of semicircles (bumps), from y `top` down to the bottom of the face."""
    m = new_mask()
    d = ImageDraw.Draw(m)
    d.rectangle([u(FACE[0] - 2), u(top), u(FACE[2] + 2), u(FACE[3] + 2)], fill=255)
    x = FACE[0] - radius * 2 + phase
    while x < FACE[2] + radius * 2:
        d.ellipse([u(x - radius), u(top - amplitude), u(x + radius), u(top + amplitude)], fill=255)
        x += radius * 2.0
    return smooth(m, 0.35)


def icon_piranha(img):
    # the game's own robot piranha (its open-mouthed frame), leaping up out of the water: only its upper half shows
    fish = Image.open(FISH).convert("RGBA")
    fish = fish.crop(fish.getchannel("A").getbbox())
    width_px = 40.0 * ICON_SHARE                                              # its drawn width on the board, in tile pixels
    fish = fish.resize((u(width_px), int(u(width_px) * fish.height / fish.width)), Image.LANCZOS)
    fish = fish.rotate(26, expand=True, resample=Image.BICUBIC)   # the nose up: a leap
    layer = new_layer()
    water_line = FACE[3] - 11.0
    layer.alpha_composite(fish, (u(35.0) - fish.width // 2, u(water_line - 11.0 * ICON_SHARE) - fish.height // 2))
    water_dark = lit(waves(water_line - 3.5, 2.6, 4.0, 2.0), gradient_y(water_line - 4, FACE[3], [(0, (36, 112, 196)), (1, (20, 62, 128))]), radius=1.0, bump=1.0, spec=0.2, ambient=0.9)
    water = waves(water_line, 2.6, 4.0, 0.0)
    water_lit = lit(water, gradient_y(water_line - 3, FACE[3], [(0, (110, 208, 255)), (0.35, (52, 156, 232)), (1, (28, 96, 180))]), radius=1.0, bump=1.2, spec=0.35, ambient=0.9)
    paste(img, water_dark)
    paste(img, layer)
    paste(img, water_lit)
    paste(img, outline(water, 0.7, (14, 44, 96)))
    # curves on the water: a few arcs (a half circle each), and drops thrown up by the leap
    arcs = new_mask()
    d = ImageDraw.Draw(arcs)
    for (x, y, r) in ((16.0, 42.0, 3.4), (29.0, 44.0, 2.8), (44.0, 42.0, 3.4), (57.0, 44.0, 2.6)):
        d.arc([u(x - r), u(y - r), u(x + r), u(y + r)], 200, 340, fill=255, width=u(1.0))
    paste(img, solid(arcs, (200, 238, 255), 0.85))
    for (x, y, r) in ((14.0, 32.0, 1.0), (58.0, 31.0, 1.2), (51.0, 17.0, 0.9), (19.0, 18.0, 1.0)):
        paste(img, solid(disc(x, y, r), (190, 230, 255), 0.9))
    return 1.0


ICONS = {"nuclear": icon_nuclear, "poison": icon_poison, "fire": icon_fire, "piranha": icon_piranha}


def draw_sign(kind):
    img = new_layer()
    face = draw_stand(img)
    layer = new_layer()
    k = ICONS[kind](layer)
    paste(img, scaled(layer, k, 0.0 if kind == "piranha" else ICON_DROP), face)
    return img.resize((T, T), Image.LANCZOS)


def main():
    os.makedirs(OUT, exist_ok=True)
    signs = {}
    for kind in ICONS:
        signs[kind] = draw_sign(kind)
        signs[kind].save(os.path.join(OUT, "sign_pit_%s.png" % kind))
    sheet = Image.new("RGBA", (T * 4 * 4 + 40, T * 4 + 20), (40, 46, 62, 255))
    for i, kind in enumerate(ICONS):
        sheet.alpha_composite(signs[kind].resize((T * 4, T * 4), Image.NEAREST), (10 + i * (T * 4 + 6), 10))
    sheet.save(art_lib.preview_path("pit_signs.png"))
    print("done")


if __name__ == "__main__":
    main()
