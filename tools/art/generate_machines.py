"""Generates the data-center machines used as foreground decor.

Usage (needs Pillow):  python tools/art/generate_machines.py assets/machines/data_center

Each machine writes three PNGs:
  <name>.png          the machine
  <name>_leds_a.png   bright LEDs / screen glow (first half), pulsed by the game
  <name>_leds_b.png   bright LEDs / screen glow (second half), pulsed in the other phase
Sizes are multiples of the 70px tile so they drop onto the level grid:
  machine_gpu_rack 140x210 (2x3), machine_supercomputer 210x210 (3x3),
  machine_monitoring_station 210x140 (3x2), machine_server_tower 70x210 (1x3).
"""
import math
import os
import random
import sys

from PIL import Image, ImageDraw, ImageFilter

OUT = sys.argv[1] if len(sys.argv) > 1 else "assets/machines/data_center"
os.makedirs(OUT, exist_ok=True)
SS = 3

EDGE = (12, 15, 24)
BODY_TOP = (40, 50, 72)
BODY_BOT = (22, 28, 42)
LIP = (78, 94, 126)
HI = (130, 152, 196)
CYAN = (58, 208, 255)
GREEN = (46, 230, 107)
ORANGE = (240, 138, 36)
RED = (255, 77, 77)
LED_CHOICES = [(GREEN, 0.62), (CYAN, 0.2), (ORANGE, 0.12), (RED, 0.06)]


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(len(a)))


def pick_led(rng):
    r, acc = rng.random(), 0.0
    for c, p in LED_CHOICES:
        acc += p
        if r <= acc:
            return c
    return GREEN


def new(w, h):
    return Image.new("RGBA", (w * SS, h * SS), (0, 0, 0, 0))


def fin(im):
    return im.resize((im.width // SS, im.height // SS), Image.LANCZOS)


def R(d, x0, y0, x1, y1, fill):
    d.rectangle([round(x0 * SS), round(y0 * SS), round(x1 * SS) - 1, round(y1 * SS) - 1], fill=fill)


def C(d, cx, cy, r, fill):
    d.ellipse([(cx - r) * SS, (cy - r) * SS, (cx + r) * SS, (cy + r) * SS], fill=fill)


def LN(d, pts, fill, width=1.0):
    d.line([(x * SS, y * SS) for x, y in pts], fill=fill, width=max(1, int(width * SS)))


def grad(d, x0, y0, x1, y1, top, bot):
    n = round((y1 - y0) * SS)
    for i in range(n):
        y = round(y0 * SS) + i
        d.line([(round(x0 * SS), y), (round(x1 * SS) - 1, y)], fill=lerp(top, bot, i / max(1, n - 1)) + (255,))


def cabinet(d, w, h):
    grad(d, 0, 0, w, h, BODY_TOP, BODY_BOT)
    R(d, 0, 0, w, 3, LIP + (255,))
    R(d, 0, 0, w, 1.2, HI + (255,))
    R(d, 0, 0, 3, h, EDGE + (255,))
    R(d, w - 3, 0, w, h, EDGE + (255,))
    R(d, 3, 3, 4.4, h, (70, 86, 118, 255))
    R(d, 0, h - 8, w, h, (14, 18, 28, 255))
    R(d, 0, h - 8, w, h - 6.6, (52, 64, 92, 255))


def overlays(name, size, leds, panels, seed):
    """Split LEDs/panels into two pulse groups and write the bright overlay images."""
    rng = random.Random(seed)
    groups = {"a": ([], []), "b": ([], [])}
    for led in leds:
        groups[rng.choice("ab")][0].append(led)
    for i, p in enumerate(panels):
        groups["ab"[i % 2]][1].append(p)
    w, h = size
    for key, (gl, gp) in groups.items():
        core = new(w, h)
        halo = new(w, h)
        cd, hd = ImageDraw.Draw(core), ImageDraw.Draw(halo)
        for x, y, c in gl:
            R(cd, x - 2, y - 2, x + 2, y + 2, c + (255,))
            C(hd, x, y, 8, c + (105,))
        for x0, y0, x1, y1, c, a in gp:
            R(cd, x0, y0, x1, y1, c + (a,))
            R(hd, x0 - 2, y0 - 2, x1 + 2, y1 + 2, c + (a // 2,))
        halo = halo.filter(ImageFilter.GaussianBlur(5 * SS / 2))
        Image.alpha_composite(halo, core).resize((w, h), Image.LANCZOS).save(os.path.join(OUT, f"{name}_leds_{key}.png"))


def save(name, im):
    base = fin(im)
    base.save(os.path.join(OUT, f"{name}.png"))
    shadow(name, base)


def shadow(name, base, pad=20, blur=7, strength=0.75):
    """Soft black silhouette (padded so the blur isn't clipped). The game draws it offset
    behind the machine so it casts a shadow onto the wall and separates it from the background."""
    w, h = base.size
    black = Image.new("RGBA", (w, h), (0, 0, 0, 255))
    black.putalpha(base.getchannel("A"))
    layer = Image.new("RGBA", (w + 2 * pad, h + 2 * pad), (0, 0, 0, 0))
    layer.paste(black, (pad, pad), black)
    layer = layer.filter(ImageFilter.GaussianBlur(blur))
    layer.putalpha(layer.getchannel("A").point(lambda v: int(v * strength)))
    layer.save(os.path.join(OUT, f"{name}_shadow.png"))


# ------------------------------------------------------------------ GPU rack (140x210)
def gpu_rack():
    W, H = 140, 210
    im = new(W, H)
    d = ImageDraw.Draw(im)
    rng = random.Random(3)
    leds = []
    cabinet(d, W, H)
    # Top vent panel + accent
    R(d, 9, 7, 131, 17, (20, 26, 40, 255))
    for x in range(14, 128, 8):
        R(d, x, 9, x + 4, 15, (10, 13, 22, 255))
    R(d, 9, 19, 131, 21.4, ORANGE + (255,))
    # GPU server units
    for i in range(6):
        y = 27 + i * 26.5
        R(d, 9, y, 131, y + 23, (14, 18, 28, 255))
        R(d, 10, y + 1, 130, y + 22, (29, 37, 57, 255))
        R(d, 10, y + 1, 130, y + 2.6, (50, 63, 92, 255))
        for fx in (27, 55):  # fans
            cy = y + 12
            C(d, fx, cy, 9.8, (10, 13, 22, 255))
            C(d, fx, cy, 8.4, (22, 28, 44, 255))
            for k in range(6):
                a = math.radians(k * 60 + i * 11)
                LN(d, [(fx, cy), (fx + 7.2 * math.cos(a), cy + 7.2 * math.sin(a))], (74, 92, 128, 255), 2.0)
            C(d, fx, cy, 2.2, (104, 124, 162, 255))
        for gx in range(80, 118, 3):  # heatsink grille
            R(d, gx, y + 4, gx + 1.4, y + 19, (18, 23, 36, 255))
        leds.append((124, y + 7, pick_led(rng)))
        leds.append((124, y + 16, pick_led(rng)))
    # Cable bundle down the right side
    for cx, col in ((133, (200, 108, 28)), (136, (44, 118, 190))):
        R(d, cx, 24, cx + 2, 192, col + (255,))
    for y in range(34, 190, 30):
        R(d, 131.6, y, 138.4, y + 3, (18, 22, 34, 255))
    # Plinth vents
    for x in range(20, 120, 12):
        R(d, x, H - 5.2, x + 7, H - 2.4, (8, 10, 18, 255))
    save("machine_gpu_rack", im)
    overlays("machine_gpu_rack", (W, H), leds, [], 11)


# ------------------------------------------------------------------ Supercomputer (210x210)
def supercomputer():
    W, H = 210, 210
    im = new(W, H)
    d = ImageDraw.Draw(im)
    rng = random.Random(5)
    leds, panels = [], []
    cabinet(d, W, H)
    # Status display with live bar graph
    R(d, 12, 12, 198, 60, (60, 74, 104, 255))
    R(d, 13.5, 13.5, 196.5, 58.5, (9, 14, 26, 255))
    for gy in (28, 40, 52):
        R(d, 15, gy, 195, gy + 0.6, (24, 36, 60, 255))
    for i in range(26):
        x = 17 + i * 6.8
        hgt = 7 + rng.random() * 30
        top = 56 - hgt
        R(d, x, top, x + 4.6, 56, lerp((24, 110, 150), CYAN, hgt / 37) + (255,))
        if hgt > 31:
            R(d, x, top, x + 4.6, top + 2.4, ORANGE + (255,))
    panels.append((14, 14, 196, 58, CYAN, 46))
    # Three perforated doors
    doors = [(12, 72), (75, 135), (138, 198)]
    for x0, x1 in doors:
        R(d, x0, 67, x1, 189, (13, 17, 27, 255))
        R(d, x0 + 1.2, 68.2, x1 - 1.2, 187.8, (31, 39, 60, 255))
        R(d, x0 + 1.2, 68.2, x1 - 1.2, 70, (52, 66, 96, 255))
        for py in range(76, 184, 6):
            for px in range(int(x0 + 6), int(x1 - 8), 6):
                C(d, px + (3 if (py // 6) % 2 else 0), py, 1.2, (16, 21, 33, 255))
        R(d, x1 - 7, 112, x1 - 4, 146, (98, 114, 148, 255))
        R(d, x1 - 7, 112, x1 - 5.8, 146, (150, 168, 204, 255))
    # LED strips in the gaps between doors
    for gx in (73.5, 136.5):
        R(d, gx - 1.5, 68, gx + 1.5, 188, (10, 13, 22, 255))
        for y in range(75, 184, 11):
            leds.append((gx, y, pick_led(rng)))
    # Coolant pipes + underglow
    R(d, 12, 194, 198, 196, CYAN + (255,))
    panels.append((12, 194, 198, 196, CYAN, 220))
    for y, col in ((198, (36, 108, 186)), (203, (28, 86, 154))):
        R(d, 8, y, 202, y + 3.6, col + (255,))
        R(d, 8, y, 202, y + 1.2, lerp(col, (160, 210, 255), 0.55) + (255,))
    save("machine_supercomputer", im)
    overlays("machine_supercomputer", (W, H), leds, panels, 17)


# ------------------------------------------------------------------ Monitoring station (210x140)
def monitoring_station():
    W, H = 210, 140
    im = new(W, H)
    d = ImageDraw.Draw(im)
    rng = random.Random(9)
    leds, panels = [], []

    def monitor(x0, y0, x1, y1, kind):
        R(d, x0, y0, x1, y1, (12, 16, 26, 255))
        R(d, x0 + 1, y0 + 1, x1 - 1, y1 - 1, (54, 68, 100, 255))
        sx0, sy0, sx1, sy1 = x0 + 4, y0 + 4, x1 - 4, y1 - 4
        R(d, sx0, sy0, sx1, sy1, (8, 15, 30, 255))
        for gy in range(int(sy0) + 8, int(sy1), 10):
            R(d, sx0, gy, sx1, gy + 0.6, (22, 36, 62, 255))
        w, h = sx1 - sx0, sy1 - sy0
        if kind == "line":
            y, pts = h * 0.5, []
            for i in range(16):
                y = max(4, min(h - 4, y + rng.uniform(-8, 8)))
                pts.append((sx0 + i * w / 15, sy0 + y))
            LN(d, pts, CYAN + (255,), 1.6)
            panels.append((sx0, sy0, sx1, sy1, CYAN, 42))
        elif kind == "heat":
            cols, rows = 7, 5
            for cx in range(cols):
                for cy in range(rows):
                    c = rng.choice([(36, 120, 70), (46, 190, 96), (176, 108, 28), (30, 90, 56), (150, 56, 56)])
                    cw, ch = w / cols, h / rows
                    R(d, sx0 + cx * cw + 1, sy0 + cy * ch + 1, sx0 + (cx + 1) * cw - 1, sy0 + (cy + 1) * ch - 1, c + (255,))
            panels.append((sx0, sy0, sx1, sy1, GREEN, 36))
        else:
            pts = [(sx0 + i * w / 40, sy0 + h * 0.45 + math.sin(i * 0.9) * h * 0.22 * rng.uniform(0.6, 1.2)) for i in range(41)]
            LN(d, pts, ORANGE + (255,), 1.6)
            for i in range(10):
                bh = rng.uniform(3, h * 0.25)
                R(d, sx0 + 3 + i * (w - 6) / 10, sy1 - 2 - bh, sx0 + 3 + i * (w - 6) / 10 + 3, sy1 - 2, (200, 112, 28, 255))
            panels.append((sx0, sy0, sx1, sy1, ORANGE, 38))

    # Stands then monitors
    for sx in (92, 118):
        R(d, sx, 70, sx + 3, 84, (50, 62, 90, 255))
    R(d, 28, 70, 40, 84, (50, 62, 90, 255))
    R(d, 170, 70, 182, 84, (50, 62, 90, 255))
    monitor(6, 20, 62, 72, "line")
    monitor(148, 20, 204, 72, "wave")
    monitor(66, 6, 144, 76, "heat")
    # Desk
    R(d, 0, 84, W, 94, (14, 18, 28, 255))
    grad(d, 0, 85, W, 93, (84, 102, 140), (52, 64, 92))
    R(d, 0, 85, W, 86.4, HI + (255,))
    grad(d, 0, 94, W, H, (36, 45, 66), (22, 28, 42))
    R(d, 0, 0 + H - 8, W, H, (14, 18, 28, 255))
    # Keyboard
    R(d, 66, 80, 144, 86, (20, 26, 40, 255))
    for kx in range(68, 142, 4):
        R(d, kx, 81.4, kx + 2.4, 83, (70, 86, 120, 255))
        R(d, kx, 83.8, kx + 2.4, 84.8, (58, 72, 102, 255))
    # Front panels: seams, buttons, knobs
    for sx in (70, 140):
        R(d, sx, 95, sx + 1.4, H - 8, EDGE + (255,))
    for i in range(10):
        bx = 12 + i * 5.6
        c = pick_led(rng)
        R(d, bx, 104, bx + 3.6, 108, lerp((30, 38, 58), c, 0.35) + (255,))
        leds.append((bx + 1.8, 106, c))
    for kx in (152, 172, 192):
        C(d, kx, 108, 5.2, (14, 18, 28, 255))
        C(d, kx, 108, 4, (86, 104, 140, 255))
        LN(d, [(kx, 108), (kx + 2.4, 105.2)], (200, 220, 250, 255), 1.2)
    for x in range(84, 126, 5):
        R(d, x, 120, x + 3, 126, (10, 13, 22, 255))
    for i in range(6):
        c = pick_led(rng)
        R(d, 80 + i * 8, 100, 80 + i * 8 + 5, 103, lerp((30, 38, 58), c, 0.4) + (255,))
        leds.append((82.5 + i * 8, 101.5, c))
    save("machine_monitoring_station", im)
    overlays("machine_monitoring_station", (W, H), leds, panels, 23)


# ------------------------------------------------------------------ Server tower (70x210)
def server_tower():
    W, H = 70, 210
    im = new(W, H)
    d = ImageDraw.Draw(im)
    rng = random.Random(7)
    leds = []
    cabinet(d, W, H)
    R(d, 8, 8, 62, 16, (20, 26, 40, 255))
    for x in range(12, 60, 6):
        R(d, x, 10, x + 3, 14, (10, 13, 22, 255))
    for i in range(9):
        y = 22 + i * 19.6
        R(d, 8, y, 62, y + 17, (14, 18, 28, 255))
        R(d, 9, y + 1, 61, y + 16, (30, 38, 58, 255))
        R(d, 9, y + 1, 61, y + 2.4, (50, 64, 94, 255))
        for k in range(7):
            gx = 34 + k * 3.5
            R(d, gx, y + 5, gx + 1.3, y + 14, (18, 23, 36, 255))
        for k in range(3):
            c = pick_led(rng)
            R(d, 13 + k * 6, y + 7, 16.6 + k * 6, y + 10.6, lerp((30, 38, 58), c, 0.3) + (255,))
            leds.append((14.8 + k * 6, y + 8.8, c))
    R(d, 8, H - 8, 62, H - 6.4, CYAN + (255,))
    save("machine_server_tower", im)
    overlays("machine_server_tower", (W, H), leds, [(8, H - 8, 62, H - 6.4, CYAN, 230)], 29)


if __name__ == "__main__":
    gpu_rack()
    supercomputer()
    monitoring_station()
    server_tower()
    print("wrote machines to", OUT)
