"""Draws the exit door of a level (the data-center door the player walks into to finish it), in the style of the level tiles: navy steel, cyan edge lights,
hazard-yellow stripes, lit bevels. It is a double sliding door in a heavy frame, 2 tiles wide and 3 tall (140x210):

    assets/levels/common/door/door_frame.png     the frame: two pillars, the header with a lamp socket and a hazard stripe, the threshold (the opening is clear)
    assets/levels/common/door/door_inside.png    the dark corridor behind the door, exactly the shape of the opening (the game clips the leaves to it)
    assets/levels/common/door/door_leaf.png      the left leaf; the right one is the same picture flipped
    assets/levels/common/tiles/data_center/structure/door_exit.png      the closed door whole: what the level editor shows for the exit

Usage (from the repo root; needs Pillow, numpy, opencv):
    python tools/art/generate_door.py
"""
import os

import numpy as np
from PIL import Image, ImageChops, ImageDraw

import art_lib
from art_lib import S, lit, outline, solid, paste, glow, rrect_mask, poly_mask, gradient_y, gradient_x, blur

DOOR_DIR = os.path.join(art_lib.ROOT, "assets", "levels", "common", "door")
TILE_DIR = os.path.join(art_lib.ROOT, "assets", "levels", "common", "tiles", "data_center", "structure")
W, H = 140, 210                      # the door's size in final pixels (2 x 3 tiles of 70)
PILLAR = 18                          # the width of each side pillar
HEADER = 40                          # the height of the header
THRESHOLD = 10                       # the height of the floor plate
OPEN_X0, OPEN_X1 = PILLAR, W - PILLAR            # the opening: x from-to
OPEN_Y0, OPEN_Y1 = HEADER, H - THRESHOLD         # and y from-to
MID_X = W // 2

EDGE = (11, 14, 22)
CYAN = (58, 208, 255)
STEEL_LIP = (132, 154, 198)
STEEL_TOP = (86, 104, 142)
STEEL_BOT = (34, 42, 64)
HAZARD = (255, 200, 30)
BLACK = (24, 26, 34)


def u(v):
    return int(round(v * S))


def new_mask():
    return Image.new("L", (W * S, H * S), 0)


def new_layer():
    return Image.new("RGBA", (W * S, H * S), (0, 0, 0, 0))


def box(x0, y0, x1, y1, r=0):
    return rrect_mask((W * S, H * S), [u(x0), u(y0), u(x1), u(y1)], u(r))


def add(a, b):
    return ImageChops.lighter(a, b)


def sub(a, b):
    return ImageChops.subtract(a, b)


def poly(points):
    return poly_mask([(u(x), u(y)) for x, y in points], (W * S, H * S))


def disc(cx, cy, r):
    m = new_mask()
    ImageDraw.Draw(m).ellipse([u(cx - r), u(cy - r), u(cx + r), u(cy + r)], fill=255)
    return m


def hazard_band(x0, y0, x1, y1, stripe=9.0):
    """Diagonal yellow and black stripes in a box, as a layer."""
    layer = new_layer()
    mask = box(x0, y0, x1, y1)
    paste(layer, solid(mask, HAZARD))
    black = new_mask()
    d = ImageDraw.Draw(black)
    x = x0 - (y1 - y0)
    while x < x1 + (y1 - y0):
        d.polygon([(u(x), u(y1)), (u(x + stripe), u(y1)), (u(x + stripe + (y1 - y0)), u(y0)), (u(x + (y1 - y0)), u(y0))], fill=255)
        x += stripe * 2
    paste(layer, solid(ImageChops.multiply(black, mask), BLACK))
    paste(layer, outline(mask, 0.9, EDGE))
    return layer


def frame():
    img = new_layer()
    outer = box(0, 0, W, H, 4)
    opening = box(OPEN_X0, OPEN_Y0, OPEN_X1, OPEN_Y1, 2)
    body = sub(outer, opening)
    glow(img, body, CYAN, radii=(2, 5), strengths=(0.25, 0.15))
    paste(img, lit(body, gradient_y(0, H, [(0, STEEL_LIP), (0.12, STEEL_TOP), (1, STEEL_BOT)]), radius=3.0, bump=1.8, spec=0.5, ambient=0.8))
    paste(img, outline(body, 1.4, EDGE))
    # the edge of the opening: a thin cyan light all round it
    rim = sub(box(OPEN_X0 - 1.5, OPEN_Y0 - 1.5, OPEN_X1 + 1.5, OPEN_Y1 + 1.5, 3), box(OPEN_X0 + 0.5, OPEN_Y0 + 0.5, OPEN_X1 - 0.5, OPEN_Y1 - 0.5, 2))
    paste(img, solid(rim, CYAN, 0.55))
    # the header: a hazard stripe band over a dark panel with the lamp socket in the middle
    paste(img, hazard_band(6, 6, W - 6, 15))
    panel = box(22, 19, W - 22, 35, 3)
    paste(img, solid(panel, (14, 18, 30)))
    paste(img, outline(panel, 1.0, CYAN))
    socket = disc(MID_X, 27, 5.5)
    paste(img, solid(socket, (30, 34, 48)))
    paste(img, outline(socket, 1.2, (150, 164, 196)))
    # rivets on the pillars and the header
    for rx, ry in [(9, 20), (9, 60), (9, 100), (9, 140), (9, 180), (W - 9, 20), (W - 9, 60), (W - 9, 100), (W - 9, 140), (W - 9, 180), (14, 27), (W - 14, 27)]:
        paste(img, lit(disc(rx, ry, 2.2), (190, 200, 220), radius=0.6, bump=2.4, spec=0.9))
    # vents in the pillars
    for px in (4.5, W - PILLAR + 4.5):
        for vy in (44, 52, 60):
            paste(img, solid(box(px, vy, px + 9, vy + 3, 1), (16, 20, 34)))
    # the threshold: a floor plate with a hazard strip
    paste(img, hazard_band(PILLAR, H - THRESHOLD + 1, W - PILLAR, H - 1, 7.0))
    return img


def inside():
    """The dark corridor behind the door: black at the edges, with a far light bar and a lit floor, in the shape of the opening."""
    mask = box(OPEN_X0, OPEN_Y0, OPEN_X1, OPEN_Y1, 2)
    img = new_layer()
    paste(img, solid(mask, (6, 9, 18)))
    # a faint light at the far end of the corridor: a soft cyan glow in the middle, a bright line low down
    lamp = new_layer()
    core = box(MID_X - 8, OPEN_Y0 + 60, MID_X + 8, OPEN_Y1 - 30, 3)
    glow(lamp, core, (90, 230, 255), radii=(4, 12, 28), strengths=(0.9, 0.6, 0.35))
    paste(lamp, solid(core, (210, 250, 255), 0.9))
    floor = box(OPEN_X0 + 6, OPEN_Y1 - 14, OPEN_X1 - 6, OPEN_Y1 - 8, 2)
    glow(lamp, floor, (60, 180, 255), radii=(3, 8), strengths=(0.7, 0.4))
    paste(lamp, solid(floor, (140, 220, 255), 0.8))
    clipped = Image.new("RGBA", lamp.size, (0, 0, 0, 0))
    clipped.paste(lamp, (0, 0), mask)
    paste(img, clipped)
    return img


def leaf():
    """The left leaf: a steel slab with ribs and a hazard edge on the side where the two meet."""
    img = new_layer()
    x0, x1 = OPEN_X0, MID_X + 0.5
    slab = box(x0, OPEN_Y0, x1, OPEN_Y1)
    paste(img, lit(slab, gradient_y(OPEN_Y0, OPEN_Y1, [(0, STEEL_LIP), (0.25, STEEL_TOP), (1, STEEL_BOT)]), radius=2.2, bump=1.6, spec=0.45, ambient=0.85))
    # ribs: grooves across the slab
    for ry in (OPEN_Y0 + 22, OPEN_Y0 + 52, OPEN_Y0 + 82, OPEN_Y0 + 112, OPEN_Y0 + 142):
        paste(img, solid(box(x0 + 3, ry, x1 - 12, ry + 2.5, 1), (12, 16, 28), 0.9))
        paste(img, solid(box(x0 + 3, ry + 2.5, x1 - 12, ry + 3.6, 1), (170, 190, 226), 0.35))
    # the hazard edge at the seam
    paste(img, hazard_band(x1 - 9, OPEN_Y0, x1, OPEN_Y1, 8.0))
    # a small indicator light
    paste(img, solid(disc(x0 + 9, OPEN_Y0 + 12, 2.6), (255, 90, 70)))
    paste(img, outline(slab, 1.2, EDGE))
    return img


def to_final(img):
    return img.resize((W, H), Image.LANCZOS)


def main():
    os.makedirs(DOOR_DIR, exist_ok=True)
    os.makedirs(TILE_DIR, exist_ok=True)
    f, i, lf = frame(), inside(), leaf()
    to_final(f).save(os.path.join(DOOR_DIR, "door_frame.png"))
    to_final(i).save(os.path.join(DOOR_DIR, "door_inside.png"))
    to_final(lf).save(os.path.join(DOOR_DIR, "door_leaf.png"))
    # the closed door whole (the editor's picture): inside, both leaves, the frame over them, a red lamp
    whole = new_layer()
    whole.alpha_composite(i)
    whole.alpha_composite(lf)
    whole.alpha_composite(lf.transpose(Image.FLIP_LEFT_RIGHT))
    whole.alpha_composite(f)
    lamp = new_layer()
    lamp_mask = disc(MID_X, 27, 3.8)
    glow(lamp, lamp_mask, (255, 60, 40), radii=(2, 6), strengths=(0.8, 0.5))
    paste(lamp, solid(lamp_mask, (255, 110, 90)))
    whole.alpha_composite(lamp)
    to_final(whole).save(os.path.join(TILE_DIR, "door_exit.png"))
    sheet = Image.new("RGBA", (W * 4 + 50, H + 20), (24, 30, 46, 255))
    for n, layer in enumerate([f, i, lf, whole]):
        sheet.alpha_composite(to_final(layer), (10 + n * (W + 10), 10))
    sheet.save(art_lib.preview_path("door.png"))
    print("done")


if __name__ == "__main__":
    main()
