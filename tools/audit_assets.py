"""Finds assets and scripts that nothing uses (dead files), so they are not checked in.

Usage (from the repo root):
    python tools/audit_assets.py            lists every tracked/untracked asset or script that no code, scene or data file refers to
    python tools/audit_assets.py --all      also prints the number of files it considered used

A file counts as used when
  * its name (without the extension) appears as a whole word in the code (*.gd, comments left out), scenes (*.tscn), project/export settings or
    data (*.json, *.cfg, *.godot) that are not docs; or
  * a part of its name up to an underscore appears in the code as the start of a built name (`"face_" + expression`, `"explosion_%d"`), or
  * for the Kenney character poses (`<skin>_<pose>.png`): the skin is named in the code and the pose is one the game shows (tools/audit_rules.json);
  * for the hero's parts (`<skin>_<pose>_<part>[_<style>].png`): the same, and the part and the style are ones the wardrobe knows (tools/audit_rules.json).
Pictures made only for people to look at (sprite sheets, previews) are reported separately: art tools must write those into tmp/, not the repo.
Pictures and sounds outside assets/ (in levels/, scripts/ or scenes/) are reported too.

Exit code 1 when something unused is found, so the check can run in a test or a hook.
"""
import json
import os
import re
import subprocess
import sys

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
RULES = json.load(open(os.path.join(ROOT, "tools", "audit_rules.json"), encoding="utf-8"))
ASSET_DIRS = ("assets", "scripts")
ASSET_EXT = (".png", ".jpg", ".jpeg", ".webp", ".svg", ".mp3", ".ogg", ".wav", ".gd", ".gdshader", ".tres", ".tscn", ".ttf", ".otf")
# Pictures and sounds belong in assets/ only: levels/ is data, scripts/ is code, scenes/ is scenes.
MEDIA_EXT = (".png", ".jpg", ".jpeg", ".webp", ".svg", ".mp3", ".ogg", ".wav")
MEDIA_FREE_DIRS = ("levels/", "scripts/", "scenes/")
CORPUS_EXT = (".gd", ".tscn", ".tres", ".json", ".cfg", ".godot", ".gdshader")
LOOKS_ONLY = re.compile(RULES["looking_only_pattern"])


def git_files():
    out = subprocess.run(["git", "ls-files", "--cached", "--others", "--exclude-standard"], cwd=ROOT, capture_output=True, text=True, check=True).stdout
    return [f for f in out.splitlines() if os.path.exists(os.path.join(ROOT, f))]


def read(f):
    return open(os.path.join(ROOT, f), encoding="utf-8", errors="ignore").read()


def corpus(files):
    parts = []
    for f in files:
        if not f.endswith(CORPUS_EXT) or f.startswith(("docs/", ".claude/", "tmp/")):
            continue
        text = read(f)
        if f.endswith(".gd"):
            text = "\n".join(line for line in text.splitlines() if not line.lstrip().startswith("#"))
        parts.append(text)
    return "\n".join(parts)


def built_prefix_used(stem, text):
    """True if the code builds names that start like `stem` ("face_" + x, "explosion_%d")."""
    for m in re.finditer("_", stem):
        prefix = stem[: m.end()]
        if re.search(r'["\']%s["\'%%]' % re.escape(prefix), text) or ('"%s' % prefix) in text and ("%s%%" % prefix) in text:
            return True
    base = re.sub(r"\d+$", "", stem)
    return base != stem and base in text


def is_used(f, stem, words, text):
    if stem in words:
        return True
    m = re.match(RULES["character_pose_pattern"], f)
    if m:
        return '"%s"' % m.group("skin") in text and m.group("pose") in RULES["character_poses"]
    m = re.match(RULES["character_part_pattern"], f)
    if m:
        return ('"%s"' % m.group("skin") in text and m.group("pose") in RULES["character_poses"] and m.group("part") in RULES["character_parts"])
    return built_prefix_used(stem, text)


def main():
    files = git_files()
    text = corpus(files)
    words = set(re.findall(r"[A-Za-z0-9_]+", text))
    unused, looks_only, used = [], [], []
    misplaced = [f for f in files if f.startswith(MEDIA_FREE_DIRS) and f.endswith(MEDIA_EXT)]
    if misplaced:
        print("Pictures or sounds outside assets/ (move them there, grouped as assets/<category>/<feature>/):")
        for f in misplaced:
            print("  ", f)
    for f in files:
        if not f.startswith(ASSET_DIRS) or not f.endswith(ASSET_EXT) or f in RULES["always_used"]:
            continue
        stem = os.path.splitext(os.path.basename(f))[0]
        if LOOKS_ONLY.search(f):
            looks_only.append(f)
            continue
        found = is_used(f, stem, words, text)
        if not found and f.endswith(".gd"):
            m = re.search(r"^class_name\s+(\w+)", read(f), re.M)
            found = bool(m) and len(re.findall(r"\b%s\b" % m.group(1), text)) > 1
        (used if found else unused).append(f)
    if looks_only:
        print("Pictures made only for looking at (the art tools write these into tmp/, they do not belong in the repo):")
        for f in looks_only:
            print("  ", f)
    if unused:
        print("Not referenced by any code, scene or data file:")
        for f in unused:
            print("  ", f)
    print("%d used, %d unused, %d only for looking at" % (len(used), len(unused), len(looks_only)))
    return 1 if unused or looks_only or misplaced else 0


if __name__ == "__main__":
    sys.exit(main())
