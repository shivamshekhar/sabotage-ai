# sabotage.ai

A 2.5D puzzle-platformer for Android, built with Godot 4 (GDScript). You sabotage
data centers to stop capitalists replacing humans with AI.

## Run

```bash
godot --path .                       # play
SABOTAGE_PREVIEW=1 godot --path .    # zoomed-out view of the whole level
```

Controls: A/D or arrows to move, W/S or Up/Down to climb ladders, Space to jump.
On-screen touch buttons drive the same input actions.

## Project layout

```
scenes/
  main.tscn                 Entry scene (just runs core/main.gd)
scripts/
  core/
    main.gd                 Wires level, player, camera, touch UI, win banner
    input_setup.gd          Registers keyboard input actions (touch uses the same ones)
  player/
    player.gd               Movement: run, jump, ladders, respawn on hazards
    player_sprite.gd        Picks the character pose from the movement state
  level/
    level.gd                Builds a level from an ASCII map (sprites, colliders, hazards)
    level_data.gd           The level maps themselves (edit these to design levels)
    background.gd           Parallax data-center background (3 depth layers, blinking LEDs)
    sprite_library.gd       The only place that knows where art lives on disk
  ui/
    touch_controls.gd       On-screen buttons for phones
assets/
  kenney/
    platformer-pack-industrial/sprites/   Level art (see NAMES.md for the old numeric IDs)
    platformer-characters/<name>/         Character poses (player, adventurer, female, soldier, zombie)
  backgrounds/data_center/  Generated parallax layers (far, mid_base, mid_leds_a/b, cables)
tools/
  art/generate_background.py   Regenerates the background layers (needs Pillow)
```

## Regenerating the background

```bash
pip install pillow
python tools/art/generate_background.py assets/backgrounds/data_center
```

Tweak colours, rack layout or cable runs in the script, rerun, and Godot re-imports
the PNGs. Each layer is 1280px wide and tiles seamlessly; scroll speeds are set in
`scripts/level/background.gd` (lower = further away).

## Designing levels

Levels are ASCII grids in `scripts/level/level_data.gd`, one character per 70px
tile (legend at the top of that file). Ground/ledge/slime tiles pick their
start/middle/end variant automatically from neighbouring tiles.

Jump limits to design around: ~128px high (a bit under 2 tiles), ~256px far
(~3.6 tiles) at full speed. Keep steps to 1 tile and gaps to 3 tiles or less.

## Swapping the hero

Change `CHARACTER` in `scripts/player/player_sprite.gd` to `adventurer`, `female`,
`soldier` or `zombie`.

## Credits

Art by [Kenney](https://kenney.nl) (CC0): Platformer Pack: Industrial, Platformer Characters 1.
