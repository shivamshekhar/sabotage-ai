"""Builds the art for the deadly pits.

Usage (needs Pillow; from the repo root):  python tools/art/generate_pit_hazards.py

LIQUIDS  levels/common/pit_hazards/<kind>/pit_<kind>_liquid.png: a seamless tile of each liquid. They are recolours of the
         hand-made lava and water tiles from Kenney's "Platformer Pack Redux" (CC0, kept in
         tools/art/sources/kenney_platformer_redux/, see its License.txt), so the waves have real art direction
         instead of being drawn from shapes in code: lava as it is, toxic waste (lava shifted to green), nuclear waste
         (water shifted to a glowing green-teal) and the piranha tank (water, deepened). The game animates them
         (see scripts/level/pit_liquid.gdshader).
PIRANHA  levels/common/pit_hazards/piranha_tank/: the robot piranha drawn once per mouth pose (closed, slight, open, wide:
         pit_piranha_tank_fish_<pose>.png), so the closed mouth lines up exactly and the open ones show both rows of teeth;
         the game flips between them to make it bite. ..._fish_eye.png is a soft glow for the eyes. No CC0 piranha sprite
         exists, so these are painted here with shaded gradients, plating, outlines and highlights; swap in other art with
         the same file names if you find something better.
The kinds MUST match SpriteLibrary.PIT_KINDS (tools/tests/assets_test.gd checks that every file exists).
"""
import colorsys
import math
import os
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "..", "..", "assets", "pit_hazards")
SRC = os.path.join(HERE, "sources", "kenney_platformer_redux")


def recolour(im, hue_shift=0.0, sat=1.0, val=1.0, gamma=1.0, contrast=1.0):
    """Shift the hue (in turns, 0..1), scale saturation and value, apply a gamma, and stretch the brightness
    contrast around the tile's average (so the waves stand out more)."""
    im = im.convert("RGBA")
    px = im.load()
    mean = sum(colorsys.rgb_to_hsv(*(c / 255.0 for c in px[x, y][:3]))[2] for x in range(0, im.width, 4) for y in range(0, im.height, 4)) / ((im.width // 4) * (im.height // 4))
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            h, s, v = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)
            h = (h + hue_shift) % 1.0
            s = min(1.0, s * sat)
            v = min(1.0, (v ** gamma) * val)
            nr, ng, nb = colorsys.hsv_to_rgb(h, s, v)
            px[x, y] = (int(nr * 255), int(ng * 255), int(nb * 255), a)
    return im


def make_liquids():
    lava = Image.open(os.path.join(SRC, "lava.png")).convert("RGBA")
    water = Image.open(os.path.join(SRC, "water.png")).convert("RGBA")
    kinds = {
        "lava": recolour(lava, 0.0, 1.05, 1.0, 0.9, 3.2),
        "toxic_waste": recolour(lava, 0.23, 0.95, 0.9, 1.0, 3.4),        # orange -> acid green
        "nuclear_waste": recolour(water, -0.125, 1.9, 0.8, 0.9, 3.2), # cyan -> glowing radioactive green
        "piranha_tank": recolour(water, 0.035, 1.7, 0.78, 1.15, 3.0),   # light cyan -> deep tank blue
    }
    for kind, im in kinds.items():
        folder = os.path.join(OUT, kind)
        os.makedirs(folder, exist_ok=True)
        im.save(os.path.join(folder, f"pit_{kind}_liquid.png"))


# ------------------------------------------------------------------ the robot piranha
SS = 8   # supersampling: everything is drawn this many times bigger and shrunk, for smooth, anti-aliased edges
OUTLINE = (16, 20, 30, 255)


def spline(points, steps=12, closed=True):
    """A smooth curve through the given points (Catmull-Rom), so shapes have flowing outlines, not straight edges."""
    out = []
    n = len(points)
    rng = range(n) if closed else range(n - 1)
    for i in rng:
        p0, p1, p2, p3 = points[(i - 1) % n], points[i], points[(i + 1) % n], points[(i + 2) % n]
        for s in range(steps):
            t = s / steps
            t2, t3 = t * t, t * t * t
            out.append(tuple(0.5 * ((2 * p1[k]) + (-p0[k] + p2[k]) * t + (2 * p0[k] - 5 * p1[k] + 4 * p2[k] - p3[k]) * t2
                                    + (-p0[k] + 3 * p1[k] - 3 * p2[k] + p3[k]) * t3) for k in (0, 1)))
    return out


def scaled(points, k=SS):
    return [(x * k, y * k) for x, y in points]


def vertical_gradient(size, stops):
    """An image whose colour runs through `stops` (list of (position 0..1, colour)) from top to bottom."""
    w, h = size
    im = Image.new("RGBA", size)
    d = ImageDraw.Draw(im)
    for y in range(h):
        t = y / max(1, h - 1)
        for i in range(len(stops) - 1):
            (t0, c0), (t1, c1) = stops[i], stops[i + 1]
            if t0 <= t <= t1:
                u = (t - t0) / max(1e-6, t1 - t0)
                col = tuple(int(c0[k] + (c1[k] - c0[k]) * u) for k in range(3)) + (255,)
                d.line([(0, y), (w, y)], fill=col)
                break
    return im


def shaded(mask, stops, highlight=0.35):
    """Fill `mask` with a vertical gradient plus a soft light along its top edge, giving the shape volume."""
    fill = vertical_gradient(mask.size, stops)
    light = ImageChops.subtract(mask, mask.filter(ImageFilter.GaussianBlur(10 * SS / 4)).transform(
        mask.size, Image.AFFINE, (1, 0, 0, 0, 1, 10 * SS / 4)))   # the part of the shape that is lit from above
    light = light.filter(ImageFilter.GaussianBlur(3 * SS / 4)).point(lambda v: int(v * highlight))
    white = Image.new("RGBA", mask.size, (255, 255, 255, 255))
    fill = Image.composite(white, fill, light)
    out = Image.new("RGBA", mask.size, (0, 0, 0, 0))
    out.paste(fill, (0, 0), mask)
    return out


def with_outline(layer, width=2):
    """The layer with a dark outline hugging it."""
    alpha = layer.split()[3]
    grown = alpha.filter(ImageFilter.MaxFilter(2 * width * SS // 2 * 2 + 1))
    ring = Image.new("RGBA", layer.size, OUTLINE)
    base = Image.new("RGBA", layer.size, (0, 0, 0, 0))
    base.paste(ring, (0, 0), grown)
    base.alpha_composite(layer)
    return base


def poly_mask(size, points):
    m = Image.new("L", size, 0)
    ImageDraw.Draw(m).polygon(scaled(points), fill=255)
    return m


def tooth(d, x, y, w, h, col=(244, 246, 250, 255)):
    d.polygon(scaled([(x, y), (x + w, y), (x + w / 2, y + h)]), fill=col, outline=OUTLINE)


def saw_teeth(d, x0, y, count, step, height, up):
    """A row of big saw-blade teeth: each a right triangle with one straight and one slanted edge, so the row looks
    jagged like a saw. `up` True points them up (lower jaw), False down (upper jaw)."""
    for i in range(count):
        x = x0 + i * step
        if up:
            pts = [(x, y), (x + step, y), (x + step * 0.3, y - height)]
        else:
            pts = [(x, y), (x + step, y), (x + step * 0.7, y + height)]
        d.polygon(scaled(pts), fill=(236, 240, 247, 255), outline=OUTLINE)
        a, b = (pts[1], pts[2]) if up else (pts[0], pts[2])
        d.line(scaled([a, b]), fill=(130, 142, 164, 255), width=max(1, SS // 2))      # a shaded cut along the slanted edge
        mid = ((pts[0][0] + pts[2][0]) / 2.0, (pts[0][1] + pts[2][1]) / 2.0)
        d.line(scaled([mid, (mid[0] + step * 0.18, mid[1])]), fill=(170, 180, 196, 255), width=max(1, SS // 2))


# The whole fish is drawn once per mouth pose, so the closed mouth lines up exactly and the open mouths show both rows of teeth.
# PIRANHA_POSES: name and how far the lower jaw is swung down, in degrees.
PIRANHA_POSES = [("closed", 0.0), ("slight", 20.0), ("open", 42.0), ("wide", 64.0)]
MOUTH_CORNER = (122, 76)    # where the lower jaw is hinged; the lip line runs from here to the nose


def piranha_frame(open_deg):
    """A robot piranha drawn from the proportions of the real fish (a deep body with a hump behind a big blunt head, a large
    high eye, a long sail-like dorsal fin, a long anal fin, a broad tail on a thick tail base, a dark back blending unevenly
    into an orange-red belly with silver speckles), with a big mechanical mouth: a long upper lip with large saw-blade teeth
    and a heavy armoured lower jaw with its own saw teeth, swung down by `open_deg` degrees around the mouth corner."""
    import random
    W, H = 184, 150
    size = (W * SS, H * SS)
    rng = random.Random(11)
    steel = [(0, (70, 78, 90)), (0.3, (98, 106, 116)), (0.55, (120, 100, 92)), (0.72, (214, 108, 48)), (1, (196, 66, 34))]
    fin_top = [(0, (206, 92, 50)), (1, (126, 40, 30))]
    tail_fill = [(0, (62, 68, 80)), (0.6, (110, 76, 66)), (1, (204, 92, 46))]

    # ---- fins and tail, behind the body
    tail = [(36, 62), (16, 32), (8, 46), (3, 70), (8, 94), (18, 106), (36, 76)]
    dorsal = [(108, 25), (102, 7), (86, 9), (70, 11), (55, 19), (46, 37), (62, 31), (82, 27)]
    adipose = [(46, 42), (38, 34), (35, 46)]
    anal = [(114, 98), (108, 116), (90, 120), (72, 116), (60, 105), (80, 102)]
    layers = []
    for pts, stops in ((tail, tail_fill), (dorsal, fin_top), (adipose, fin_top), (anal, fin_top)):
        layers.append(shaded(poly_mask(size, spline(pts, 8)), stops, 0.3))
    td = ImageDraw.Draw(layers[0])
    for ty in (34, 44, 54, 66, 78, 90, 100):
        td.line(scaled([(36, 68), (8, ty)]), fill=(40, 24, 24, 200), width=SS)
    dd = ImageDraw.Draw(layers[1])
    for dx in range(52, 104, 6):
        dd.line(scaled([(dx + 4, 30), (dx - 2, 12)]), fill=(80, 24, 20, 200), width=SS)
    ad = ImageDraw.Draw(layers[3])
    for ax in range(66, 112, 6):
        ad.line(scaled([(ax, 102), (ax - 2, 116)]), fill=(80, 24, 20, 200), width=SS)

    # ---- the body: deep, a hump behind the head, a full belly, a long upper lip running back to the mouth corner
    outline = [(163, 68), (158, 55), (149, 43), (136, 34), (118, 27), (100, 22), (80, 25), (62, 31), (47, 40), (36, 52),
               (30, 61), (30, 71), (37, 82), (51, 93), (71, 100), (93, 103), (115, 99), (126, 92), (124, 84), (122, 77),
               (142, 74), (163, 72)]
    mask = poly_mask(size, spline(outline, 10))
    body = shaded(mask, steel, 0.4)
    blobs = Image.new("RGBA", size, (0, 0, 0, 0))
    bl = ImageDraw.Draw(blobs)
    for _ in range(26):
        bx, by = rng.uniform(40, 135), rng.uniform(58, 92)
        br = rng.uniform(4, 11)
        bl.ellipse([(bx - br) * SS, (by - br * 0.8) * SS, (bx + br) * SS, (by + br * 0.8) * SS], fill=(232, 110, 42, rng.randint(80, 170)))
    blobs = blobs.filter(ImageFilter.GaussianBlur(3.5 * SS))
    clipped = Image.new("RGBA", size, (0, 0, 0, 0))
    clipped.paste(blobs, (0, 0), mask)
    body.alpha_composite(clipped)
    speck = Image.new("RGBA", size, (0, 0, 0, 0))
    sd = ImageDraw.Draw(speck)
    for _ in range(140):
        sx, sy = rng.uniform(36, 126), rng.uniform(28, 70)
        sr = rng.uniform(0.5, 1.1)
        sd.ellipse([(sx - sr) * SS, (sy - sr) * SS, (sx + sr) * SS, (sy + sr) * SS], fill=(214, 220, 226, rng.randint(110, 210)))
    clipped = Image.new("RGBA", size, (0, 0, 0, 0))
    clipped.paste(speck, (0, 0), mask)
    body.alpha_composite(clipped)
    bd = ImageDraw.Draw(body)
    bd.line(scaled([(34, 66), (96, 64)]), fill=(20, 24, 34, 120), width=int(0.9 * SS))
    bd.line(scaled([(60, 36), (66, 92)]), fill=(20, 24, 34, 90), width=int(0.8 * SS))
    for k, off in enumerate((0, 4, 8)):                # gill cover
        bd.arc([(100 - off) * SS, 32 * SS, (126 - off) * SS, 92 * SS], 105, 255, fill=(22, 26, 38, 255), width=int(1.8 * SS))
    plate = [(108, 40), (122, 42), (126, 62), (122, 82), (108, 86), (102, 62)]
    bd.polygon(scaled(spline(plate, 6)), fill=(104, 112, 124, 150), outline=(24, 28, 40, 220))
    for rx, ry in ((111, 46), (118, 48), (119, 76), (111, 80), (56, 74), (80, 84), (88, 40)):
        bd.ellipse([(rx - 1.7) * SS, (ry - 1.7) * SS, (rx + 1.7) * SS, (ry + 1.7) * SS], fill=(34, 40, 56, 255))
        bd.ellipse([(rx - 0.9) * SS, (ry - 1.0) * SS, (rx + 0.3) * SS, (ry + 0.1) * SS], fill=(196, 208, 230, 255))
    pect = [(118, 80), (98, 86), (106, 99), (126, 92)]
    bd.polygon(scaled(spline(pect, 6)), fill=(188, 78, 44, 255), outline=(48, 20, 18, 255))
    for fx in (104, 109, 114):
        bd.line(scaled([(fx + 6, 84), (fx, 94)]), fill=(100, 36, 26, 255), width=SS // 2)
    bd.ellipse([126 * SS, 34 * SS, 146 * SS, 54 * SS], fill=(18, 22, 34, 255), outline=(170, 180, 196, 255), width=int(1.4 * SS))
    bd.ellipse([131 * SS, 39 * SS, 141 * SS, 49 * SS], fill=(138, 36, 18, 255))
    bd.polygon(scaled([(122, 33), (150, 43), (148, 35), (126, 27)]), fill=(24, 28, 40, 255))

    # ---- the lower jaw: big, heavy and mechanical, hinged at the mouth corner. It is drawn in its own layer, swung down by
    # open_deg around the hinge, and placed BEHIND the body (so when it is shut its teeth are hidden behind the lip and its
    # top edge lines up with the lip exactly) but in front of the fins.
    JW, JH, TOP = 44, 46, 18        # jaw image size, and how many rows above its top edge are kept for the teeth
    hinge_in_jaw = (0, TOP + 2)     # the hinge, in the jaw image
    jsize = (JW * SS, (JH + TOP) * SS)
    jp = [(0, 2), (8, 0), (36, 0), (43, 5), (44, 12), (37, 28), (22, 36), (8, 36), (0, 26)]
    jp = [(x, y + TOP) for x, y in jp]
    jmask = poly_mask(jsize, spline(jp, 8))
    jaw = shaded(jmask, [(0, (150, 158, 172)), (0.4, (100, 108, 122)), (1, (56, 62, 76))], 0.45)
    jd = ImageDraw.Draw(jaw)
    for bx in (11, 26):                                  # armour bands with bolts
        jd.rectangle([bx * SS, (TOP + 1) * SS, (bx + 5) * SS, (TOP + 33) * SS], fill=(214, 100, 44, 255), outline=(30, 20, 20, 255), width=SS // 2)
        for by in (7, 24):
            jd.ellipse([(bx + 1.2) * SS, (TOP + by - 1.2) * SS, (bx + 3.8) * SS, (TOP + by + 1.4) * SS], fill=(40, 44, 58, 255))
    jd.rounded_rectangle([4 * SS, (TOP + 14) * SS, 36 * SS, (TOP + 19) * SS], radius=2 * SS, fill=(74, 80, 94, 255), outline=(24, 26, 36, 255), width=SS // 2)
    for rx in range(8, 34, 5):                           # a hydraulic rod along the side
        jd.line(scaled([(rx, TOP + 14), (rx, TOP + 19)]), fill=(150, 158, 172, 255), width=SS // 2)
    saw_teeth(jd, 5, TOP + 0.4, 4, 8.8, 15.0, True)   # big saw teeth along the top edge, pointing up
    jaw = with_outline(jaw, 2)
    # rotate about the hinge and drop the jaw onto a full-size canvas with the hinge on the mouth corner
    pad = 70
    jc = Image.new("RGBA", ((JW + 2 * pad) * SS, (JH + TOP + 2 * pad) * SS), (0, 0, 0, 0))
    jc.alpha_composite(jaw, (pad * SS, pad * SS))
    center = ((pad + hinge_in_jaw[0]) * SS, (pad + hinge_in_jaw[1]) * SS)
    jc = jc.rotate(-open_deg, center=center, resample=Image.BICUBIC)
    jaw_layer = Image.new("RGBA", size, (0, 0, 0, 0))
    jaw_layer.alpha_composite(jc, (int(MOUTH_CORNER[0] * SS - center[0]), int(MOUTH_CORNER[1] * SS - center[1])))

    # ---- the big upper teeth along the long upper lip, on top of everything
    teeth = Image.new("RGBA", size, (0, 0, 0, 0))
    td2 = ImageDraw.Draw(teeth)
    tooth_height = 15.0 * min(1.0, open_deg / 30.0)    # a shut mouth shows no teeth; they appear as it opens
    if tooth_height > 1.0:
        saw_teeth(td2, 124, 75.0, 5, 7.6, tooth_height, False)

    sprite = Image.new("RGBA", size, (0, 0, 0, 0))
    for layer in layers:
        sprite.alpha_composite(with_outline(layer, 2))
    sprite.alpha_composite(jaw_layer)
    sprite.alpha_composite(with_outline(body, 2))
    sprite.alpha_composite(teeth)
    return sprite.resize((W, H), Image.LANCZOS)


def make_piranha():
    folder = os.path.join(OUT, "piranha_tank")
    os.makedirs(folder, exist_ok=True)
    for name, angle in PIRANHA_POSES:
        piranha_frame(angle).save(os.path.join(folder, f"pit_piranha_tank_fish_{name}.png"))
    # ---- the eye glow: a soft red-orange light, drawn bigger than the eye so it blooms
    G = 48
    glow = Image.new("RGBA", (G * SS, G * SS), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    for r, a in ((23, 40), (17, 90), (11, 170), (6, 255)):
        gd.ellipse([(24 - r) * SS, (24 - r) * SS, (24 + r) * SS, (24 + r) * SS], fill=(255, 70 + (255 - a) // 4, 40, a))
    glow = glow.filter(ImageFilter.GaussianBlur(2.5 * SS)).resize((G, G), Image.LANCZOS)
    glow.save(os.path.join(folder, "pit_piranha_tank_fish_eye.png"))


if __name__ == "__main__":
    make_liquids()
    make_piranha()
    print("wrote pit hazards to", os.path.normpath(OUT))
