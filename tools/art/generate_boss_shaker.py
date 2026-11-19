"""Draws the first boss: a glass salt shaker with a glowing angry face, its belly full of stolen data-center hardware.

Usage (from the repo root; needs Pillow and numpy):
    python tools/art/generate_boss_shaker.py          writes the boss layers and what he sprays into assets/bosses/ (and a picture of him whole into tmp/art_previews/)

HOW IT IS DRAWN (so the detail is real shading, not flat shapes stacked up): everything is rendered at 4x and shrunk with a
high-quality filter. Each part is a mask; `lit()` turns a mask into a bevelled, lit surface (it blurs the mask into a height map,
takes its slope as a surface normal and lights it from the upper left, with a specular glint), so metal, circuit boards and plastic
all get rounded edges and highlights. The glass is the hardware pile seen through a tinted, reflective shell; the face is bloom
(a blurred copy added back on top) so it really glows. Change SEED or the PILE list to get another arrangement of hardware.
"""
import math
import os
import random

import cv2
import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter

from art_lib import (INK, LIGHT, ROOT, S, arr, blur, glow, gradient_x, gradient_y, lit, outline, paste, poly_mask, preview_path, rrect_mask, s, solid, to_img)

OUT = os.path.join(ROOT, "assets", "bosses")

W, H = 600, 830            # the drawing canvas in pixels
TRIM = 36                  # rows cut off the top at the end (the final picture is W x (H - TRIM))
SEED = 7


def new_mask(size=None):
    return Image.new("L", size or (W * S, H * S), 0)


# ----------------------------------------------------------------------------------------------------------------------
# hardware pieces: each returns an RGBA image (4x) with a dark outline, ready to rotate and paste into the pile
# ----------------------------------------------------------------------------------------------------------------------
def finish(img, width=2.2):
    """Add the ink outline around an RGBA piece and pad it."""
    pad = s(8)
    canvas = Image.new("RGBA", (img.width + 2 * pad, img.height + 2 * pad), (0, 0, 0, 0))
    canvas.alpha_composite(img, (pad, pad))
    a = canvas.getchannel("A")
    ring = outline(a, width)
    out = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    out.alpha_composite(ring)
    out.alpha_composite(canvas)
    return out


def ram_stick(w=168, h=46, seed=0):
    rnd = random.Random(seed)
    size = (s(w), s(h))
    body = rrect_mask(size, (0, 0, size[0] - 1, size[1] - s(7)), s(3))
    img = lit(body, gradient_y(0, h, [(0, (60, 160, 90)), (1, (28, 110, 60))]), radius=2.2, bump=1.2)
    d = ImageDraw.Draw(img)
    # chips
    n = 4
    cw = (w - 28) / n
    for i in range(n):
        x0 = 14 + i * cw
        chip = rrect_mask(size, (s(x0), s(8), s(x0 + cw - 6), s(h - 20)), s(2))
        paste(img, lit(chip, (34, 36, 42), radius=1.6, bump=1.6, spec=0.5))
        # pin dots on chip edge
        for j in range(5):
            d.ellipse([s(x0 + 3 + j * (cw - 12) / 4), s(h - 17.5), s(x0 + 5 + j * (cw - 12) / 4), s(h - 15.5)], fill=(150, 150, 120, 255))
    # silver label
    lab = rrect_mask(size, (s(w - 40), s(h - 18), s(w - 14), s(h - 10)), s(1.5))
    paste(img, lit(lab, (205, 208, 214), radius=1.2, bump=1.0))
    # gold fingers with a notch
    for i in range(int((w - 8) / 6)):
        x = 4 + i * 6
        if abs(x - w * 0.62) < 4:
            continue
        d.rectangle([s(x), s(h - 8), s(x + 4), s(h - 1)], fill=(238, 192, 70, 255))
        d.rectangle([s(x), s(h - 8), s(x + 1.2), s(h - 1)], fill=(255, 232, 140, 255))
    # silk screen dots
    for _ in range(6):
        x, y = rnd.uniform(8, w - 10), rnd.uniform(h - 24, h - 20)
        d.ellipse([s(x), s(y), s(x + 2), s(y + 2)], fill=(225, 235, 220, 255))
    return finish(img)


def gpu(w=230, h=98):
    size = (s(w), s(h))
    body = rrect_mask(size, (s(10), 0, s(w - 2), s(h - 10)), s(9))
    img = lit(body, gradient_y(0, h, [(0, (96, 100, 112)), (1, (52, 55, 64))]), radius=5, bump=1.6, spec=0.5)
    d = ImageDraw.Draw(img)
    # silver bracket
    br = rrect_mask(size, (0, s(2), s(14), s(h - 4)), s(3))
    paste(img, lit(br, (190, 194, 202), radius=2, bump=1.3))
    # accent stripes
    for k in range(3):
        d.line([s(w - 44), s(10 + k * 7), s(w - 12), s(2 + k * 7)], fill=(30, 32, 38, 255), width=s(2.2))
    # two fans
    for cx in (w * 0.31, w * 0.69):
        cy = (h - 10) / 2.0
        R = 36
        ring = Image.new("L", size, 0)
        ImageDraw.Draw(ring).ellipse([s(cx - R), s(cy - R), s(cx + R), s(cy + R)], fill=255)
        paste(img, lit(ring, (24, 26, 32), radius=3, bump=1.8, spec=0.2))
        blades = Image.new("L", size, 0)
        bd = ImageDraw.Draw(blades)
        for b in range(9):
            a0 = b * TAU9 + 0.2
            pts = []
            for t in np.linspace(0, 1, 9):
                r = 8 + 25 * t
                ang = a0 + 0.9 * t
                pts.append((cx + math.cos(ang) * r, cy + math.sin(ang) * r))
            for t in np.linspace(1, 0, 9):
                r = 8 + 25 * t
                ang = a0 + 0.9 * t + 0.42 * (0.4 + 0.6 * math.sin(t * math.pi))
                pts.append((cx + math.cos(ang) * r, cy + math.sin(ang) * r))
            bd.polygon([(s(x), s(y)) for x, y in pts], fill=255)
        paste(img, lit(blades, gradient_y(cy - 30, cy + 30, [(0, (190, 194, 204)), (1, (110, 114, 126))]), radius=1.8, bump=1.8))
        paste(img, outline(blades, 0.5, (30, 30, 38)))
        hub = Image.new("L", size, 0)
        ImageDraw.Draw(hub).ellipse([s(cx - 8), s(cy - 8), s(cx + 8), s(cy + 8)], fill=255)
        paste(img, lit(hub, (70, 74, 86), radius=3, bump=2.0, spec=0.6))
        d.ellipse([s(cx - 2.5), s(cy - 2.5), s(cx + 2.5), s(cy + 2.5)], fill=(18, 18, 22, 255))
    # gold PCIe edge
    for i in range(int(w * 0.5 / 4)):
        x = w * 0.3 + i * 4
        d.rectangle([s(x), s(h - 9), s(x + 2.6), s(h - 2)], fill=(238, 192, 70, 255))
    return finish(img)


TAU9 = math.tau / 9.0


def psu(w=124, h=112):
    size = (s(w), s(h))
    body = rrect_mask(size, (0, 0, size[0] - 1, size[1] - 1), s(8))
    img = lit(body, gradient_y(0, h, [(0, (150, 153, 162)), (1, (92, 95, 106))]), radius=5, bump=1.8, spec=0.5)
    d = ImageDraw.Draw(img)
    # fan grille: recessed disc, concentric rings and spokes
    cx, cy, R = 46, h / 2, 40
    well = Image.new("L", size, 0)
    ImageDraw.Draw(well).ellipse([s(cx - R), s(cy - R), s(cx + R), s(cy + R)], fill=255)
    paste(img, solid(well, (34, 36, 44)))
    for r in (36, 28, 20, 12):
        d.ellipse([s(cx - r), s(cy - r), s(cx + r), s(cy + r)], outline=(150, 154, 166, 255), width=s(1.8))
    for a in range(12):
        ang = a * math.tau / 12 + 0.1
        d.line([s(cx + math.cos(ang) * 5), s(cy + math.sin(ang) * 5), s(cx + math.cos(ang) * 38), s(cy + math.sin(ang) * 38)],
               fill=(150, 154, 166, 255), width=s(1.6))
    hub = Image.new("L", size, 0)
    ImageDraw.Draw(hub).ellipse([s(cx - 7), s(cy - 7), s(cx + 7), s(cy + 7)], fill=255)
    paste(img, lit(hub, (210, 214, 222), radius=2.5, bump=2.0, spec=0.7))
    paste(img, outline(well, 1.4, (60, 62, 72)))
    # side panel with the bolt
    pan = rrect_mask(size, (s(w - 34), s(10), s(w - 6), s(h - 10)), s(4))
    paste(img, lit(pan, (70, 74, 86), radius=2.4, bump=1.5))
    bolt = [(w - 14, 22), (w - 28, 52), (w - 19, 52), (w - 26, 86), (w - 8, 44), (w - 18, 44), (w - 11, 22)]
    bm = poly_mask([(s(x), s(y)) for x, y in bolt], size)
    paste(img, lit(bm, (255, 196, 40), radius=1.6, bump=1.6, spec=0.6))
    # screws
    for x, y in ((8, 8), (w - 8, 8), (8, h - 8), (w - 8, h - 8)):
        d.ellipse([s(x - 3), s(y - 3), s(x + 3), s(y + 3)], fill=(60, 62, 72, 255))
        d.line([s(x - 2), s(y), s(x + 2), s(y)], fill=(170, 174, 184, 255), width=s(1))
    return finish(img)


def cpu(w=96):
    size = (s(w), s(w))
    sub = rrect_mask(size, (0, 0, size[0] - 1, size[1] - 1), s(8))
    img = lit(sub, gradient_y(0, w, [(0, (52, 150, 84)), (1, (24, 100, 56))]), radius=4, bump=1.4)
    d = ImageDraw.Draw(img)
    for i in range(9):
        t = 9 + i * (w - 18) / 8
        for (x, y) in ((t, 4.5), (t, w - 4.5), (4.5, t), (w - 4.5, t)):
            d.ellipse([s(x - 2), s(y - 2), s(x + 2), s(y + 2)], fill=(240, 196, 74, 255))
            d.ellipse([s(x - 1.4), s(y - 1.4), s(x), s(y)], fill=(255, 236, 150, 255))
    ihs = rrect_mask(size, (s(14), s(14), s(w - 14), s(w - 14)), s(5))
    paste(img, lit(ihs, gradient_x(14, w - 14, [(0, (232, 235, 242)), (0.5, (176, 180, 190)), (1, (130, 134, 146))]), radius=3, bump=1.8, spec=0.6))
    paste(img, outline(ihs, 0.9, (90, 94, 106)))
    d.line([s(24), s(w - 26), s(w - 40), s(w - 26)], fill=(120, 124, 136, 255), width=s(1.4))
    d.line([s(24), s(w - 21), s(w - 54), s(w - 21)], fill=(120, 124, 136, 255), width=s(1.4))
    d.polygon([(s(w - 24), s(20)), (s(w - 20), s(20)), (s(w - 20), s(24))], fill=(120, 124, 136, 255))
    return finish(img)


def chipset(w=80):
    """A square chip with pins on all four sides (a "chipset"): a dark package, silver pins, a die window and silk-screen marks."""
    size = (s(w), s(w))
    img = Image.new("RGBA", size, (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    n = 9
    pitch = (w - 24) / (n - 1)
    for i in range(n):
        t = 12 + i * pitch
        for (x0, y0, x1, y1) in ((t - 1.6, 0, t + 1.6, 11), (t - 1.6, w - 11, t + 1.6, w), (0, t - 1.6, 11, t + 1.6), (w - 11, t - 1.6, w, t + 1.6)):
            d.rectangle([s(x0), s(y0), s(x1), s(y1)], fill=(196, 200, 210, 255))
            d.rectangle([s(x0), s(y0), s(x0 + 1.0), s(y1)], fill=(244, 246, 250, 255))
    pkg = rrect_mask(size, (s(8), s(8), s(w - 8), s(w - 8)), s(5))
    paste(img, lit(pkg, gradient_y(8, w - 8, [(0, (62, 66, 80)), (1, (30, 32, 40))]), radius=3, bump=1.8, spec=0.5))
    paste(img, outline(pkg, 0.8, (14, 14, 20)))
    die = rrect_mask(size, (s(w * 0.3), s(w * 0.3), s(w * 0.7), s(w * 0.7)), s(3))
    paste(img, lit(die, (96, 104, 130), radius=2, bump=1.4, spec=0.6))
    d.ellipse([s(15), s(15), s(20), s(20)], fill=(210, 214, 224, 255))               # pin-1 dot
    d.line([s(w * 0.3), s(w - 18), s(w * 0.62), s(w - 18)], fill=(150, 156, 170, 255), width=s(1.3))
    d.line([s(w * 0.3), s(w - 14), s(w * 0.5), s(w - 14)], fill=(150, 156, 170, 255), width=s(1.3))
    return finish(img, 1.6)


def rack(w=138, h=104):
    size = (s(w), s(h))
    img = Image.new("RGBA", size, (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    unit_h = (h - 6) / 3.0
    for i in range(3):
        y0 = 3 + i * unit_h
        m = rrect_mask(size, (s(2), s(y0), s(w - 3), s(y0 + unit_h - 3)), s(4))
        paste(img, lit(m, gradient_y(y0, y0 + unit_h, [(0, (74, 78, 90)), (1, (34, 36, 44))]), radius=2.6, bump=1.5, spec=0.45))
        paste(img, outline(m, 0.9, (20, 20, 26)))
        # vent slots
        for k in range(9):
            x = 12 + k * 6
            d.rectangle([s(x), s(y0 + 6), s(x + 2.5), s(y0 + unit_h - 10)], fill=(16, 17, 22, 255))
        # handles / drive bay
        d.rectangle([s(w - 52), s(y0 + 6), s(w - 30), s(y0 + unit_h - 10)], fill=(22, 24, 30, 255), outline=(110, 114, 126, 255), width=s(0.8))
        # LEDs
        for k in range(3):
            c = (90, 255, 130, 255) if k != 2 else (255, 190, 70, 255)
            lx = w - 22 + k * 6
            d.ellipse([s(lx - 2), s(y0 + unit_h / 2 - 3), s(lx + 2), s(y0 + unit_h / 2 + 1)], fill=c)
            d.ellipse([s(lx - 0.9), s(y0 + unit_h / 2 - 2.2), s(lx + 0.2), s(y0 + unit_h / 2 - 1.1)], fill=(235, 255, 240, 255))
    ledmask = Image.new("L", size, 0)
    ld = ImageDraw.Draw(ledmask)
    for i in range(3):
        y0 = 3 + i * unit_h
        for k in range(3):
            lx = w - 22 + k * 6
            ld.ellipse([s(lx - 2.4), s(y0 + unit_h / 2 - 3.4), s(lx + 2.4), s(y0 + unit_h / 2 + 1.4)], fill=255)
    glow(img, ledmask, (90, 255, 140), radii=(1.2, 3.5), strengths=(0.5, 0.35))
    return finish(img, 1.6)


def heatsink(w=118, h=176):
    size = (s(w), s(h))
    img = Image.new("RGBA", size, (0, 0, 0, 0))
    n = 12
    fw = (w - 12) / n
    for i in range(n):
        x0 = 6 + i * fw
        m = rrect_mask(size, (s(x0 + 0.6), s(6), s(x0 + fw - 1.6), s(h - 30)), s(1.5))
        paste(img, lit(m, gradient_x(x0, x0 + fw, [(0, (176, 180, 192)), (0.5, (120, 124, 136)), (1, (70, 74, 86))]), radius=1.3, bump=1.2, spec=0.5))
    base = rrect_mask(size, (s(0), s(h - 34), s(w - 1), s(h - 1)), s(5))
    paste(img, lit(base, gradient_y(h - 34, h, [(0, (150, 154, 164)), (1, (86, 90, 102))]), radius=3, bump=1.8, spec=0.6))
    d = ImageDraw.Draw(img)
    for x in (12, w - 12):
        d.ellipse([s(x - 3.5), s(h - 22), s(x + 3.5), s(h - 15)], fill=(50, 52, 62, 255))
        d.ellipse([s(x - 1.8), s(h - 20.6), s(x + 1.8), s(h - 16.4)], fill=(190, 194, 204, 255))
    return finish(img, 1.8)


def cable(points, color=(224, 128, 36), width=11):
    """An orange cable along the polyline `points` (final px, whole-canvas coordinates) as an RGBA layer."""
    size = (W * S, H * S)
    m = new_mask(size)
    d = ImageDraw.Draw(m)
    pts = [(s(x), s(y)) for x, y in points]
    d.line(pts, fill=255, width=s(width), joint="curve")
    for p in (pts[0], pts[-1]):
        d.ellipse([p[0] - s(width / 2), p[1] - s(width / 2), p[0] + s(width / 2), p[1] + s(width / 2)], fill=255)
    out = Image.new("RGBA", size, (0, 0, 0, 0))
    out.alpha_composite(outline(m, 1.7, (80, 40, 14)))
    out.alpha_composite(lit(m, color, radius=width / 2.0 - 0.5, bump=2.4, spec=0.5, ambient=0.5))
    return out


def bezier(p0, p1, p2, p3, n=40):
    pts = []
    for i in range(n + 1):
        t = i / n
        a = (1 - t) ** 3
        b = 3 * (1 - t) ** 2 * t
        c = 3 * (1 - t) * t * t
        d = t ** 3
        pts.append((a * p0[0] + b * p1[0] + c * p2[0] + d * p3[0], a * p0[1] + b * p1[1] + c * p2[1] + d * p3[1]))
    return pts


def place(canvas, piece, cx, cy, angle, clip=None):
    """Rotate `piece` by `angle` degrees and paste it with its centre at (cx, cy) (final px)."""
    rot = piece.rotate(-angle, resample=Image.BICUBIC, expand=True)
    x, y = s(cx) - rot.width // 2, s(cy) - rot.height // 2
    layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    sx, sy = max(0, -x), max(0, -y)
    crop = rot.crop((sx, sy, rot.width, rot.height))
    layer.alpha_composite(crop, (x + sx, y + sy))
    paste(canvas, layer, clip)


# ----------------------------------------------------------------------------------------------------------------------
# the shaker
# ----------------------------------------------------------------------------------------------------------------------
CX = 300
# HOLES: the cap holes, (x offset from the centre, row) in canvas pixels.
HOLES = [(-95, 129), (-56, 108), (2, 104), (58, 108), (97, 129), (-34, 141), (37, 141)]
K = 0.83                   # reference picture pixels -> final pixels
BODY_TOP, BODY_BOTTOM = 286, 746
BASE_HW = 262


def Y(ref_y):
    """Final row of a row of the reference picture (the shaker's top is at ref row 71)."""
    return 70.0 + (ref_y - 71.0) * K


def hw_ref(ry):
    """Half the shaker's width (in reference-picture pixels) at reference row `ry`, measured from the reference silhouette:
    a flat-topped dome, a plain neck band, a round collar bulge, a body whose sides run straight and widen, and a very round base."""
    if ry < 71 or ry > 885:
        return 0.0
    if ry <= 205:
        u = (205.0 - ry) / 134.0
        return 217.5 * math.sqrt(max(1.0 - u ** 2.4, 0.0))
    if ry <= 254:
        return 217.5 - 23.0 * ((ry - 205.0) / 49.0) ** 2
    if ry <= 274:
        return 194.5
    if ry <= 331:
        return 194.0 + 12.5 * math.sin(math.pi * (ry - 274.0) / 57.0)
    if ry <= 745:
        return min(194.0 + (ry - 331.0) * 0.3035, 315.5)
    v = (ry - 745.0) / 140.0
    return 315.5 * math.sqrt(max(1.0 - v ** 2.8, 0.0))


def half_width(y):
    """Half the glass body's width at final row y."""
    if y < BODY_TOP or y > BODY_BOTTOM:
        return 0.0
    return hw_ref(71.0 + (y - 70.0) / K) * K


def profile_mask(size, ref_a, ref_b):
    """The part of the shaker's silhouette between two reference rows."""
    m = Image.new("L", size, 0)
    left, right = [], []
    for ry in np.arange(ref_a, ref_b + 0.25, 0.25):
        hw = hw_ref(float(ry)) * K
        left.append((s(CX - hw), s(Y(ry))))
        right.append((s(CX + hw), s(Y(ry))))
    ImageDraw.Draw(m).polygon(left + right[::-1], fill=255)
    return m


def body_mask():
    m = new_mask()
    d = ImageDraw.Draw(m)
    left, right = [], []
    for yy in np.arange(BODY_TOP, BODY_BOTTOM + 0.25, 0.25):
        hw = half_width(float(yy))
        left.append((s(CX - hw), s(yy)))
        right.append((s(CX + hw), s(yy)))
    d.polygon(left + right[::-1], fill=255)
    return m


EXPRESSIONS = ["idle", "charge", "attack", "hurt", "dead"]
# the glow, the body and the white-hot core colour of each expression, and how strong its glow is
FACE_COLORS = {
    "idle": ((60, 200, 255), (150, 236, 255), (245, 254, 255), 1.0),
    "charge": ((255, 150, 40), (255, 200, 120), (255, 246, 220), 1.1),
    "attack": ((255, 60, 50), (255, 140, 110), (255, 232, 222), 1.25),
    "hurt": ((120, 220, 255), (210, 245, 255), (255, 255, 255), 1.0),
    "dead": ((90, 110, 130), (140, 156, 172), (180, 192, 205), 0.35),
}
EYE_Y = 392
MOUTH_Y = 474


def tint_layer(layer, color, amount):
    """Blend the colours of an RGBA layer towards `color` by `amount` (the transparency stays)."""
    a = np.asarray(layer, dtype=np.float32).copy()
    a[..., :3] = a[..., :3] * (1.0 - amount) + np.array(color, np.float32) * amount
    return Image.fromarray(a.astype(np.uint8), "RGBA")


def _slab(fd, sign, cx, slant, thick_base, thick_gain, span=124.0, bulge=8.0):
    """An angry eye: a thick curved stroke, high on the outside and low towards the middle, with round ends."""
    top_edge, bot_edge = [], []
    for i in range(25):
        u = i / 24.0
        x = cx + sign * span / 2.0 - sign * span * u
        y = EYE_Y - slant / 2.0 + slant * u + bulge * math.sin(u * math.pi)
        top_edge.append((x, y))
        thick = thick_base + thick_gain * math.sin(min(u + 0.1, 1.0) * math.pi * 0.85)
        bot_edge.append((x, y + thick))
    fd.polygon([(s(x), s(y)) for x, y in top_edge + bot_edge[::-1]], fill=255)
    for (x, y) in (top_edge[0], top_edge[24]):
        fd.ellipse([s(x - thick_base / 2.0), s(y - 2), s(x + thick_base / 2.0), s(y + thick_base)], fill=255)
    return top_edge


def _stroke(fd, pts, width):
    """A thick polyline with round ends and joints."""
    sp = [(s(x), s(y)) for x, y in pts]
    fd.line(sp, fill=255, width=s(width), joint="curve")
    for (x, y) in sp:
        fd.ellipse([x - s(width / 2.0), y - s(width / 2.0), x + s(width / 2.0), y + s(width / 2.0)], fill=255)


def make_face(expr, full, inner):
    """The glowing eyes and mouth of one expression, as an RGBA layer (bloom included), ready to be placed over the glass back."""
    glow_c, body_c, core_c, power = FACE_COLORS[expr]
    face = Image.new("L", full, 0)
    fd = ImageDraw.Draw(face)
    pupils = Image.new("L", full, 0)
    pd = ImageDraw.Draw(pupils)
    my = MOUTH_Y + (14 if expr == "attack" else 0)
    for sign in (-1, 1):
        cx = CX + sign * 90
        if expr == "idle":                       # a hard glare: heavy, steeply slanted brows
            _slab(fd, sign, cx, 56.0, 18.0, 28.0)
        elif expr == "charge":                   # narrowed to burning slits, leaning in
            _slab(fd, sign, cx, 76.0, 9.0, 14.0, span=136.0, bulge=4.0)
        elif expr == "attack":                   # wide open and furious, with slit pupils
            _slab(fd, sign, cx, 40.0, 22.0, 24.0, span=128.0, bulge=6.0)
            pd.ellipse([s(cx - sign * 18 - 6), s(EYE_Y - 2), s(cx - sign * 18 + 6), s(EYE_Y + 32)], fill=255)
        elif expr == "hurt":                     # screwed-up chevrons: > <
            _stroke(fd, [(cx - sign * 34, EYE_Y - 26), (cx + sign * 22, EYE_Y + 4), (cx - sign * 34, EYE_Y + 34)], 13.0)
        else:                                    # dead: X eyes
            _stroke(fd, [(cx - 30, EYE_Y - 24), (cx + 30, EYE_Y + 30)], 12.0)
            _stroke(fd, [(cx + 30, EYE_Y - 24), (cx - 30, EYE_Y + 30)], 12.0)
    # the mouth
    if expr == "idle":                           # a scowl with two fangs
        _stroke(fd, [(CX + x, my + 16 * (x / 46.0) ** 2) for x in range(-46, 47, 6)], 9.0)
        for fx in (-24, 24):
            fd.polygon([(s(CX + fx - 7), s(my + 16 * (fx / 46.0) ** 2 + 2)), (s(CX + fx + 7), s(my + 16 * (fx / 46.0) ** 2 + 2)),
                        (s(CX + fx), s(my + 16 * (fx / 46.0) ** 2 + 24))], fill=255)
    elif expr == "charge":                       # a snarl: open trapezoid with teeth
        _stroke(fd, [(CX - 50, my - 6), (CX + 50, my - 6), (CX + 38, my + 28), (CX - 38, my + 28), (CX - 50, my - 6)], 7.0)
        for tx in range(-36, 37, 18):
            fd.polygon([(s(CX + tx - 6), s(my - 4)), (s(CX + tx + 6), s(my - 4)), (s(CX + tx), s(my + 14))], fill=255)
    elif expr == "attack":                       # a roar: a wide open mouth with teeth top and bottom
        _stroke(fd, [(CX - 62, my - 14), (CX + 62, my - 14), (CX + 52, my + 40), (CX - 52, my + 40), (CX - 62, my - 14)], 8.0)
        for tx in range(-48, 49, 16):
            fd.polygon([(s(CX + tx - 6), s(my - 12)), (s(CX + tx + 6), s(my - 12)), (s(CX + tx), s(my + 8))], fill=255)
            fd.polygon([(s(CX + tx - 6), s(my + 38)), (s(CX + tx + 6), s(my + 38)), (s(CX + tx), s(my + 18))], fill=255)
    elif expr == "hurt":                         # a wobbly grimace
        _stroke(fd, [(CX + x, my + 7 * math.sin(x / 9.0)) for x in range(-48, 49, 4)], 8.0)
    else:                                        # dead: a flat line
        _stroke(fd, [(CX - 36, my + 6), (CX + 36, my + 6)], 8.0)
    face = face.filter(ImageFilter.GaussianBlur(S * 2.2))
    face = face.point(lambda v: 255 if v > 150 else int(max(0, v - 60) * 2.8))
    pupils = pupils.filter(ImageFilter.GaussianBlur(S * 1.5)).point(lambda v: 255 if v > 120 else 0)
    face = ImageChops.subtract(face, pupils)
    core_mask = face.filter(ImageFilter.MinFilter(s(5) // 2 * 2 + 1)).filter(ImageFilter.GaussianBlur(S * 1.2))
    out = Image.new("RGBA", full, (0, 0, 0, 0))
    glow(out, face, glow_c, radii=(3, 9, 22), strengths=tuple(min(1.0, v * power) for v in (0.8, 0.55, 0.4)), clip=inner)
    paste(out, solid(face, body_c), inner)
    paste(out, solid(core_mask, core_c), inner)
    return out


def composite(layers, expr="idle", pile_shift=(0, 0), with_shadow=False):
    """The layers stacked as the game stacks them: back, the pile (clipped to the glass), the face, the front (and optionally the shadow below)."""
    out = Image.new("RGBA", layers["back"].size, (0, 0, 0, 0))
    if with_shadow:
        out.alpha_composite(layers["shadow"])
    out.alpha_composite(layers["back"])
    for name in ("pile_back", "pile_mid", "pile_front"):
        pile = ImageChops.offset(layers[name], s(pile_shift[0]), s(pile_shift[1]))
        pile.putalpha(ImageChops.multiply(pile.getchannel("A"), layers["inner"]))
        out.alpha_composite(pile)
    out.alpha_composite(layers["faces"][expr])
    out.alpha_composite(layers["front"])
    return out


def build(shadow=True):
    rnd = random.Random(SEED)
    full = (W * S, H * S)
    img = Image.new("RGBA", full, (0, 0, 0, 0))

    # --- floating shadow (left out of the in-game sprite: the game draws its own)
    shadow_img = Image.new("RGBA", full, (0, 0, 0, 0))
    if shadow:
        sh = new_mask()
        ImageDraw.Draw(sh).ellipse([s(CX - 190), s(783), s(CX + 190), s(815)], fill=255)
        paste(shadow_img, solid(blur(sh, 4), (60, 60, 78), 0.75))
        core = new_mask()
        ImageDraw.Draw(core).ellipse([s(CX - 150), s(789), s(CX + 150), s(811)], fill=255)
        paste(shadow_img, solid(blur(core, 2), (46, 46, 62), 0.55))

    body = body_mask()
    inner = body.filter(ImageFilter.MinFilter(s(10) // 2 * 2 + 1))     # the inside of the glass (the glass wall is ~5 px)

    # --- cap and collar masks
    cap = profile_mask(full, 71, 254)
    ring1 = rrect_mask(full, (s(CX - 161.5), s(Y(248)), s(CX + 161.5), s(Y(280))), s(12))
    ring2 = profile_mask(full, 276, 334)
    silhouette = ImageChops.lighter(ImageChops.lighter(cap, ring1), ImageChops.lighter(ring2, body))

    # --- outline of the whole silhouette first (it ends up behind everything)
    paste(img, outline(silhouette, 7))

    # --- the glass body: back wall, then the hardware, then the front glass over it
    glass_back = lit(body, gradient_x(CX - BASE_HW, CX + BASE_HW, [(0, (150, 156, 170)), (0.45, (116, 122, 138)), (1, (84, 90, 106))]),
                     radius=18, bump=0.9, spec=0.0, ambient=0.78)
    paste(img, glass_back)
    # a darker band inside the bottom and a soft glow behind the face
    vig = arr(blur(inner, 14))
    shade_in = Image.new("RGBA", full, (38, 42, 56, 0))
    shade_in.putalpha(to_img((1.0 - vig) * arr(inner) * 0.55))
    paste(img, shade_in)
    layers = {"back": img}
    img = Image.new("RGBA", full, (0, 0, 0, 0))

    # hardware pile (not clipped here: the game clips it to the inside of the glass, so it can be shaken about)
    pile = Image.new("RGBA", full, (0, 0, 0, 0))
    # back row: heatsink and cables
    place(pile, heatsink(), 232, 636, -8)
    place(pile, heatsink(), 336, 612, 10)
    cable_layer = Image.new("RGBA", full, (0, 0, 0, 0))
    cable_layer.alpha_composite(cable(bezier((340, 640), (330, 560), (400, 560), (430, 610)), width=11))
    cable_layer.alpha_composite(cable(bezier((470, 700), (520, 650), (500, 590), (460, 575)), width=9))
    cable_layer.alpha_composite(cable(bezier((300, 700), (250, 650), (180, 690), (170, 700)), width=8))
    pile.alpha_composite(cable_layer)
    plan = [
        # (piece factory, cx, cy, angle)
        (lambda: ram_stick(seed=1), 160, 598, -14),
        (lambda: ram_stick(seed=2), 178, 640, 8),
        (lambda: ram_stick(seed=3), 436, 596, 16),
        (lambda: ram_stick(seed=4), 410, 560, -4),
        (lambda: ram_stick(seed=5), 462, 650, 28),
        (lambda: gpu(), 352, 612, -22),
        (lambda: rack(), 442, 688, 0),
        (lambda: psu(), 134, 700, 0),
        (lambda: ram_stick(seed=6), 250, 714, 6),
        (lambda: cpu(), 316, 700, -4),
        (lambda: ram_stick(seed=8), 380, 716, -10),
        (lambda: ram_stick(seed=9), 210, 668, 22),
        (lambda: psu(), 470, 626, -14),
        (lambda: ram_stick(seed=10), 300, 640, -30),
        (lambda: cpu(), 120, 640, 12),
        (lambda: ram_stick(seed=11), 96, 676, -22),
        (lambda: rack(), 280, 690, 6),
        # below the glass floor: hidden by the game's clip, they fill the gap when the pile is thrown up while shaking
        (lambda: rack(), 200, 752, 0),
        (lambda: ram_stick(seed=12), 330, 760, 4),
        (lambda: psu(), 420, 756, 0),
        (lambda: ram_stick(seed=13), 130, 764, -6),
        (lambda: cpu(), 470, 764, 0),
    ]
    # three depths of the pile, drawn in the same order as before (so the overlaps look the same), so the game can shake each on its own
    pile_mid = Image.new("RGBA", full, (0, 0, 0, 0))
    pile_front = Image.new("RGBA", full, (0, 0, 0, 0))
    for i, (make, cx, cy, ang) in enumerate(plan):
        place(pile if i < 6 else (pile_front if 14 <= i < 17 else pile_mid), make(), cx, cy, ang)
    # the pile is seen through glass: slightly faded and bluer
    for name, img_ in (("pile_back", pile), ("pile_mid", pile_mid), ("pile_front", pile_front)):
        layers[name] = tint_layer(img_, (96, 108, 132), 0.30)

    # --- the glowing faces (inside the glass): one picture per expression, all in the same place
    layers["faces"] = {name: make_face(name, full, inner) for name in EXPRESSIONS}

    # --- the cap holes glowing hot (the game fades this in while the boss sprays)
    hot = new_mask()
    hd = ImageDraw.Draw(hot)
    for hx, hy in HOLES:
        hd.ellipse([s(CX + hx - 15), s(hy - 7), s(CX + hx + 15), s(hy + 7)], fill=255)
    hot_img = Image.new("RGBA", full, (0, 0, 0, 0))
    glow(hot_img, hot, (255, 120, 40), radii=(1.5, 5, 12), strengths=(1.0, 0.7, 0.5), clip=cap)
    layers["cap_glow"] = hot_img
    layers["inner"] = inner

    # --- glass: front reflections, rim, tint at the edges
    rim = ImageChops.subtract(inner, inner.filter(ImageFilter.MinFilter(s(6) // 2 * 2 + 1)))
    rim_l = lit(rim, (210, 218, 232), radius=2.5, bump=1.6, spec=0.5, ambient=0.5)
    rim_l.putalpha(rim.point(lambda v: int(v * 0.55)))
    paste(img, rim_l)
    # long soft reflection on the left, two dashes, a small glint bottom-right
    refl = new_mask()
    rd = ImageDraw.Draw(refl)
    for (ya, yb, off, wd) in ((366, 478, 30, 20), (498, 548, 40, 14), (566, 590, 46, 10)):
        left, right = [], []
        for yy in np.linspace(ya, yb, 24):
            x = CX - half_width(float(yy)) + off
            left.append((s(x), s(yy)))
            right.append((s(x + wd), s(yy)))
        rd.polygon(left + right[::-1], fill=255)
    refl = refl.filter(ImageFilter.GaussianBlur(S * 1.4))
    paste(img, solid(refl, (236, 242, 250), 0.6), inner)
    paste(img, solid(blur(refl, 4), (230, 240, 255), 0.25), inner)
    glint = new_mask()
    ImageDraw.Draw(glint).ellipse([s(470), s(590), s(486), s(650)], fill=255)
    paste(img, solid(blur(glint, 3), (225, 235, 250), 0.35), inner)
    # base thickness: the bright sliver where the glass floor is
    floor = new_mask()
    ImageDraw.Draw(floor).rounded_rectangle([s(CX - 190), s(726), s(CX + 190), s(738)], radius=s(6), fill=255)
    paste(img, solid(blur(floor, 2), (200, 210, 228), 0.35), inner)

    # --- the metal collar rings
    metal = gradient_x(116, 484, [(0, (214, 212, 224)), (0.28, (178, 176, 192)), (0.62, (128, 126, 142)), (1, (86, 85, 100))])
    paste(img, outline(ring2, 5))
    ring2_l = lit(ring2, metal, radius=9, bump=1.6, spec=0.5, ambient=0.6)
    paste(img, ring2_l)
    paste(img, outline(ring1, 4.5))
    paste(img, lit(ring1, metal, radius=10, bump=1.7, spec=0.55, ambient=0.6))
    # the groove where the neck band meets the collar bulge
    groove = new_mask()
    ImageDraw.Draw(groove).rounded_rectangle([s(CX - 166), s(Y(276) - 2), s(CX + 166), s(Y(276) + 3)], radius=s(2), fill=255)
    paste(img, solid(blur(groove, 1.2), (40, 40, 52), 0.85), ring2)

    # --- the dome cap
    paste(img, outline(cap, 6))
    cap_col = gradient_x(116, 484, [(0, (210, 208, 222)), (0.2, (196, 194, 210)), (0.52, (150, 148, 166)), (0.82, (110, 108, 126)), (1, (86, 85, 102))])
    paste(img, lit(cap, cap_col, radius=22, bump=2.0, spec=0.7, ambient=0.5))
    # the flat top face (lighter, an ellipse seen from slightly above) and the darker rounded side below it
    top_face = new_mask()
    ImageDraw.Draw(top_face).ellipse([s(CX - 150), s(Y(100)), s(CX + 150), s(Y(194))], fill=255)
    paste(img, solid(blur(top_face, 3), (236, 234, 246), 0.38), cap)
    lip = new_mask()
    ImageDraw.Draw(lip).arc([s(CX - 150), s(Y(100)), s(CX + 150), s(Y(194))], 8, 172, fill=255, width=s(3.2))
    paste(img, solid(blur(lip, 1.2), (66, 64, 84), 0.7), cap)
    sheen = new_mask()
    ImageDraw.Draw(sheen).ellipse([s(CX - 120), s(Y(104)), s(CX - 20), s(Y(140))], fill=255)
    paste(img, solid(blur(sheen, 8), (255, 255, 255), 0.35), cap)
    under = new_mask()
    ImageDraw.Draw(under).rectangle([s(100), s(Y(228)), s(500), s(Y(262))], fill=255)
    paste(img, solid(blur(under, 7), (50, 50, 68), 0.5), cap)
    side_hi = new_mask()
    for x0, wd in ((CX - 150, 16), (CX - 118, 6)):
        ImageDraw.Draw(side_hi).rounded_rectangle([s(x0), s(Y(208)), s(x0 + wd), s(Y(244))], radius=s(wd / 2), fill=255)
    paste(img, solid(blur(side_hi, 1.6), (240, 240, 252), 0.5), cap)
    rimlight = ImageChops.subtract(cap, cap.filter(ImageFilter.MinFilter(s(4) // 2 * 2 + 1)))
    paste(img, solid(blur(rimlight, 0.6), (240, 240, 250), 0.35), cap)
    # the holes: seven small dark slots on the top face, in the reference's pattern
    for hx, hy in HOLES:
        x, y = CX + hx, hy
        rx, ry = 14.0, 6.6
        hole = new_mask()
        ImageDraw.Draw(hole).ellipse([s(x - rx), s(y - ry), s(x + rx), s(y + ry)], fill=255)
        rim = new_mask()
        ImageDraw.Draw(rim).ellipse([s(x - rx - 2), s(y - ry - 2), s(x + rx + 2), s(y + ry + 2)], fill=255)
        paste(img, outline(rim, 1.2, (110, 108, 128)), cap)
        paste(img, solid(hole, (30, 30, 40)), cap)
        deep = new_mask()
        ImageDraw.Draw(deep).ellipse([s(x - rx + 1), s(y - ry + 1.5), s(x + rx - 1), s(y + ry)], fill=255)
        paste(img, solid(blur(deep, 0.8), (12, 12, 18)), cap)
        edge = new_mask()
        ImageDraw.Draw(edge).arc([s(x - rx + 1), s(y - ry + 1), s(x + rx - 1), s(y + ry)], 25, 155, fill=255, width=s(1.1))
        paste(img, solid(blur(edge, 0.5), (140, 140, 164), 0.7), cap)
        lip_hi = new_mask()
        ImageDraw.Draw(lip_hi).arc([s(x - rx - 2), s(y - ry - 2), s(x + rx + 2), s(y + ry + 2)], 205, 335, fill=255, width=s(1.3))
        paste(img, solid(blur(lip_hi, 0.5), (246, 246, 255), 0.8), cap)

    # --- final outline pass for crispness along the body edge, plus the shadow where the cap meets the collar
    paste(img, outline(body, 4.2))
    layers["front"] = img
    layers["shadow"] = shadow_img
    return layers


def tight_box(img, pad=2):
    """The box of the non-transparent part of an RGBA image, with `pad` px around it."""
    box = img.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox()
    return (max(box[0] - pad, 0), max(box[1] - pad, 0), min(box[2] + pad, img.width), min(box[3] + pad, img.height))


def shrink(img, box):
    """Crop to `box` (given in 4x pixels, the top TRIM rows already removed) and reduce to final size."""
    c = img.crop(box)
    return c.resize((max(1, c.width // S), max(1, c.height // S)), Image.LANCZOS)


def export_game_art():
    """The pictures the boss stage uses, in assets/bosses/saltman/: the shaker in layers that the game stacks (back, the pile of
    hardware, a face for each expression, the front glass and metal, the glowing cap holes) so the game can shake the hardware inside
    and cross-fade the expressions; a mask of the inside of the glass; where the cap holes are; and a finished picture of each pose.
    Plus the three things it sprays (RAM stick, CPU, chipset) in assets/bosses/."""
    import json
    layers = build(shadow=False)
    top = s(TRIM)

    def cut(img):
        return img.crop((0, top, img.width, img.height))
    base = {k: cut(v) for k, v in layers.items() if k != "faces"}
    base["faces"] = {k: cut(v) for k, v in layers["faces"].items()}
    box = tight_box(base["back"], 2 * S)
    box = (box[0] // S * S, box[1] // S * S, box[2] // S * S, box[3] // S * S)       # on whole final pixels, so the layers stay in register
    folder = os.path.join(OUT, "saltman")
    os.makedirs(folder, exist_ok=True)
    for f in os.listdir(folder):
        if f.endswith(".png"):                                  # (the engine's .import files stay: they hold each picture's id)
            os.remove(os.path.join(folder, f))
    for name in ("back", "pile_back", "pile_mid", "pile_front", "front", "cap_glow"):
        shrink(base[name], box).save(os.path.join(folder, name + ".png"), optimize=True)
    for name, img in base["faces"].items():
        shrink(img, box).save(os.path.join(folder, "face_" + name + ".png"), optimize=True)
    mask = Image.new("RGBA", base["inner"].size, (255, 255, 255, 0))
    mask.putalpha(base["inner"])
    shrink(mask, box).save(os.path.join(folder, "inner_mask.png"), optimize=True)
    width, height = (box[2] - box[0]) // S, (box[3] - box[1]) // S
    ox, oy = box[0] / S, box[1] / S
    holes = [[CX + hx - ox, hy - TRIM - oy] for hx, hy in HOLES]
    json.dump({"size": [width, height], "cap_holes": holes, "expressions": EXPRESSIONS}, open(os.path.join(folder, "meta.json"), "w"), indent=1)
    poses = []
    for e in EXPRESSIONS:
        pose = shrink(composite(base, e), box)
        pose.save(preview_path("saltman_pose_" + e + ".png"), optimize=True)
        poses.append(pose)
    sheet = Image.new("RGBA", (width * len(poses), height), (236, 238, 244, 255))
    for i, pose in enumerate(poses):
        sheet.alpha_composite(pose, (i * width, 0))
    sheet.convert("RGB").save(preview_path("saltman_pose_sheet.png"))
    # what it sprays
    for name, piece, size in (("ram_stick", ram_stick(seed=21), None), ("cpu", cpu(), (60, 60)), ("chipset", chipset(), (54, 54))):
        small = piece.resize(size or (piece.width // 4, piece.height // 4), Image.LANCZOS)
        small.crop(small.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox()).save(os.path.join(OUT, name + ".png"), optimize=True)
    print("wrote the game art (%dx%d layers, %d expressions, %d cap holes)" % (width, height, len(EXPRESSIONS), len(holes)))


def main():
    os.makedirs(OUT, exist_ok=True)
    layers = build(shadow=True)
    big = composite(layers, "idle", with_shadow=True).crop((0, s(TRIM), W * S, H * S))
    final = big.resize((W, H - TRIM), Image.LANCZOS)
    path = preview_path("salt_shaker.png")          # the whole boss in one picture: only for looking at (the game builds him from the layers)
    final.save(path, optimize=True)
    export_game_art()
    print("wrote", path, final.size, "%.0f KB" % (os.path.getsize(path) / 1024))


if __name__ == "__main__":
    main()
