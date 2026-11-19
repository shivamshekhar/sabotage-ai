"""Brings every new tile picture into the level editor (and the level command-line tool): run it after adding pictures to the tile folders.

Usage (from the repo root):
    python tools/sync_editor.py            adds a tile-registry entry for every tile picture the editor does not offer yet
    python tools/sync_editor.py --check    changes nothing; exit code 1 and a list if something is missing (for tests and hooks)

How the editor learns about things: its palette is built from the tile registry (levels/common/tile_registry.json), so a picture in
levels/common/tiles/** is only placeable once it has an entry there. This tool finds the pictures that have no entry (nothing in the registry or
the game code names them) and adds one each, as decor (a picture behind the player) in a group named after its folder, with the next free id.
Change `behavior` to "solid" (a block the player stands on) or move the entry to another group by hand if the new tile should be something else.
It also reports registry entries whose picture no longer exists. Other things the editor lists (objects, minigames, level/terrain/player values)
come from tools/level_editor/catalog.json, which tools/tests/editor_sync_test.gd checks against the game.
"""
import json
import os
import re
import subprocess
import sys

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
REGISTRY = os.path.join(ROOT, "levels", "common", "tile_registry.json")
TILE_FOLDERS = (os.path.join("levels", "common", "tiles", "data_center"), os.path.join("levels", "common", "tiles", "kenney_industrial"))
NEXT_DECOR_ID = 1000                      # decor and anything else starts here (see the registry's own doc)
GROUP_PREFIX = "Extra decor: "
# BUILT_IN_FAMILIES: tile families the game picks by building the name (SpriteLibrary.TILE_CATEGORIES): ground_start / _middle / _end ..., ledge_*, ladder_* ...
BUILT_IN_FAMILIES = {"ground", "ledge", "ladder", "spikes", "monitor", "panel", "gear", "canister", "siren", "lamp", "sign", "arrow", "powerup", "barrier"}


def tile_pictures():
    """{stem: category folder} of every tile picture (the themed folder wins when both have one)."""
    found = {}
    for folder in reversed(TILE_FOLDERS):
        for dirpath, _, files in os.walk(os.path.join(ROOT, folder)):
            for f in files:
                if f.endswith(".png"):
                    found[f[:-4]] = os.path.basename(dirpath)
    return found


def code_words():
    """Every word in the game's code (comments left out): tiles the game picks by name need no registry entry."""
    out = subprocess.run(["git", "ls-files", "--cached", "--others", "--exclude-standard", "scripts"], cwd=ROOT, capture_output=True, text=True, check=True).stdout
    words = set()
    for f in out.splitlines():
        if f.endswith(".gd") and os.path.exists(os.path.join(ROOT, f)):
            text = open(os.path.join(ROOT, f), encoding="utf-8", errors="ignore").read()
            text = "\n".join(l for l in text.splitlines() if not l.lstrip().startswith("#"))
            words.update(re.findall(r"[A-Za-z0-9_]+", text))
    return words


def main():
    check_only = "--check" in sys.argv
    registry = json.load(open(REGISTRY, encoding="utf-8"))
    kinds = registry["kinds"]
    named = set()
    for k in kinds:
        sprite = k.get("sprite", {})
        if isinstance(sprite, dict):
            named.update(v for v in sprite.values() if isinstance(v, str))
    pictures = tile_pictures()
    words = code_words()
    def used_by_code(stem):
        """True if the code names the picture, or builds its name from a family prefix ("ground_" + kind)."""
        if stem in words:
            return True
        family = stem.split("_")[0]
        return family in BUILT_IN_FAMILIES
    missing = sorted(s for s in pictures if s not in named and not used_by_code(s))
    gone = sorted(k["key"] for k in kinds if isinstance(k.get("sprite"), dict) and "tile" in k["sprite"] and k["sprite"]["tile"] not in pictures)
    if gone:
        print("Registry entries whose picture is missing:", ", ".join(gone))
    if not missing:
        print("The editor offers every tile picture.")
        return 1 if gone else 0
    print("%d tile picture(s) the editor does not offer yet:" % len(missing))
    for s in missing:
        print("  ", s, "(", pictures[s], ")")
    if check_only:
        return 1
    next_id = max(NEXT_DECOR_ID, max(k["id"] for k in kinds) + 1)
    for s in missing:
        kinds.append({"id": next_id, "key": "decor_" + s, "name": s.replace("_", " ").capitalize(), "group": GROUP_PREFIX + pictures[s], "behavior": "decor", "sprite": {"tile": s}})
        next_id += 1
    with open(REGISTRY, "w", encoding="utf-8", newline="\n") as f:
        json.dump(registry, f, indent=2, ensure_ascii=False)
        f.write("\n")
    print("Added %d entries to the tile registry (decor; edit behavior/group by hand if needed)." % len(missing))
    return 0


if __name__ == "__main__":
    sys.exit(main())
