# The player's sprites: folders and names

The hero is drawn from **parts** (hair, torso, boots, ...) that are put one over the other. Every part has its own pictures, so the wardrobe can swap one part
without touching the others. This page says where those pictures live and how they are named. The picture generator is `tools/art/generate_player.py`; the code that
reads them is `WardrobeCatalog` (what exists) and `OutfitComposer` (puts them together).

## Folder structure

```
assets/characters/saboteur/player/
  <part>/                       a part WITHOUT styles: head, arms, gun
    player_<pose>_<part>.png
  <part>/<style>/               a part WITH styles: hair, goggles, torso, gloves, pants, boots
    player_<pose>_<part>.png
```

The parts that have styles, and the styles that exist now:

| Part (slot) | Style folders |
|-------------|---------------|
| `hair` | `quiff` (original), `beret`, `crop`, `mohawk`, `slick`, `spiky`, `swept` |
| `goggles` | `on_chest` (original), `glasses`, `mask_and_band`, `shades`, `visor` |
| `torso` | `t_shirt` (original), `aloha_shirt`, `leather_vest`, `long_sleeves`, `martial_gi`, `shinobi_vest`, `sleeveless`, `smock` |
| `gloves` | `fingerless` (original), `arm_guards`, `paint_stained`, `studded`, `wristbands` |
| `pants` | `cargo` (original), `bandaged`, `martial_gi`, `painted`, `plain`, `ripped_jeans`, `slacks` |
| `boots` | `sneakers` (original), `combat_boots`, `martial_boots`, `plain`, `sandals`, `work_boots` |
| `gun` | no styles: `player_shoot_gun.png` (the EMP gun in the fist) and `player_wave_gun.png` (a ball of energy between both hands) |
| `head`, `arms` | no styles: the pictures are directly in the part folder |

Example: `hair/crop/player_walk2_hair.png`, `head/player_walk2_head.png`.

## Naming convention

- **File:** `player_<pose>_<part>.png`. The file name is the **same in every style folder** of a part; only the folder tells the styles apart.
- **Folder:** lower case letters and `_` (`long_sleeves`). The folder name is the style's id (it is saved in the player's outfit) and, in upper case with `_` shown
  as a space, what the wardrobe screen says (`long_sleeves` shows as LONG SLEEVES).
- **Pose** is one of the names in `tools/audit_rules.json` (`idle1`, `walk2`, `shoot`, ...). `CharacterPoses` says which pose shows which state.
- **Colour is not a style.** There is no folder per colour: colours are made at run time from the original tones (`WardrobeCatalog.PALETTES` and `recolor()`).
- **All pictures of a part are the same size** (128x110 px, the whole figure's frame, feet on the bottom edge, facing right), so they stack without any offset.
- **Parts and layers:** boots, pants, arms, torso, gun, gloves, head, hair, goggles, drawn in that order (bottom to top, `CharacterPoses.PARTS`).

## Which poses need a picture

- **`wave`** is the shooting pose of the `martial_gi` torso (`WardrobeCatalog.pose_for()`): the shoot pose with the arm that hangs behind removed from every part and the ball of energy held between both hands; every part has its own `player_wave_<part>.png`. Every other outfit shoots with `shoot` (the EMP gun).

- A pose that has parts of its own (`idle1..3`, `walk1/2`, `jump`, `fall`, `hurt`, `action1/2`, `climb1/2`, `shoot`) needs a picture for every part that has something in
  it. `gun` exists only in `shoot`; a part with nothing in a pose (goggles from behind) simply has no file there.
- `blink1..3` and `look` only have a `head` picture; the other parts come from `idle1..3` / `idle2` (`CharacterPoses.SHARED_PARTS`).
- A style that has no picture for a pose falls back to the part's original style for that pose (`OutfitComposer`). Aim to give every style every pose anyway.
- The "no part" choices (BALD, NONE, BARE HANDS) have no folder and no picture.

## Adding a new style (clothing)

1. Make a folder named for the style in the part's folder, e.g. `assets/characters/saboteur/player/torso/hoodie/`.
2. Put `player_<pose>_torso.png` for the poses in it (at least `idle1`, which `tools/tests/wardrobe_test.gd` requires; the full set is the aim).
   Draw it in `generate_player.py` (add it to `STYLE_FOLDERS` there) or by hand in the same 128x110 frame.
3. Run `godot --headless --path . --import`. That is all: the wardrobe finds the folder by itself and lists it (original style first, the others alphabetically).
4. Run `wardrobe_test` and `python tools/audit_assets.py` (a picture that does not follow the naming above is reported as unused).

## Hand-made pictures and the generator

`tools/art/generate_player.py` writes the pictures and remembers a fingerprint of each in `tools/art/player_pictures.json`. **A picture you changed by hand is never overwritten**:
the generator sees that the file no longer matches its fingerprint, keeps it and prints its name (`--force` redraws everything). The pieces of the painter, rocker, tropical and masked-ninja outfits are drawn by `tools/art/player_styles.py` (the generator hands it its helpers with `bind()`); seen from behind they get a round head of their own. The spiky hair is drawn from a hand-made template,
`tools/art/sources/spiky_hair_idle1.png` (the standing pose's picture, outline and shading included), which the generator moves onto the head of every other pose; to change the
look of that hair, edit the template and run the generator (the other poses follow, the pictures you edited by hand stay as they are).

## What is still in code

- The **original style** of each slot (`WardrobeCatalog.ORIGINAL_STYLES`): the one the hero starts in and the fallback.
- The **colour a style comes with** (`WardrobeCatalog.STYLE_COLORS`): the spiky hair is put on in yellow, and the player can still change it. A style with a **fixed colour** (`WardrobeCatalog.FIXED_COLORS`: the martial-arts top and pants are orange, its boots and wristbands blue) has no colour choice at all; its pictures are drawn in the slot's original colour and shown in the fixed one.
- The **colours** of each slot and how a slot is recoloured (`PALETTES`, `RULES`).
- Which slots can be left empty (`NONE_LABELS`).
- A brand-new slot (a cape, say) also needs its place in `CharacterPoses.PARTS`, `WardrobeCatalog.SLOTS` and the generator.

See also [art.md](art.md) (the generators) and [gameplay.md](gameplay.md) (the wardrobe screen).
