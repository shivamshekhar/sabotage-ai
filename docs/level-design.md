# Designing levels

Every level of the game is a **level file** in its own folder. They are made with the level editor or the level CLI, and the game
plays them as they are.

```
levels/                       the data
  common/tile_registry.json   every kind of tile
  level_01/
    level.sablevel.json       the level: tiles, objects, player/terrain values, puzzles, title, next level
  level_02/ ...
assets/levels/                the art, the same shape (see art.md)
  common/                     art every level shares
    tiles/  machines/  pit_hazards/
  level_01/
    background/               this level's parallax background layers (far, mid_base, mid_leds_a, mid_leds_b, cables)
  level_02/ ...
```

| Way to make a level | Use it for | Docs |
|---|---|---|
| **Level editor** (a Godot window: palette, drag and drop, inspectors) | making a level by hand | [tools/level_editor/README.md](../tools/level_editor/README.md) |
| **Level CLI** (`tools/level_cli.sh`) | scripts and AI assistants making and checking levels | [tools/level_editor/CLI.md](../tools/level_editor/CLI.md) |

The map's `E` is the level's **exit door** (see gameplay.md): the door is 2 tiles wide and 3 tall and stands on the `E` tile, so the tiles above it and beside it must be free
(`level_traversal_test.gd` checks it for every level).

The file format is described in [tools/level_editor/FORMAT.md](../tools/level_editor/FORMAT.md). Play any file with
`godot --path . -- --level-file=path/to/level.sablevel.json`.

## The levels

The ids are the folder names. The game starts on `level_01`; finishing a level loads the one named in its `meta.next`, and after
the last one it starts again.

| Id | Title | Theme |
|---|---|---|
| `level_01` | SERVER HALL | toxic waste, a first Bro, a ladder climb, a first laser gate |
| `level_02` | COOLING PLANT | robotic-piranha tanks, a ledge climb, a gallery of ledges |
| `level_03` | THE FOUNDRY | lava, a stepped pyramid, stepping stones, a gauntlet |
| `level_04` | REACTOR CORE | nuclear waste, a tall ladder, two laser gates |
| `level_05` | THE MAINFRAME | everything, three laser gates and a final arena with a boss Bro |
| `test` | TEST LEVEL | a sandbox built in code (`LevelData.test_level()`) that the automated tests rely on; do not change it |

Pick one with `SABOTAGE_LEVEL=<id>` (for example `SABOTAGE_LEVEL=level_03 godot --path .`). `tools/level_cli.sh list` shows them all.

Each level has its own colour-graded copy of the background (`tools/art/make_level_backgrounds.py` makes levels 2 to 5 from level 1's).

## Making a new level

1. `tools/level_cli.sh from-plan levels/level_06/level.sablevel.json --plan @plan.json --title "MY LEVEL"` builds it from pieces and gives
   it its own `background/` folder (see [CLI.md](../tools/level_editor/CLI.md)); or open the editor (`tools/level_editor.sh`) and
   draw it by hand, saving into `levels/level_06/`.
2. `tools/level_cli.sh solve levels/level_06/level.sablevel.json` proves the exit can be reached and the laser gates work in order.
3. Chain it: `tools/level_cli.sh set levels/level_05/level.sablevel.json meta next=level_06`.
4. `tools/run_tests.sh` checks every level folder (`tools/tests/levels_test.gd`).

## Tiles

A level's tiles are a **CSV grid of tile numbers** (like Tiled's CSV layers): row after row of numbers in `level.sablevel.json`
(`tools/level_cli.sh export-csv` / `import-csv` convert to and from a plain `.csv`). Every number is the permanent `id` of a kind in
`levels/common/tile_registry.json`, which is built for any number of tile kinds (1000+ is fine):

- **A new solid block, decor picture or decor machine is one entry in the registry and its sprite, with no code change.** Give it a
  new `id`, a `key`, a `name`, a `group`, `"behavior": "solid"` / `"decor"` / `"machine"` and a `sprite`. It shows up in the editor's
  palette (searchable, large groups start folded) and in `tools/level_cli.sh catalog tiles`.
- Kinds with behaviour of their own (ground, ladders, spikes, pits, enemies, lasers...) are built into the game and have a map
  character; see the table in [FORMAT.md](../tools/level_editor/FORMAT.md). Inside the game the map is still rows of characters (a
  private one per generic kind), and `TileRegistry.physics_rows()` reduces a map to what each tile does for the solver and the AI.

Ground, ledge and slime tiles pick their start/middle/end variant from their neighbours.

## Fair jumps

The limits come from the movement constants in `scripts/player/player.gd` (the comment above each has the formulas):

- maximum step height = `JUMP_VELOCITY`² / (2 · `GRAVITY`)
- maximum gap you can jump = `SPEED` · air time, where air time = 2 · |`JUMP_VELOCITY`| / `GRAVITY`

Keep steps and gaps comfortably inside them. `tools/tests/lib/level_solver.gd` simulates the player's jumps from every spot; the
level tests and `tools/level_cli.sh solve` use it to prove a level can be finished and has no dead ends. To print and solve one
level: `SABOTAGE_LEVEL=level_02 godot_console --headless --path . --script res://tools/solve_level.gd`.

## Hazards, enemies, checkpoints

- **Spikes** (`^` floor, `v` ceiling) hurt for 20% of health. **Deadly pits** (`A` toxic waste, `F` lava, `N` nuclear waste,
  `W` piranha tank) kill, and each has creatures that leap out of it (puffer fish and poison gas in the toxic waste, lava balls in the
  lava, glowing eels in the glowing nuclear waste, robot piranhas in the tank; see [gameplay.md](gameplay.md)). Falling further than the
  fall-death height also kills.
- **AI Bros** (`B`) need flat ground to pace on; the builder and the validator report a Bro without room.
- **Checkpoints** (`K`) set where you respawn.

## Laser force fields and computers

A digit `1`-`9` in the map is a laser field and a solid wall while on; the digit is its id. Each is switched off by one computer,
the lock terminal `L`, which opens the nearest gate unless its `laser` value names another. Standing at it and pressing E (USE on a
phone) opens a puzzle popup; solving it switches the field off. In the editor there is one "Laser gate" item: a new gate gets the
lowest unused id, and you can change it in the inspector.

**Invisible walls:** the tile `invisible_wall` (id 900, group "Boundaries" in the editor palette) fences the player in without a visible
wall: only the player collides with it (physics layer `PhysicsLayers.BARRIER`), enemies, thrown objects and the solver ignore it, and the
editor shows it as a faint hatched block that is not drawn in the game.

The 10 puzzles are `Minigame` subclasses in `scripts/ui/minigames/`: memory pads, a timing bar, a rotating lock (`ring_lock`: a
turning arc and a still marker), a safe cracker (`safe_cracker`: nested rings locked one by one), a stacker (`stacker`: drop a sliding
block onto a tower), "don't press the red button", "press the button that SAYS green" (three buttons), "wrong answers only" (3
questions), button mashing (tap a small red arcade button 4 times while it hops around) and a riddle captcha (a funny riddle told by the thing itself, such as "I have 88 keys but
cannot open a single door. What am I?", and six cartoon pictures with one right answer; a stockpile of 28 riddles and 48 cartoon emoji
pictures in `assets/ui/captcha/`). The captcha is *resting*: it is not in the "random" choice (`HackPopup.RESTING`) but can still be
asked for by name. To add a puzzle, subclass `Minigame` (or `QuizGame` for multiple choice), give it `auto_solve()` / `auto_fail()` test
hooks and register it in `HackPopup` (`GAME_NAMES`, `_make_game`) and in `tools/level_editor/catalog.json`;
`tools/tests/minigame_test.gd` then checks it. Always put a computer where the player can reach it before its laser.

The hero is the Kenney `player` character and the AI Bro the `zombie`; only the ten poses the game shows are kept in `assets/characters/` (`tools/audit_rules.json` lists them). To use another character, add its poses there and point `PlayerSprite.CHARACTER` at it.

## Laser gates and power-up boxes

A laser gate must close its corridor completely: the gate fills the corridor from the floor to the slab above it, and above the slab a pillar of ground tiles runs on up to the ceiling (a vehicle with a booster could otherwise fly over the slab). `tools/tests/powerup_levels_test.gd` checks that every gate column is solid from the ceiling down to the gate and that a flying mech cannot get past any gate.

Every level has exactly one power-up box (tile `powerup_box`, group "Pickups"), placed as a challenge: over a pit or gap, a tile or two past a ledge's end and two rows above the ledge (105 px above its top), so the player has to jump from the ledge and come down on it. The test checks that a player on foot can reach it and that it cannot be reached from the floor far below.
