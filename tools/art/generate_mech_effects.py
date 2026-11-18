"""Draws the mech's damage effects, its missile and the weapon effects. Run generate_mech.py first (this one draws on its body).

Usage (from the repo root; needs Pillow, numpy and opencv):
    python tools/art/generate_mech_effects.py       writes into assets/powerups/mech/

DAMAGE (the mech survives five hits; each one shows on the mech itself):
    body_cracks.png, canopy_cracks.png   hit 1: cracks across the cab, the engine block and the cockpit glass. They are drawn ON the
                                         body picture's own shape (clipped to it), so they are painted onto the mech, not floating.
    link_broken.png, spark.png           hit 2: a leg snaps: the last whole link has a jagged torn end with wires and a bent piston;
                                         the rest of the leg falls off (the game uses link.png, joint.png and claw.png for that)
    smoke_1..3.png                       hit 3: puffs of smoke from the exhaust stack and the engine
    fire_1..4.png, body_burn.png         hit 4: flames on the engine block and the cab roof, and a layer of soot over the body
    (hit 5: the mech explodes; the game throws its own parts about)
WEAPONS:
    missile.png, missile_flame_1..3.png, missile_glow.png   the missile (pointing right), its exhaust flame (pointing left, the picture's
                                                            right edge is the nozzle) and the glow round it
    laser_halo.png, laser_burst.png      the rings and the starburst at the laser's muzzle when it fires
Every picture is drawn at 4x and shrunk, like the others; the game shows them at half size (see MechVisual.TEX).
"""
import math
import os
import random
import sys

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import generate_mech as gm  # noqa: E402
import generate_boss_shaker as bs  # noqa: E402
from generate_boss_shaker import S, lit, outline, solid  # noqa: E402

OUT = gm.OUT
BW, BH = gm.BW, gm.BH
mk, P, pl, poly, rr, ell, vgrad = gm.mk, gm.P, gm.pl, gm.poly, gm.rr, gm.ell, gm.vgrad


def save(canvas, name):
    out = gm.finish(canvas, os.path.join(OUT, name))
    return out


def lines_mask(size, polylines, width):
    m = Image.new("L", (size[0] * S, size[1] * S), 0)
    d = ImageDraw.Draw(m)
    for pts in polylines:
        d.line([P(x, y) for x, y in pts], fill=255, width=max(1, int(width * S)), joint="curve")
        for x, y in (pts[0], pts[-1]):
            d.ellipse([P(x - width / 2, y - width / 2), P(x + width / 2, y + width / 2)], fill=255)
    return m


def jag(rnd, x, y, ang, length, step=8.0, jitter=0.6):
    pts = [(x, y)]
    for _ in range(max(2, int(length / step))):
        ang += rnd.uniform(-jitter, jitter)
        d = step * rnd.uniform(0.7, 1.3)
        x += math.cos(ang) * d
        y += math.sin(ang) * d
        pts.append((x, y))
    return pts


def crack_cluster(rnd, origin, mains, length, base_angle=0.0):
    out = []
    for k in range(mains):
        ang = base_angle + k * math.tau / mains + rnd.uniform(-0.3, 0.3)
        pts = jag(rnd, origin[0], origin[1], ang, length * rnd.uniform(0.7, 1.2))
        out.append(pts)
        i = len(pts) // 2
        out.append(jag(rnd, pts[i][0], pts[i][1], ang + rnd.choice([-1, 1]) * rnd.uniform(0.6, 1.0), length * 0.45, jitter=0.7))
    return out


# ----------------------------------------------------------------------------------------------------------------------
# hit 1: cracks
# ----------------------------------------------------------------------------------------------------------------------
def draw_cracks(body_alpha):
    rnd = random.Random(11)
    clusters = []
    clusters += crack_cluster(rnd, (206, 130), 5, 52, 0.4)     # the cab below the window
    clusters += crack_cluster(rnd, (62, 98), 4, 40, 1.0)       # the engine block
    clusters += crack_cluster(rnd, (232, 168), 3, 30, 3.4)     # the hull
    m = lines_mask((BW, BH), clusters, 2.2)
    dark = ImageChops.multiply(m, body_alpha)
    light = ImageChops.subtract(ImageChops.offset(m, int(1.3 * S), int(1.3 * S)), m)
    light = ImageChops.multiply(light, body_alpha)
    # chipped paint: small dark flakes beside the cracks
    flakes = Image.new("L", m.size, 0)
    fd = ImageDraw.Draw(flakes)
    for pts in clusters[::2]:
        for x, y in pts[1:4]:
            r = rnd.uniform(1.2, 2.6)
            fd.polygon([P(x + math.cos(a) * r * rnd.uniform(0.6, 1.4), y + math.sin(a) * r * rnd.uniform(0.6, 1.4)) for a in (0, 1.6, 3.1, 4.7)], fill=255)
    flakes = ImageChops.multiply(flakes, body_alpha)
    c = Image.new("RGBA", m.size, (0, 0, 0, 0))
    c.alpha_composite(solid(light, (255, 238, 180), 0.6))
    c.alpha_composite(solid(flakes, (60, 40, 16), 0.9))
    c.alpha_composite(solid(dark, (26, 18, 12), 0.95))
    return c


def draw_canopy_cracks():
    rnd = random.Random(5)
    win = poly(mk(BW, BH), gm.WINDOW)
    cx, cy = 222, 88
    rays = []
    for k in range(8):
        ang = k * math.tau / 8 + rnd.uniform(-0.25, 0.25)
        rays.append(jag(rnd, cx, cy, ang, rnd.uniform(34, 60), step=7, jitter=0.25))
    rings = []
    for r in (12, 24):
        pts = []
        for k in range(9):
            a = k * math.tau / 8 + rnd.uniform(-0.1, 0.1)
            pts.append((cx + math.cos(a) * r * rnd.uniform(0.85, 1.15), cy + math.sin(a) * r * rnd.uniform(0.85, 1.15)))
        rings.append(pts)
    m = ImageChops.multiply(lines_mask((BW, BH), rays + rings, 1.6), win)
    shadow = ImageChops.multiply(ImageChops.offset(m, int(1.2 * S), int(1.2 * S)), win)
    c = Image.new("RGBA", m.size, (0, 0, 0, 0))
    c.alpha_composite(solid(shadow, (8, 12, 20), 0.55))
    c.alpha_composite(solid(m, (236, 248, 255), 0.9))
    # a little white chip at the impact point
    c.alpha_composite(solid(ImageChops.multiply(ell(mk(BW, BH), cx, cy, 3.5), win), (255, 255, 255), 0.95))
    return c


# ----------------------------------------------------------------------------------------------------------------------
# hit 2: the broken leg
# ----------------------------------------------------------------------------------------------------------------------
BLW, BLH = 62, 46          # the broken link's picture (the link is 52 x 40: this one has room for the wires)


def draw_link_broken():
    c = Image.new("RGBA", (BLW * S, BLH * S), (0, 0, 0, 0))
    oy = (BLH - gm.LKH) / 2.0                       # the link sits in the middle of the taller picture
    shell = rr(mk(BLW, BLH), (1, oy + 4, gm.LKW - 1, oy + gm.LKH - 4), 13)
    cut = poly(mk(BLW, BLH), [(0, 0), (30, 0), (36, oy + 8), (30, oy + 14), (38, oy + 21), (31, oy + 28), (36, oy + 35), (33, BLH), (0, BLH)])
    shell = ImageChops.multiply(shell, cut)
    gm.part(c, shell, vgrad(oy + 4, oy + gm.LKH - 4, gm.YEL_L, gm.YEL_D), radius=3.0, bump=2.4, spec=0.55, outline_w=1.2)
    # the torn edge shows the dark inside
    edge = ImageChops.subtract(shell, shell.filter(ImageFilter.MinFilter(9 * S // 2 * 2 + 1)).filter(ImageFilter.MinFilter(3)))
    edge = ImageChops.multiply(edge, poly(mk(BLW, BLH), [(24, 0), (62, 0), (62, BLH), (24, BLH)]))
    c.alpha_composite(solid(edge, (46, 28, 12), 0.95))
    # the cylinder end and a bent piston sticking out of the break
    cyl = rr(mk(BLW, BLH), (4, oy + 13, 28, oy + gm.LKH - 13), 5)
    gm.part(c, cyl, vgrad(oy + 13, oy + gm.LKH - 13, (110, 118, 136), (44, 50, 64)), radius=1.2, bump=2.2, outline_w=0.8)
    rod = mk(BLW, BLH)
    gm.line(rod, (30, oy + 20), (42, oy + 17), 5)
    gm.line(rod, (42, oy + 17), (54, oy + 9), 5)
    gm.part(c, rod, vgrad(oy, oy + 40, (220, 228, 240), (110, 118, 136)), radius=0.8, bump=2.4, spec=0.9, outline_w=0.7)
    # wires: three coloured wires curling out of the break
    for col, pts in (((235, 60, 50), [(33, oy + 16), (42, oy + 24), (48, oy + 30), (46, oy + 38)]),
                     ((70, 150, 255), [(34, oy + 22), (44, oy + 28), (54, oy + 28), (56, oy + 36)]),
                     ((255, 210, 60), [(32, oy + 27), (40, oy + 33), (44, oy + 40), (38, oy + 44)])):
        wm = mk(BLW, BLH)
        d = ImageDraw.Draw(wm)
        d.line([P(x, y) for x, y in pts], fill=255, width=int(1.8 * S), joint="curve")
        c.alpha_composite(outline(wm, 0.7))
        c.alpha_composite(solid(wm, col))
    # a spark at the end of the piston
    sp = ell(mk(BLW, BLH), 54, oy + 9, 3.0)
    bs.glow(c, sp, (255, 220, 120), radii=(1.2, 3.5), strengths=(1.0, 0.6))
    c.alpha_composite(solid(sp, (255, 255, 230)))
    return c


def draw_spark():
    n = 32
    c = Image.new("RGBA", (n * S, n * S), (0, 0, 0, 0))
    m = mk(n, n)
    d = ImageDraw.Draw(m)
    cx = cy = n / 2
    for k in range(4):
        a = k * math.pi / 4
        for sign in (1, -1):
            pass
        d.polygon([P(cx + math.cos(a) * 15, cy + math.sin(a) * 15), P(cx + math.cos(a + 1.57) * 1.6, cy + math.sin(a + 1.57) * 1.6),
                   P(cx - math.cos(a) * 15, cy - math.sin(a) * 15), P(cx - math.cos(a + 1.57) * 1.6, cy - math.sin(a + 1.57) * 1.6)], fill=255)
    bs.glow(c, m, (255, 200, 80), radii=(1.0, 3.0), strengths=(1.0, 0.7))
    c.alpha_composite(solid(m, (255, 240, 190)))
    c.alpha_composite(solid(ell(mk(n, n), cx, cy, 3.4), (255, 255, 255)))
    return c


# ----------------------------------------------------------------------------------------------------------------------
# hit 3: smoke
# ----------------------------------------------------------------------------------------------------------------------
def draw_smoke(seed):
    n = 96
    rnd = random.Random(seed)
    m = mk(n, n)
    d = ImageDraw.Draw(m)
    for _ in range(7):
        a = rnd.uniform(0, math.tau)
        r = rnd.uniform(0, 14)
        rad = rnd.uniform(14, 22)
        d.ellipse([P(n / 2 + math.cos(a) * r - rad, n / 2 + math.sin(a) * r - rad), P(n / 2 + math.cos(a) * r + rad, n / 2 + math.sin(a) * r + rad)], fill=255)
    base = vgrad(10, 86, (196, 196, 206), (92, 94, 108))
    c = lit(m, base, radius=6.0, bump=1.5, spec=0.0, ambient=0.62)
    c.putalpha(m.filter(ImageFilter.GaussianBlur(4.5 * S)).point(lambda v: int(v * 0.62)))
    return c


# ----------------------------------------------------------------------------------------------------------------------
# hit 4: fire and soot
# ----------------------------------------------------------------------------------------------------------------------
FW_, FH_ = 80, 124          # a flame picture: pointing up, the base on the bottom edge in the middle


def tongue(cx, base_w, height, sway, lean=0.0, top=0):
    pts_l, pts_r = [], []
    steps = 24
    for k in range(steps + 1):
        t = k / steps
        y = FH_ - 4 - t * height
        w = base_w * (1 - t) ** 0.85 * (0.75 + 0.25 * math.cos(t * math.pi * 2.0))
        x = cx + sway * math.sin(t * math.pi * 1.5) * (0.4 + t) + lean * t * 8
        pts_l.append((x - w, y))
        pts_r.append((x + w, y))
    return pts_l + pts_r[::-1]


def draw_fire(variant):
    c = Image.new("RGBA", (FW_ * S, FH_ * S), (0, 0, 0, 0))
    specs = [
        [(40, 22, 104, 8, 0), (22, 12, 70, -7, -1), (58, 12, 78, 7, 1)],
        [(40, 22, 96, -9, 0), (24, 13, 80, 6, -1), (57, 11, 64, -6, 1)],
        [(40, 22, 110, 7, 0), (21, 11, 62, -5, -1), (59, 13, 84, 9, 1)],
        [(40, 22, 100, -7, 0), (23, 12, 74, 8, -1), (58, 12, 68, -8, 1)],
    ][variant]
    outer = mk(FW_, FH_)
    mid = mk(FW_, FH_)
    core = mk(FW_, FH_)
    for cx, bw, h, sw, ln in specs:
        poly(outer, tongue(cx, bw, h, sw, ln))
        poly(mid, tongue(cx, bw * 0.66, h * 0.72, sw * 0.8, ln))
        poly(core, tongue(cx, bw * 0.36, h * 0.42, sw * 0.5, ln))
    outer = outer.filter(ImageFilter.GaussianBlur(0.9 * S))
    mid = mid.filter(ImageFilter.GaussianBlur(0.8 * S))
    core = core.filter(ImageFilter.GaussianBlur(0.7 * S))
    bs.glow(c, outer, (255, 110, 30), radii=(3, 9), strengths=(0.65, 0.45))
    c.alpha_composite(solid(outer, (255, 96, 22), 0.96))
    c.alpha_composite(solid(mid, (255, 186, 52)))
    c.alpha_composite(solid(core, (255, 248, 210)))
    return c


def draw_burn(body_alpha):
    rnd = random.Random(3)
    m = mk(BW, BH)
    d = ImageDraw.Draw(m)
    for (x, y, r) in ((60, 64, 34), (104, 66, 26), (38, 118, 24), (212, 50, 24), (258, 102, 20), (150, 146, 22), (92, 138, 20)):
        d.ellipse([P(x - r, y - r * 0.8), P(x + r, y + r * 0.8)], fill=int(rnd.uniform(220, 255)))
    # scorch streaks rising from the vents
    for x in (36, 62, 90):
        d.rectangle([P(x - 4, 60), P(x + 4, 120)], fill=120)
    m = m.filter(ImageFilter.GaussianBlur(5 * S)).point(lambda v: min(255, int(v * 1.5)))
    m = ImageChops.multiply(m, body_alpha)
    c = Image.new("RGBA", m.size, (0, 0, 0, 0))
    c.alpha_composite(solid(m, (14, 10, 8), 0.86))
    return c


# ----------------------------------------------------------------------------------------------------------------------
# the missile
# ----------------------------------------------------------------------------------------------------------------------
MW, MH = 132, 48


def draw_missile():
    c = Image.new("RGBA", (MW * S, MH * S), (0, 0, 0, 0))
    cy = MH / 2
    # fins at the tail (the far ones darker, drawn first), then canards near the nose
    for pts_, col in (([(32, cy - 9), (58, cy - 9), (46, 1), (24, 3)], (150, 156, 172)), ([(32, cy + 9), (58, cy + 9), (46, MH - 1), (24, MH - 3)], (150, 156, 172))):
        gm.part(c, poly(mk(MW, MH), pts_), vgrad(0, MH, (190, 196, 210), (110, 116, 134)), radius=1.0, bump=2.0, outline_w=0.9)
    for pts_ in ([(92, cy - 9), (104, cy - 9), (99, cy - 15)], [(92, cy + 9), (104, cy + 9), (99, cy + 15)]):
        gm.part(c, poly(mk(MW, MH), pts_), (170, 176, 190), radius=0.7, bump=1.6, outline_w=0.7)
    # the body: a long cylinder, lit from above
    body = rr(mk(MW, MH), (22, cy - 10, 104, cy + 10), 8)
    gm.part(c, body, vgrad(cy - 10, cy + 10, (252, 253, 255), (138, 146, 166)), radius=2.4, bump=2.2, spec=0.85, outline_w=1.0)
    # the red nose cone with a dark seeker tip
    cone = poly(mk(MW, MH), [(100, cy - 10), (128, cy), (100, cy + 10)])
    cone = cone.filter(ImageFilter.GaussianBlur(1.4 * S)).point(lambda v: 255 if v > 128 else 0)
    gm.part(c, cone, vgrad(cy - 10, cy + 10, (255, 120, 96), (160, 22, 20)), radius=2.0, bump=2.2, spec=0.8, outline_w=1.0)
    tip = ImageChops.multiply(ell(mk(MW, MH), 124, cy, 5, 5), cone)
    c.alpha_composite(solid(tip, (36, 38, 48)))
    # bands, stencil lines and panel seams
    for x0, x1, col in ((44, 52, gm.YEL), (84, 88, gm.YEL), (60, 62, (40, 44, 56)), (72, 73.4, (40, 44, 56))):
        band = ImageChops.multiply(rr(mk(MW, MH), (x0, cy - 10, x1, cy + 10), 0.5), body)
        c.alpha_composite(solid(band, col, 0.95))
    for x in (34, 96):
        c.alpha_composite(solid(ImageChops.multiply(rr(mk(MW, MH), (x, cy - 10, x + 1.2, cy + 10), 0), body), (90, 98, 118), 0.8))
    for bx in (38, 66, 78):
        gm.part(c, ell(mk(MW, MH), bx, cy - 6, 1.1), (130, 138, 156), outline_w=0.3, radius=0.4, bump=2.0, spec=0.7)
    # a small black "danger" stripe pattern near the tail
    zig = ImageChops.multiply(gm.stripes(MW, MH, 5, 2.4, 1.0), ImageChops.multiply(rr(mk(MW, MH), (24, cy - 10, 32, cy + 10), 0), body))
    c.alpha_composite(solid(zig, (40, 44, 56), 0.9))
    # the nozzle: a dark bell with a hot glow inside
    bell = poly(mk(MW, MH), [(22, cy - 8), (14, cy - 11), (14, cy + 11), (22, cy + 8)])
    gm.part(c, bell, vgrad(cy - 11, cy + 11, (84, 90, 106), (30, 34, 44)), radius=1.0, bump=2.2, outline_w=0.9)
    glow_m = ell(mk(MW, MH), 14.5, cy, 3.0, 7.5)
    bs.glow(c, glow_m, (255, 150, 50), radii=(1.2, 3.5), strengths=(1.0, 0.6))
    c.alpha_composite(solid(glow_m, (255, 226, 160)))
    return c


FLW, FLH = 170, 52


def draw_missile_flame(variant):
    c = Image.new("RGBA", (FLW * S, FLH * S), (0, 0, 0, 0))
    cy = FLH / 2
    length = (150, 128, 160)[variant]
    wid = (15, 17, 13)[variant]

    def drop(sl, sw):
        top, bot = [], []
        for k in range(0, 25):
            t = k / 24.0
            x = FLW - 2 - t * length * sl
            w = (1 - t) ** 0.9 * wid * sw * (0.5 + 0.5 * math.sin(min(1.0, t * 5) * math.pi / 2))
            wob = math.sin(t * 9 + variant * 2.0) * 1.4 * t
            top.append((x, cy - w + wob))
            bot.append((x, cy + w + wob))
        return poly(mk(FLW, FLH), top + bot[::-1])
    outer = drop(1.0, 1.0).filter(ImageFilter.GaussianBlur(1.3 * S))
    mid = drop(0.72, 0.66).filter(ImageFilter.GaussianBlur(1.0 * S))
    core = drop(0.42, 0.36).filter(ImageFilter.GaussianBlur(0.8 * S))
    bs.glow(c, outer, (255, 110, 30), radii=(3, 9), strengths=(0.7, 0.45))
    c.alpha_composite(solid(outer, (255, 96, 24), 0.95))
    c.alpha_composite(solid(mid, (255, 196, 70)))
    c.alpha_composite(solid(core, (255, 250, 225)))
    # shock diamonds along the core
    diamonds = mk(FLW, FLH)
    dd = ImageDraw.Draw(diamonds)
    for k in range(3):
        x = FLW - 18 - k * 20 - variant * 3
        dd.polygon([P(x, cy), P(x - 7, cy - 3.2), P(x - 14, cy), P(x - 7, cy + 3.2)], fill=255)
    c.alpha_composite(solid(diamonds.filter(ImageFilter.GaussianBlur(0.4 * S)), (255, 255, 240), 0.9))
    return c


def draw_glow(size, color):
    yy, xx = np.mgrid[0:size * S, 0:size * S].astype(np.float32)
    d = np.sqrt((xx / S - size / 2) ** 2 + (yy / S - size / 2) ** 2) / (size / 2)
    a = np.clip(1.0 - d, 0, 1) ** 1.5
    out = np.zeros((size * S, size * S, 4), np.uint8)
    out[..., 0], out[..., 1], out[..., 2] = color
    out[..., 3] = np.clip(a * 255, 0, 255).astype(np.uint8)
    return Image.fromarray(out, "RGBA")


# ----------------------------------------------------------------------------------------------------------------------
# the laser's muzzle effects
# ----------------------------------------------------------------------------------------------------------------------
BLUE = (70, 150, 255)
BLUE_L = (190, 224, 255)


def draw_halo():
    n = 192
    c = Image.new("RGBA", (n * S, n * S), (0, 0, 0, 0))
    for r, w, a in ((26, 5, 1.0), (48, 4, 0.75), (70, 3, 0.5), (88, 2, 0.3)):
        ring = mk(n, n)
        ImageDraw.Draw(ring).ellipse([P(n / 2 - r, n / 2 - r), P(n / 2 + r, n / 2 + r)], outline=255, width=int(w * S))
        bs.glow(c, ring, BLUE, radii=(1.0, 3.5, 8), strengths=(0.9 * a, 0.6 * a, 0.35 * a))
        c.alpha_composite(solid(ring, BLUE_L, a))
    core = ell(mk(n, n), n / 2, n / 2, 12)
    bs.glow(c, core, BLUE, radii=(3, 9, 18), strengths=(1.0, 0.7, 0.5))
    c.alpha_composite(solid(core, (235, 245, 255), 0.9))
    return c


def draw_burst():
    n = 160
    c = Image.new("RGBA", (n * S, n * S), (0, 0, 0, 0))
    m = mk(n, n)
    d = ImageDraw.Draw(m)
    for k in range(8):
        a = k * math.pi / 4 + 0.2
        ln = 76 if k % 2 == 0 else 46
        d.polygon([P(n / 2 + math.cos(a) * ln, n / 2 + math.sin(a) * ln), P(n / 2 + math.cos(a + 1.57) * 3.6, n / 2 + math.sin(a + 1.57) * 3.6),
                   P(n / 2 - math.cos(a) * ln, n / 2 - math.sin(a) * ln), P(n / 2 - math.cos(a + 1.57) * 3.6, n / 2 - math.sin(a + 1.57) * 3.6)], fill=255)
    bs.glow(c, m, BLUE, radii=(1.5, 4, 10), strengths=(0.9, 0.6, 0.4))
    c.alpha_composite(solid(m, BLUE_L, 0.95))
    core = ell(mk(n, n), n / 2, n / 2, 9)
    bs.glow(c, core, BLUE, radii=(3, 8), strengths=(1.0, 0.7))
    c.alpha_composite(solid(core, (255, 255, 255)))
    return c


def main():
    body = gm.draw_body()
    alpha = body.getchannel("A")
    save(draw_cracks(alpha), "body_cracks.png")
    save(draw_canopy_cracks(), "canopy_cracks.png")
    save(draw_link_broken(), "link_broken.png")
    save(draw_spark(), "spark.png")
    for i in range(3):
        save(draw_smoke(20 + i), "smoke_%d.png" % (i + 1))
    for i in range(4):
        save(draw_fire(i), "fire_%d.png" % (i + 1))
    save(draw_burn(alpha), "body_burn.png")
    save(draw_missile(), "missile.png")
    for i in range(3):
        save(draw_missile_flame(i), "missile_flame_%d.png" % (i + 1))
    save(draw_glow(96, (255, 150, 60)), "missile_glow.png")
    save(draw_halo(), "laser_halo.png")
    save(draw_burst(), "laser_burst.png")
    print("done")


if __name__ == "__main__":
    main()
