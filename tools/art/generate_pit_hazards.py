"""Builds the art for the deadly pits.

Usage (needs Pillow; from the repo root):  python tools/art/generate_pit_hazards.py

LIQUIDS  assets/pit_hazards/<kind>/pit_<kind>_liquid.png: a seamless tile of each liquid. They are recolours of the
         hand-made lava and water tiles from Kenney's "Platformer Pack Redux" (CC0, kept in
         tools/art/sources/kenney_platformer_redux/, see its License.txt), so the waves have real art direction
         instead of being drawn from shapes in code: lava as it is, toxic waste (lava shifted to green), nuclear waste
         (water shifted to a glowing green-teal) and the piranha tank (water, deepened). The game animates them
         (see scripts/level/pit_liquid.gdshader).
PIRANHA  assets/pit_hazards/piranha_tank/: the robot piranha as separate parts so the game can animate the bite:
         pit_piranha_tank_fish_body.png (everything but the lower jaw, with the upper teeth), ..._fish_jaw.png (the
         lower jaw with its teeth, hinged at its left end) and ..._fish_eye.png (a soft glow for the eyes).
         No CC0 piranha sprite with a separate jaw exists, so these are painted here with shaded gradients, plating,
         outlines and highlights; swap in other art with the same three file names if you find something better.
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


def make_piranha():
    """A robot piranha: a long, lean body (about as long as it is two-and-a-half times deep), a big blunt head with a steep
    forehead and a heavy underbite full of triangular teeth, a forked tail, a spiky dorsal fin and a red-orange belly, with
    metal plating."""
    W, H = 152, 100
    size = (W * SS, H * SS)
    steel = [(0, (128, 144, 170)), (0.35, (86, 100, 128)), (0.64, (98, 72, 76)), (1, (208, 92, 54))]
    fin = [(0, (214, 92, 56)), (1, (120, 38, 30))]
    # ---- fins and tail, behind the body
    tail = [(34, 58), (4, 26), (14, 54), (4, 86), (36, 64)]
    dorsal = [(98, 32), (88, 12), (78, 20), (68, 8), (56, 33)]
    anal = [(88, 81), (80, 95), (68, 89), (56, 95), (52, 80)]
    layers = []
    for pts in (tail, dorsal, anal):
        layers.append(shaded(poly_mask(size, spline(pts, 8)), fin, 0.3))
    td = ImageDraw.Draw(layers[0])
    for ty in (34, 46, 58, 72):                       # tail ribs
        td.line(scaled([(33, 60), (7, ty)]), fill=(80, 22, 22, 255), width=SS)
    dd = ImageDraw.Draw(layers[1])
    for dx in (62, 70, 78, 86):                       # dorsal ribs
        dd.line(scaled([(dx, 30), (dx + 2, 14)]), fill=(80, 22, 22, 255), width=SS)
    # ---- the body: long and lean, nose to the right; the lower jaw is a separate sprite
    outline = [(147, 53), (141, 45), (129, 37), (113, 32), (93, 29), (71, 28), (51, 32), (37, 39), (28, 47), (23, 52),
               (24, 59), (31, 67), (43, 75), (61, 80), (83, 81), (105, 77), (119, 70), (121, 62), (133, 58), (147, 57)]
    mask = poly_mask(size, spline(outline, 10))
    body = shaded(mask, steel, 0.5)
    plates = Image.new("RGBA", size, (0, 0, 0, 0))
    pd = ImageDraw.Draw(plates)
    for row in range(7):
        for col in range(11):
            cx = 36 + col * 7.4 + (3.7 if row % 2 else 0)
            cy = 36 + row * 7.0
            r = 4.8
            pd.arc([(cx - r) * SS, (cy - r) * SS, (cx + r) * SS, (cy + r) * SS], 200, 340, fill=(28, 36, 56, 150), width=SS)
    clipped = Image.new("RGBA", size, (0, 0, 0, 0))
    clipped.paste(plates, (0, 0), mask)
    body.alpha_composite(clipped)
    bd = ImageDraw.Draw(body)
    for k, off in enumerate((0, 4, 8)):                # gill cover
        bd.arc([(92 - off) * SS, 32 * SS, (118 - off) * SS, 76 * SS], 105, 255, fill=(24, 30, 44, 255), width=int(1.7 * SS))
    bd.line(scaled([(32, 54), (118, 58)]), fill=(24, 30, 44, 130), width=int(1.0 * SS))   # lateral line seam
    for rx, ry in ((74, 42), (64, 54), (74, 66), (54, 62), (84, 72)):                      # rivets
        bd.ellipse([(rx - 1.6) * SS, (ry - 1.6) * SS, (rx + 1.6) * SS, (ry + 1.6) * SS], fill=(36, 44, 62, 255))
        bd.ellipse([(rx - 0.9) * SS, (ry - 1.0) * SS, (rx + 0.3) * SS, (ry + 0.1) * SS], fill=(190, 205, 230, 255))
    pect = [(96, 60), (80, 65), (86, 76), (102, 70)]    # pectoral fin plate
    bd.polygon(scaled(spline(pect, 6)), fill=(150, 64, 48, 255), outline=(40, 18, 18, 255))
    # eye socket (the game adds the glow) with an angry brow
    bd.ellipse([118 * SS, 36 * SS, 132 * SS, 50 * SS], fill=(16, 20, 32, 255), outline=(160, 170, 190, 255), width=SS)
    bd.ellipse([122 * SS, 40 * SS, 129 * SS, 47 * SS], fill=(96, 14, 12, 255))
    bd.polygon(scaled([(114, 34), (139, 44), (137, 37), (118, 29)]), fill=(22, 26, 38, 255))
    # upper teeth along the lip, pointing down
    for i in range(5):
        tooth(bd, 123 + i * 4.6, 58.4, 4.6, 8.4)
    sprite = Image.new("RGBA", size, (0, 0, 0, 0))
    for layer in layers:
        sprite.alpha_composite(with_outline(layer, 2))
    sprite.alpha_composite(with_outline(body, 2))
    sprite = sprite.resize((W, H), Image.LANCZOS)

    # ---- the lower jaw: a deep wedge hinged at its left end (0, 9), teeth pointing up, its tip level with the nose
    JW, JH = 27, 26
    jsize = (JW * SS, JH * SS)
    jaw_pts = [(0, 8), (7, 7), (21, 7), (26, 9), (27, 13), (24, 21), (15, 25), (5, 25), (0, 18)]
    jmask = poly_mask(jsize, spline(jaw_pts, 8))
    jaw = shaded(jmask, [(0, (170, 84, 60)), (0.5, (128, 50, 42)), (1, (74, 26, 28))], 0.4)
    jd = ImageDraw.Draw(jaw)
    jd.line(scaled([(3, 15), (24, 13)]), fill=(40, 14, 16, 170), width=SS)
    for rx in (8, 15, 21):
        jd.ellipse([(rx - 1.0) * SS, 17 * SS, (rx + 1.0) * SS, 19 * SS], fill=(190, 205, 230, 255))
    for i in range(4):
        jd.polygon(scaled([(4 + i * 5.2, 7.4), (8 + i * 5.2, 7.4), (6 + i * 5.2, 0.4)]), fill=(244, 246, 250, 255), outline=OUTLINE)
    jaw = with_outline(jaw, 2).resize((JW, JH), Image.LANCZOS)

    # ---- the eye glow: a soft red-orange light, drawn bigger than the eye so it blooms
    G = 44
    glow = Image.new("RGBA", (G * SS, G * SS), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    for r, a in ((21, 40), (15, 90), (10, 170), (5, 255)):
        gd.ellipse([(22 - r) * SS, (22 - r) * SS, (22 + r) * SS, (22 + r) * SS], fill=(255, 70 + (255 - a) // 4, 40, a))
    glow = glow.filter(ImageFilter.GaussianBlur(2.5 * SS)).resize((G, G), Image.LANCZOS)

    folder = os.path.join(OUT, "piranha_tank")
    os.makedirs(folder, exist_ok=True)
    sprite.save(os.path.join(folder, "pit_piranha_tank_fish_body.png"))
    jaw.save(os.path.join(folder, "pit_piranha_tank_fish_jaw.png"))
    glow.save(os.path.join(folder, "pit_piranha_tank_fish_eye.png"))


if __name__ == "__main__":
    make_liquids()
    make_piranha()
    print("wrote pit hazards to", os.path.normpath(OUT))
