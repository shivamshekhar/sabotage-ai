"""Draws the small icons of the puzzle window (HackPopup), in the style of the level tiles (navy steel, cyan and hazard-yellow edges, lit bevels):

    icon_firewall.png     a steel shield with a brick wall in it and a flame over it: the title of the window
    icon_lock.png         a closed padlock (hazard yellow): the puzzle is not solved yet
    icon_unlocked.png     an open padlock (green): access granted

Usage (from the repo root; needs Pillow, numpy, opencv):
    python tools/art/generate_ui_icons.py       writes assets/ui/icons/icon_*.png (128x128) and tmp/art_previews/ui_icons.png (all of them, for looking at only)

and the five icons of the title screen's menu: icon_levels (a server stack), icon_upgrades (an arrow up), icon_vehicles (the mech), icon_gadgets (a chip), icon_settings (a cog).
"""
import os

import numpy as np
from PIL import Image, ImageChops, ImageDraw

import art_lib
from art_lib import S, lit, outline, solid, paste, glow, rrect_mask, poly_mask, gradient_y, blur

OUT = os.path.join(art_lib.ROOT, "assets", "ui", "icons")
N = 128                      # the icon's size, in final pixels
W = N * S

EDGE = (11, 14, 22)
CYAN = (58, 208, 255)
STEEL_LIP = (132, 154, 198)
STEEL_TOP = (70, 86, 122)
STEEL_BOT = (30, 38, 58)
BRICK_TOP = (255, 160, 60)
BRICK_BOT = (200, 70, 30)
HAZARD_TOP = (255, 226, 110)
HAZARD_BOT = (214, 140, 10)
GREEN_TOP = (150, 255, 170)
GREEN_BOT = (40, 170, 80)


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


def smooth(mask, radius=1.2):
    return blur(mask, radius).point(lambda v: 255 if v > 128 else 0)


def add(a, b):
    return ImageChops.lighter(a, b)


def sub(a, b):
    return ImageChops.subtract(a, b)


def shrink(mask, px):
    """The mask pulled in by about `px` final pixels."""
    from PIL import ImageFilter
    return mask.filter(ImageFilter.MinFilter(max(3, u(px) // 2 * 2 + 1)))


# ---------------------------------------------------------------------------------------------------------------------------
def icon_firewall():
    img = new_layer()
    # the shield: a flat top with rounded corners narrowing to a point
    shield = smooth(add(rrect((16, 10, 112, 74), 12), poly([(16, 46), (112, 46), (102, 86), (64, 120), (26, 86)])), 1.6)
    glow(img, shield, CYAN, radii=(2, 6), strengths=(0.5, 0.3))
    paste(img, lit(shield, gradient_y(10, 120, [(0, STEEL_LIP), (0.5, STEEL_TOP), (1, STEEL_BOT)]), radius=3.0, bump=1.8, spec=0.5, ambient=0.8))
    paste(img, outline(shield, 1.4, EDGE))
    inner = smooth(shrink(shield, 8.0), 1.0)
    paste(img, solid(inner, (16, 22, 38)))
    # the brick wall inside: rows of bricks with a gap between (mortar), every other row shifted half a brick
    bricks = new_mask()
    d = ImageDraw.Draw(bricks)
    row_h, brick_w, gap = 15.0, 29.0, 3.0
    for row in range(8):
        y = 18.0 + row * row_h
        shift = (brick_w / 2.0) if row % 2 else 0.0
        x = 12.0 - shift
        while x < 120.0:
            d.rounded_rectangle([u(x + gap / 2), u(y + gap / 2), u(x + brick_w - gap / 2), u(y + row_h - gap / 2)], radius=u(1.5), fill=255)
            x += brick_w
    bricks = ImageChops.multiply(bricks, inner)
    paste(img, lit(bricks, gradient_y(18, 118, [(0, BRICK_TOP), (1, BRICK_BOT)]), radius=1.2, bump=2.0, spec=0.4, ambient=0.72))
    paste(img, outline(inner, 1.0, EDGE))
    # a flame over the wall
    fx, fy = 64.0, 66.0
    flame = smooth(poly([(fx + 1, fy - 34), (fx + 9, fy - 18), (fx + 21, fy - 6), (fx + 24, fy + 10), (fx + 18, fy + 24), (fx + 3, fy + 32), (fx - 12, fy + 28),
                         (fx - 23, fy + 14), (fx - 22, fy - 2), (fx - 14, fy - 10), (fx - 12, fy + 3), (fx - 4, fy - 8), (fx - 5, fy - 22)]), 2.0)
    glow(img, flame, (255, 110, 30), radii=(2, 6), strengths=(0.6, 0.4))
    paste(img, lit(flame, gradient_y(fy - 34, fy + 32, [(0, (255, 226, 90)), (0.5, (255, 130, 28)), (1, (214, 50, 24))]), radius=3.0, bump=1.6, spec=0.5, ambient=0.8))
    paste(img, outline(flame, 1.2, EDGE))
    core = smooth(poly([(fx + 2, fy - 8), (fx + 11, fy + 6), (fx + 12, fy + 17), (fx + 3, fy + 26), (fx - 8, fy + 22), (fx - 10, fy + 11), (fx - 3, fy + 3), (fx, fy + 8)]), 1.8)
    paste(img, lit(core, gradient_y(fy - 8, fy + 26, [(0, (255, 252, 200)), (1, (255, 196, 40))]), radius=2.0, bump=1.2, spec=0.4, ambient=0.9))
    return img


def _padlock(body_top, body_bottom, open_lock):
    img = new_layer()
    body = rrect((22, 56, 106, 116), 12)
    # the shackle: a thick arch of steel; open: raised, with only the right leg in the body
    ring = sub(ellipse(64, 58, 30, 40), ellipse(64, 58, 17, 27))
    if not open_lock:
        shackle = ImageChops.multiply(ring, rrect((0, 0, N, 62), 1))
        shackle = add(shackle, rrect((34, 56, 47, 66), 1))
        shackle = add(shackle, rrect((81, 56, 94, 66), 1))
    else:
        # open: the arch is lifted off the body; only its right leg stays in it, the left one hangs free above the body
        raised = new_mask()
        raised.paste(ring, (0, -u(14)))
        left = ImageChops.multiply(raised, rrect((0, 0, 64, 50), 1))
        right = ImageChops.multiply(raised, rrect((64, 0, N, 60), 1))
        shackle = add(add(left, right), rrect((81, 44, 94, 66), 1))
    shackle = smooth(shackle, 0.8)
    paste(img, lit(shackle, gradient_y(10, 64, [(0, STEEL_LIP), (1, STEEL_TOP)]), radius=2.6, bump=2.0, spec=0.7, ambient=0.8))
    paste(img, outline(shackle, 1.3, EDGE))
    glow(img, body, CYAN if not open_lock else (80, 255, 140), radii=(2, 6), strengths=(0.35, 0.25))
    paste(img, lit(body, gradient_y(56, 116, [(0, body_top), (1, body_bottom)]), radius=3.0, bump=1.8, spec=0.6, ambient=0.78))
    paste(img, outline(body, 1.4, EDGE))
    # the keyhole
    hole = add(disc(64, 82, 8.0), poly([(59, 86), (69, 86), (72, 104), (56, 104)]))
    paste(img, solid(smooth(hole, 0.7), (26, 28, 38)))
    paste(img, solid(disc(61.5, 79.5, 1.6), (255, 255, 255), 0.5))
    # rivets
    for rx, ry in ((32, 66), (96, 66), (32, 106), (96, 106)):
        paste(img, lit(disc(rx, ry, 2.2), (190, 200, 220), radius=0.6, bump=2.4, spec=0.9))
    return img



def line_mask(points, width):
    """A thick line through `points` (round ends), as a mask."""
    m = new_mask()
    d = ImageDraw.Draw(m)
    pts = [(u(x), u(y)) for x, y in points]
    d.line(pts, fill=255, width=u(width), joint="curve")
    for x, y in pts:
        d.ellipse([x - u(width) // 2, y - u(width) // 2, x + u(width) // 2, y + u(width) // 2], fill=255)
    return m


def steel(img, mask, y0, y1, glow_color=CYAN):
    glow(img, mask, glow_color, radii=(2, 6), strengths=(0.4, 0.25))
    paste(img, lit(mask, gradient_y(y0, y1, [(0, STEEL_LIP), (0.4, STEEL_TOP), (1, STEEL_BOT)]), radius=2.6, bump=1.8, spec=0.5, ambient=0.8))
    paste(img, outline(mask, 1.4, EDGE))


def led(img, cx, cy, color):
    glow(img, disc(cx, cy, 3.2), color, radii=(2, 5), strengths=(0.7, 0.4))
    paste(img, solid(disc(cx, cy, 3.2), color))
    paste(img, solid(disc(cx - 0.9, cy - 0.9, 1.1), (255, 255, 255), 0.7))


def icon_levels():
    """A stack of three server units with blinking lights: the data centers (the levels)."""
    img = new_layer()
    for i, (top, light) in enumerate(((12, (80, 255, 140)), (48, (255, 190, 60)), (84, (58, 208, 255)))):
        unit = rrect((14, top, 114, top + 32), 6)
        steel(img, unit, top, top + 32)
        paste(img, solid(rrect((54, top + 8, 104, top + 12), 1.5), (14, 18, 30)))
        paste(img, solid(rrect((54, top + 20, 104, top + 24), 1.5), (14, 18, 30)))
        led(img, 28, top + 16, light)
        led(img, 40, top + 16, (255, 80, 70) if i == 1 else light)
    return img


def icon_upgrades():
    """A big green arrow pointing up out of a steel plate: stronger."""
    img = new_layer()
    plate = rrect((22, 100, 106, 118), 5)
    steel(img, plate, 100, 118)
    arrow = smooth(poly([(64, 8), (112, 58), (84, 58), (84, 96), (44, 96), (44, 58), (16, 58)]), 1.2)
    glow(img, arrow, (80, 255, 140), radii=(2, 6), strengths=(0.6, 0.4))
    paste(img, lit(arrow, gradient_y(8, 96, [(0, GREEN_TOP), (1, GREEN_BOT)]), radius=3.2, bump=1.8, spec=0.6, ambient=0.8))
    paste(img, outline(arrow, 1.5, EDGE))
    chevron = smooth(poly([(50, 70), (64, 58), (78, 70), (78, 78), (64, 66), (50, 78)]), 0.8)
    paste(img, solid(chevron, (230, 255, 236), 0.75))
    return img


def icon_vehicles():
    """The mech: a yellow body with a cyan canopy, a gun and four legs."""
    img = new_layer()
    legs = new_mask()
    for sx in (-1, 1):
        legs = add(legs, line_mask([(64 + sx * 18, 78), (64 + sx * 36, 92), (64 + sx * 40, 114)], 6))
        legs = add(legs, line_mask([(64 + sx * 8, 80), (64 + sx * 14, 96), (64 + sx * 14, 114)], 6))
    legs = smooth(legs, 1.0)
    paste(img, lit(legs, gradient_y(78, 116, [(0, STEEL_LIP), (1, STEEL_BOT)]), radius=2.4, bump=1.6, spec=0.5, ambient=0.8))
    paste(img, outline(legs, 1.3, EDGE))
    barrel = rrect((84, 46, 120, 56), 3)
    steel(img, barrel, 46, 56)
    body = rrect((26, 40, 96, 82), 12)
    glow(img, body, (255, 190, 40), radii=(2, 6), strengths=(0.45, 0.3))
    paste(img, lit(body, gradient_y(40, 82, [(0, HAZARD_TOP), (1, HAZARD_BOT)]), radius=3.2, bump=1.8, spec=0.6, ambient=0.8))
    paste(img, outline(body, 1.5, EDGE))
    canopy = smooth(sub(ellipse(54, 44, 22, 22), rrect((0, 44, N, N), 1)), 1.0)
    paste(img, lit(canopy, gradient_y(22, 44, [(0, (190, 245, 255)), (1, (60, 170, 220))]), radius=2.4, bump=1.4, spec=0.9, ambient=0.85))
    paste(img, outline(canopy, 1.3, EDGE))
    for rx, ry in ((34, 70), (88, 70)):
        paste(img, lit(disc(rx, ry, 2.2), (190, 200, 220), radius=0.6, bump=2.4, spec=0.9))
    return img


def icon_gadgets():
    """A processor chip with pins and a glowing die."""
    img = new_layer()
    pins = new_mask()
    for i in range(5):
        p = 38 + i * 13
        for box in ((p - 3, 14, p + 3, 34), (p - 3, 94, p + 3, 114), (14, p - 3, 34, p + 3), (94, p - 3, 114, p + 3)):
            pins = add(pins, rrect(box, 1.5))
    paste(img, lit(pins, gradient_y(14, 114, [(0, (214, 222, 240)), (1, (130, 144, 180))]), radius=1.0, bump=2.0, spec=0.6, ambient=0.85))
    paste(img, outline(pins, 1.1, EDGE))
    chip = rrect((28, 28, 100, 100), 8)
    steel(img, chip, 28, 100)
    die = rrect((44, 44, 84, 84), 5)
    glow(img, die, CYAN, radii=(2, 6, 12), strengths=(0.8, 0.5, 0.3))
    paste(img, lit(die, gradient_y(44, 84, [(0, (170, 240, 255)), (1, (30, 130, 190))]), radius=2.0, bump=1.4, spec=0.7, ambient=0.9))
    paste(img, outline(die, 1.3, EDGE))
    paste(img, solid(disc(36, 36, 2.2), (255, 210, 80)))
    return img


def icon_settings():
    """A cog."""
    import math
    img = new_layer()
    cx = cy = 64.0
    teeth = new_mask()
    for k in range(8):
        a = k * math.tau / 8
        ca, sa = math.cos(a), math.sin(a)
        pts = []
        for r, half in ((34, 11), (56, 8)):
            for sign in (-1, 1):
                px, py = cx + ca * r + (-sa) * half * sign, cy + sa * r + ca * half * sign
                pts.append((px, py))
        teeth = add(teeth, poly([pts[0], pts[2], pts[3], pts[1]]))
    ring = disc(cx, cy, 42)
    cog = smooth(sub(add(teeth, ring), disc(cx, cy, 17)), 1.2)
    steel(img, cog, 8, 120)
    paste(img, outline(disc(cx, cy, 17), 1.4, EDGE))
    hub = disc(cx, cy, 9)
    glow(img, hub, CYAN, radii=(2, 5), strengths=(0.7, 0.4))
    paste(img, solid(hub, (120, 220, 255)))
    return img


def main():
    os.makedirs(OUT, exist_ok=True)
    icons = {"icon_firewall": icon_firewall(), "icon_lock": _padlock(HAZARD_TOP, HAZARD_BOT, False), "icon_unlocked": _padlock(GREEN_TOP, GREEN_BOT, True),
             "icon_levels": icon_levels(), "icon_upgrades": icon_upgrades(), "icon_vehicles": icon_vehicles(), "icon_gadgets": icon_gadgets(), "icon_settings": icon_settings()}
    sheet = Image.new("RGBA", (N * len(icons) + 10 * (len(icons) + 1), N + 20), (24, 30, 46, 255))
    for i, (name, layer) in enumerate(icons.items()):
        small = layer.resize((N, N), Image.LANCZOS)
        small.save(os.path.join(OUT, name + ".png"))
        sheet.alpha_composite(small, (10 + i * (N + 10), 10))
    sheet.save(art_lib.preview_path("ui_icons.png"))
    print("done")


if __name__ == "__main__":
    main()
