"""Generates the data-center parallax background layers.

Usage (needs Pillow):  python tools/art/generate_background.py assets/backgrounds/data_center

Every layer is 1280px wide and tiles seamlessly on X (Godot repeats it with Parallax2D).
Layers: far.png, mid_base.png, mid_leds_a.png, mid_leds_b.png, cables.png.
The two LED layers are the same racks' bright LEDs split into two random halves;
the game pulses them in opposite phase so the racks look alive.
"""
import os
import random
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter

W, H = 1280, 900
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


# ---------------------------------------------------------------- far layer
def make_far():
    rng = random.Random(7)
    im = vgrad((9, 12, 22), (24, 33, 54))
    d = ImageDraw.Draw(im)

    def rack_row(base_y, h, body, edge, slot, led_dim):
        w, gap = 70, 10  # period 80 divides 1280
        x = 0
        while x < W:
            d.rectangle([x, base_y - h, x + w - 1, base_y], fill=body)
            d.line([(x, base_y - h), (x + w - 1, base_y - h)], fill=edge)
            d.line([(x, base_y - h), (x, base_y)], fill=edge)
            for yy in range(base_y - h + 12, base_y - 6, 14):
                d.line([(x + 6, yy), (x + w - 7, yy)], fill=slot)
                if rng.random() < 0.55:
                    c = pick_led(rng)
                    d.rectangle([x + 9, yy - 5, x + 11, yy - 3], fill=lerp(body[:3], c, led_dim) + (255,))
            x += w + gap

    rack_row(660, 300, (19, 26, 43, 255), (30, 40, 62, 255), (14, 19, 32, 255), 0.35)
    rack_row(790, 340, (25, 34, 55, 255), (40, 54, 82, 255), (17, 23, 38, 255), 0.5)

    # Blue haze rising from the floor
    haze = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    hd = ImageDraw.Draw(haze)
    for y in range(280, H):
        a = int(120 * min(1.0, (y - 280) / 420))
        hd.line([(0, y), (W, y)], fill=(35, 80, 130, a))
    im = Image.alpha_composite(im, haze)

    # Ceiling light panels, light shafts and glow blobs
    shafts = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shafts)
    for k in range(4):
        x0 = 60 + 320 * k
        sd.polygon([(x0, 14), (x0 + 200, 14), (x0 + 300, 700), (x0 - 100, 700)], fill=(130, 180, 255, 20))
    im = Image.alpha_composite(im, shafts.filter(ImageFilter.GaussianBlur(14)))
    blobs = [(160 + 320 * k, 20, 90, (150, 200, 255, 120)) for k in range(4)]
    blobs += [(60 + 320 * k, 560, 120, (30, 90, 160, 55)) for k in range(4)]
    im = Image.alpha_composite(im, glow_layer(blobs, 40))
    d = ImageDraw.Draw(im)
    for k in range(4):
        x0 = 60 + 320 * k
        d.rectangle([x0, 0, x0 + 199, 12], fill=(205, 225, 255, 255))
    im.convert("RGB").save(os.path.join(OUT, "far.png"))


# ---------------------------------------------------------------- mid layer
def make_mid():
    rng = random.Random(21)
    base = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(base)
    bright = {"a": [], "b": []}

    RW = 160
    TOP = 250

    def draw_rack(x):
        # Body with a vertical gradient
        for y in range(TOP, H):
            c = lerp((38, 47, 68), (22, 28, 42), (y - TOP) / (H - TOP))
            d.line([(x, y), (x + RW - 1, y)], fill=c + (255,))
        d.rectangle([x, TOP, x + 5, H], fill=(12, 15, 24, 255))
        d.rectangle([x + RW - 6, TOP, x + RW - 1, H], fill=(12, 15, 24, 255))
        d.line([(x + 7, TOP), (x + 7, H)], fill=(78, 94, 126, 255), width=2)
        # Top plate + cable stubs
        d.rectangle([x, TOP - 14, x + RW - 1, TOP + 10], fill=(27, 33, 49, 255))
        d.line([(x, TOP - 14), (x + RW - 1, TOP - 14)], fill=(70, 85, 115, 255))
        for i in range(5):
            cx = x + 20 + i * 28
            col = [(240, 138, 36), (58, 150, 230), (16, 20, 30), (240, 138, 36), (16, 20, 30)][i]
            d.rectangle([cx, TOP - 40, cx + 7, TOP - 14], fill=col + (255,))
        # Server units
        for y in range(TOP + 30, H - 20, 40):
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

    for period in (0, 640):
        for rx in (0, 160, 480):  # rack, rack, gap, rack
            draw_rack(period + rx)

    base.save(os.path.join(OUT, "mid_base.png"))

    for key, leds in bright.items():
        core = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        cd = ImageDraw.Draw(core)
        halo = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        hd = ImageDraw.Draw(halo)
        for x, y, c in leds:
            cd.rectangle([x - 3, y - 3, x + 3, y + 3], fill=c + (255,))
            hd.ellipse([x - 11, y - 11, x + 11, y + 11], fill=c + (110,))
        halo = halo.filter(ImageFilter.GaussianBlur(5))
        Image.alpha_composite(halo, core).save(os.path.join(OUT, f"mid_leds_{key}.png"))


# -------------------------------------------------------------- cables layer
def make_cables():
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)

    # Hanging cable bundles (endpoints sit on period boundaries -> seamless)
    specs = [
        (0, 640, 130, (240, 138, 36), 7, 36),
        (0, 640, 95, (58, 150, 230), 6, 40),
        (60, 580, 170, (14, 18, 28), 11, 34),
        (200, 640, 115, (220, 60, 60), 5, 38),
        (0, 420, 80, (14, 18, 28), 8, 36),
    ]
    for p in (0, 640):
        for x0, x1, sag, col, wd, yb in specs:
            pts = []
            for i in range(41):
                t = i / 40
                pts.append((p + x0 + t * (x1 - x0), yb + sag * 4 * t * (1 - t)))
            d.line(pts, fill=col + (255,), width=wd, joint="curve")

    # Ceiling cable tray
    d.rectangle([0, 0, W, 34], fill=(16, 20, 32, 255))
    d.line([(0, 34), (W, 34)], fill=(52, 66, 96, 255), width=3)
    for x in range(10, W, 40):
        d.rectangle([x, 12, x + 20, 20], fill=(32, 40, 60, 255))

    # Support columns (one per tile, wrapping around the seam)
    for x0 in (0, W - 18):
        d.rectangle([x0, 0, x0 + 17, H], fill=(13, 17, 27, 255))
        d.line([(x0 + (2 if x0 == 0 else 15), 0), (x0 + (2 if x0 == 0 else 15), H)], fill=(44, 57, 84, 255), width=2)
    for y in range(120, H, 180):  # hazard bands on the columns
        for x0 in (0, W - 18):
            d.rectangle([x0, y, x0 + 17, y + 14], fill=(245, 197, 24, 255))
            for s in range(0, 18, 8):
                d.polygon([(x0 + s, y), (x0 + s + 4, y), (x0 + s + 8, y + 14), (x0 + s + 4, y + 14)], fill=(20, 20, 24, 255))
    im.save(os.path.join(OUT, "cables.png"))


if __name__ == "__main__":
    make_far()
    make_mid()
    make_cables()
    print("wrote layers to", OUT)
