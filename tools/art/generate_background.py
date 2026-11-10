"""Generates the data-center parallax background layers.

Usage (needs Pillow):  python tools/art/generate_background.py assets/backgrounds/data_center

Every layer is 1280px wide and tiles seamlessly on X, and is one STOREY tall (H px) and tiles on Y too
(Godot repeats it with Parallax2D). A storey is a hall with a floor slab: server racks stand on the floor,
a gantry with stairs and support columns shows the layout of the rest of the data center, and the
underside of the slab above is the ceiling. Because every rack stands on a floor inside the image,
nothing ever floats, wherever the camera is. scripts/level/background.gd must use the same W and H.

Layers: far.png, mid_base.png, mid_leds_a.png, mid_leds_b.png, cables.png.
The two LED layers are the same racks' bright LEDs split into two random halves;
the game pulses them in opposite phase so the racks look alive.
"""
import os
import random
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter

W, H = 1280, 700
# Where the floor top sits inside each layer's image (y in px from the top). The far floor is higher up the
# image than the mid one: further-away floors rise towards the horizon, which gives depth.
FAR_FLOOR = 520
MID_FLOOR = 600
SLAB = 34   # thickness of a floor slab as seen edge-on
# Depth of field: blur radius (px) per layer. The further the layer, the blurrier, so the
# gameplay plane in front stays crisp and the background recedes.
BLUR_FAR = 1.8
BLUR_MID = 2.4
BLUR_NEAR = 1.0
OUT = sys.argv[1] if len(sys.argv) > 1 else "assets/backgrounds/data_center"
os.makedirs(OUT, exist_ok=True)

LED_COLORS = [
    ((46, 230, 107), 0.72),   # green
    ((58, 208, 255), 0.12),   # cyan
    ((240, 138, 36), 0.10),   # orange
    ((255, 77, 77), 0.06),    # red
]


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(len(a)))


def vgrad(top, bottom, size=(W, H)):
    im = Image.new("RGBA", size)
    d = ImageDraw.Draw(im)
    for y in range(size[1]):
        d.line([(0, y), (size[0], y)], fill=lerp(top, bottom, y / (size[1] - 1)) + (255,))
    return im


def wrap_blur(im, radius):
    """Gaussian blur that wraps on X (so the layer still tiles seamlessly) and is
    alpha-aware (premultiplied) so transparent edges don't get dark fringes.
    Used for depth-of-field: the further a layer, the blurrier."""
    mode = im.mode
    w, h = im.size
    work = im.convert("RGBa") if mode == "RGBA" else im
    tiled = Image.new(work.mode, (w * 3, h))
    for i in range(3):
        tiled.paste(work, (i * w, 0))
    tiled = tiled.filter(ImageFilter.GaussianBlur(radius)).crop((w, 0, 2 * w, h))
    return tiled.convert("RGBA") if mode == "RGBA" else tiled


def pick_led(rng):
    r, acc = rng.random(), 0.0
    for color, p in LED_COLORS:
        acc += p
        if r <= acc:
            return color
    return LED_COLORS[0][0]


def wrapped(draw_fn):
    """Call draw_fn(x_offset) at -W, 0, +W so blurred glows wrap seamlessly."""
    for ox in (-W, 0, W):
        draw_fn(ox)


def glow_layer(blobs, blur):
    """blobs: list of (x, y, radius, rgba). Returns a blurred RGBA layer (wraps on X)."""
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)

    def draw(ox):
        for x, y, r, col in blobs:
            d.ellipse([x + ox - r, y - r, x + ox + r, y + r], fill=col)

    wrapped(draw)
    return layer.filter(ImageFilter.GaussianBlur(blur))


def slab(d, floor_y, edge, face, under, hi):
    """A floor slab seen edge-on: top edge at floor_y, a front face, then dark underside beams."""
    d.rectangle([0, floor_y, W, floor_y + SLAB], fill=face)
    d.line([(0, floor_y), (W, floor_y)], fill=hi, width=2)
    d.line([(0, floor_y + SLAB), (W, floor_y + SLAB)], fill=edge, width=2)
    d.rectangle([0, floor_y + SLAB + 1, W, H], fill=under)
    for x in range(0, W, 160):  # underside I-beams, every 160 px (divides W so the tile stays seamless)
        d.rectangle([x + 70, floor_y + SLAB + 1, x + 90, H], fill=edge)
        d.rectangle([x + 58, floor_y + SLAB + 1, x + 102, floor_y + SLAB + 7], fill=face)
    for x in range(0, W, 80):   # warning ticks along the slab's front face
        d.rectangle([x + 8, floor_y + 10, x + 22, floor_y + 16], fill=(120, 96, 30, 255))


# ---------------------------------------------------------------- far layer
def make_far():
    rng = random.Random(7)
    im = vgrad((8, 11, 20), (20, 28, 48))
    d = ImageDraw.Draw(im)

    # A distant floor plane: racks stand on it (their bottoms are inside it), so they read as grounded.
    for y in range(FAR_FLOOR, FAR_FLOOR + 70):
        d.line([(0, y), (W, y)], fill=lerp((34, 50, 80), (22, 32, 54), (y - FAR_FLOOR) / 70) + (255,))

    def rack_row(base_y, h, body, edge, slot, led_dim):
        w, gap = 70, 10  # period 80 divides 1280
        x = 0
        while x < W:
            d.rectangle([x, base_y - h, x + w - 1, base_y], fill=body)
            d.line([(x, base_y - h), (x + w - 1, base_y - h)], fill=edge)
            d.line([(x, base_y - h), (x, base_y)], fill=edge)
            d.rectangle([x, base_y - 4, x + w - 1, base_y], fill=(8, 11, 19, 255))  # dark plinth
            for yy in range(base_y - h + 12, base_y - 10, 14):
                d.line([(x + 6, yy), (x + w - 7, yy)], fill=slot)
                if rng.random() < 0.55:
                    c = pick_led(rng)
                    d.rectangle([x + 9, yy - 5, x + 11, yy - 3], fill=lerp(body[:3], c, led_dim) + (255,))
            x += w + gap

    rack_row(FAR_FLOOR + 8, 250, (19, 26, 43, 255), (30, 40, 62, 255), (14, 19, 32, 255), 0.35)   # back row
    rack_row(FAR_FLOOR + 34, 270, (25, 34, 55, 255), (40, 54, 82, 255), (17, 23, 38, 255), 0.5)   # front row

    # The slab the far floor sits on, and the dark underside that is the ceiling of the storey below.
    slab(d, FAR_FLOOR + 70, (10, 14, 24, 255), (16, 22, 38, 255), (9, 12, 21, 255), (52, 70, 104, 255))

    # Blue haze rising from the floor
    haze = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    hd = ImageDraw.Draw(haze)
    for y in range(180, FAR_FLOOR + 70):
        a = int(110 * min(1.0, (y - 180) / 340))
        hd.line([(0, y), (W, y)], fill=(35, 80, 130, a))
    im = Image.alpha_composite(im, haze)

    # Ceiling light panels, light shafts and glow blobs
    shafts = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shafts)
    for k in range(4):
        x0 = 60 + 320 * k
        sd.polygon([(x0, 14), (x0 + 200, 14), (x0 + 300, FAR_FLOOR), (x0 - 100, FAR_FLOOR)], fill=(130, 180, 255, 20))
    im = Image.alpha_composite(im, shafts.filter(ImageFilter.GaussianBlur(14)))
    blobs = [(160 + 320 * k, 20, 90, (150, 200, 255, 120)) for k in range(4)]
    blobs += [(60 + 320 * k, FAR_FLOOR - 80, 120, (30, 90, 160, 55)) for k in range(4)]
    im = Image.alpha_composite(im, glow_layer(blobs, 40))
    d = ImageDraw.Draw(im)
    for k in range(4):
        x0 = 60 + 320 * k
        d.rectangle([x0, 0, x0 + 199, 12], fill=(205, 225, 255, 255))
    wrap_blur(im.convert("RGB"), BLUR_FAR).save(os.path.join(OUT, "far.png"))


# ---------------------------------------------------------------- mid layer
def make_mid():
    rng = random.Random(21)
    base = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(base)
    bright = {"a": [], "b": []}

    RW = 160
    RH = 300
    TOP = MID_FLOOR - RH
    GANTRY = MID_FLOOR - 400          # y of the walkway deck's top
    EDGE, FACE, HI = (12, 15, 24, 255), (30, 38, 58, 255), (78, 94, 126, 255)

    slab(d, MID_FLOOR, EDGE, FACE, (14, 18, 29, 255), HI)

    def draw_rack(x):
        for y in range(TOP, MID_FLOOR):
            c = lerp((38, 47, 68), (22, 28, 42), (y - TOP) / (MID_FLOOR - TOP))
            d.line([(x, y), (x + RW - 1, y)], fill=c + (255,))
        d.rectangle([x, TOP, x + 5, MID_FLOOR], fill=(12, 15, 24, 255))
        d.rectangle([x + RW - 6, TOP, x + RW - 1, MID_FLOOR], fill=(12, 15, 24, 255))
        d.line([(x + 7, TOP), (x + 7, MID_FLOOR)], fill=HI, width=2)
        # Top plate + cable stubs
        d.rectangle([x, TOP - 14, x + RW - 1, TOP + 10], fill=(27, 33, 49, 255))
        d.line([(x, TOP - 14), (x + RW - 1, TOP - 14)], fill=(70, 85, 115, 255))
        for i in range(5):
            cx = x + 20 + i * 28
            col = [(240, 138, 36), (58, 150, 230), (16, 20, 30), (240, 138, 36), (16, 20, 30)][i]
            d.rectangle([cx, TOP - 40, cx + 7, TOP - 14], fill=col + (255,))
        # Server units
        for y in range(TOP + 30, MID_FLOOR - 26, 40):
            d.rectangle([x + 14, y, x + RW - 15, y + 33], fill=(41, 52, 78, 255), outline=(17, 22, 34, 255))
            d.rectangle([x + 14, y, x + RW - 15, y + 2], fill=(62, 76, 108, 255))
            for v in range(6):
                d.line([(x + 92 + v * 8, y + 8), (x + 92 + v * 8, y + 26)], fill=(24, 30, 46, 255), width=2)
            for i in range(4):
                color = pick_led(rng)
                lx, ly = x + 24 + i * 13, y + 13
                dim = lerp((41, 52, 78), color, 0.28) + (255,)
                d.rectangle([lx, ly, lx + 6, ly + 6], fill=dim)
                if rng.random() < 0.7:  # this LED is "active"
                    bright["a" if rng.random() < 0.5 else "b"].append((lx + 3, ly + 3, color))
        # Base plinth: the rack sits ON the floor, with a dark contact line
        d.rectangle([x - 2, MID_FLOOR - 14, x + RW + 1, MID_FLOOR], fill=(12, 15, 24, 255))
        d.line([(x - 2, MID_FLOOR - 14), (x + RW + 1, MID_FLOOR - 14)], fill=(52, 66, 96, 255))

    # Rack groups: A (0-320), a gap with the stairs (320-560), B (560-880), a gap with columns, C (1040-1200)
    for rx in (0, 160, 560, 720, 1040):
        draw_rack(rx)

    # Gantry: an elevated walkway over rack group B, with a railing, reached by the stairs from the floor
    gx0, gx1 = 556, 1044
    d.rectangle([gx0, GANTRY, gx1, GANTRY + 8], fill=(58, 72, 102, 255))           # deck
    d.line([(gx0, GANTRY), (gx1, GANTRY)], fill=(120, 140, 184, 255), width=2)
    d.rectangle([gx0, GANTRY + 9, gx1, GANTRY + 20], fill=(20, 26, 40, 255))        # underside beam
    for x in range(gx0 + 6, gx1, 12):                                               # grating ticks
        d.line([(x, GANTRY + 10), (x, GANTRY + 19)], fill=(40, 50, 74, 255))
    for x in range(gx0 + 4, gx1, 48):                                               # railing posts
        d.rectangle([x, GANTRY - 46, x + 3, GANTRY], fill=(90, 106, 140, 255))
    d.line([(gx0, GANTRY - 46), (gx1, GANTRY - 46)], fill=(120, 140, 184, 255), width=3)
    d.line([(gx0, GANTRY - 24), (gx1, GANTRY - 24)], fill=(70, 86, 118, 255), width=2)
    # Support columns down to the floor (in the gaps between racks), with base plates and cross braces
    for cx in (900, 1018):
        d.rectangle([cx, GANTRY + 21, cx + 16, MID_FLOOR], fill=(36, 46, 68, 255))
        d.line([(cx + 2, GANTRY + 21), (cx + 2, MID_FLOOR)], fill=HI, width=2)
        d.rectangle([cx - 8, MID_FLOOR - 8, cx + 24, MID_FLOOR], fill=(14, 18, 29, 255))   # base plate
    for y in range(GANTRY + 40, MID_FLOOR - 40, 90):                                       # X braces between the columns
        d.line([(916, y), (1018, y + 80)], fill=(30, 38, 58, 255), width=3)
        d.line([(1018, y), (916, y + 80)], fill=(30, 38, 58, 255), width=3)
    # Lights under the gantry
    for x in range(580, 1030, 90):
        d.rectangle([x, GANTRY + 21, x + 30, GANTRY + 25], fill=(160, 200, 255, 255))

    # Stairs from the floor up to the gantry, in the gap between rack groups A and B
    sx0, sx1 = 334, 556
    steps = 14
    dx, dy = (sx1 - sx0) / steps, (MID_FLOOR - GANTRY) / steps
    d.polygon([(sx0, MID_FLOOR), (sx1, GANTRY), (sx1, MID_FLOOR)], fill=(18, 23, 36, 255))  # dark mass under the flight
    for i in range(steps):
        x = sx0 + i * dx
        y = MID_FLOOR - (i + 1) * dy
        d.rectangle([x, y, x + dx + 1, y + 5], fill=(88, 106, 142, 255))                   # tread
        d.rectangle([x, y + 5, x + dx + 1, y + dy], fill=(30, 38, 58, 255))                # riser
    d.line([(sx0, MID_FLOOR - 4), (sx1, GANTRY - 2)], fill=(12, 15, 24, 255), width=7)       # stringer
    d.line([(sx0, MID_FLOOR - 52), (sx1, GANTRY - 52)], fill=(120, 140, 184, 255), width=3)  # handrail
    for i in range(0, steps + 1, 2):
        x = sx0 + i * dx
        y = MID_FLOOR - max(i, 1) * dy
        d.line([(x, y - 2), (x, y - 50)], fill=(90, 106, 140, 255), width=3)

    # A small cart with crates parked at the end of the aisle
    d.rectangle([1214, MID_FLOOR - 26, 1270, MID_FLOOR - 8], fill=(52, 64, 92, 255), outline=(14, 18, 28, 255))
    d.rectangle([1222, MID_FLOOR - 46, 1250, MID_FLOOR - 26], fill=(150, 104, 40, 255), outline=(14, 18, 28, 255))
    for wx in (1222, 1260):
        d.ellipse([wx - 6, MID_FLOOR - 12, wx + 6, MID_FLOOR], fill=(12, 15, 24, 255))

    wrap_blur(base, BLUR_MID).save(os.path.join(OUT, "mid_base.png"))

    for key, leds in bright.items():
        core = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        cd = ImageDraw.Draw(core)
        halo = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        hd = ImageDraw.Draw(halo)
        for x, y, c in leds:
            cd.rectangle([x - 3, y - 3, x + 3, y + 3], fill=c + (255,))
            hd.ellipse([x - 11, y - 11, x + 11, y + 11], fill=c + (110,))
        halo = halo.filter(ImageFilter.GaussianBlur(5))
        wrap_blur(Image.alpha_composite(halo, core), BLUR_MID).save(os.path.join(OUT, f"mid_leds_{key}.png"))


# -------------------------------------------------------------- cables layer
def make_cables():
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)

    # Hanging cable bundles (endpoints sit on period boundaries -> seamless)
    specs = [
        (0, 640, 80, (240, 138, 36), 7, 36),
        (0, 640, 60, (58, 150, 230), 6, 40),
        (60, 580, 100, (14, 18, 28), 11, 34),
        (200, 640, 70, (220, 60, 60), 5, 38),
        (0, 420, 50, (14, 18, 28), 8, 36),
    ]
    for p in (0, 640):
        for x0, x1, sag, col, wd, yb in specs:
            pts = []
            for i in range(41):
                t = i / 40
                pts.append((p + x0 + t * (x1 - x0), yb + sag * 4 * t * (1 - t)))
            d.line(pts, fill=col + (255,), width=wd, joint="curve")

    # Ceiling cable tray (under the slab above)
    d.rectangle([0, 0, W, 34], fill=(16, 20, 32, 255))
    d.line([(0, 34), (W, 34)], fill=(52, 66, 96, 255), width=3)
    for x in range(10, W, 40):
        d.rectangle([x, 12, x + 20, 20], fill=(32, 40, 60, 255))

    # Support columns (one per tile, wrapping around the seam), floor to ceiling
    for x0 in (0, W - 18):
        d.rectangle([x0, 0, x0 + 17, H], fill=(13, 17, 27, 255))
        d.line([(x0 + (2 if x0 == 0 else 15), 0), (x0 + (2 if x0 == 0 else 15), H)], fill=(44, 57, 84, 255), width=2)
    for y in range(120, H - 20, 180):  # hazard bands on the columns
        for x0 in (0, W - 18):
            d.rectangle([x0, y, x0 + 17, y + 14], fill=(245, 197, 24, 255))
            for s in range(0, 18, 8):
                d.polygon([(x0 + s, y), (x0 + s + 4, y), (x0 + s + 8, y + 14), (x0 + s + 4, y + 14)], fill=(20, 20, 24, 255))
    wrap_blur(im, BLUR_NEAR).save(os.path.join(OUT, "cables.png"))


if __name__ == "__main__":
    make_far()
    make_mid()
    make_cables()
    print("wrote layers to", OUT)
