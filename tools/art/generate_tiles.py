"""Generates the data-center themed foreground tiles.

Usage (needs Pillow):
    python tools/art/generate_tiles.py <kenney_tiles_dir> <out_dir>
    e.g. python tools/art/generate_tiles.py assets/tiles/kenney_industrial assets/tiles/data_center

- Structural pieces (ground, ledges, ladders, crates, spikes) are drawn from scratch
  in the same palette as the background: dark steel, cyan edge lights, orange accents.
- Props (monitors, panels, gear, sirens, canisters, slime...) are Kenney sprites regraded
  into the palette: neutral greys become navy steel, saturated accents stay bright.

Output files keep the Kenney names (see assets/tiles/kenney_industrial/NAMES.md), so the game
(SpriteLibrary) can use them as drop-in replacements. Like the Kenney set they are stored in category
folders (terrain/, structure/, equipment/, hazards/, lights/, signage/), chosen from the first word of
the sprite's name.
"""
import os
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter

SRC = sys.argv[1] if len(sys.argv) > 1 else "assets/tiles/kenney_industrial"
OUT = sys.argv[2] if len(sys.argv) > 2 else "assets/tiles/data_center"
os.makedirs(OUT, exist_ok=True)

SS = 4  # supersampling factor
T = 70

EDGE = (11, 14, 22)
STEEL_TOP = (46, 57, 82)
STEEL_BOT = (26, 33, 50)
STEEL_LIP = (84, 102, 140)
STEEL_HI = (132, 154, 198)
STEEL_SEAM_HI = (62, 78, 112)
RIVET = (98, 116, 152)
CYAN = (58, 208, 255)
ORANGE = (240, 138, 36)
RED = (255, 77, 77)


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(len(a)))


def canvas(w, h):
    return Image.new("RGBA", (w * SS, h * SS), (0, 0, 0, 0))


def finish(im):
    return im.resize((im.width // SS, im.height // SS), Image.LANCZOS)


def rect(d, x0, y0, x1, y1, fill):
    d.rectangle([round(x0 * SS), round(y0 * SS), round(x1 * SS) - 1, round(y1 * SS) - 1], fill=fill)


def poly(d, pts, fill):
    d.polygon([(x * SS, y * SS) for x, y in pts], fill=fill)


def circle(d, cx, cy, r, fill):
    d.ellipse([(cx - r) * SS, (cy - r) * SS, (cx + r) * SS, (cy + r) * SS], fill=fill)


def vgrad(d, x0, y0, x1, y1, top, bot):
    n = round((y1 - y0) * SS)
    for i in range(n):
        y = round(y0 * SS) + i
        d.line([(round(x0 * SS), y), (round(x1 * SS) - 1, y)], fill=lerp(top, bot, i / max(1, n - 1)) + (255,))


def glow(im, strips, color, blur, alpha):
    """Composite a blurred glow behind `strips` ((x0,y0,x1,y1) rects) onto im."""
    layer = Image.new("RGBA", im.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for x0, y0, x1, y1 in strips:
        rect(d, x0, y0, x1, y1, color + (alpha,))
    layer = layer.filter(ImageFilter.GaussianBlur(blur * SS))
    return Image.alpha_composite(layer, im)


def cut_corners(im, w, h, tl=0, tr=0, bl=0, br=0):
    """Chamfer the given corners (sizes in px) by clearing alpha."""
    mask = Image.new("L", im.size, 255)
    md = ImageDraw.Draw(mask)
    if tl: poly(md, [(0, 0), (tl, 0), (0, tl)], 0)
    if tr: poly(md, [(w, 0), (w - tr, 0), (w, tr)], 0)
    if bl: poly(md, [(0, h), (bl, h), (0, h - bl)], 0)
    if br: poly(md, [(w, h), (w - br, h), (w, h - br)], 0)
    a = ImageChops.multiply(im.getchannel("A"), mask)
    im.putalpha(a)
    return im


# ------------------------------------------------------------------ ground
def ground(kind):
    """kind: start | middle | end | single | fill"""
    im = canvas(T, T)
    d = ImageDraw.Draw(im)
    top_tile = kind != "fill"
    if top_tile:
        vgrad(d, 0, 0, T, T, STEEL_TOP, STEEL_BOT)
    else:
        vgrad(d, 0, 0, T, T, STEEL_BOT, (20, 25, 38))
    left_cap = kind in ("start", "single")
    right_cap = kind in ("end", "single")

    # Panel seams: dark line with a soft highlight, on both sides so neighbours form a double seam
    rect(d, 0, 0, 1.6, T, EDGE + (255,))
    rect(d, 1.6, 10 if top_tile else 0, 3, T, STEEL_SEAM_HI + (255,))
    rect(d, T - 1.6, 0, T, T, EDGE + (255,))
    # Horizontal seam
    y = 42
    rect(d, 0, y, T, y + 1.6, EDGE + (255,))
    rect(d, 0, y + 1.6, T, y + 3, STEEL_SEAM_HI + (255,))
    # Rivets
    for rx, ry in ((9, 28), (T - 9, 28), (9, 58), (T - 9, 58)):
        circle(d, rx, ry, 2.6, EDGE + (255,))
        circle(d, rx, ry, 1.8, RIVET + (255,))
    if not top_tile:
        # Vent slits so the fill tile isn't a flat slab
        for i in range(4):
            rect(d, 22, 14 + i * 5, 48, 16 + i * 5, EDGE + (255,))

    strips = []
    if top_tile:
        # Top lip + glowing cyan edge-light
        rect(d, 0, 0, T, 7, STEEL_LIP + (255,))
        rect(d, 0, 0, T, 2.2, STEEL_HI + (255,))
        rect(d, 0, 7, T, 8.4, EDGE + (255,))
        x0 = 9 if left_cap else 0
        x1 = T - 9 if right_cap else T
        strips.append((x0, 8.4, x1, 11))
        rect(d, x0, 8.4, x1, 11, CYAN + (255,))
        rect(d, x0, 8.4, x1, 9.2, (190, 240, 255, 255))
        im = glow(im, strips, CYAN, 4, 140)
        d = ImageDraw.Draw(im)
        # Cap edges: bevel
        if left_cap:
            rect(d, 0, 0, 2.2, T, EDGE + (255,))
        if right_cap:
            rect(d, T - 2.2, 0, T, T, EDGE + (255,))
        im = cut_corners(im, T, T, tl=9 if left_cap else 0, tr=9 if right_cap else 0)
    return finish(im)


# ------------------------------------------------------------------ ledges
def ledge(kind):
    """Catwalk, 70x70 canvas with art in the top 40px. kind: start | middle | end | single"""
    W, H = T, 40
    im = canvas(T, T)
    d = ImageDraw.Draw(im)
    left_cap = kind in ("start", "single")
    right_cap = kind in ("end", "single")

    # Hanging lattice under the plate
    for x in range(-35, T + 35, 35):
        d.line([(x * SS, 18 * SS), ((x + 17.5) * SS, 38 * SS)], fill=(50, 62, 90, 255), width=2 * SS)
        d.line([((x + 17.5) * SS, 38 * SS), ((x + 35) * SS, 18 * SS)], fill=(50, 62, 90, 255), width=2 * SS)
    # Plate
    vgrad(d, 0, 0, T, 14, (62, 76, 108), (32, 40, 60))
    rect(d, 0, 0, T, 6, STEEL_LIP + (255,))
    rect(d, 0, 0, T, 2.2, STEEL_HI + (255,))
    rect(d, 0, 6, T, 7.4, EDGE + (255,))
    # Underside edge + cyan under-glow
    rect(d, 0, 13, T, 15, EDGE + (255,))
    x0 = 8 if left_cap else 0
    x1 = T - 8 if right_cap else T
    rect(d, x0, 15, x1, 17.4, CYAN + (255,))
    im = glow(im, [(x0, 15, x1, 17.4)], CYAN, 4, 150)
    d = ImageDraw.Draw(im)
    # Rivets + seams
    for rx in (10, T - 10):
        circle(d, rx, 10, 1.8, EDGE + (255,))
        circle(d, rx, 10, 1.2, RIVET + (255,))
    rect(d, 0, 0, 1.4, 14, EDGE + (255,))
    rect(d, T - 1.4, 0, T, 14, EDGE + (255,))
    if left_cap:
        rect(d, 0, 0, 2.2, 15, EDGE + (255,))
    if right_cap:
        rect(d, T - 2.2, 0, T, 15, EDGE + (255,))
    # Clear below the lattice
    clear = Image.new("L", im.size, 0)
    ImageDraw.Draw(clear).rectangle([0, 0, T * SS, H * SS], fill=255)
    im.putalpha(ImageChops.multiply(im.getchannel("A"), clear))
    im = cut_corners(im, T, 14, tl=6 if left_cap else 0, tr=6 if right_cap else 0)
    if left_cap:
        # Trim the lattice start so it doesn't poke out past the chamfer
        pass
    return finish(im)


# ------------------------------------------------------------------ ladders
def ladder(top):
    """Ladder cell. The top cell has a deck plate (same lip + cyan edge-light as the ground
    tiles) so it joins the floor line next to it and the player stands on a deck, not on rail tips."""
    im = canvas(T, T)
    d = ImageDraw.Draw(im)
    ORANGE_D = (178, 92, 22)
    ORANGE_L = (255, 168, 64)
    y0 = 11 if top else 0
    for rx in (14, 48):
        rect(d, rx, y0, rx + 8, T, ORANGE_D + (255,))
        rect(d, rx, y0, rx + 2.4, T, ORANGE_L + (255,))
        rect(d, rx + 6.4, y0, rx + 8, T, (120, 60, 14, 255))
    # Rung grid is continuous across cells (12, 35, 58); the top cell's first rung is under the deck.
    for ry in ((35, 58) if top else (12, 35, 58)):
        rect(d, 22, ry, 48, ry + 8, (78, 92, 124, 255))
        rect(d, 22, ry, 48, ry + 2.4, (130, 150, 190, 255))
        rect(d, 22, ry + 6.4, 48, ry + 8, EDGE + (255,))
    if top:
        vgrad(d, 0, 0, T, 11, STEEL_TOP, (36, 45, 66))
        rect(d, 0, 0, T, 7, STEEL_LIP + (255,))
        rect(d, 0, 0, T, 2.2, STEEL_HI + (255,))
        rect(d, 0, 7, T, 8.4, EDGE + (255,))
        rect(d, 0, 8.4, T, 11, CYAN + (255,))
        rect(d, 0, 8.4, T, 9.2, (190, 240, 255, 255))
        rect(d, 0, 11, T, 12.6, EDGE + (255,))
        rect(d, 0, 0, 1.6, 12.6, EDGE + (255,))
        rect(d, T - 1.6, 0, T, 12.6, EDGE + (255,))
        im = glow(im, [(0, 8.4, T, 11)], CYAN, 4, 140)
    return finish(im)


# ------------------------------------------------------------------ spikes
def spikes(up=True):
    im = canvas(T, T)
    d = ImageDraw.Draw(im)
    base_y = 60
    tip_y = 24
    tips = []
    for cx in (17, 35, 53):
        poly(d, [(cx - 10, base_y), (cx, tip_y), (cx + 10, base_y)], (140, 156, 186, 255))
        poly(d, [(cx, tip_y), (cx + 10, base_y), (cx + 1, base_y)], (96, 110, 140, 255))
        # Glowing red tip
        poly(d, [(cx - 3.6, tip_y + 11), (cx, tip_y), (cx + 3.6, tip_y + 11)], RED + (255,))
        tips.append((cx - 3, tip_y, cx + 3, tip_y + 10))
    rect(d, 0, base_y, T, T, (30, 38, 58, 255))
    rect(d, 0, base_y, T, base_y + 2, STEEL_LIP + (255,))
    rect(d, 0, base_y + 2, T, base_y + 3.2, EDGE + (255,))
    for rx in (8, 35, 62):
        circle(d, rx, 65.5, 1.6, RIVET + (255,))
    im = glow(im, tips, RED, 4, 170)
    out = finish(im)
    return out if up else out.transpose(Image.FLIP_TOP_BOTTOM)


# ------------------------------------------------------------------ crates
def crate(orange=False):
    im = canvas(T, T)
    d = ImageDraw.Draw(im)
    vgrad(d, 0, 0, T, T, (52, 64, 92), (34, 43, 64))
    # Frame
    rect(d, 0, 0, T, 4, STEEL_LIP + (255,))
    rect(d, 0, 0, T, 1.8, STEEL_HI + (255,))
    rect(d, 0, T - 4, T, T, (22, 28, 44, 255))
    rect(d, 0, 0, 4, T, (40, 50, 74, 255))
    rect(d, T - 4, 0, T, T, (26, 33, 50, 255))
    inner = (8, 8, T - 8, T - 8)
    rect(d, *inner, (30, 38, 58, 255))
    if orange:
        rect(d, 0, 26, T, 44, ORANGE + (255,))
        for sx in range(-20, T + 20, 16):
            poly(d, [(sx, 44), (sx + 8, 44), (sx + 18, 26), (sx + 10, 26)], (28, 20, 12, 255))
        rect(d, 0, 26, T, 28, (255, 190, 100, 255))
        rect(d, 0, 42, T, 44, (150, 76, 10, 255))
    else:
        d.line([(10 * SS, 10 * SS), ((T - 10) * SS, (T - 10) * SS)], fill=(88, 106, 142, 255), width=int(5 * SS))
        d.line([((T - 10) * SS, 10 * SS), (10 * SS, (T - 10) * SS)], fill=(88, 106, 142, 255), width=int(5 * SS))
        d.line([(10 * SS, 10 * SS), ((T - 10) * SS, (T - 10) * SS)], fill=(120, 142, 182, 255), width=int(1.6 * SS))
    for rx, ry in ((6.5, 6.5), (T - 6.5, 6.5), (6.5, T - 6.5), (T - 6.5, T - 6.5)):
        circle(d, rx, ry, 2.4, EDGE + (255,))
        circle(d, rx, ry, 1.6, RIVET + (255,))
    rect(d, 0, 0, 1.4, T, EDGE + (255,))
    rect(d, T - 1.4, 0, T, T, EDGE + (255,))
    rect(d, 0, T - 1.4, T, T, EDGE + (255,))
    return finish(cut_corners(im, T, T, tl=7, tr=7, bl=7, br=7))


# ------------------------------------------------------------------ prop grading
STEEL_RAMP_DARK = (13, 18, 30)
STEEL_RAMP_LIGHT = (128, 148, 188)


def grade(img):
    """Neutral greys -> navy steel ramp; saturated accents stay bright."""
    img = img.convert("RGBA")
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            mx, mn = max(r, g, b), min(r, g, b)
            sat = (mx - mn) / mx if mx else 0
            lum = (0.299 * r + 0.587 * g + 0.114 * b) / 255
            if sat < 0.3:
                t = max(0.0, min(1.0, lum)) ** 1.35
                c = lerp(STEEL_RAMP_DARK, STEEL_RAMP_LIGHT, t * 0.95)
                px[x, y] = c + (a,)
            else:
                k = 0.95
                px[x, y] = (int(r * k), int(g * k), int(b * k), a)
    return img


GRADED_PROPS = [
    "monitor_text", "monitor_tv_text", "monitor_blank", "monitor_tv_blank", "gear_full",
    "siren_blue", "siren_orange", "siren_green", "siren_yellow", "lamp_pole_green",
    "canister_blue_vertical", "canister_yellow_vertical", "sign_power_green",
    "slime_floor_start", "slime_floor_middle", "slime_floor_end", "slime_floor_single", "slime_floor_bump",
    "panel_controls_start", "panel_controls_middle", "panel_controls_end",
    "panel_dark_start", "panel_dark_middle", "panel_dark_end",
    "rail_thin_start", "rail_thin_middle", "rail_thin_end",
]


# Category folder for a tile, from the first word of its name. This MUST match
# SpriteLibrary.TILE_CATEGORIES in scripts/level/sprite_library.gd (tools/tests/assets_test.gd checks
# that the files on disk agree with that table).
TILE_CATEGORIES = {
    "ground": "terrain", "ledge": "terrain", "slime": "terrain",
    "block": "structure", "ladder": "structure", "scaffold": "structure",
    "pipe": "structure", "rail": "structure", "glass": "structure",
    "monitor": "equipment", "panel": "equipment", "gear": "equipment", "canister": "equipment",
    "spikes": "hazards", "hazard": "hazards", "barrier": "hazards",
    "siren": "lights", "lamp": "lights",
    "arrow": "signage", "sign": "signage",
}


def category(name):
    return TILE_CATEGORIES[name.split("_")[0]]


def save(img, name):
    folder = os.path.join(OUT, category(name))
    os.makedirs(folder, exist_ok=True)
    img.save(os.path.join(folder, name + ".png"))


if __name__ == "__main__":
    for k in ("start", "middle", "end", "single", "fill"):
        save(ground(k), f"ground_{k}")
    for k in ("start", "middle", "end", "single"):
        save(ledge(k), f"ledge_{k}")
    save(ladder(True), "ladder_top")
    save(ladder(False), "ladder_middle")
    save(spikes(True), "spikes_up")
    save(spikes(False), "spikes_down")
    save(crate(False), "block_metal_x")
    save(crate(True), "block_metal_orange")
    for name in GRADED_PROPS:
        src = os.path.join(SRC, category(name), name + ".png")
        if os.path.exists(src):
            save(grade(Image.open(src)), name)
    print("wrote tiles to", OUT)
