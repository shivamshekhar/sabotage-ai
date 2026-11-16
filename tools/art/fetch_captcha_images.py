"""Downloads the pictures of the "I am not a robot" captcha minigame: the cartoon emoji of Google's Noto Emoji set (Apache License 2.0),
and writes what the game needs.

Usage (needs Pillow and an internet connection; from the repo root):
    python tools/art/fetch_captcha_images.py            download every emoji in PICTURES, put each on a soft pastel square, save them as
                                                        small PNGs in assets/captcha/ and write the credits (assets/captcha/CREDITS.md)
                                                        and the list the game reads (assets/captcha/manifest.json)
The game ships the pictures (it never needs the internet). To add a picture, add its code point to PICTURES; to add or change a riddle,
edit RIDDLES; then run it again.

WHY EMOJI: friendly, colourful cartoon pictures in one consistent style, instantly recognisable even this small, and fine for players of
12 and up. Each is downloaded as it is published (128 px, the size the game shows them at: no scaling) and only placed on a pastel square
(the colour depends on the picture's name, so it never gives the answer away).

THE RIDDLES: each is an easy, funny riddle told by the thing itself ("I have 88 keys but cannot open a single door. What am I?") that does
not name its answer, with ONE right picture among five others. The game picks the right picture and five more from PICTURES, leaving out
the pictures in the riddle's `exclude` list: any picture that could also fit the riddle (the keyboard riddle leaves out the key, because a
key opens doors, and the laptop and the saxophone, because they have keys). Riddles are about things, never about the player.
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

# BACKGROUNDS: soft pastel colours the pictures are put on, chosen by the picture's name.
BACKGROUNDS = [(250, 236, 214), (219, 238, 250), (226, 246, 222), (252, 226, 232), (238, 230, 252), (253, 246, 206), (214, 244, 240)]

# PICTURES: file name -> the emoji's code points (hex, joined with _). First the answers of the riddles, then pictures that only serve as
# wrong answers. Do not add anything with legs, ears, hands, eyes, a tongue, a head or holes (people, animals, dolls, robots, flutes,
# cheese...): too many riddles are about those, and the wrong pictures must never fit a riddle.
PICTURES = {
    # answers
    "keyboard": "1f3b9", "alarm_clock": "23f0", "coin": "1fa99", "sponge": "1f9fd", "candle": "1f56f", "book": "1f4d6", "fire": "1f525",
    "needle": "1faa1", "umbrella": "2602", "telephone": "260e", "mushroom": "1f344", "banana": "1f34c", "shoe": "1f45f", "egg": "1f95a",
    "corn": "1f33d", "footprints": "1f463", "light_bulb": "1f4a1", "chair": "1fa91", "tree": "1f333", "snail": "1f40c", "newspaper": "1f4f0",
    "key": "1f511", "mirror": "1fa9e", "balloon": "1f388", "anchor": "2693", "magnet": "1f9f2", "ice_cube": "1f9ca", "rocket": "1f680",
    # only wrong answers
    "guitar": "1f3b8", "violin": "1f3bb", "drum": "1f941", "trumpet": "1f3ba", "saxophone": "1f3b7", "palette": "1f3a8", "scarf": "1f9e3",
    "socks": "1f9e6", "pencil": "270f", "scissors": "2702", "factory": "1f3ed", "satellite": "1f6f0", "framed_picture": "1f5bc",
    "laptop": "1f4bb", "printer": "1f5a8", "joystick": "1f579", "paintbrush": "1f58c", "crayon": "1f58d", "pinata": "1fa85", "scroll": "1f4dc",
}

# RIDDLES: the riddle, its answer (a picture name) and the pictures that could also fit it and so are never shown with it.
RIDDLES = [
    {"text": "I have 88 keys but cannot open a single door. What am I?", "answer": "keyboard", "exclude": ["key", "saxophone", "laptop", "printer", "joystick"]},
    {"text": "I have two hands but I have never clapped, and I scream every morning. What am I?", "answer": "alarm_clock", "exclude": []},
    {"text": "I have a head and a tail but no body. What am I?", "answer": "coin", "exclude": ["snail"]},
    {"text": "I am full of holes, yet I still hold water. What am I?", "answer": "sponge", "exclude": []},
    {"text": "I get shorter the longer I live. What am I?", "answer": "candle", "exclude": ["fire", "pencil", "crayon"]},
    {"text": "I have a spine but no bones, and I am full of stories. What am I?", "answer": "book", "exclude": ["newspaper", "scroll"]},
    {"text": "Feed me and I grow; give me a drink and I die. What am I?", "answer": "fire", "exclude": ["candle"]},
    {"text": "I have one eye but cannot see a thing. What am I?", "answer": "needle", "exclude": []},
    {"text": "I go up exactly when the rain comes down. What am I?", "answer": "umbrella", "exclude": []},
    {"text": "I have a ring but no finger. What am I?", "answer": "telephone", "exclude": []},
    {"text": "I am a kind of room with no doors and no windows. What am I?", "answer": "mushroom", "exclude": ["factory"]},
    {"text": "I am yellow, I am curved, and I am the star of every cartoon slip. What am I?", "answer": "banana", "exclude": []},
    {"text": "I have a tongue but I have never said a word. What am I?", "answer": "shoe", "exclude": []},
    {"text": "I must be cracked before I can be of any use. What am I?", "answer": "egg", "exclude": ["pinata", "balloon"]},
    {"text": "I have lots of ears but cannot hear a thing. What am I?", "answer": "corn", "exclude": []},
    {"text": "The more of me you take, the more you leave behind. What am I?", "answer": "footprints", "exclude": []},
    {"text": "I can fill a whole room but take up no space. What am I?", "answer": "light_bulb", "exclude": ["candle", "fire"]},
    {"text": "I have four legs but I have never walked anywhere. What am I?", "answer": "chair", "exclude": []},
    {"text": "I have plenty of bark but I have never bitten anyone. What am I?", "answer": "tree", "exclude": []},
    {"text": "I carry my house on my back and I am never in a hurry. What am I?", "answer": "snail", "exclude": []},
    {"text": "I am black and white and read all over. What am I?", "answer": "newspaper", "exclude": ["book", "scroll", "framed_picture"]},
    {"text": "I have teeth but have never bitten anyone, and I love opening doors. What am I?", "answer": "key", "exclude": ["keyboard"]},
    {"text": "I show you everything but never say a word. What am I?", "answer": "mirror", "exclude": ["framed_picture"]},
    {"text": "I am full of hot air and I go bang if you poke me. What am I?", "answer": "balloon", "exclude": ["pinata"]},
    {"text": "I am heavy, I love the sea floor, and I stop ships from drifting off. What am I?", "answer": "anchor", "exclude": []},
    {"text": "I am very attractive and I stick to metal. What am I?", "answer": "magnet", "exclude": []},
    {"text": "I am cold, I am clear, and I vanish in the sun. What am I?", "answer": "ice_cube", "exclude": []},
    {"text": "I count down before I leave and I never need a runway. What am I?", "answer": "rocket", "exclude": ["satellite"]},
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
    os.makedirs(OUT, exist_ok=True)
    for f in os.listdir(OUT):                                      # start clean (older versions kept pictures in group folders)
        path = os.path.join(OUT, f)
        if os.path.isdir(path):
            for g in os.listdir(path):
                os.remove(os.path.join(path, g))
            os.rmdir(path)
        elif f.endswith(".png"):
            os.remove(path)
    names = []
    total = 0
    credits = ["# Captcha pictures: credits", "",
               "The pictures are emoji from Google's Noto Emoji set (%s), licensed under the Apache License 2.0 "
               "(https://www.apache.org/licenses/LICENSE-2.0). They are shown here on a soft coloured square and with a smaller palette; "
               "otherwise they are as published." % SOURCE_PAGE, ""]
    for name, codes in PICTURES.items():
        try:
            raw = get(SOURCE % codes)
        except urllib.error.HTTPError as e:
            print("missing", name, codes, e.code)
            continue
        time.sleep(0.12)
        path = os.path.join(OUT, name + ".png")
        on_pastel(Image.open(BytesIO(raw)), name).quantize(PALETTE, method=Image.MEDIANCUT, dither=Image.NONE).save(path, optimize=True)
        total += os.path.getsize(path)
        names.append(name + ".png")
        credits.append("- `%s.png`: U+%s" % (name, codes.upper().replace("_", " U+")))
    riddles = [r for r in RIDDLES if r["answer"] + ".png" in names]
    manifest = {"pictures": names, "riddles": [{"text": r["text"], "answer": r["answer"] + ".png", "exclude": [e + ".png" for e in r["exclude"]]} for r in riddles]}
    json.dump(manifest, open(os.path.join(OUT, "manifest.json"), "w"), indent=1)
    open(os.path.join(OUT, "CREDITS.md"), "w", encoding="utf-8").write("\n".join(credits) + "\n")
    print("wrote %d pictures, %d riddles, %.0f KB" % (len(names), len(riddles), total / 1024))


if __name__ == "__main__":
    main()
