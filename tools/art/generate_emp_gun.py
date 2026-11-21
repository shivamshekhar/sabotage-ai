"""Draws the player's EMP gun: a chunky sci-fi pistol in the style of the mech's turrets (lit navy steel, cyan coils and lights, a yellow hazard band like the mech's
body). Seen from the side, pointing right:

    a rubber grip and trigger guard, a steel body with a charge gauge (six cyan cells), a ribbed capacitor drum on top, a flared emitter dish, and two electrodes with a
    crackle of electricity jumping between their tips.

Usage (from the repo root; needs Pillow, numpy, opencv):
    python tools/art/generate_emp_gun.py      writes
        assets/weapons/emp_gun/emp_gun.png          the gun, 224 x 120 px (meant to be shown at half that size, like the mech's parts; the muzzle is at its right edge)
        tmp/art_previews/emp_gun_preview.png        the gun in the player's hand, for looking at only
"""
import os
import random
import sys

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import art_lib  # noqa: E402
from art_lib import S, lit, paste, solid, mk, poly, rr, ell, line, vgrad, part, finish, inside  # noqa: E402

OUT = os.path.join(art_lib.ROOT, "assets", "weapons", "emp_gun")

GW, GH = 224, 120                 # the picture's size in px
SEED = 11                         # the crackle between the electrodes is seeded, so every run draws the same picture

STEEL = (92, 100, 118)
STEEL_D = (46, 52, 66)
NAVY = (58, 70, 100)
NAVY_D = (30, 38, 58)
RUBBER = (44, 48, 60)
CYAN = (60, 190, 255)
CYAN_L = (205, 240, 255)
YEL = (255, 198, 26)
YEL_D = (214, 140, 10)
BLACK = (28, 30, 38)

def canvas():
    return Image.new("RGBA", (GW * art_lib.S, GH * art_lib.S), (0, 0, 0, 0))


def draw_gun():
    c = canvas()

    # the grip and the trigger guard (behind the body)
    grip = poly(mk(GW, GH), [(54, 64), (84, 64), (78, 114), (46, 114)])
    part(c, grip, vgrad(64, 114, (84, 92, 112), (52, 58, 72)), radius=2.0, bump=2.0)
    ridges = mk(GW, GH)
    for k in range(5):
        y = 78 + k * 7
        line(ridges, (52 - (y - 64) * 0.12, y), (80 - (y - 64) * 0.12, y), 1.4)
    c.alpha_composite(solid(inside(ridges, grip), (22, 24, 32), 0.75))
    guard = mk(GW, GH)
    ImageDraw.Draw(guard).arc([84 * S, 60 * S, 124 * S, 100 * S], 0, 180, fill=255, width=4 * S)
    part(c, guard, (84, 92, 110), radius=1.0, bump=1.6, outline_w=0.7)
    trigger = poly(mk(GW, GH), [(96, 70), (104, 70), (101, 88), (95, 86)])
    part(c, trigger, YEL_D, radius=1.0, outline_w=0.7)

    # the body
    body = rr(mk(GW, GH), (36, 34, 144, 74), 10)
    part(c, body, vgrad(34, 74, (112, 126, 160), NAVY_D), radius=3.0, bump=2.2, spec=0.7)
    # a recessed gauge: six cells of charge
    window = rr(mk(GW, GH), (58, 46, 122, 60), 4)
    part(c, window, (18, 22, 32), radius=1.0, bump=1.0, outline_w=0.8)
    cells = mk(GW, GH)
    for k in range(6):
        x = 61 + k * 10
        rr(cells, (x, 49, x + 7, 57), 1.5)
    art_lib.glow(c, cells, CYAN, radii=(1.2, 4, 9), strengths=(1.0, 0.6, 0.35))
    c.alpha_composite(solid(cells, CYAN_L, 0.9))
    # the yellow hazard band under the gauge
    band = rr(mk(GW, GH), (58, 63, 122, 70), 2)
    part(c, band, vgrad(63, 70, (255, 226, 110), YEL_D), radius=1.0, bump=1.4, outline_w=0.7)
    # rivets and two status lights at the back
    for x, y in ((42, 40), (42, 68), (138, 68)):
        part(c, ell(mk(GW, GH), x, y, 2.2), (150, 160, 184), radius=0.6, bump=2.0, outline_w=0.5)
    for x, col in ((47, (255, 120, 70)), (54, CYAN)):
        lamp = ell(mk(GW, GH), x, 40, 2.4)
        art_lib.glow(c, lamp, col, radii=(1.4, 4), strengths=(0.9, 0.5))
        c.alpha_composite(solid(lamp, tuple(min(255, v + 90) for v in col)))

    # the capacitor drum on top: a ribbed cylinder
    drum = rr(mk(GW, GH), (56, 16, 124, 38), 9)
    part(c, drum, vgrad(16, 38, (150, 160, 182), STEEL_D), radius=2.6, bump=2.2, spec=0.8)
    ribs = mk(GW, GH)
    for x in range(64, 120, 8):
        line(ribs, (x, 17), (x, 37), 1.6)
    c.alpha_composite(solid(inside(ribs, drum), (24, 28, 40), 0.55))
    coil = mk(GW, GH)
    for x in range(68, 120, 16):
        line(coil, (x, 19), (x, 35), 2.2)
    art_lib.glow(c, coil, CYAN, radii=(1.2, 4, 10), strengths=(1.0, 0.6, 0.4))
    c.alpha_composite(solid(coil, CYAN_L, 0.9))

    # the neck and the flared emitter dish
    neck = rr(mk(GW, GH), (138, 40, 156, 68), 4)
    part(c, neck, vgrad(40, 68, (120, 130, 154), STEEL_D), radius=1.6, bump=2.2, spec=0.7)
    dish = poly(mk(GW, GH), [(152, 44), (182, 22), (186, 22), (186, 86), (182, 86), (152, 64)])
    part(c, dish, vgrad(22, 86, (134, 144, 170), (40, 46, 60)), radius=2.0, bump=2.4, spec=0.8)
    # the rings of the dish
    rings = mk(GW, GH)
    for k, x in enumerate((162, 171, 180)):
        half = 12 + k * 9
        line(rings, (x, 54 - half), (x, 54 + half), 1.6)
    c.alpha_composite(solid(inside(rings, dish), (24, 28, 40), 0.55))
    # the glowing mouth of the dish
    mouth = ell(mk(GW, GH), 186, 54, 5, 31)
    part(c, mouth, (20, 28, 44), radius=1.0, bump=1.0, outline_w=0.8)
    core = ell(mk(GW, GH), 187, 54, 3, 22)
    art_lib.glow(c, core, CYAN, radii=(2, 6, 14), strengths=(1.0, 0.8, 0.5))
    c.alpha_composite(solid(core, CYAN_L))

    # two electrodes with a crackle of electricity between their tips
    top_tip, bottom_tip = (200, 28), (200, 80)
    prongs = mk(GW, GH)
    line(prongs, (180, 26), top_tip, 2.6)
    line(prongs, (180, 82), bottom_tip, 2.6)
    part(c, prongs, (150, 160, 184), radius=0.8, bump=1.8, outline_w=0.7)
    balls = mk(GW, GH)
    for tip in (top_tip, bottom_tip):
        ell(balls, tip[0], tip[1], 3.6)
    art_lib.glow(c, balls, CYAN, radii=(1.6, 5, 12), strengths=(1.0, 0.8, 0.5))
    c.alpha_composite(solid(balls, CYAN_L))
    c.alpha_composite(crackle(top_tip, bottom_tip))
    return c


def crackle(a, b):
    """A bolt of electricity from `a` to `b`: a jagged line, a thin white one inside a wider cyan glow."""
    rng = random.Random(SEED)
    steps = 7
    points = [a]
    for k in range(1, steps):
        t = k / steps
        points.append((a[0] + (b[0] - a[0]) * t + rng.uniform(-5.5, 5.5), a[1] + (b[1] - a[1]) * t + rng.uniform(-1.5, 1.5)))
    points.append(b)
    bolt = mk(GW, GH)
    for p, q in zip(points, points[1:]):
        line(bolt, p, q, 1.6)
    layer = Image.new("RGBA", bolt.size, (0, 0, 0, 0))
    art_lib.glow(layer, bolt, CYAN, radii=(1.2, 3.5, 8), strengths=(1.0, 0.7, 0.4))
    layer.alpha_composite(solid(bolt, CYAN_L))
    return layer


def preview(gun):
    """The gun in the player's hand (half size, as in the game), next to the player picture, for looking at only."""
    player = Image.open(os.path.join(art_lib.ROOT, "assets", "characters", "kenney_platformer", "player", "player_idle.png")).convert("RGBA")
    scale = 1.2
    player = player.resize((int(player.width * scale), int(player.height * scale)), Image.LANCZOS)
    small = gun.resize((gun.width // 2, gun.height // 2), Image.LANCZOS)
    sheet = Image.new("RGBA", (700, 260), (60, 66, 84, 255))
    sheet.alpha_composite(player, (60, 120 - player.height // 2 + 70))
    sheet.alpha_composite(small, (60 + player.width - 28, 120 - small.height // 2 + 70))
    sheet.alpha_composite(gun, (300, 70))
    return sheet


def main():
    os.makedirs(OUT, exist_ok=True)
    gun = finish(draw_gun(), os.path.join(OUT, "emp_gun.png"))
    preview(gun).save(art_lib.preview_path("emp_gun_preview.png"))
    print("done")


if __name__ == "__main__":
    main()


