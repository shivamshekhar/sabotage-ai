"""Draws the first power-up vehicle: a four-legged mech with the body of a yellow construction crane and legs like Doctor Octopus's
tentacles, with a missile turret and a laser turret and a rocket booster under its belly.

Usage (from the repo root; needs Pillow, numpy and opencv):
    python tools/art/generate_mech.py       writes assets/powerups/mech/*.png (and a picture of the mech assembled into tmp/art_previews/)

THE PARTS (every picture faces right; the game flips them to face left; they are drawn at twice the size they are shown at):
    body.png          the crane cab, engine block, counterweight and hull. The cockpit window is a TRANSPARENT hole: the game puts the
                      player's picture behind it (and canopy.png, the glass, in front of it).
    canopy.png        the glass of the cockpit, a reflection over the player
    missile_turret.png, laser_turret.png   the two turrets; they turn about their pivot (their pivots and muzzles are constants of MechVisual)
    link.png, joint.png, claw.png, hip.png the pieces of a leg. The game draws each leg as a chain of links along a smooth curve from the
                      hip to the foot (that is what gives the octopus movement), a joint between every two links and the claw at the end
    flame_1..3.png    the rocket booster's flame (pointing down), shown while jumping
    (the missile, the damage effects and the weapon effects are drawn by generate_mech_effects.py)
HOW IT IS DRAWN: like the boss (generate_boss_shaker.py): every part is a mask, lit into a bevelled surface at 4x and shrunk.
"""
import math
import os
import sys

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import art_lib  # noqa: E402
from art_lib import S, INK, lit, outline, paste, solid  # noqa: E402

OUT = os.path.join(art_lib.ROOT, "assets", "powerups", "mech")

YEL = (255, 198, 26)
YEL_D = (214, 140, 10)
YEL_L = (255, 226, 110)
STEEL = (92, 100, 118)
STEEL_D = (46, 52, 66)
BLACK = (28, 30, 38)
CYAN = (60, 140, 255)          # the laser is blue
RED = (230, 52, 40)


def mk(w, h):
    return Image.new("L", (w * S, h * S), 0)


def P(x, y):
    return (x * S, y * S)


def pl(points):
    return [P(x, y) for x, y in points]


def poly(m, points, v=255):
    ImageDraw.Draw(m).polygon(pl(points), fill=v)
    return m


def rr(m, box, r, v=255):
    x0, y0, x1, y1 = box
    ImageDraw.Draw(m).rounded_rectangle([P(x0, y0), P(x1, y1)], radius=r * S, fill=v)
    return m


def ell(m, cx, cy, rx, ry=None, v=255):
    ry = rx if ry is None else ry
    ImageDraw.Draw(m).ellipse([P(cx - rx, cy - ry), P(cx + rx, cy + ry)], fill=v)
    return m


def line(m, a, b, width, v=255):
    ImageDraw.Draw(m).line([P(*a), P(*b)], fill=v, width=max(1, int(width * S)))
    return m


def vgrad(y0, y1, top, bottom):
    def fn(xx, yy):
        t = np.clip((yy / S - y0) / max(1e-6, (y1 - y0)), 0, 1)[..., None]
        return np.array(top, np.float32) * (1 - t) + np.array(bottom, np.float32) * t
    return fn


def part(canvas, m, base, outline_w=1.1, **kw):
    """Light the mask `m` with `base` (colour or function) and paste it with a dark outline."""
    kw.setdefault("radius", 2.4)
    kw.setdefault("bump", 2.0)
    canvas.alpha_composite(lit(m, base, **kw))
    if outline_w:
        canvas.alpha_composite(outline(m, outline_w))


def finish(canvas, path):
    w, h = canvas.size[0] // S, canvas.size[1] // S
    out = canvas.resize((w, h), Image.LANCZOS)
    out.save(path)
    return out


def inside(m, clip):
    return ImageChops.multiply(m, clip)


def stripes(w, h, period, width, slant=1.0):
    """Diagonal hazard stripes (a mask) over a w x h area."""
    m = mk(w, h)
    d = ImageDraw.Draw(m)
    k = -h
    while k < w + h:
        d.polygon([P(k, 0), P(k + width, 0), P(k + width + h * slant, h), P(k + h * slant, h)], fill=255)
        k += period
    return m


# ----------------------------------------------------------------------------------------------------------------------
# the body
# ----------------------------------------------------------------------------------------------------------------------
BW, BH = 300, 214          # the body picture's size in px (shown at half that)
WINDOW = [(178, 62), (226, 62), (254, 86), (254, 118), (178, 118)]    # the cockpit hole, in body px


def draw_body():
    c = Image.new("RGBA", (BW * S, BH * S), (0, 0, 0, 0))

    # exhaust stack (behind everything)
    stack = rr(mk(BW, BH), (34, 8, 52, 70), 4)
    part(c, stack, (62, 66, 80), radius=1.6, bump=2.4)
    cap = rr(mk(BW, BH), (30, 4, 56, 16), 4)
    part(c, cap, (84, 90, 104), radius=1.2)
    # the hull (the belly): dark steel with hazard stripes along its lower edge
    hull = rr(mk(BW, BH), (16, 150, 290, 198), 10)
    part(c, hull, vgrad(150, 198, (84, 92, 110), (40, 46, 60)), bump=2.2)
    strip_area = rr(mk(BW, BH), (22, 178, 284, 194), 4)
    hz = inside(stripes(BW, BH, 22, 11), strip_area)
    c.alpha_composite(solid(strip_area, BLACK))
    c.alpha_composite(solid(hz, YEL))
    c.alpha_composite(outline(strip_area, 0.8))
    # bolts on the hull
    for bx in range(36, 290, 38):
        b = ell(mk(BW, BH), bx, 162, 3.2)
        part(c, b, (150, 158, 176), outline_w=0.5, radius=0.8, bump=2.6, spec=0.8)

    # the turntable ring between hull and cab (a crane's slewing ring)
    ring = rr(mk(BW, BH), (60, 138, 262, 154), 6)
    part(c, ring, vgrad(138, 154, (130, 138, 156), (60, 66, 82)), radius=1.4)
    for gx in range(70, 258, 10):
        tooth = rr(mk(BW, BH), (gx, 145, gx + 5, 153), 1)
        c.alpha_composite(solid(tooth, (34, 38, 50), 0.9))

    # engine block / counterweight at the back
    block = rr(mk(BW, BH), (14, 62, 128, 142), 12)
    part(c, block, vgrad(62, 142, YEL_L, YEL_D), bump=2.4, spec=0.5)
    # the vents (dark slits with a glow behind)
    for k in range(5):
        slit = rr(mk(BW, BH), (30, 78 + k * 11, 96, 84 + k * 11), 2)
        c.alpha_composite(solid(slit, (40, 24, 8), 0.95))
        c.alpha_composite(solid(ImageChops.offset(slit, 0, S), (255, 170, 60), 0.25))
    # black stripe and bolts on the counterweight
    band = inside(stripes(BW, BH, 18, 9, 0.6), rr(mk(BW, BH), (18, 122, 124, 138), 3))
    c.alpha_composite(solid(rr(mk(BW, BH), (18, 122, 124, 138), 3), BLACK))
    c.alpha_composite(solid(band, YEL))
    c.alpha_composite(outline(rr(mk(BW, BH), (18, 122, 124, 138), 3), 0.8))
    for bx, by in ((26, 72), (116, 72), (26, 112), (116, 112)):
        part(c, ell(mk(BW, BH), bx, by, 3.2), (150, 158, 176), outline_w=0.5, radius=0.8, bump=2.6, spec=0.8)
    # the beacon sits on top of the engine block, on its own little base
    base = rr(mk(BW, BH), (80, 54, 104, 65), 3)
    part(c, base, (70, 76, 92), radius=1.0)
    beacon = ell(mk(BW, BH), 92, 55, 10, 10)
    beacon = ImageChops.multiply(beacon, rr(mk(BW, BH), (70, 40, 120, 56), 1))
    part(c, beacon, (255, 140, 30), radius=3.0, bump=2.6, spec=0.9)
    art_lib.glow(c, ell(mk(BW, BH), 92, 50, 5, 5), (255, 170, 60), radii=(2, 6, 14), strengths=(0.9, 0.55, 0.35))

    # the cab (the nose): a sloped, rounded yellow shell
    cab_pts = [(116, 142), (116, 70), (138, 46), (234, 46), (276, 82), (294, 118), (294, 142)]
    cab = poly(mk(BW, BH), cab_pts)
    cab = cab.filter(ImageFilter.GaussianBlur(3 * S)).point(lambda v: 255 if v > 128 else 0).filter(ImageFilter.GaussianBlur(0.6 * S))
    part(c, cab, vgrad(46, 142, YEL_L, YEL_D), radius=3.4, bump=2.4, spec=0.55, outline_w=1.3)
    # panel lines
    for seg in (((116, 100), (176, 100)), ((130, 124), (294, 124)), ((250, 100), (250, 142))):
        gm = inside(line(mk(BW, BH), seg[0], seg[1], 1.4), cab)
        c.alpha_composite(solid(gm, (140, 90, 6), 0.8))
        c.alpha_composite(solid(ImageChops.offset(gm, 0, S), YEL_L, 0.5))
    # the headlight and the front bumper
    lamp = rr(mk(BW, BH), (278, 110, 296, 128), 5)
    part(c, lamp, (250, 250, 235), radius=1.6, bump=1.6, spec=0.9, outline_w=0.9)
    art_lib.glow(c, lamp, (255, 245, 190), radii=(2, 6, 16), strengths=(0.6, 0.45, 0.35))
    bumper = rr(mk(BW, BH), (270, 130, 300, 146), 4)
    part(c, bumper, (70, 76, 92), radius=1.2)
    # the pedestal on the cab roof that the missile turret stands on (its base rests on this plate; see MISSILE_MOUNT)
    plate = rr(mk(BW, BH), (146, 38, 206, 50), 4)
    part(c, plate, vgrad(38, 50, (130, 138, 156), (60, 66, 82)), radius=1.2, bump=2.2, outline_w=0.9)
    for bx in (154, 198):
        part(c, ell(mk(BW, BH), bx, 44, 2.0), (180, 188, 204), outline_w=0.4, radius=0.5, bump=2.6, spec=0.9)

    # the belly: a booster nozzle sticking out under the hull
    nozzle = poly(mk(BW, BH), [(128, 196), (172, 196), (182, 212), (118, 212)])
    part(c, nozzle, vgrad(196, 212, (96, 102, 120), (30, 34, 44)), radius=1.2, bump=2.2, spec=0.7, outline_w=1.0)
    inner = rr(mk(BW, BH), (126, 205, 174, 213), 3)
    c.alpha_composite(solid(inner, (255, 140, 40), 0.9))

    # the cockpit: a frame around the window, then the hole
    win = poly(mk(BW, BH), WINDOW)
    frame_outer = win.filter(ImageFilter.MaxFilter(11 * S // 2 * 2 // S * 2 + 1))
    frame = ImageChops.subtract(frame_outer, win)
    part(c, frame_outer, (44, 48, 60), radius=1.2, bump=2.0, outline_w=0.9)
    # make the hole (transparent) after everything is drawn
    hole = Image.new("RGBA", c.size, (0, 0, 0, 0))
    alpha = c.getchannel("A")
    alpha = ImageChops.subtract(alpha, win)
    c.putalpha(alpha)
    # a dark rim just inside the hole, so the window reads as recessed
    rim = ImageChops.subtract(win.filter(ImageFilter.MaxFilter(5)), win)
    c.alpha_composite(solid(rim, (10, 12, 18), 0.9))
    return c


def draw_canopy():
    """The glass over the window (same size as the body so it lines up): a tint and two reflection streaks."""
    c = Image.new("RGBA", (BW * S, BH * S), (0, 0, 0, 0))
    win = poly(mk(BW, BH), WINDOW)
    c.alpha_composite(solid(win, (120, 200, 255), 0.16))
    streak1 = inside(poly(mk(BW, BH), [(190, 62), (206, 62), (186, 118), (178, 118), (178, 100)]), win)
    streak2 = inside(poly(mk(BW, BH), [(212, 62), (220, 62), (200, 118), (196, 118)]), win)
    c.alpha_composite(solid(streak1, (235, 248, 255), 0.35))
    c.alpha_composite(solid(streak2, (235, 248, 255), 0.22))
    c.alpha_composite(solid(inside(line(mk(BW, BH), (180, 64), (252, 64), 1.6), win), (255, 255, 255), 0.5))
    return c


# ----------------------------------------------------------------------------------------------------------------------
# the turrets
# ----------------------------------------------------------------------------------------------------------------------
MTW, MTH = 184, 92         # the missile turret: pivot at (40, 50); the muzzle (where a missile leaves) is at (176, 44)
MT_PIVOT = (40, 50)


gm_stripes = stripes


def draw_missile_turret():
    c = Image.new("RGBA", (MTW * S, MTH * S), (0, 0, 0, 0))
    # two launch tubes (one above the other: the far one is darker), a body block, a swivel base
    far = rr(mk(MTW, MTH), (40, 24, 146, 44), 6)
    part(c, far, vgrad(24, 44, (70, 76, 92), (40, 44, 58)), radius=1.6)
    near = rr(mk(MTW, MTH), (36, 38, 150, 62), 7)
    part(c, near, vgrad(38, 62, (150, 158, 176), (60, 66, 82)), radius=2.0, bump=2.4, spec=0.6)
    # the tube ends: a steel flange with rivets, and the missile inside showing its nose (a silver collar, a red ogive with a dark tip, a highlight)
    for xe, y0, y1, dark in ((146, 24, 44, True), (150, 38, 62, False)):
        yc = (y0 + y1) / 2.0
        h = y1 - y0
        # the nose first (behind the flange)
        nose_len = 28
        collar = rr(mk(MTW, MTH), (xe - 6, yc - h * 0.38, xe + 6, yc + h * 0.38), 2)
        part(c, collar, vgrad(yc - h * 0.38, yc + h * 0.38, (230, 234, 242), (120, 128, 148)), radius=1.0, bump=2.0, spec=0.8, outline_w=0.7)
        cone = poly(mk(MTW, MTH), [(xe + 4, yc - h * 0.36), (xe + nose_len, yc - h * 0.05), (xe + nose_len, yc + h * 0.05), (xe + 4, yc + h * 0.36)])
        cone = cone.filter(ImageFilter.GaussianBlur(1.2 * S)).point(lambda v: 255 if v > 128 else 0)
        gm_col = vgrad(yc - h * 0.36, yc + h * 0.36, (255, 120, 96) if not dark else (210, 84, 70), (150, 20, 18) if not dark else (110, 18, 16))
        part(c, cone, gm_col, radius=1.8, bump=2.2, spec=0.85, outline_w=0.9)
        tip = inside(ell(mk(MTW, MTH), xe + nose_len - 1, yc, 4.0, h * 0.09), cone)
        c.alpha_composite(solid(tip, (36, 38, 48)))
        # a pale stripe along the cone (a glint) and a seam ring
        glint = inside(poly(mk(MTW, MTH), [(xe + 8, yc - h * 0.26), (xe + nose_len - 6, yc - h * 0.04), (xe + nose_len - 6, yc - h * 0.0), (xe + 8, yc - h * 0.20)]), cone)
        c.alpha_composite(solid(glint, (255, 220, 210), 0.55))
        seam = inside(rr(mk(MTW, MTH), (xe + 12, yc - h * 0.4, xe + 13.4, yc + h * 0.4), 0), cone)
        c.alpha_composite(solid(seam, (90, 12, 12), 0.7))
        # the flange (a ring round the tube end), with rivets and a dark bore line
        flange = rr(mk(MTW, MTH), (xe - 14, y0 - 3, xe - 2, y1 + 3), 3)
        part(c, flange, vgrad(y0 - 3, y1 + 3, (176, 184, 202), (64, 70, 88)), radius=1.6, bump=2.4, spec=0.8, outline_w=1.0)
        for ry in (y0 + 1, y1 - 1):
            part(c, ell(mk(MTW, MTH), xe - 8, ry, 1.5), (210, 216, 230), outline_w=0.3, radius=0.4, bump=2.4, spec=0.9)
        gap = rr(mk(MTW, MTH), (xe - 2.4, y0 - 1, xe + 0.4, y1 + 1), 1)
        c.alpha_composite(solid(gap, (14, 16, 22), 0.9))
        # warning stripes on the tube just behind the flange
        zone = inside(gm_stripes(MTW, MTH, 8, 3.6, 1.0), rr(mk(MTW, MTH), (xe - 26, y0 + 2, xe - 15, y1 - 2), 1))
        c.alpha_composite(solid(zone, YEL, 0.95))
    # yellow bands
    for bx in (62, 104):
        band = inside(rr(mk(MTW, MTH), (bx, 36, bx + 10, 64), 1), rr(mk(MTW, MTH), (36, 38, 160, 62), 7))
        c.alpha_composite(solid(band, YEL))
        c.alpha_composite(outline(band, 0.6))
    # the swivel base
    base = rr(mk(MTW, MTH), (14, 56, 70, 84), 8)
    part(c, base, vgrad(56, 84, YEL_L, YEL_D), radius=2.0, bump=2.2)
    pivot = ell(mk(MTW, MTH), *MT_PIVOT, 12)
    part(c, pivot, (110, 118, 136), radius=1.4, bump=2.4, spec=0.8)
    part(c, ell(mk(MTW, MTH), *MT_PIVOT, 5), (40, 44, 56), radius=0.8, outline_w=0.6)
    # a status light
    art_lib.glow(c, ell(mk(MTW, MTH), 66, 50, 2.4), (255, 90, 70), radii=(1.4, 4), strengths=(0.9, 0.5))
    c.alpha_composite(solid(ell(mk(MTW, MTH), 66, 50, 2.4), (255, 190, 170)))
    return c


LTW, LTH = 160, 76         # the laser turret: pivot at (34, 38)
LT_PIVOT = (34, 38)


def draw_laser_turret():
    c = Image.new("RGBA", (LTW * S, LTH * S), (0, 0, 0, 0))
    # a long tapered barrel with cooling fins and glowing coils
    barrel = poly(mk(LTW, LTH), [(30, 26), (136, 30), (136, 46), (30, 50)])
    part(c, barrel, vgrad(26, 50, (150, 158, 176), (50, 56, 72)), radius=1.8, bump=2.2, spec=0.7)
    fins = mk(LTW, LTH)
    for fx in range(46, 100, 9):
        rr(fins, (fx, 20, fx + 5, 56), 1)
    part(c, inside(fins, mk(LTW, LTH).point(lambda v: 255)), (90, 98, 116), radius=1.0, outline_w=0.7)
    coils = mk(LTW, LTH)
    for k in range(4):
        x = 104 + k * 7
        line(coils, (x, 29), (x, 47), 2.2)
    art_lib.glow(c, coils, CYAN, radii=(1.2, 4, 10), strengths=(1.0, 0.6, 0.4))
    c.alpha_composite(solid(coils, (200, 224, 255)))
    # the muzzle and the lens
    muzzle = rr(mk(LTW, LTH), (134, 26, 150, 50), 5)
    part(c, muzzle, (60, 66, 82), radius=1.2, bump=2.2, outline_w=0.9)
    lens = ell(mk(LTW, LTH), 148, 38, 4.5, 8)
    art_lib.glow(c, lens, CYAN, radii=(1.6, 5, 12), strengths=(1.0, 0.8, 0.5))
    c.alpha_composite(solid(lens, (215, 232, 255)))
    # the base: a yellow housing and the ball joint
    housing = rr(mk(LTW, LTH), (10, 40, 56, 66), 8)
    part(c, housing, vgrad(40, 66, YEL_L, YEL_D), radius=2.0, bump=2.2)
    ball = ell(mk(LTW, LTH), *LT_PIVOT, 13)
    part(c, ball, (110, 118, 136), radius=1.4, bump=2.4, spec=0.8)
    part(c, ell(mk(LTW, LTH), *LT_PIVOT, 5), (40, 44, 56), radius=0.8, outline_w=0.6)
    return c


# ----------------------------------------------------------------------------------------------------------------------
# the leg pieces
# ----------------------------------------------------------------------------------------------------------------------
LKW, LKH = 52, 40           # one link (pointing right): its length and thickness in px
JW = 44


def draw_link():
    c = Image.new("RGBA", (LKW * S, LKH * S), (0, 0, 0, 0))
    shell = rr(mk(LKW, LKH), (1, 4, LKW - 1, LKH - 4), 13)
    part(c, shell, vgrad(4, LKH - 4, YEL_L, YEL_D), radius=3.0, bump=2.4, spec=0.55, outline_w=1.2)
    # the hydraulic piston running through it, with a cylinder at one end
    cyl = rr(mk(LKW, LKH), (4, 13, 30, LKH - 13), 5)
    part(c, cyl, vgrad(13, LKH - 13, (110, 118, 136), (44, 50, 64)), radius=1.2, bump=2.2, outline_w=0.8)
    rod = rr(mk(LKW, LKH), (26, 17, LKW - 6, LKH - 17), 3)
    part(c, rod, vgrad(17, LKH - 17, (220, 228, 240), (110, 118, 136)), radius=0.8, bump=2.4, spec=0.9, outline_w=0.6)
    # black wear stripe and a bolt
    stripe = inside(stripes(LKW, LKH, 9, 4, 0.8), rr(mk(LKW, LKH), (36, 6, 48, 12), 1))
    c.alpha_composite(solid(stripe, BLACK, 0.9))
    for bx in (10, 42):
        part(c, ell(mk(LKW, LKH), bx, LKH / 2, 2.2), (150, 158, 176), outline_w=0.4, radius=0.6, bump=2.6, spec=0.9)
    return c


def draw_joint():
    c = Image.new("RGBA", (JW * S, JW * S), (0, 0, 0, 0))
    ball = ell(mk(JW, JW), JW / 2, JW / 2, JW / 2 - 3)
    part(c, ball, (62, 68, 84), radius=3.0, bump=2.6, spec=0.7, outline_w=1.2)
    ring = ImageChops.subtract(ell(mk(JW, JW), JW / 2, JW / 2, 11), ell(mk(JW, JW), JW / 2, JW / 2, 6))
    part(c, ring, vgrad(10, 34, YEL_L, YEL_D), radius=1.0, bump=2.0, outline_w=0.6)
    part(c, ell(mk(JW, JW), JW / 2, JW / 2, 4.2), (170, 178, 196), radius=0.8, bump=2.6, spec=0.9, outline_w=0.5)
    return c


CLW, CLH = 92, 78            # the claw: palm at the left, fingers reaching right and down


def draw_claw():
    c = Image.new("RGBA", (CLW * S, CLH * S), (0, 0, 0, 0))
    palm = rr(mk(CLW, CLH), (2, 20, 40, 58), 12)
    part(c, palm, vgrad(20, 58, YEL_L, YEL_D), radius=3.0, bump=2.4, outline_w=1.2)
    part(c, ell(mk(CLW, CLH), 16, 39, 7), (70, 76, 92), radius=1.2, bump=2.4, outline_w=0.8)
    # three fingers: thick curved bars (a polyline), the middle one straight ahead, the others up and down
    def finger(points, w):
        m = mk(CLW, CLH)
        for a, b in zip(points, points[1:]):
            line(m, a, b, w)
        for p in points:
            ell(m, p[0], p[1], w / 2)
        part(c, m, vgrad(0, CLH, (150, 158, 176), (52, 58, 74)), radius=1.8, bump=2.4, spec=0.7, outline_w=1.0)
        tip = ell(mk(CLW, CLH), points[-1][0], points[-1][1], w / 2 * 0.8)
        c.alpha_composite(solid(tip, (225, 230, 240)))
    finger([(34, 26), (56, 18), (76, 24), (86, 40)], 10)
    finger([(34, 52), (56, 60), (76, 56), (86, 44)], 10)
    finger([(36, 39), (62, 40), (82, 40)], 9)
    return c


def draw_hip():
    c = Image.new("RGBA", (56 * S, 56 * S), (0, 0, 0, 0))
    ball = ell(mk(56, 56), 28, 28, 25)
    part(c, ball, (72, 78, 96), radius=4.0, bump=2.6, spec=0.8, outline_w=1.4)
    ring = ImageChops.subtract(ell(mk(56, 56), 28, 28, 17), ell(mk(56, 56), 28, 28, 11))
    part(c, ring, vgrad(10, 46, YEL_L, YEL_D), radius=1.4, bump=2.0, outline_w=0.7)
    part(c, ell(mk(56, 56), 28, 28, 6), (190, 198, 214), radius=1.0, bump=2.6, spec=0.9, outline_w=0.6)
    return c


# ----------------------------------------------------------------------------------------------------------------------
# flames, missile
# ----------------------------------------------------------------------------------------------------------------------
def draw_flame(variant):
    w, h = 64, 110
    c = Image.new("RGBA", (w * S, h * S), (0, 0, 0, 0))
    length = (96, 80, 104)[variant]
    wid = (22, 26, 20)[variant]
    # a teardrop pointing down from the top-centre
    def drop(scale_l, scale_w):
        pts_ = []
        for k in range(0, 21):
            t = k / 20.0
            y = 4 + t * length * scale_l
            half = math.sin(t * math.pi * 0.5 + 0.0) ** 0.5 * 0 + (1 - t) ** 0.8 * wid * scale_w * (0.55 + 0.45 * math.sin(min(1.0, t * 4) * math.pi / 2))
            pts_.append((w / 2 - half, y))
        for k in range(20, -1, -1):
            t = k / 20.0
            y = 4 + t * length * scale_l
            half = (1 - t) ** 0.8 * wid * scale_w * (0.55 + 0.45 * math.sin(min(1.0, t * 4) * math.pi / 2))
            pts_.append((w / 2 + half, y))
        return poly(mk(w, h), pts_)
    outer = drop(1.0, 1.0).filter(ImageFilter.GaussianBlur(1.2 * S))
    mid = drop(0.72, 0.68).filter(ImageFilter.GaussianBlur(1.0 * S))
    core = drop(0.42, 0.4).filter(ImageFilter.GaussianBlur(0.8 * S))
    art_lib.glow(c, outer, (255, 120, 30), radii=(3, 9), strengths=(0.7, 0.5))
    c.alpha_composite(solid(outer, (255, 110, 30), 0.95))
    c.alpha_composite(solid(mid, (255, 200, 70), 1.0))
    c.alpha_composite(solid(core, (255, 250, 230), 1.0))
    return c


# ----------------------------------------------------------------------------------------------------------------------
# the preview
# ----------------------------------------------------------------------------------------------------------------------
def bezier(p0, p1, p2, t):
    return ((1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t * t * p2[0], (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t * t * p2[1])


def preview(parts, pose):
    """The mech assembled in a pose, in px at half size (the game's size), roughly as the game builds it."""
    W, H = 460, 380
    img = Image.new("RGBA", (W, H), (26, 32, 50, 255))
    ground = H - 40
    ImageDraw.Draw(img).rectangle([0, ground, W, H], fill=(44, 52, 74, 255))
    cx = W / 2
    belly = ground - (96 if pose == "stand" else 190)
    body_img = parts["body"]
    hip_y = belly
    roots = [(-52, 0.8), (-24, 1.0), (24, 1.0), (52, 0.8)]

    def leg(root_x, shade, foot, bend):
        root = (cx + root_x, hip_y - 4)
        mid = ((root[0] + foot[0]) / 2 + bend[0], (root[1] + foot[1]) / 2 + bend[1])
        n = 6
        ptsl = [bezier(root, mid, foot, k / n) for k in range(n + 1)]
        for k in range(n):
            a, b = ptsl[k], ptsl[k + 1]
            ln = math.hypot(b[0] - a[0], b[1] - a[1])
            ang = math.degrees(math.atan2(b[1] - a[1], b[0] - a[0]))
            thick = 1.0 - 0.5 * k / n
            link = parts["link"].resize((max(2, int(ln * 2 * 1.08)), max(2, int(LKH * thick))), Image.LANCZOS)
            link = link.rotate(-ang, expand=True, resample=Image.BICUBIC)
            half = (link.width // 2, link.height // 2)
            # the link is drawn at half size: shrink the texture to the game scale
            link = link.resize((max(1, link.width // 2), max(1, link.height // 2)), Image.LANCZOS)
            mid_pt = ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2)
            tinted = tint(link, shade)
            img.alpha_composite(tinted, (int(mid_pt[0] - tinted.width / 2), int(mid_pt[1] - tinted.height / 2)))
            j = parts["joint"].resize((int(JW * 0.5 * thick), int(JW * 0.5 * thick)), Image.LANCZOS)
            j = tint(j, shade)
            img.alpha_composite(j, (int(b[0] - j.width / 2), int(b[1] - j.height / 2)))
        claw = tint(parts["claw"].resize((CLW // 2, CLH // 2), Image.LANCZOS), shade)
        ang = math.degrees(math.atan2(ptsl[-1][1] - ptsl[-2][1], ptsl[-1][0] - ptsl[-2][0]))
        claw = claw.rotate(-ang, expand=True, resample=Image.BICUBIC)
        img.alpha_composite(claw, (int(foot[0] - claw.width * 0.28), int(foot[1] - claw.height / 2)))

    if pose == "stand":
        feet = [(-120, 0), (-76, 0), (74, 0), (118, 0)]
        for (rx, sh), (fx, _) in zip(roots, feet):
            if sh < 1.0 or True:
                pass
        for (rx, sh), (fx, _) in list(zip(roots, feet))[:2]:
            leg(rx, 0.62, (cx + fx, ground - 2), (rx * 0.5, -30))
    else:
        feet = [(-60, 0), (-34, 0), (36, 0), (62, 0)]
        for (rx, sh), (fx, _) in list(zip(roots, feet))[:2]:
            leg(rx, 0.62, (cx + fx * 0.6, belly + 56), (-30 if rx < 0 else 30, 24))
    bw, bh = body_img.width // 2, body_img.height // 2
    bx, by = int(cx - bw / 2), int(belly - bh + 14)
    body_small = body_img.resize((bw, bh), Image.LANCZOS)
    # a pretend player behind the cockpit window
    pl_ = Image.new("RGBA", (bw, bh), (0, 0, 0, 0))
    ImageDraw.Draw(pl_).ellipse([bx * 0 + 100, 36, 124, 62], fill=(236, 190, 150, 255))
    ImageDraw.Draw(pl_).rectangle([96, 58, 132, 90], fill=(70, 150, 200, 255))
    img.alpha_composite(pl_, (bx, by))
    img.alpha_composite(body_small, (bx, by))
    img.alpha_composite(parts["canopy"].resize((bw, bh), Image.LANCZOS), (bx, by))
    mt = parts["missile_turret"].resize((MTW // 2, MTH // 2), Image.LANCZOS)
    img.alpha_composite(mt, (int(bx + 76 - MT_PIVOT[0] / 2 + 22), int(by + 24 - MT_PIVOT[1] / 2)))
    lt = parts["laser_turret"].resize((LTW // 2, LTH // 2), Image.LANCZOS)
    img.alpha_composite(lt, (int(bx + 120 - LT_PIVOT[0] / 2), int(by + bh - 30 - LT_PIMOT_Y)))
    for leg_i in (1,):
        pass
    for rx, sh in roots[2:]:
        if pose == "stand":
            fx = {24: 74, 52: 118}[rx]
            leg(rx, 1.0, (cx + fx, ground - 2), (rx * 0.5, -30))
        else:
            leg(rx, 1.0, (cx + rx * 0.6, belly + 56), (30, 24))
    if pose == "jump":
        fl = parts["flame_1"].resize((32, 55), Image.LANCZOS)
        img.alpha_composite(fl, (int(cx - 16), int(belly + 4)))
    return img


LT_PIMOT_Y = LT_PIVOT[1] / 2


def tint(im, shade):
    if shade >= 1.0:
        return im
    r, g, b, a = im.split()
    mul = lambda ch: ch.point(lambda v: int(v * shade))
    return Image.merge("RGBA", (mul(r), mul(g), mul(b), a))


def main():
    os.makedirs(OUT, exist_ok=True)
    parts = {}
    for name, fn in (("body", draw_body), ("canopy", draw_canopy), ("missile_turret", draw_missile_turret), ("laser_turret", draw_laser_turret),
                     ("link", draw_link), ("joint", draw_joint), ("claw", draw_claw), ("hip", draw_hip)):
        parts[name] = finish(fn(), os.path.join(OUT, name + ".png"))
    for i in range(3):
        parts["flame_%d" % (i + 1)] = finish(draw_flame(i), os.path.join(OUT, "flame_%d.png" % (i + 1)))
    sheet = Image.new("RGBA", (920, 380), (0, 0, 0, 0))
    sheet.alpha_composite(preview(parts, "stand"), (0, 0))
    sheet.alpha_composite(preview(parts, "jump"), (460, 0))
    sheet.save(art_lib.preview_path("mech_preview.png"))
    print("done")


if __name__ == "__main__":
    main()
