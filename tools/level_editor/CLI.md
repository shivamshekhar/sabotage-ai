# Level CLI

Make, edit and check level files (`*.sablevel.json`, format in [FORMAT.md](FORMAT.md)) without the editor window. Meant for
scripts and AI assistants. Each command prints one JSON object whose `"ok"` field says whether it worked; the exit code is
0 on success, 1 otherwise.

```
tools/level_cli.sh help
tools/level_cli.sh pieces                       # what from-plan understands
tools/level_cli.sh catalog                      # every tile, object, and value with defaults
```

Set `GODOT=/path/to/Godot_..._console.exe` if Godot is not the winget install. Paths are absolute, `res://`, `user://`, or
relative to the project root (so `levels/my.sablevel.json`).

## Fastest way to a new level

1. Write a plan: a JSON list of pieces (see `pieces`). Example, saved as `plan.json`:
   `[["flat",8,"PK"],["hurdle"],["pit",3,"A"],["rise",4],["flat",8,"B"],["tunnel","1"],["flat",7,"B"],["drop",3],["flat",6,"K"],["exit"]]`
2. `tools/level_cli.sh from-plan levels/level_06/level.sablevel.json --plan @plan.json --title "MY LEVEL"`. A level lives in
   `levels/<id>/level.sablevel.json`: the id is the folder name, and the level gets its own `assets/levels/<id>/background/` folder (copied
   from level_01's, or `--background-from <id>`; the wrapper then makes Godot import the images). `levels/common/` holds what
   all levels share (the tile registry) and is not a level.
3. `tools/level_cli.sh solve levels/level_06/level.sablevel.json` proves the exit is reachable, with no dead ends, and gates open in order.
4. Fine-tune: `place`, `set-tile`, `fill`, `set player speed=450`, `minigame add ...`; `show` to look at the map.
5. Chain it into the game: `tools/level_cli.sh set levels/level_05/level.sablevel.json meta next=level_06` (a level's `meta.next`
   names the level after it; none = the game restarts).
6. Play it: `SABOTAGE_LEVEL=level_06 godot --path .`, or `godot --path . -- --level-file=levels/level_06/level.sablevel.json`, or open it in the editor.

Rules for a plan: start with `["flat", n, "PK"]` (spawn + checkpoint), end with one `["exit"]`, give each `tunnel` its own laser
id 1-9, keep `drop` to 6 rows or fewer, flats with a Bro (`B`) need at least 7 columns, aim for 100-140 columns in total.

## Commands

| Command | What it does |
|---|---|
| `new <file> [--cols N] [--rows N] [--id] [--title] [--next] [--background-from ID]` | empty level with floor, spawn, exit |
| `from-plan <file> --plan <json or @file> [--theme S,G,R,M] [--liquid A\|F\|N\|W]` | level built from pieces |
| `list` | the levels of the game: id, title, next level, size, files |
| `convert <id> <file>` | an existing level (or `test`) copied to a new file |
| `set-tile <file> <col> <row> <tile>` | one tile. `<tile>` is a tile number (`12`), a key (`ground`, `decor_gear_half`) or a built-in map character (`#`) |
| `pit-signs <file>` | the warning sign (a green skull for toxic waste, a flame for lava, the radiation trefoil for nuclear waste, a piranha for the piranha tank) on the ground before every deadly pit that has none; run it again any time, it only adds what is missing. `solve` fails while a pit has no sign |
| `fill <file> <c0> <r0> <c1> <r1> <tile>` | rectangle (`0` or `.` erases) |
| `catalog tiles [--search X] [--group X] [--limit N]` | the tile registry (there can be thousands): number, key, name, group, behaviour |
| `export-csv <file> <csv>` / `import-csv <file> <csv>` | the tiles as a plain CSV grid of tile numbers (a spreadsheet or tile editor) and back |
| `upgrade <file>` | rewrite a level file in the current format (version 2: CSV tile numbers) |
| `place <file> <type> <col> <row> [--name T] [--prop k=v]...` | ai_bro, checkpoint, exit, player_spawn, lock_terminal, tank_settings; `laser_gate` needs `--id 1-9 --height N` |
| `remove <file> <col> <row>` | erase tile and object |
| `set <file> player\|terrain\|meta k=v...` | player values, gravity etc., title/id/next |
| `minigame <file> add --id --kind [--name] [--param k=v]... [--question "q\|right\|wrong1\|wrong2"]...` | also `list`, `remove --id` |
| `info <file> [--solve]` | counts, values, problems |
| `validate <file>` | problems only |
| `solve <file>` | the generic level checks: exit reachable, no dead ends, gates have computers and block the way, sealed to the ceiling, the power-up box reachable (exit code 1 if any fails) |
| `show <file> [--rows a-b] [--cols a-b]` | the map as text with a column ruler |

Rows count from the top (row 0); a tile's `(col, row)` is where its object stands. Editing commands save in place and return the
level's remaining `problems`; fix them before playing.
