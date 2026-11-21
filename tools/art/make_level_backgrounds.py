"""Give each level its own background: the layers in assets/levels/level_01/background/ (made by generate_background.py) are colour-graded
into assets/levels/<level>/background/ for the other levels, so each level has a look of its own (cool water, hot foundry, green
reactor, violet mainframe).

Usage (from the repo root; needs Pillow):
    python tools/art/make_level_backgrounds.py

Afterwards run `godot --headless --path . --import` so Godot imports the new images.
"""
import glob
import os

from PIL import Image

SOURCE = "assets/levels/level_01/background"

# GRADES: for each level, the factor each colour channel (red, green, blue) of its background layers is multiplied by. Above 1
# brightens that colour, below 1 removes it. Keep the values within about 0.6 to 1.3 so the racks stay readable.
GRADES = {
    "level_02": (0.78, 1.05, 1.20),   # the cooling plant: cold teal-blue
    "level_03": (1.25, 0.88, 0.68),   # the foundry: hot orange
    "level_04": (0.80, 1.20, 0.82),   # the reactor core: green glow
    "level_05": (1.10, 0.80, 1.25),   # the mainframe: violet
}


def grade(img, factors):
    r, g, b, a = img.convert("RGBA").split()
    r = r.point(lambda v: min(255, int(v * factors[0])))
    g = g.point(lambda v: min(255, int(v * factors[1])))
    b = b.point(lambda v: min(255, int(v * factors[2])))
    return Image.merge("RGBA", (r, g, b, a))


def main():
    for level, factors in GRADES.items():
        out = "assets/levels/%s/background" % level
        os.makedirs(out, exist_ok=True)
        for f in sorted(glob.glob(SOURCE + "/*.png")):
            grade(Image.open(f), factors).save(os.path.join(out, os.path.basename(f)))
        print("wrote", out)


if __name__ == "__main__":
    main()
