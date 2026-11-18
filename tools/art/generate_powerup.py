"""Draws the power-up box and the frames of it breaking apart, in the style of the level tiles (see generate_tiles.py: the metal crate):
navy steel with a light lip along the top, darker bottom and right edges, corner rivets, chamfered corners, seams, and cyan edge lights
that glow. The box adds a cross of cuts, four glowing corner brackets and a "?" on a recessed panel.

Usage (from the repo root; needs Pillow):
    python tools/art/generate_powerup.py      writes
        levels/common/tiles/data_center/powerups/powerup_box.png   70x70, the picture the level editor shows (amber "?")
        assets/powerups/box.png                                    the box with its amber "?" (560x560; the game draws it at 0.25)
        assets/powerups/box_base.png                               the box without the "?"
        assets/powerups/box_question.png                           just the "?" and its halo, in white: the game tints it, so it can
                                                                   fade slowly through colours and blink (see PowerUpBox)
        assets/powerups/box_break_1.png .. box_break_6.png         the break-apart frames, same size as box.png
        assets/powerups/box_sheet.png                              all of them in a row (for looking at)

The box is cut along its cross into four pieces; the break frames move, turn and fade those pieces (1: a crack of light, 2: the
cut opens in a flash, 3-4: the pieces fly apart, 5-6: they shrink and fade among small sparks).
"""
import math
import os
import random

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
OUT_ASSETS = os.path.join(ROOT, "assets", "powerups")
OUT_TILE = os.path.join(ROOT, "levels", "common", "tiles", "data_center", "powerups")

K = 4                        # final pixels per unit (one unit = one pixel of a 70 px tile)
SS = 8                       # drawing resolution per unit (drawn at this and shrunk, so edges are smooth)
CANVAS = 140                 # canvas size in units: the box (BOX units) in the middle with room for the pieces to fly
BOX = 64
O = (CANVAS - BOX) / 2       # where the box starts

# the tile palette (generate_tiles.py)
EDGE = (11, 14, 22)
STEEL_LIP = (84, 102, 140)
STEEL_HI = (132, 154, 198)
STEEL_SEAM_HI = (62, 78, 112)
RIVET = (98, 116, 152)
CYAN = (58, 208, 255)
AMBER = (255, 196, 64)


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(len(a)))


def canvas():
    return Image.new("RGBA", (CANVAS * SS, CANVAS * SS), (0, 0, 0, 0))


def X(v):
    return round((O + v) * SS)


def rect(d, x0, y0, x1, y1, fill):
    d.rectangle([X(x0), X(y0), X(x1) - 1, X(y1) - 1], fill=fill)


def circle(d, cx, cy, r, fill):
    d.ellipse([X(cx - r), X(cy - r), X(cx + r), X(cy + r)], fill=fill)


def vgrad(d, x0, y0, x1, y1, top, bot):
    n = X(y1) - X(y0)
    for i in range(n):
        d.line([(X(x0), X(y0) + i), (X(x1) - 1, X(y0) + i)], fill=lerp(top, bot, i / max(1, n - 1)) + (255,))


def poly(d, pts, fill):
    d.polygon([(X(x), X(y)) for x, y in pts], fill=fill)


def chamfer(im, c):
    mask = Image.new("L", im.size, 255)
    md = ImageDraw.Draw(mask)
    B = BOX
    for (cx, cy), (sx, sy) in (((0, 0), (1, 1)), ((B, 0), (-1, 1)), ((0, B), (1, -1)), ((B, B), (-1, -1))):
        poly(md, [(cx, cy), (cx + sx * c, cy), (cx, cy + sy * c)], 0)
    im.putalpha(ImageChops.multiply(im.getchannel("A"), mask))


def font(size_units):
    for name in ("arialbd.ttf", "segoeuib.ttf"):
        try:
            return ImageFont.truetype("C:/Windows/Fonts/" + name, round(size_units * SS))
        except OSError:
            continue
    return ImageFont.load_default()


def glow_layer(im, strips, color, blur, alpha):
    """A blurred glow behind rectangles ((x0, y0, x1, y1) in box units), composited under `im`."""
    layer = Image.new("RGBA", im.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for x0, y0, x1, y1 in strips:
        rect(d, x0, y0, x1, y1, color + (alpha,))
    layer = layer.filter(ImageFilter.GaussianBlur(blur * SS))
    return Image.alpha_composite(layer, im)


def question_mask(size):
    """The "?" as an L mask."""
    q = Image.new("L", size, 0)
    ImageDraw.Draw(q).text((X(BOX / 2), X(BOX / 2) + round(0.8 * SS)), "?", font=font(34), fill=255, anchor="mm")
    return q


def tinted(color, mask, strength=1.0):
    layer = Image.new("RGBA", mask.size, tuple(color) + (0,))
    layer.putalpha(mask.point(lambda v: int(v * strength)))
    return layer


def draw_question(im, color, shadow=True):
    """Draw the "?" onto `im` in `color`: a soft halo, a drop shadow (optional), the letter and a light edge on top."""
    q = question_mask(im.size)
    halo = q.filter(ImageFilter.GaussianBlur(2.2 * SS))
    im = Image.alpha_composite(im, tinted(color, halo, 0.8))
    if shadow:
        im = Image.alpha_composite(im, tinted((8, 10, 18), ImageChops.offset(q, round(0.9 * SS), round(1.1 * SS)), 0.8))
    im = Image.alpha_composite(im, tinted(color, q))
    edge = ImageChops.subtract(ImageChops.offset(q, 0, -round(0.5 * SS)), ImageChops.offset(q, 0, round(0.5 * SS)))
    return Image.alpha_composite(im, tinted((255, 255, 255), edge, 0.55))


def draw_box(with_question=True):
    """The box, on the big canvas, drawn at SS px per unit."""
    im = canvas()
    d = ImageDraw.Draw(im)
    B = BOX
    m = B / 2
    # --- steel body and frame (the crate's)
    vgrad(d, 0, 0, B, B, (52, 64, 92), (34, 43, 64))
    rect(d, 0, 0, B, 4, STEEL_LIP + (255,))
    rect(d, 0, 0, B, 1.8, STEEL_HI + (255,))
    rect(d, 0, B - 4, B, B, (22, 28, 44, 255))
    rect(d, 0, 0, 4, B, (40, 50, 74, 255))
    rect(d, B - 4, 0, B, B, (26, 33, 50, 255))

    # --- the cuts: a dark seam with a soft highlight beside it, through the frame (they stop at the panel)
    for (x0, y0, x1, y1) in ((m - 0.8, 0, m + 0.8, 9), (m - 0.8, B - 9, m + 0.8, B), (0, m - 0.8, 9, m + 0.8), (B - 9, m - 0.8, B, m + 0.8)):
        rect(d, x0, y0, x1, y1, EDGE + (255,))
    for (x0, y0, x1, y1) in ((m + 0.8, 1.8, m + 1.8, 9), (m + 0.8, B - 9, m + 1.8, B - 4), (1.8, m + 0.8, 9, m + 1.8), (B - 9, m + 0.8, B - 4, m + 1.8)):
        rect(d, x0, y0, x1, y1, STEEL_SEAM_HI + (255,))
    # diagonal cuts at the panel's corners
    for sx, sy in ((0, 0), (1, 0), (0, 1), (1, 1)):
        cx0 = 9 if sx == 0 else B - 9
        cy0 = 9 if sy == 0 else B - 9
        ex = 3.2 if sx == 0 else B - 3.2
        ey = 3.2 if sy == 0 else B - 3.2
        d.line([(X(cx0), X(cy0)), (X(ex), X(ey))], fill=EDGE + (255,), width=round(1.3 * SS))

    # --- the recessed panel
    rect(d, 9, 9, B - 9, B - 9, EDGE + (255,))
    vgrad(d, 10, 10, B - 10, B - 10, (26, 33, 52), (36, 45, 68))
    rect(d, 10, 10, B - 10, 11.6, (18, 23, 36, 255))           # the shadow under the lip
    rect(d, 10, B - 11.4, B - 10, B - 10, (52, 64, 92, 255))    # a catch of light at the bottom

    # --- glowing corner brackets (cyan edge lights, as on the ground tiles), with a halo
    brackets = []
    for sx in (0, 1):
        for sy in (0, 1):
            bx = 13 if sx == 0 else B - 13
            by = 13 if sy == 0 else B - 13
            dx = 1 if sx == 0 else -1
            dy = 1 if sy == 0 else -1
            brackets.append((min(bx, bx + dx * 10), min(by, by + dy * 2), max(bx, bx + dx * 10), max(by, by + dy * 2)))
            brackets.append((min(bx, bx + dx * 2), min(by, by + dy * 10), max(bx, bx + dx * 2), max(by, by + dy * 10)))
    im = glow_layer(im, brackets, CYAN, 1.8, 170)
    d = ImageDraw.Draw(im)
    for r in brackets:
        rect(d, *r, CYAN + (255,))
    for r in brackets:
        rect(d, r[0], r[1], r[2], r[1] + min(0.8, r[3] - r[1]), (200, 245, 255, 255))

    if with_question:
        im = draw_question(im, AMBER)

    # --- rivets in the corners (the crate's) and the outline
    d = ImageDraw.Draw(im)
    for rx, ry in ((5.8, 5.8), (B - 5.8, 5.8), (5.8, B - 5.8), (B - 5.8, B - 5.8)):
        circle(d, rx, ry, 2.2, EDGE + (255,))
        circle(d, rx, ry, 1.4, RIVET + (255,))
    rect(d, 0, 0, 1.3, B, EDGE + (255,))
    rect(d, B - 1.3, 0, B, B, EDGE + (255,))
    rect(d, 0, 0, B, 1.3, EDGE + (255,))
    rect(d, 0, B - 1.3, B, B, EDGE + (255,))
    # cut the corners and keep only the box (the glows may spread past it)
    keep = Image.new("L", im.size, 0)
    rect(ImageDraw.Draw(keep), 0, 0, B, B, 255)
    im.putalpha(ImageChops.multiply(im.getchannel("A"), keep))
    chamfer(im, 6)
    return im


def draw_question_layer():
    """Just the "?" and its halo in white (the game tints it), on the big canvas."""
    return draw_question(canvas(), (255, 255, 255), shadow=False)


def finish(im, path=None):
    out = im.resize((CANVAS * K, CANVAS * K), Image.LANCZOS)
    if path:
        out.save(path)
    return out


# ----------------------------------------------------------------------------------------------------------------------
# breaking apart
# ----------------------------------------------------------------------------------------------------------------------
def make_pieces(img):
    """Cut the box along its cross: four pieces (RGBA on the big canvas) and their centres (units)."""
    pieces = []
    mid = CANVAS / 2
    for qx in (0, 1):
        for qy in (0, 1):
            m = Image.new("L", img.size, 0)
            x0, x1 = (0, mid) if qx == 0 else (mid, CANVAS)
            y0, y1 = (0, mid) if qy == 0 else (mid, CANVAS)
            ImageDraw.Draw(m).rectangle([round(x0 * SS), round(y0 * SS), round(x1 * SS) - 1, round(y1 * SS) - 1], fill=255)
            p = img.copy()
            p.putalpha(ImageChops.multiply(img.getchannel("A"), m))
            bb = p.getchannel("A").getbbox()
            pieces.append((p, ((bb[0] + bb[2]) / 2 / SS, (bb[1] + bb[3]) / 2 / SS)))
    return pieces


def place(piece, centre, offset, angle, scale, alpha):
    """The piece turned and scaled about its centre, then moved by `offset` (units)."""
    cx, cy = centre[0] * SS, centre[1] * SS
    th = math.radians(angle)
    c, s = math.cos(th) / scale, math.sin(th) / scale
    ox, oy = offset[0] * SS, offset[1] * SS
    a, b, d, e = c, s, -s, c
    cc = cx - (a * (cx + ox) + b * (cy + oy))
    ff = cy - (d * (cx + ox) + e * (cy + oy))
    out = piece.transform(piece.size, Image.AFFINE, (a, b, cc, d, e, ff), resample=Image.BICUBIC)
    if alpha < 1.0:
        out.putalpha(out.getchannel("A").point(lambda v: int(v * alpha)))
    return out


FRAMES = [
    dict(kind="crack"),
    dict(kind="pieces", sep=2.0, turn=0, scale=1.0, alpha=1.0, flash=0.9, sparks=6),
    dict(kind="pieces", sep=9.0, turn=9, scale=0.97, alpha=1.0, flash=0.6, sparks=10),
    dict(kind="pieces", sep=17.0, turn=20, scale=0.85, alpha=0.9, flash=0.3, sparks=10),
    dict(kind="pieces", sep=24.0, turn=32, scale=0.6, alpha=0.55, flash=0.0, sparks=8),
    dict(kind="pieces", sep=29.0, turn=44, scale=0.35, alpha=0.2, flash=0.0, sparks=6),
]


def draw_sparks(im, rnd, n, spread, alpha):
    d = ImageDraw.Draw(im)
    mid = CANVAS / 2
    for _ in range(n):
        ang = rnd.uniform(0, math.tau)
        dist = spread * rnd.uniform(0.35, 1.0)
        x, y = mid + math.cos(ang) * dist, mid + math.sin(ang) * dist
        sz = rnd.uniform(1.0, 2.2)
        col = rnd.choice([CYAN, CYAN, AMBER])
        d.rounded_rectangle([round((x - sz) * SS), round((y - sz) * SS), round((x + sz) * SS), round((y + sz) * SS)], radius=round(0.5 * SS), fill=col + (int(255 * alpha),))


def break_frame(index, box_img, pieces):
    p = FRAMES[index]
    base = Image.new("RGBA", box_img.size, (0, 0, 0, 0))
    mid = CANVAS / 2
    if p["kind"] == "crack":
        base.alpha_composite(box_img)
        pts = [(mid - 14, mid - 30), (mid - 4, mid - 10), (mid - 10, mid - 2), (mid + 3, mid + 8), (mid - 2, mid + 20), (mid + 12, mid + 31)]
        glow = Image.new("RGBA", base.size, (0, 0, 0, 0))
        ImageDraw.Draw(glow).line([(x * SS, y * SS) for x, y in pts], fill=CYAN + (255,), width=round(3.2 * SS), joint="curve")
        base.alpha_composite(glow.filter(ImageFilter.GaussianBlur(1.6 * SS)))
        ImageDraw.Draw(base).line([(x * SS, y * SS) for x, y in pts], fill=(225, 250, 255, 255), width=round(1.4 * SS), joint="curve")
        return base
    if p["flash"] > 0:
        fl = Image.new("RGBA", base.size, (0, 0, 0, 0))
        r = 10 + p["sep"] * 1.2
        ImageDraw.Draw(fl).ellipse([round((mid - r) * SS), round((mid - r) * SS), round((mid + r) * SS), round((mid + r) * SS)], fill=(190, 240, 255, int(220 * p["flash"])))
        base.alpha_composite(fl.filter(ImageFilter.GaussianBlur(5 * SS)))
    for k, (piece, centre) in enumerate(pieces):
        vx = 1 if centre[0] > mid else -1
        vy = 1 if centre[1] > mid else -1
        off = (vx * p["sep"], vy * p["sep"] * 0.85 + p["sep"] * p["sep"] / 60.0)
        angle = p["turn"] * vx * (1 if vy < 0 else -1)
        base.alpha_composite(place(piece, centre, off, angle, p["scale"], p["alpha"]))
    draw_sparks(base, random.Random(7 + index), p["sparks"], 10 + p["sep"] * 1.4, max(0.0, min(1.0, p["alpha"] + 0.3)))
    return base


def main():
    os.makedirs(OUT_ASSETS, exist_ok=True)
    os.makedirs(OUT_TILE, exist_ok=True)
    box_img = draw_box()
    big = finish(box_img, os.path.join(OUT_ASSETS, "box.png"))
    finish(draw_box(with_question=False), os.path.join(OUT_ASSETS, "box_base.png"))
    finish(draw_question_layer(), os.path.join(OUT_ASSETS, "box_question.png"))
    px = BOX * K
    off = int(O * K)
    tile_src = big.crop((off, off, off + px, off + px)).resize((BOX, BOX), Image.LANCZOS)
    tile = Image.new("RGBA", (70, 70), (0, 0, 0, 0))
    tile.alpha_composite(tile_src, (3, 3))
    tile.save(os.path.join(OUT_TILE, "powerup_box.png"))
    pieces = make_pieces(box_img)
    frames = [big]
    for i in range(len(FRAMES)):
        frames.append(finish(break_frame(i, box_img, pieces), os.path.join(OUT_ASSETS, "box_break_%d.png" % (i + 1))))
    half = CANVAS * K // 2
    sheet = Image.new("RGBA", (half * len(frames), half), (24, 28, 42, 255))
    for i, f in enumerate(frames):
        sheet.alpha_composite(f.resize((half, half), Image.LANCZOS), (i * half, 0))
    sheet.save(os.path.join(OUT_ASSETS, "box_sheet.png"))
    print("frames:", len(frames))


if __name__ == "__main__":
    main()
