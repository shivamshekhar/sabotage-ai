"""Generates the data-center machines used as foreground decor.

Usage (needs Pillow):  python tools/art/generate_machines.py assets/machines/data_center

Each machine writes three PNGs into its own folder (<out>/<machine>/, e.g. gpu_rack/):
  <name>.png          the machine
  <name>_leds_a.png   bright LEDs / screen glow (first half), pulsed by the game
  <name>_leds_b.png   bright LEDs / screen glow (second half), pulsed in the other phase
  <name>_shadow.png   soft drop shadow
Shared moving parts (the fan blades) go in <out>/parts/.
Sizes are multiples of the 70px tile so they drop onto the level grid:
  machine_gpu_rack 140x210 (2x3), machine_supercomputer 210x210 (3x3),
  machine_monitoring_station 280x210 (4x3), machine_server_tower 70x210 (1x3), machine_lock_terminal 140x210 (2x3).
"""
import math
import os
import random
import sys

from PIL import Image, ImageDraw, ImageFilter

OUT = sys.argv[1] if len(sys.argv) > 1 else "assets/machines/data_center"
os.makedirs(OUT, exist_ok=True)

# Files are stored one folder per machine (gpu_rack/, supercomputer/, ...) with its image, LED layers and
# shadow together; shared moving parts go in parts/. This MUST match SpriteLibrary.machine_folder() in
# scripts/level/sprite_library.gd, which finds the files by name (tools/tests/assets_test.gd checks it).
FILE_SUFFIXES = ("_leds_a", "_leds_b", "_shadow")
SHARED_PARTS = ("machine_fan",)


def machine_dir(file_name):
    base = file_name
    for suffix in FILE_SUFFIXES:
        if base.endswith(suffix):
            base = base[: -len(suffix)]
    folder = "parts" if base in SHARED_PARTS else base[len("machine_"):]
    path = os.path.join(OUT, folder)
    os.makedirs(path, exist_ok=True)
    return path
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
        Image.alpha_composite(halo, core).resize((w, h), Image.LANCZOS).save(os.path.join(machine_dir(f"{name}_leds_{key}"), f"{name}_leds_{key}.png"))


def save(name, im):
    base = fin(im)
    base.save(os.path.join(machine_dir(name), f"{name}.png"))
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
    layer.save(os.path.join(machine_dir(f"{name}_shadow"), f"{name}_shadow.png"))


# ------------------------------------------------------------------ GPU rack (140x210)
def gpu_rack():
    W, H = 140, 210
    im = new(W, H)
    d = ImageDraw.Draw(im)
    rng = random.Random(3)
    leds = []
    fan_centers = []   # where the game places the spinning blade sprite (machine_fan.png)
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
        for fx in (27, 55):  # fan housings; the blades are a separate sprite so the game can spin them
            cy = y + 12
            C(d, fx, cy, 9.8, (10, 13, 22, 255))
            C(d, fx, cy, 8.4, (22, 28, 44, 255))
            fan_centers.append((fx, cy))
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
    write_fan_data({"machine_gpu_rack": fan_centers})


# ------------------------------------------------------------------ spinning fan blades
FAN_SIZE = 24  # px; the blades are drawn centred in a square this size


def fan_blades():
    """The rotating part of a fan: blades and hub on a transparent square. The game places one of
    these over each fan housing in the machine sprite and rotates it around its centre."""
    c = FAN_SIZE / 2
    im = new(FAN_SIZE, FAN_SIZE)
    d = ImageDraw.Draw(im)
    for k in range(6):
        a = math.radians(k * 60)
        tip = (c + 7.8 * math.cos(a), c + 7.8 * math.sin(a))
        LN(d, [(c, c), tip], (74, 92, 128, 255), 2.6)
        # a lighter leading edge so the rotation reads
        side = (c + 7.8 * math.cos(a + 0.35) * 0.9, c + 7.8 * math.sin(a + 0.35) * 0.9)
        LN(d, [(c, c), side], (112, 134, 176, 255), 1.0)
    C(d, c, c, 2.6, (104, 124, 162, 255))
    C(d, c, c, 1.2, (150, 170, 206, 255))
    save_raw("machine_fan", fin(im))


def save_raw(name, img):
    img.save(os.path.join(machine_dir(name), f"{name}.png"))


SCREEN_DATA = {}   # every machine's screen rectangles; the file is rewritten with all of them each time


def write_screen_data(machines):
    """Writes scripts/level/machine_screens.gd: the screen rectangles of machines whose screens
    show live content, in pixels from the top-left of the machine sprite."""
    SCREEN_DATA.update(machines)
    machines = SCREEN_DATA
    path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "scripts", "level", "machine_screens.gd")
    out = [
        "class_name MachineScreens",
        "extends RefCounted",
        "## GENERATED by tools/art/generate_machines.py. Do not edit by hand; re-run the generator.",
        "## Screens on machines whose content is drawn live by the game (see monitor_screen.gd), as",
        "## rectangles in pixels from the top-left corner of the machine sprite.",
        "",
    ]
    for name, rects in machines.items():
        const = name.replace("machine_", "").upper()
        out.append(f"# {const}: screens of the sprite \"{name}\", by position (left, center, right).")
        out.append(f"const {const}: Dictionary = {{")
        for key, (x, y, w, h) in rects.items():
            out.append(f'\t"{key}": Rect2({x:.1f}, {y:.1f}, {w:.1f}, {h:.1f}),')
        out.append("}")
        out.append("")
    out += [
        "",
        "## Screen rectangles for a machine sprite name (empty if it has no live screens).",
        "static func rects(sprite_name: String) -> Dictionary:",
        "\tmatch sprite_name:",
    ]
    for name in machines:
        out.append(f'\t\t"{name}":')
        out.append(f"\t\t\treturn {name.replace('machine_', '').upper()}")
    out += ["\t\t_:", "\t\t\treturn {}", ""]
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(out))
    print("wrote", os.path.normpath(path))


def write_fan_data(machines):
    """Writes scripts/level/machine_fans.gd: where each machine's fans are, in pixels from the
    top-left of the machine sprite. Generated here so the positions always match the art."""
    path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "scripts", "level", "machine_fans.gd")
    out = [
        "class_name MachineFans",
        "extends RefCounted",
        "## GENERATED by tools/art/generate_machines.py. Do not edit by hand; re-run the generator.",
        "## Where the spinning fans sit on each machine sprite, in pixels from its top-left corner.",
        "",
        "# FAN_SPRITE: name of the sprite (in the machines folder) that is placed on each fan and rotated.",
        'const FAN_SPRITE := "machine_fan"',
        "",
    ]
    for name, centers in machines.items():
        const = name.replace("machine_", "").upper()
        out.append(f"# {const}: fan centres for the sprite \"{name}\".")
        out.append(f"const {const}: Array[Vector2] = [")
        for x, y in centers:
            out.append(f"\tVector2({x:.1f}, {y:.1f}),")
        out.append("]")
        out.append("")
    out += [
        "",
        "## Fan centres for a machine sprite name (empty if that machine has no fans).",
        "static func centres(sprite_name: String) -> Array[Vector2]:",
        "\tmatch sprite_name:",
    ]
    for name in machines:
        out.append(f'\t\t"{name}":')
        out.append(f"\t\t\treturn {name.replace('machine_', '').upper()}")
    out += [
        "\t\t_:",
        "\t\t\tvar none: Array[Vector2] = []",
        "\t\t\treturn none",
        "",
    ]
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(out))
    print("wrote", os.path.normpath(path))


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
    W, H = 280, 210
    im = new(W, H)
    d = ImageDraw.Draw(im)
    rng = random.Random(9)
    leds, panels = [], []
    screens = {}   # screen rectangles (px from the sprite's top-left); the game draws live content there

    def monitor(x0, y0, x1, y1, name):
        # Bezel and a blank screen. What is shown on the screen is drawn live by the game
        # (see scripts/level/monitor_screen.gd), so nothing is painted on it here.
        R(d, x0, y0, x1, y1, (12, 16, 26, 255))
        R(d, x0 + 1, y0 + 1, x1 - 1, y1 - 1, (54, 68, 100, 255))
        sx0, sy0, sx1, sy1 = x0 + 4, y0 + 4, x1 - 4, y1 - 4
        R(d, sx0, sy0, sx1, sy1, (8, 15, 30, 255))
        screens[name] = (sx0, sy0, sx1 - sx0, sy1 - sy0)

    # Monitor necks, then the three monitors: a tall centre one flanked by two smaller ones
    for nx in (39, 134, 229):
        R(d, nx, 126, nx + 12, 142, (50, 62, 90, 255))
    monitor(6, 46, 84, 126, "left")
    monitor(196, 46, 274, 126, "right")
    monitor(90, 8, 190, 126, "center")
    # Desk
    R(d, 0, 142, W, 154, (14, 18, 28, 255))
    grad(d, 0, 143, W, 153, (84, 102, 140), (52, 64, 92))
    R(d, 0, 143, W, 144.6, HI + (255,))
    grad(d, 0, 154, W, H, (36, 45, 66), (22, 28, 42))
    R(d, 0, H - 10, W, H, (14, 18, 28, 255))
    # Keyboard
    R(d, 104, 134, 176, 142, (20, 26, 40, 255))
    for kx in range(106, 174, 5):
        R(d, kx, 135.6, kx + 3, 138, (70, 86, 120, 255))
        R(d, kx, 139, kx + 3, 140.6, (58, 72, 102, 255))
    # Front panels: seams, buttons, knobs, vents
    for sx in (94, 186):
        R(d, sx, 155, sx + 1.6, H - 10, EDGE + (255,))
    for i in range(10):
        bx = 14 + i * 7.4
        c = pick_led(rng)
        R(d, bx, 168, bx + 4.6, 173, lerp((30, 38, 58), c, 0.35) + (255,))
        leds.append((bx + 2.3, 170.5, c))
    for kx in (212, 235, 258):
        C(d, kx, 180, 6.5, (14, 18, 28, 255))
        C(d, kx, 180, 5, (86, 104, 140, 255))
        LN(d, [(kx, 180), (kx + 3, 176.5)], (200, 220, 250, 255), 1.4)
    for x in range(112, 170, 6):
        R(d, x, 186, x + 3.6, 194, (10, 13, 22, 255))
    for i in range(6):
        c = pick_led(rng)
        R(d, 106 + i * 11, 166, 106 + i * 11 + 7, 170, lerp((30, 38, 58), c, 0.4) + (255,))
        leds.append((109.5 + i * 11, 168, c))
    save("machine_monitoring_station", im)
    overlays("machine_monitoring_station", (W, H), leds, panels, 23)
    write_screen_data({"machine_monitoring_station": screens})


# ------------------------------------------------------------------ Lock terminal (140x210)
def lock_terminal():
    """The computer that switches off a laser gate: one big screen (drawn live: a red padlock while the
    gate is locked, a green one once open), a keyboard and a card reader, and red-and-black warning
    stripes so it can't be mistaken for the decorative monitoring stations."""
    W, H = 140, 210
    im = new(W, H)
    d = ImageDraw.Draw(im)
    leds, panels = [], []
    screens = {}
    cabinet(d, W, H)
    # Warning stripes along the top and bottom edges.
    for x in range(0, W, 14):
        R(d, x, 5, x + 7, 12, (200, 40, 40, 255))
        R(d, x + 7, 5, x + 14, 12, (20, 14, 16, 255))
        R(d, x, H - 22, x + 7, H - 15, (200, 40, 40, 255))
        R(d, x + 7, H - 22, x + 14, H - 15, (20, 14, 16, 255))
    # The big screen: bezel and a blank screen for the game to draw on.
    R(d, 10, 18, W - 10, 128, (12, 16, 26, 255))
    R(d, 11, 19, W - 11, 127, (54, 68, 100, 255))
    R(d, 15, 23, W - 15, 123, (8, 15, 30, 255))
    screens["lock"] = (15, 23, W - 30, 100)
    # Desk with keyboard and card reader.
    R(d, 6, 134, W - 6, 146, (14, 18, 28, 255))
    grad(d, 7, 135, W - 7, 145, (84, 102, 140), (52, 64, 92))
    R(d, 24, 136, 78, 144, (20, 26, 40, 255))
    for kx in range(26, 76, 5):
        R(d, kx, 137.4, kx + 3, 139.6, (70, 86, 120, 255))
        R(d, kx, 141, kx + 3, 142.6, (58, 72, 102, 255))
    R(d, 90, 136, 128, 144, (10, 13, 22, 255))
    R(d, 94, 139, 124, 141.4, (255, 190, 60, 255))
    panels.append((94, 139, 124, 141.4, (255, 190, 60), 230))
    # Status lights on the front.
    for i in range(4):
        c = RED if i % 2 == 0 else ORANGE
        R(d, 22 + i * 28, 158, 22 + i * 28 + 10, 164, lerp((30, 38, 58), c, 0.4) + (255,))
        leds.append((27 + i * 28, 161, c))
    for x in range(30, 110, 7):
        R(d, x, 176, x + 4, 188, (10, 13, 22, 255))
    save("machine_lock_terminal", im)
    overlays("machine_lock_terminal", (W, H), leds, panels, 31)
    write_screen_data({"machine_lock_terminal": screens})


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
    fan_blades()
    gpu_rack()
    supercomputer()
    monitoring_station()
    lock_terminal()
    server_tower()
    print("wrote machines to", OUT)
