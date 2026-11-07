"""Generates the app icon (icon.png, 512x512) from the player's idle pose.

Usage (needs Pillow):  python tools/art/generate_icon.py icon.png

Dark steel tile in the game's palette with a cyan edge-light and the hero in front.
Godot uses icon.png (project setting application/config/icon) for the Android launcher
icon; Google Play also wants a 512x512 store icon, which this file can double as.
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFilter

OUT = sys.argv[1] if len(sys.argv) > 1 else "icon.png"
HERO = "assets/characters/kenney_platformer/player/player_idle.png"
S = 512


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(len(a)))


bg = Image.new("RGBA", (S, S))
d = ImageDraw.Draw(bg)
for y in range(S):
    d.line([(0, y), (S, y)], fill=lerp((46, 57, 82), (18, 23, 36), y / S) + (255,))

# Server-rack stripes behind the hero, like the game's background
for i in range(7):
    y = 40 + i * 62
    d.rectangle([40, y, S - 40, y + 44], fill=(24, 31, 48, 255), outline=(12, 15, 24, 255), width=3)
    for k in range(5):
        x = 64 + k * 22
        col = [(46, 230, 107), (58, 208, 255), (240, 138, 36)][(i + k) % 3]
        d.rectangle([x, y + 16, x + 9, y + 25], fill=col + (255,))
    for vx in range(300, S - 64, 14):
        d.rectangle([vx, y + 10, vx + 5, y + 34], fill=(14, 18, 28, 255))

# Darken so the hero pops, then add the cyan edge-light
shade = Image.new("RGBA", (S, S), (6, 9, 18, 150))
bg = Image.alpha_composite(bg, shade)
glow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
ImageDraw.Draw(glow).rounded_rectangle([6, 6, S - 7, S - 7], radius=70, outline=(58, 208, 255, 255), width=10)
bg = Image.alpha_composite(bg, glow.filter(ImageFilter.GaussianBlur(10)))
bg = Image.alpha_composite(bg, glow)

# Hero, scaled up, with a soft shadow
hero = Image.open(HERO).convert("RGBA")
scale = 4.1
hero = hero.resize((int(hero.width * scale), int(hero.height * scale)), Image.LANCZOS)
shadow = Image.new("RGBA", hero.size, (0, 0, 0, 255))
shadow.putalpha(hero.getchannel("A"))
shadow = shadow.filter(ImageFilter.GaussianBlur(14))
x, y = (S - hero.width) // 2, S - hero.height - 14
bg.paste(shadow, (x + 8, y + 12), shadow)
bg.paste(hero, (x, y), hero)

# Round the corners of the icon itself
mask = Image.new("L", (S, S), 0)
ImageDraw.Draw(mask).rounded_rectangle([0, 0, S - 1, S - 1], radius=84, fill=255)
bg.putalpha(mask)
bg.save(OUT)
print("wrote", OUT)
