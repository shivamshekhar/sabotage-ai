"""Downloads the pictures of the "I am not a robot" captcha minigame: the cartoon emoji of Google's Noto Emoji set (Apache License 2.0),
and writes what the game needs.

Usage (needs Pillow and an internet connection; from the repo root):
    python tools/art/fetch_captcha_images.py            download every emoji in GROUPS, put each on a soft pastel square, save them as small
                                                        PNGs in assets/captcha/<group>/ and write the credits (assets/captcha/CREDITS.md)
                                                        and the list the game reads (assets/captcha/manifest.json)
The game ships the pictures (it never needs the internet). To add pictures, add their code points to GROUPS and run it again; to add or
change a question, edit QUESTIONS.

WHY EMOJI: they are friendly, colourful cartoon pictures in one consistent style, instantly recognisable even this small, and fine for
players of 12 and up. Each is downloaded as it is published (128 px, the size the game shows them at: no scaling) and only placed on a
pastel square (the colour depends on the picture, never on its group, so it does not give the answer away).

THE QUESTIONS: each has a DEFINITE answer and exactly ONE right picture: the one picture of the `target` group(s) among five pictures
from the `others` groups ("Which one goes on your feet?": the socks among a scarf, gloves, electronics, instruments and decorations;
"Which one is NOT an instrument?": one odd picture among five instruments). The `others` of a question must never include something that
could also be right.
"""
import json
import os
import time
import urllib.error
import urllib.request
from io import BytesIO

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(ROOT, "assets", "captcha")
SOURCE = "https://cdn.jsdelivr.net/gh/googlefonts/noto-emoji@v2.047/png/128/emoji_u%s.png"   # (the published 128 px pictures of the v2.047 release)
SOURCE_PAGE = "https://github.com/googlefonts/noto-emoji"
USER_AGENT = "SabotageGameCaptchaImageFetcher/1.0"

# TILE: the side in pixels of the pictures (the size Noto publishes them at, and the size the game shows them at: CaptchaGame.TILE_SIZE).
# PALETTE: colours in the saved PNG (flat cartoon colours, so 64 keeps them small without visible loss).
TILE = 128
PALETTE = 64

# BACKGROUNDS: soft pastel colours the pictures are put on, chosen by the picture's name (never by its group).
BACKGROUNDS = [(250, 236, 214), (219, 238, 250), (226, 246, 222), (252, 226, 232), (238, 230, 252), (253, 246, 206), (214, 244, 240)]

# GROUPS: the pictures of each group: [file name, code points of the emoji (hex, joined with _), what it is]. The groups are small
# and exact on purpose, so a question about one has a definite answer. A picture that does not exist in the set is skipped with a message.
GROUPS = {
    "instrument": [
        ["accordion", "1fa97", "accordion"], ["banjo", "1fa95", "banjo"], ["drum", "1f941", "drum"], ["flute", "1fa88", "flute"],
        ["long_drum", "1fa98", "long drum"], ["saxophone", "1f3b7", "saxophone"], ["trumpet", "1f3ba", "trumpet"], ["violin", "1f3bb", "violin"],
    ],
    "dancer": [
        ["dancer_woman", "1f483", "woman dancing"], ["dancer_man", "1f57a", "man dancing"], ["dancer_woman_light", "1f483_1f3fb", "woman dancing, light skin"],
        ["dancer_man_dark", "1f57a_1f3ff", "man dancing, dark skin"], ["dancer_woman_medium", "1f483_1f3fd", "woman dancing, medium skin"],
    ],
    "electronic": [
        ["desktop_computer", "1f5a5", "desktop computer"], ["laptop", "1f4bb", "laptop"], ["printer", "1f5a8", "printer"],
        ["fax_machine", "1f4e0", "fax machine"], ["satellite", "1f6f0", "satellite"], ["satellite_antenna", "1f4e1", "satellite antenna"],
        ["joystick", "1f579", "joystick"], ["light_bulb", "1f4a1", "light bulb"], ["mechanical_arm", "1f9be", "mechanical arm"],
    ],
    "robot": [["robot", "1f916", "robot"]],
    "drawing": [["pencil", "270f", "pencil"], ["crayon", "1f58d", "crayon"], ["paintbrush", "1f58c", "paintbrush"], ["palette", "1f3a8", "artist palette"]],
    "sewing": [["sewing_needle", "1faa1", "sewing needle"], ["thread", "1f9f5", "spool of thread"]],
    "decor": [
        ["teddy_bear", "1f9f8", "teddy bear"], ["nesting_dolls", "1fa86", "nesting dolls"], ["pinata", "1fa85", "pinata"],
        ["framed_picture", "1f5bc", "framed picture"], ["scroll", "1f4dc", "scroll"], ["amphora", "1f3fa", "clay amphora"],
    ],
    "gloves": [["gloves", "1f9e4", "gloves"]],
    "socks": [["socks", "1f9e6", "socks"]],
    "scarf": [["scarf", "1f9e3", "scarf"]],
}

# QUESTIONS: the question each round asks, the group(s) the one right picture comes from (`target`: a group, or a list of groups to pick
# one from) and the groups the five wrong pictures come from (`others`). The game picks one at random. Every question has a DEFINITE
# answer and exactly one right picture: no group in `others` may contain anything that could also be right (a laptop can play music, so
# laptops are never among the wrong pictures of "Which one can you play a song on?").
QUESTIONS = [
    {"text": "Which one can you draw with?", "target": "drawing", "others": ["scarf", "socks", "gloves", "instrument", "decor", "dancer", "sewing"]},
    {"text": "Beep boop. Which one is the robot?", "target": "robot", "others": ["instrument", "scarf", "socks", "gloves", "decor", "dancer", "drawing", "sewing"]},
    {"text": "Which one is a living, breathing human?", "target": "dancer", "others": ["electronic", "robot", "instrument", "decor", "scarf", "socks", "gloves", "drawing", "sewing"]},
    {"text": "Which one needs electricity to work?", "target": "electronic", "others": ["instrument", "scarf", "socks", "gloves", "decor", "drawing", "sewing", "dancer"]},
    {"text": "Which one needs no electricity and no batteries?", "target": ["instrument", "scarf", "socks", "gloves", "drawing", "sewing", "decor"], "others": ["electronic"]},
    {"text": "Someone smuggled an imposter into the orchestra. Which one is NOT an instrument?", "target": ["scarf", "socks", "gloves", "drawing", "sewing", "decor", "dancer"], "others": ["instrument"]},
    {"text": "Which one can you play a song on?", "target": "instrument", "others": ["scarf", "socks", "gloves", "drawing", "sewing", "decor", "dancer"]},
    {"text": "It is freezing outside. Which one do you put on?", "target": ["scarf", "socks", "gloves"], "others": ["electronic", "instrument", "decor", "drawing", "sewing"]},
    {"text": "Which one goes on your hands?", "target": "gloves", "others": ["scarf", "socks", "electronic", "instrument", "decor"]},
    {"text": "Which one goes on your feet?", "target": "socks", "others": ["scarf", "gloves", "electronic", "instrument", "decor"]},
    {"text": "Which one goes around your neck?", "target": "scarf", "others": ["socks", "gloves", "electronic", "instrument", "decor"]},
    {"text": "Which one would you use to sew on a button?", "target": "sewing", "others": ["scarf", "socks", "gloves", "drawing", "instrument", "decor", "electronic", "dancer"]},
]


def get(url):
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(req, timeout=40) as r:
        return r.read()


def on_pastel(im, name):
    """The emoji centred on a soft pastel square (the colour is chosen by the picture's name)."""
    im = im.convert("RGBA")
    background = BACKGROUNDS[sum(ord(c) for c in name) % len(BACKGROUNDS)]
    base = Image.new("RGBA", (TILE, TILE), background + (255,))
    side = int(TILE * 0.88)
    im = im.resize((side, side), Image.LANCZOS)
    base.alpha_composite(im, ((TILE - side) // 2, (TILE - side) // 2))
    return base.convert("RGB")


def main():
    manifest = {"questions": QUESTIONS}
    credits = ["# Captcha pictures: credits", "",
               "The pictures are emoji from Google's Noto Emoji set (%s), licensed under the Apache License 2.0 "
               "(https://www.apache.org/licenses/LICENSE-2.0). They are shown here on a soft coloured square and with a smaller palette; "
               "otherwise they are as published." % SOURCE_PAGE, ""]
    total = 0
    for group, items in GROUPS.items():
        folder = os.path.join(OUT, group)
        os.makedirs(folder, exist_ok=True)
        for f in os.listdir(folder):
            os.remove(os.path.join(folder, f))
        manifest[group] = []
        credits += ["## " + group, ""]
        for name, codes, label in items:
            try:
                raw = get(SOURCE % codes)
            except urllib.error.HTTPError as e:
                print("missing", name, codes, e.code)
                continue
            time.sleep(0.15)
            picture = on_pastel(Image.open(BytesIO(raw)), name)
            path = os.path.join(folder, name + ".png")
            picture.quantize(PALETTE, method=Image.MEDIANCUT, dither=Image.NONE).save(path, optimize=True)
            total += os.path.getsize(path)
            manifest[group].append(name + ".png")
            credits.append("- `%s/%s.png`: %s (U+%s)" % (group, name, label, codes.upper().replace("_", " U+")))
        credits.append("")
    json.dump(manifest, open(os.path.join(OUT, "manifest.json"), "w"), indent=1)
    open(os.path.join(OUT, "CREDITS.md"), "w", encoding="utf-8").write("\n".join(credits) + "\n")
    print("wrote", {k: len(v) for k, v in manifest.items() if k != "questions"}, "%.0f KB of pictures" % (total / 1024))


if __name__ == "__main__":
    main()
