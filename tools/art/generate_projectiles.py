"""Generates the player's throwable objects: small pixel-art pictures of things that are the opposite of AI slop.

Usage (needs Pillow; from the repo root):  python tools/art/generate_projectiles.py

Writes <out>/<group>/projectile_<name>.png, 32x32, transparent background:
  paintings/  famous public-domain paintings, shrunk to pixel art and put in a gold frame
              (sources in tools/art/sources/, downloaded from Wikimedia Commons; see the README credits)
  cats/       a cute cat photo (drawn here, in pixels)
  everyday/   hand-drawn pixel objects: paintbrush, pencil, book, vinyl record, film camera
The folder names MUST match SpriteLibrary.PROJECTILE_GROUPS (tools/tests/assets_test.gd checks it).
"""
import os
import sys
import urllib.request

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "..", "..", "assets", "projectiles", "pixel_art")
SOURCES = os.path.join(HERE, "sources")
SIZE = 32

# Public-domain paintings on Wikimedia Commons: name -> file title. Downloaded once into tools/art/sources/.
PAINTINGS = {
    "mona_lisa": "Mona_Lisa,_by_Leonardo_da_Vinci,_from_C2RMF_retouched.jpg",
    "starry_night": "Van_Gogh_-_Starry_Night_-_Google_Art_Project.jpg",
    "great_wave": "Great_Wave_off_Kanagawa2.jpg",
    "pearl_earring": "Meisje_met_de_parel.jpg",
    "the_scream": "The_Scream.jpg",
    "vitruvian_man": "Da_Vinci_Vitruve_Luc_Viatour.jpg",
}

# PAINTING_COLORS: how many colours a painting is reduced to. Fewer: chunkier, more "pixel art".
PAINTING_COLORS = 20

FRAME_DARK = (92, 58, 24, 255)
FRAME_GOLD = (226, 176, 64, 255)
FRAME_LIGHT = (250, 222, 120, 255)
TRANSPARENT = (0, 0, 0, 0)


def out_path(group, name):
    folder = os.path.join(OUT, group)
    os.makedirs(folder, exist_ok=True)
    return os.path.join(folder, f"projectile_{name}.png")


def fetch(name, title):
    os.makedirs(SOURCES, exist_ok=True)
    path = os.path.join(SOURCES, f"{name}.jpg")
    if not os.path.exists(path):
        url = f"https://commons.wikimedia.org/wiki/Special:FilePath/{title}?width=250"
        req = urllib.request.Request(url, headers={"User-Agent": "sabotage-ai-game-art/1.0 (pixel-art generator)"})
        with urllib.request.urlopen(req) as r, open(path, "wb") as f:
            f.write(r.read())
    return path


def framed_painting(name, title):
    src = Image.open(fetch(name, title)).convert("RGB")
    # Fit inside the frame's inner area (28x28 at most), keeping the painting's proportions.
    inner_max = SIZE - 6
    scale = min(inner_max / src.width, inner_max / src.height)
    w, h = max(1, round(src.width * scale)), max(1, round(src.height * scale))
    art = src.resize((w, h), Image.LANCZOS).quantize(PAINTING_COLORS, method=Image.MEDIANCUT).convert("RGBA")
    fw, fh = w + 6, h + 6
    im = Image.new("RGBA", (SIZE, SIZE), TRANSPARENT)
    ox, oy = (SIZE - fw) // 2, (SIZE - fh) // 2
    d = ImageDraw.Draw(im)
    d.rectangle([ox, oy, ox + fw - 1, oy + fh - 1], fill=FRAME_DARK)
    d.rectangle([ox + 1, oy + 1, ox + fw - 2, oy + fh - 2], fill=FRAME_GOLD)
    d.rectangle([ox + 1, oy + 1, ox + fw - 2, oy + 1], fill=FRAME_LIGHT)
    d.rectangle([ox + 2, oy + 2, ox + fw - 3, oy + fh - 3], fill=FRAME_DARK)
    im.paste(art, (ox + 3, oy + 3))
    im.save(out_path("paintings", name))


def px(d, pts, fill):
    for x, y in pts:
        d.point((x, y), fill=fill)


def cat_photo():
    """A cute cat in a polaroid-style photo."""
    im = Image.new("RGBA", (SIZE, SIZE), TRANSPARENT)
    d = ImageDraw.Draw(im)
    white, grey = (250, 248, 240, 255), (200, 198, 190, 255)
    d.rectangle([3, 2, 28, 29], fill=grey)
    d.rectangle([3, 2, 28, 28], fill=white)
    d.rectangle([5, 4, 26, 22], fill=(120, 190, 230, 255))            # sky-blue background
    d.rectangle([5, 19, 26, 22], fill=(110, 170, 110, 255))           # a bit of grass
    orange, dark_o, cream = (240, 150, 60, 255), (200, 100, 30, 255), (255, 235, 200, 255)
    d.polygon([(8, 11), (9, 5), (13, 9)], fill=orange)                # ears
    d.polygon([(24, 11), (23, 5), (19, 9)], fill=orange)
    d.polygon([(9, 9), (10, 7), (11, 9)], fill=(255, 160, 170, 255))
    d.polygon([(23, 9), (22, 7), (21, 9)], fill=(255, 160, 170, 255))
    d.ellipse([7, 8, 25, 21], fill=orange)                            # head
    d.ellipse([11, 14, 21, 21], fill=cream)                           # muzzle
    for x0 in (11, 19):                                               # eyes with a sparkle
        d.rectangle([x0, 12, x0 + 2, 14], fill=(30, 30, 40, 255))
        d.point((x0, 12), fill=(255, 255, 255, 255))
    d.point((15, 15), fill=(255, 110, 140, 255))                      # nose
    d.point((16, 15), fill=(255, 110, 140, 255))
    px(d, [(15, 17), (16, 17), (14, 16), (17, 16)], dark_o)           # mouth
    px(d, [(7, 15), (8, 16), (24, 15), (23, 16)], white)              # whiskers
    px(d, [(10, 9), (12, 9), (21, 9), (19, 9)], dark_o)               # forehead stripes
    d.rectangle([8, 24, 23, 25], fill=(220, 215, 205, 255))           # a scribbled caption line
    im.save(out_path("cats", "cat_photo"))


def paintbrush():
    im = Image.new("RGBA", (SIZE, SIZE), TRANSPARENT)
    d = ImageDraw.Draw(im)
    # a diagonal brush, handle at the lower left, tip at the upper right
    for i in range(14):
        x, y = 5 + i, 26 - i
        d.rectangle([x, y, x + 2, y + 2], fill=(150, 90, 40, 255) if i % 5 else (110, 64, 28, 255))
    for i in range(14, 18):
        x, y = 5 + i, 26 - i
        d.rectangle([x, y, x + 2, y + 2], fill=(200, 205, 215, 255))  # metal ferrule
    d.polygon([(22, 10), (27, 5), (28, 4), (26, 9)], fill=(220, 40, 60, 255))  # bristles
    d.rectangle([26, 3, 29, 6], fill=(230, 60, 80, 255))
    px(d, [(29, 3), (28, 2)], (255, 180, 190, 255))
    d.ellipse([3, 24, 8, 29], fill=(60, 120, 220, 255))               # a drop of blue paint
    im.save(out_path("everyday", "paintbrush"))


def pencil():
    im = Image.new("RGBA", (SIZE, SIZE), TRANSPARENT)
    d = ImageDraw.Draw(im)
    for i in range(20):
        x, y = 4 + i, 27 - i
        d.rectangle([x, y, x + 2, y + 2], fill=(250, 205, 50, 255) if i % 4 else (225, 170, 30, 255))
    for i in range(20, 24):
        x, y = 4 + i, 27 - i
        d.rectangle([x, y, x + 2, y + 2], fill=(240, 210, 160, 255))  # sharpened wood
    d.polygon([(28, 3), (29, 2), (30, 1), (29, 4)], fill=(50, 50, 60, 255))
    d.rectangle([2, 26, 6, 30], fill=(240, 120, 140, 255))            # eraser
    d.rectangle([5, 23, 7, 27], fill=(190, 195, 205, 255))
    im.save(out_path("everyday", "pencil"))


def book():
    im = Image.new("RGBA", (SIZE, SIZE), TRANSPARENT)
    d = ImageDraw.Draw(im)
    d.rectangle([5, 4, 27, 27], fill=(40, 40, 70, 255))               # cover edge
    d.rectangle([6, 5, 26, 26], fill=(150, 40, 50, 255))
    d.rectangle([6, 5, 9, 26], fill=(110, 28, 36, 255))               # spine
    d.rectangle([13, 9, 23, 13], fill=(232, 196, 90, 255))            # a gold title plate
    d.rectangle([14, 17, 22, 18], fill=(232, 196, 90, 255))
    d.rectangle([14, 21, 19, 22], fill=(232, 196, 90, 255))
    d.rectangle([6, 27, 27, 29], fill=(245, 240, 225, 255))           # pages along the bottom
    for x in range(8, 27, 3):
        d.point((x, 28), fill=(200, 195, 180, 255))
    im.save(out_path("everyday", "book"))


def vinyl_record():
    im = Image.new("RGBA", (SIZE, SIZE), TRANSPARENT)
    d = ImageDraw.Draw(im)
    d.ellipse([2, 2, 29, 29], fill=(20, 20, 26, 255))
    for r in (13, 11, 9):                                             # grooves
        d.ellipse([16 - r, 16 - r, 15 + r, 15 + r], outline=(52, 52, 64, 255))
    d.ellipse([10, 10, 21, 21], fill=(220, 60, 70, 255))              # label
    d.ellipse([13, 13, 18, 18], fill=(250, 235, 200, 255))
    d.ellipse([15, 15, 16, 16], fill=(20, 20, 26, 255))               # spindle hole
    px(d, [(6, 8), (7, 6), (9, 5)], (120, 120, 140, 255))             # a glint
    im.save(out_path("everyday", "vinyl_record"))


def film_camera():
    im = Image.new("RGBA", (SIZE, SIZE), TRANSPARENT)
    d = ImageDraw.Draw(im)
    d.rectangle([3, 9, 28, 25], fill=(30, 30, 38, 255))               # body outline
    d.rectangle([4, 10, 27, 24], fill=(150, 154, 166, 255))
    d.rectangle([4, 14, 27, 22], fill=(40, 40, 52, 255))              # leatherette band
    d.rectangle([5, 6, 11, 9], fill=(30, 30, 38, 255))                # viewfinder hump
    d.rectangle([6, 7, 10, 9], fill=(180, 184, 196, 255))
    d.rectangle([21, 7, 26, 9], fill=(240, 190, 60, 255))             # flash
    d.ellipse([10, 11, 22, 23], fill=(20, 20, 26, 255))               # lens
    d.ellipse([12, 13, 20, 21], fill=(70, 100, 170, 255))
    d.ellipse([14, 15, 18, 19], fill=(30, 40, 90, 255))
    px(d, [(13, 14), (14, 14)], (220, 235, 255, 255))                 # glass glint
    im.save(out_path("everyday", "film_camera"))


if __name__ == "__main__":
    for name, title in PAINTINGS.items():
        framed_painting(name, title)
    cat_photo()
    paintbrush()
    pencil()
    book()
    vinyl_record()
    film_camera()
    print("wrote projectiles to", os.path.normpath(OUT))
