"""Draws the creatures that leap out of the deadly pits (besides the robot piranha of generate_pit_hazards.py).

Usage (needs Pillow; from the repo root):  python tools/art/generate_pit_creatures.py [output folder]
(The output folder is assets/levels/common/pit_hazards by default, the same as generate_pit_hazards.py.)

PUFFER     toxic_waste/pit_toxic_waste_puffer_<small|mid|big>.png : a mutant pufferfish, acid green with a pale belly, bone-yellow
           spines and an orange eye. Three frames: deflated, half puffed, fully puffed up; the game inflates it as it leaps.
FIREBALL   lava/pit_lava_ball_<a|b|c>.png : a classic cartoon fireball: a glowing white-yellow head and a comet of layered
           dark-orange, orange and yellow flame streaming back to the left in wavy tongues, with loose embers. Three frames with
           different tongues and embers, flipped through to flicker.
EEL        nuclear_waste/pit_nuclear_waste_eel_<a|b|c|d>.png : a glowing eel, a dark teal body with bright radioactive green
           bands and belly, a frilled fin and a bright eye. Four frames of the body swimming (a travelling S-curve).
All are painted in the same way as the piranha (drawn 8 times bigger and shrunk for clean edges, smooth curved outlines, a dark
outline, a gradient with a light from above, speckles and highlights), so they belong to the same game. They face RIGHT; the game
turns them to follow their leap. The sprites are drawn here with shaded gradients: swap in other art with the same file names
if you find something better.
"""
import math
import os
import random
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import generate_pit_hazards as base  # noqa: E402  (the shared brushes: spline, shaded, with_outline, ...)

SS = base.SS
OUT = base.OUT
spline, scaled, shaded, with_outline, poly_mask = base.spline, base.scaled, base.shaded, base.with_outline, base.poly_mask


def ellipse(d, cx, cy, rx, ry, **kw):
    d.ellipse([(cx - rx) * SS, (cy - ry) * SS, (cx + rx) * SS, (cy + ry) * SS], **kw)


def clip_to(layer, mask):
    out = Image.new("RGBA", layer.size, (0, 0, 0, 0))
    out.paste(layer, (0, 0), mask)
    return out


def soft(layer, radius):
    """A Gaussian blur that does not darken the edges (it is done on premultiplied colours)."""
    return layer.convert("RGBa").filter(ImageFilter.GaussianBlur(radius * SS)).convert("RGBA")


def tube(points, widths):
    """The closed outline of a tube that follows `points` with the given half-widths (a smooth curve is made from it)."""
    left, right = [], []
    n = len(points)
    for i, (x, y) in enumerate(points):
        x0, y0 = points[max(0, i - 1)]
        x1, y1 = points[min(n - 1, i + 1)]
        tx, ty = x1 - x0, y1 - y0
        ln = math.hypot(tx, ty) or 1.0
        nx, ny = -ty / ln, tx / ln
        left.append((x + nx * widths[i], y + ny * widths[i]))
        right.append((x - nx * widths[i], y - ny * widths[i]))
    return left + right[::-1]


# ---------------------------------------------------------------------------------------------------------------- the puffer
PUFFER_FRAMES = [("small", 0.0), ("mid", 0.5), ("big", 1.0)]


def puffer_frame(t):
    """A toxic pufferfish facing right, `t` from 0 (deflated) to 1 (puffed up like a spiky ball)."""
    W, H = 176, 156
    size = (W * SS, H * SS)
    rng = random.Random(5)
    cx, cy = 90, 80
    rx = 43 + 8 * t
    ry = 27 + 25 * t
    # ---- the fins and tail, behind the body
    tail = [(cx - rx + 6, cy - 5), (cx - rx - 14, cy - 22 - 3 * t), (cx - rx - 24, cy - 8), (cx - rx - 24, cy + 8),
            (cx - rx - 14, cy + 22 + 3 * t), (cx - rx + 6, cy + 5)]
    fin_stops = [(0, (214, 224, 92)), (0.55, (122, 176, 52)), (1, (52, 110, 48))]
    tail_layer = shaded(poly_mask(size, spline(tail, 8)), fin_stops, 0.35)
    td = ImageDraw.Draw(tail_layer)
    for k in range(-3, 4):
        td.line(scaled([(cx - rx + 4, cy + k * 1.4), (cx - rx - 22, cy + k * 5.2)]), fill=(40, 80, 36, 190), width=SS)
    dorsal = [(cx - 14, cy - ry + 3), (cx - 24, cy - ry - 12 - 4 * t), (cx - 4, cy - ry - 4), (cx + 10, cy - ry + 3)]
    dorsal_layer = shaded(poly_mask(size, spline(dorsal, 8)), fin_stops, 0.3)
    pect = [(cx + 2, cy + 8 + 8 * t), (cx - 16, cy + 6 + 10 * t), (cx - 14, cy + 22 + 14 * t), (cx + 2, cy + 20 + 12 * t)]
    pect_layer = shaded(poly_mask(size, spline(pect, 8)), fin_stops, 0.3)
    pd = ImageDraw.Draw(pect_layer)
    for k in range(4):
        pd.line(scaled([(cx + 1, cy + 11 + 8 * t + k * 2.6), (cx - 13, cy + 10 + 10 * t + k * 4.4)]), fill=(40, 80, 36, 190), width=SS // 2)

    # ---- the spines (behind the body so only their length shows): bone yellow, dark at the root
    spines = Image.new("RGBA", size, (0, 0, 0, 0))
    sd = ImageDraw.Draw(spines)
    length = 5 + 17 * t
    for k in range(22):
        a = 2 * math.pi * k / 22 + 0.14
        if -0.5 < math.atan2(math.sin(a), math.cos(a)) < 0.5 and False:
            continue
        ca, sa = math.cos(a), math.sin(a)
        if ca > 0.82 and abs(sa) < 0.45:     # none around the mouth
            continue
        bx, by = cx + rx * ca, cy + ry * sa
        # the outward direction of the ellipse at that angle
        ox, oy = ca / rx, sa / ry
        ol = math.hypot(ox, oy)
        ox, oy = ox / ol, oy / ol
        px, py = -oy, ox
        wd = 3.1 + 1.6 * t
        tip = (bx + ox * length, by + oy * length)
        sd.polygon(scaled([(bx + px * wd, by + py * wd), tip, (bx - px * wd, by - py * wd)]), fill=(238, 226, 120, 255))
        sd.polygon(scaled([(bx + px * wd, by + py * wd), (bx + ox * length * 0.55 + px * wd * 0.35, by + oy * length * 0.55 + py * wd * 0.35),
                           (bx - px * wd, by - py * wd)]), fill=(70, 62, 36, 255))
    # ---- the body: dark green back, a bright acid green flank, a pale yellow belly
    pts = []
    for k in range(32):
        a = 2 * math.pi * k / 32
        pts.append((cx + rx * math.cos(a) * (1 + 0.05 * math.cos(a)), cy + ry * math.sin(a)))
    mask = poly_mask(size, spline(pts, 8))
    body = shaded(mask, [(0, (36, 84, 44)), (0.32, (92, 152, 46)), (0.62, (170, 206, 70)), (0.82, (232, 232, 132)), (1, (206, 206, 96))], 0.42)
    blobs = Image.new("RGBA", size, (0, 0, 0, 0))
    bd = ImageDraw.Draw(blobs)
    for _ in range(18):                                          # dark toxic blotches on the back
        bx, by = rng.uniform(cx - rx * 0.8, cx + rx * 0.5), rng.uniform(cy - ry * 0.85, cy - ry * 0.05)
        ellipse(bd, bx, by, rng.uniform(3, 7), rng.uniform(2.4, 5), fill=(24, 62, 34, rng.randint(140, 220)))
    for _ in range(46):                                          # bright speckles
        bx, by = rng.uniform(cx - rx * 0.9, cx + rx * 0.8), rng.uniform(cy - ry * 0.8, cy + ry * 0.3)
        ellipse(bd, bx, by, rng.uniform(0.7, 1.4), rng.uniform(0.7, 1.4), fill=(222, 240, 120, rng.randint(150, 230)))
    body.alpha_composite(clip_to(soft(blobs, 0.4), mask))
    bdr = ImageDraw.Draw(body)
    # the belly line, a gill slit and a few rivet-like warts
    bdr.arc([(cx - rx * 0.95) * SS, (cy - ry * 0.2) * SS, (cx + rx * 0.9) * SS, (cy + ry * 1.0) * SS], 200, 340, fill=(120, 150, 54, 200), width=int(1.4 * SS))
    for k in range(3):
        bdr.arc([(cx + rx * 0.2 - k * 3.5) * SS, (cy - ry * 0.35) * SS, (cx + rx * 0.62 - k * 3.5) * SS, (cy + ry * 0.45) * SS], 110, 250, fill=(26, 56, 34, 255), width=int(1.5 * SS))
    for wx, wy in ((-0.45, -0.55), (-0.1, -0.7), (0.2, -0.62), (-0.62, -0.1), (-0.3, 0.2)):
        ellipse(bdr, cx + rx * wx, cy + ry * wy, 1.9, 1.9, fill=(36, 70, 36, 255))
        ellipse(bdr, cx + rx * wx - 0.4, cy + ry * wy - 0.5, 0.8, 0.8, fill=(206, 232, 130, 255))
    # the mouth: a small beak of two white plates
    mx, my = cx + rx * 0.98, cy + ry * 0.12
    bdr.polygon(scaled([(mx - 4, my - 5), (mx + 5, my - 1), (mx - 4, my)]), fill=(244, 240, 214, 255), outline=base.OUTLINE)
    bdr.polygon(scaled([(mx - 4, my + 5), (mx + 4, my + 1.5), (mx - 4, my)]), fill=(226, 220, 190, 255), outline=base.OUTLINE)
    bdr.line(scaled([(mx - 8, my), (mx + 3, my)]), fill=(24, 40, 30, 255), width=int(1.2 * SS))
    # the big eye
    er = 8.2 + 3.6 * t
    ex, ey = cx + rx * 0.5, cy - ry * 0.28
    ellipse(bdr, ex, ey, er + 1.2, er + 1.2, fill=(22, 30, 34, 255))
    ellipse(bdr, ex, ey, er, er, fill=(255, 196, 44, 255))
    ellipse(bdr, ex + 0.7, ey + 0.4, er * 0.72, er * 0.72, fill=(236, 120, 24, 255))
    bdr.ellipse([(ex + 0.6 - er * 0.2) * SS, (ey - er * 0.62) * SS, (ex + 0.6 + er * 0.2) * SS, (ey + er * 0.62) * SS], fill=(18, 14, 14, 255))   # slit pupil
    ellipse(bdr, ex - er * 0.35, ey - er * 0.4, er * 0.22, er * 0.22, fill=(255, 252, 230, 255))
    bdr.polygon(scaled([(ex - er * 1.2, ey - er * 0.3), (ex + er * 1.1, ey - er * 1.0), (ex + er * 1.0, ey - er * 0.55), (ex - er * 1.0, ey - er * 0.05)]), fill=(34, 74, 40, 255))   # heavy brow

    sprite = Image.new("RGBA", size, (0, 0, 0, 0))
    sprite.alpha_composite(with_outline(tail_layer, 2))
    sprite.alpha_composite(with_outline(dorsal_layer, 2))
    sprite.alpha_composite(with_outline(spines, 1))
    sprite.alpha_composite(with_outline(body, 2))
    sprite.alpha_composite(with_outline(pect_layer, 1))
    return sprite.resize((W, H), Image.LANCZOS)


# ---------------------------------------------------------------------------------------------------------------- the lava ball
LAVA_FRAMES = ["a", "b", "c"]


def lava_ball_frame(variant):
    """A fireball facing right, drawn like the classic cartoon fireball: a glowing white-yellow head and a comet of layered flame
    (dark orange, orange, yellow) streaming back to the left in wavy tongues, with a few loose embers. `variant` 0..2 moves the
    tongues and embers, so flipping through the frames makes the fire flicker."""
    W, H = 250, 124
    size = (W * SS, H * SS)
    rng = random.Random(70 + variant)
    cx, cy, R = 188, 62, 29
    ph = variant * 2.3

    def flame(scale, length, phase, tongues, color, sway=5.0):
        """One layer of flame: it wraps round the front of the head (so the head is the fire's own round nose, not a ball laid on top)
        and streams back to a point, its edges rippling in tongues."""
        n = 44
        r = R * (0.62 + 0.5 * scale)                      # the radius of the rounded front
        top, bottom = [], []
        for i in range(n + 1):
            t = i / n                                     # 0 at the head, 1 at the tip
            x = cx - t * length * scale
            half = r * (1.0 - t) ** 0.85
            ripple_t = 1.0 + 0.26 * math.sin(t * tongues * 2 * math.pi + phase) * min(1.0, t * 2.5)
            ripple_b = 1.0 + 0.26 * math.sin(t * tongues * 2 * math.pi + phase + 2.4) * min(1.0, t * 2.5)
            spike_t = 1.0 + 0.14 * max(0.0, math.sin(t * (tongues + 1) * 2 * math.pi + phase * 1.3)) ** 2
            spike_b = 1.0 + 0.14 * max(0.0, math.sin(t * (tongues + 1) * 2 * math.pi + phase * 1.3 + 1.7)) ** 2
            centre = cy + sway * t * math.sin(t * 4.2 + phase)
            top.append((x, centre - half * ripple_t * spike_t))
            bottom.append((x, centre + half * ripple_b * spike_b))
        nose = [(cx + r * math.sin(a), cy - r * math.cos(a)) for a in [k * math.pi / 10 for k in range(1, 10)]]   # a half circle, top to bottom
        poly = top[::-1] + nose + bottom
        layer = Image.new("RGBA", size, (0, 0, 0, 0))
        ImageDraw.Draw(layer).polygon(scaled(spline(poly, 3)), fill=color)
        return soft(layer, 0.6)

    # ---- the glow around the head
    halo = Image.new("RGBA", size, (0, 0, 0, 0))
    hd = ImageDraw.Draw(halo)
    ellipse(hd, cx, cy, R * 1.9, R * 1.6, fill=(255, 110, 20, 38))
    ellipse(hd, cx - 6, cy, R * 1.45, R * 1.25, fill=(255, 150, 30, 48))
    halo = soft(halo, 7)

    sprite = Image.new("RGBA", size, (0, 0, 0, 0))
    sprite.alpha_composite(halo)
    # ---- the flame: dark orange-red outside, then orange, yellow, and a pale core, each with its own ripples
    sprite.alpha_composite(flame(1.0, 160, ph, 2, (214, 50, 22, 255), 7))
    sprite.alpha_composite(flame(0.86, 142, ph + 1.1, 2, (240, 92, 24, 255), 6))
    sprite.alpha_composite(flame(0.7, 116, ph + 2.2, 2, (255, 150, 34, 255), 5))
    sprite.alpha_composite(flame(0.5, 88, ph + 3.1, 2, (255, 210, 80, 255), 4))
    sprite.alpha_composite(flame(0.3, 60, ph + 4.0, 1, (255, 244, 170, 255), 3))
    # ---- the hot head: white-yellow light that fades into the flame round it (soft steps, blurred, so there is no edge)
    head = Image.new("RGBA", size, (0, 0, 0, 0))
    hdr = ImageDraw.Draw(head)
    for frac, col in ((0.96, (255, 170, 40, 120)), (0.84, (255, 196, 60, 170)), (0.7, (255, 220, 96, 215)), (0.56, (255, 238, 140, 240)),
                      (0.42, (255, 248, 190, 255)), (0.26, (255, 254, 232, 255))):
        ellipse(hdr, cx + (1 - frac) * 3.0, cy, R * frac, R * frac, fill=col)
    sprite.alpha_composite(soft(head, 2.4))
    # ---- loose embers: small red-orange flakes, longer than they are wide, scattered behind the fire
    for _ in range(9):
        ex = rng.uniform(8, cx - R - 20)
        ey = cy + rng.uniform(-R * 1.05, R * 1.05)
        ln = rng.uniform(4.5, 8.5)
        col = rng.choice(((232, 52, 28, 255), (255, 96, 30, 255), (255, 150, 40, 255)))
        ember = [(ex + ln, ey), (ex + ln * 0.2, ey - ln * 0.32), (ex - ln * 0.6, ey - ln * 0.05), (ex + ln * 0.2, ey + ln * 0.3)]
        em = Image.new("RGBA", size, (0, 0, 0, 0))
        ImageDraw.Draw(em).polygon(scaled(spline(ember, 5)), fill=col)
        sprite.alpha_composite(soft(em, 0.4))
    return sprite.resize((W, H), Image.LANCZOS)


# ---------------------------------------------------------------------------------------------------------------- the glowing eel
EEL_FRAMES = ["a", "b", "c", "d"]


def eel_frame(phase):
    """A glowing eel facing right: long and slim, a dark teal body with a bright glowing lateral line and belly, a frill of fin
    along the back, a pointed snout. Its body is an S-curve whose bend travels along it as `phase` (radians) advances."""
    W, H = 232, 100
    size = (W * SS, H * SS)
    n = 56
    head_x, tail_x = 212, 12
    pts, widths = [], []
    for i in range(n):
        u = i / (n - 1)                                    # 0 at the head, 1 at the tail
        x = head_x + (tail_x - head_x) * u
        amp = 6 + 15 * u
        y = 50 + amp * math.sin(u * 2 * math.pi * 1.3 - phase)
        pts.append((x, y))
        widths.append(9.2 - 6.6 * (u ** 1.1) if u > 0.1 else 6.4 + 28 * u)
    widths = [max(1.4, w) for w in widths]

    def normal(i):
        x0, y0 = pts[max(0, i - 1)]
        x1, y1 = pts[min(n - 1, i + 1)]
        tx, ty = x1 - x0, y1 - y0
        ln = math.hypot(tx, ty) or 1.0
        return -ty / ln, tx / ln                           # points to the belly side

    # the frill along the back and round the tail, behind the body
    fin_edge = []
    for i in range(7, n - 1):
        nx, ny = normal(i)
        frill = (5 + 3.0 * math.sin(i * 0.9 + phase * 1.5)) * (1 + 1.6 * max(0, (i - n * 0.8) / (n * 0.2)))
        fin_edge.append((pts[i][0] - nx * (widths[i] + frill), pts[i][1] - ny * (widths[i] + frill)))
    fin_base = [pts[i] for i in range(n - 2, 6, -1)]
    fin = shaded(poly_mask(size, fin_edge + fin_base), [(0, (170, 255, 110)), (0.55, (50, 160, 124)), (1, (18, 74, 78))], 0.3)
    fd = ImageDraw.Draw(fin)
    for i in range(8, n - 2, 3):                           # fin rays
        nx, ny = normal(i)
        j = i - 7
        if j < len(fin_edge):
            fd.line(scaled([pts[i], fin_edge[j]]), fill=(10, 52, 58, 170), width=SS // 2)
    # the body
    mask = poly_mask(size, spline(tube(pts, widths), 4))
    body = shaded(mask, [(0, (8, 34, 44)), (0.38, (18, 80, 84)), (0.7, (50, 160, 108)), (1, (170, 255, 96))], 0.45)
    lines = Image.new("RGBA", size, (0, 0, 0, 0))
    ld = ImageDraw.Draw(lines)
    ld.line(scaled(pts[4:n - 3]), fill=(190, 255, 110, 255), width=int(1.8 * SS))                    # the glowing lateral line
    for i in range(5, n - 4, 2):                           # luminous dots along the belly
        nx, ny = normal(i)
        w = widths[i] * 0.6
        ellipse(ld, pts[i][0] + nx * w, pts[i][1] + ny * w, 1.3, 1.3, fill=(240, 255, 170, 255))
    for i in range(6, n - 6, 5):                           # a few glowing marks across the back
        nx, ny = normal(i)
        w = widths[i]
        ld.line(scaled([(pts[i][0] - nx * w * 0.2, pts[i][1] - ny * w * 0.2), (pts[i][0] - nx * w * 0.9, pts[i][1] - ny * w * 0.9)]), fill=(150, 240, 100, 230), width=int(1.4 * SS))
    body.alpha_composite(clip_to(lines, mask))
    # the head: a pointed snout, a mouth line with small teeth, a bright eye, gill marks
    hx, hy = pts[0]
    head_poly = [(hx + 24, hy + 1.5), (hx + 15, hy - 7), (hx + 1, hy - 11.5), (hx - 14, hy - 9), (hx - 19, hy + 1), (hx - 12, hy + 10.5),
                 (hx + 4, hy + 9.5), (hx + 17, hy + 6)]
    head_mask = poly_mask(size, spline(head_poly, 8))
    head = shaded(head_mask, [(0, (34, 118, 106)), (0.5, (16, 72, 78)), (1, (96, 206, 100))], 0.5)
    body.alpha_composite(head)
    hd = ImageDraw.Draw(body)
    hd.line(scaled([(hx + 22, hy + 3.2), (hx + 8, hy + 5.6), (hx - 6, hy + 4.4)]), fill=(6, 22, 28, 255), width=int(1.3 * SS))
    for k in range(5):
        tx = hx + 19 - k * 3.6
        hd.polygon(scaled([(tx, hy + 3.6), (tx - 1.5, hy + 3.8 + 2.4), (tx - 3.0, hy + 4.4)]), fill=(240, 250, 220, 255))
    for k in range(3):
        hd.arc([(hx - 19 - k * 3) * SS, (hy - 8) * SS, (hx - 5 - k * 3) * SS, (hy + 10) * SS], 100, 260, fill=(8, 44, 52, 255), width=int(1.3 * SS))
    ellipse(hd, hx + 7, hy - 3.5, 4.8, 4.8, fill=(8, 28, 32, 255))
    ellipse(hd, hx + 7, hy - 3.5, 3.9, 3.9, fill=(238, 255, 150, 255))
    ellipse(hd, hx + 7.6, hy - 3.5, 1.8, 2.3, fill=(20, 60, 20, 255))
    ellipse(hd, hx + 6.0, hy - 5.0, 1.0, 1.0, fill=(255, 255, 255, 255))
    # a pectoral fin behind the head
    pf = [(hx - 10, hy + 5), (hx - 24, hy + 15), (hx - 29, hy + 23), (hx - 14, hy + 13)]
    pect = shaded(poly_mask(size, spline(pf, 6)), [(0, (170, 255, 110)), (1, (30, 110, 100))], 0.3)

    # the soft bioluminescent halo, kept inside the sprite (the game adds a brighter copy on top)
    halo = Image.new("RGBA", size, (0, 0, 0, 0))
    ImageDraw.Draw(halo).polygon(scaled(tube(pts, [w + 5 for w in widths])), fill=(120, 255, 90, 130))
    halo = soft(halo, 3.0)

    sprite = Image.new("RGBA", size, (0, 0, 0, 0))
    sprite.alpha_composite(halo)
    sprite.alpha_composite(with_outline(fin, 2))
    sprite.alpha_composite(with_outline(pect, 1))
    sprite.alpha_composite(with_outline(body, 2))
    return sprite.resize((W, H), Image.LANCZOS)


def main():
    out_puffer = os.path.join(OUT, "toxic_waste")
    out_lava = os.path.join(OUT, "lava")
    out_eel = os.path.join(OUT, "nuclear_waste")
    for folder in (out_puffer, out_lava, out_eel):
        os.makedirs(folder, exist_ok=True)
    for name, t in PUFFER_FRAMES:
        puffer_frame(t).save(os.path.join(out_puffer, f"pit_toxic_waste_puffer_{name}.png"))
    for i, name in enumerate(LAVA_FRAMES):
        lava_ball_frame(i).save(os.path.join(out_lava, f"pit_lava_ball_{name}.png"))
    for i, name in enumerate(EEL_FRAMES):
        eel_frame(i * math.pi / 2.0).save(os.path.join(out_eel, f"pit_nuclear_waste_eel_{name}.png"))
    print("wrote pit creatures to", os.path.normpath(OUT))


if __name__ == "__main__":
    main()
