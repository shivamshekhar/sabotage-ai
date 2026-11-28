# Level file format (`*.sablevel.json`)

One JSON file describes one playable level. The **game** loads it (`scripts/level/level_file.gd`, class `LevelFile`) and the
**level editor** (this folder) reads and writes it. Every kind of tile and placeable object is an entry in the **tile registry**
(`levels/common/tile_registry.json`, see "Tiles" below); `catalog.json` (next to this file) lists the other things the editor can
edit (player, terrain and meta values, puzzle kinds, the pit creature settings). The editor builds its palette and its property
panels from them, so a new tile or a new tunable value is a data entry, not an editor change.

## Top level

```json
{
  "format": 2,
  "meta": { "id": "my_level", "title": "DATA CENTER 02", "next": "" },
  "grid": { "cols": 120, "rows": 40 },
  "terrain": { "gravity_scale": 1.0, "fall_death_height": 700.0, "pit_death_delay": 0.5, "background": "background" },
  "player": { "name": "SABOTEUR", "max_health": 100, "speed": 380.0, "...": "see catalog.json, section player" },
  "tiles": ["1,1,1,1,1", "1,0,0,26,1", "..."],
  "tile_keys": { "1": "ground", "26": "player_spawn" },
  "objects": { "12,30": { "type": "ai_bro", "name": "Lobby Bro", "props": { "chase_speed": 150.0 } } },
  "minigames": [{ "id": "riddles", "name": "Wrong answers only", "kind": "wrong_only", "params": { "rounds": 2 } }]
}
```

- `format` is `2`. Version 1 (the tiles as rows of text characters) is still read and is written as version 2 the next time the
  level is saved (`tools/level_cli.sh upgrade <file>` does that without opening the editor).
- `meta.id` is the level's id (letters, digits, `_` and `-`). `meta.title` is the level's name (shown in the editor and in the "Next:" line). `meta.stage` (optional) is the number the HUD shows for the level; without it the HUD counts the levels like Super Mario Bros: 1-1, 1-2, 1-3, 1-4, 2-1, ...
  `meta.boss` (optional) puts a boss fight in the level (`"salt_shaker"` = RAM Saltman): the game adds the boss, takes over the camera (it stops at the first and last `invisible_wall` tiles of the row above the floor) and finishes the level when the boss is beaten. See `levels/level_06`.
  `meta.next` is the id of the level to play after this one is finished (`""` = the game restarts from the first level).
- `grid.cols` x `grid.rows` is the size in tiles (one tile = 70 px, `Level.T`). `tiles` has exactly `rows` strings (row 0 is
  the top), each a CSV row of exactly `cols` tile numbers.
- `terrain` holds level-wide physics and look. `background` is the folder of the level's parallax layers (`far`, `mid_base`, `mid_leds_a`, `mid_leds_b`, `cables` PNGs): a path relative to the level's art folder (the default, `background`, is the `background/` folder in `assets/levels/<id>/`; for a file played with `--level-file`, the folder next to the file) or a full `res://` path. If it has no layers the first level's background is used. A level of the game lives in `levels/<id>/level.sablevel.json` with its own `assets/levels/<id>/background/`.
- `player` holds the player's tunable values for this level (all optional; a missing key keeps the game's default).
  The spawn point is the `P` tile (see below), not a value here.
- `tiles` is the map: a CSV grid of **tile numbers**, one JSON string per row, like the CSV layers of Tiled. A number is the `id`
  of a kind in the tile registry (0 = empty, 1 = ground, ...). Numbers are permanent, so files never go stale when kinds are added.
  `tile_keys` names each number used (`"1": "ground"`), so a file can be read without the registry and a mismatch with the registry
  is reported. `tools/level_cli.sh export-csv` / `import-csv` turn the tiles into a plain `.csv` file and back (a spreadsheet, or a
  tile editor that reads CSV, can edit it).
- `objects` stores extra information (a name and tuned values) for things that sit on a tile. The key is `"col,row"` of the
  tile that holds the object's marker character; `type` names the catalog entry; `name` is a free label (shown by the editor
  and, for enemies, above their health bar); `props` holds only the values that differ from the defaults. An object that has no
  entry here simply uses all defaults. An entry whose tile no longer holds the matching marker is ignored by the game.
- `minigames` are puzzle definitions a lock terminal can use (see "Minigames").

## Tiles: the registry

There is no limit on how many kinds of tile exist. They are listed in `levels/common/tile_registry.json`, one entry per kind:

```json
{ "id": 1000, "key": "decor_gear_half", "name": "Gear half", "group": "Extra decor: structure", "behavior": "decor", "sprite": { "tile": "gear_half" } }
```

- `id` is the number stored in level files. **Permanent: never change or reuse one.** Ids 0-99 are the game's own kinds, 100-999 solid
  blocks, 1000 and up decor and anything else (a convention; any unused number works).
- `key` is the readable name (used by the command-line tool, `tile_keys`, and the editor).
- `behavior` says what a kind without code of its own is: `solid` (a block the player stands on, drawn with `sprite`), `barrier` (an invisible wall: only the player is stopped by it, nothing is drawn in the game, the editor shows its `sprite`; id 900 `invisible_wall`), `powerup` (a floating power-up box: jump on it to get a vehicle, see docs/gameplay.md; not solid; id 901 `powerup_box`), `decor` (a
  picture behind the player; optional `z` depth and `tint` [r, g, b]) or `machine` (a decor machine with a `footprint`).
  **A new tile of those three kinds is only a new entry here and its art: no code changes.** `name` and `group` decide how the
  editor's palette shows it.
- The kinds the game has always had (ground, ladders, spikes, pits, checkpoints, AI Bros, ...) have a `char`, the one-character
  code the game uses for them inside. Everything else gets a private character derived from its id (`TileRegistry`), so a map
  inside the game is still a list of strings with one character per tile, with room for over 65,000 kinds.

The game's own kinds (id: key, character):

| id    | key                                                                                                                                                                   | char            |     | id    | key                                                                                                                             | char                  |
| ----- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------- | --- | ----- | ------------------------------------------------------------------------------------------------------------------------------- | --------------------- |
| 0     | `air` (empty)                                                                                                                                                         | `.`             |     | 1     | `ground` (auto start/middle/end/fill)                                                                                           | `#`                   |
| 2     | `ledge` (one-way)                                                                                                                                                     | `=`             |     | 3     | `ladder`                                                                                                                        | `H`                   |
| 4     | `crate_metal`                                                                                                                                                         | `X`             |     | 5     | `crate_orange`                                                                                                                  | `O`                   |
| 6     | `spikes_floor` (hurt)                                                                                                                                                 | `^`             |     | 7     | `spikes_ceiling` (hurt)                                                                                                         | `v`                   |
| 8-11  | `pit_toxic`, `pit_lava`, `pit_nuclear`, `pit_piranha` (deadly)                                                                                                        | `A` `F` `N` `W` |     | 30-38 | `laser_gate_1` ... `laser_gate_9`                                                                                               | `1`-`9`               |
| 26    | `player_spawn` (exactly one)                                                                                                                                          | `P`             |     | 27    | `exit` (exactly one)                                                                                                            | `E`                   |
| 28    | `checkpoint`                                                                                                                                                          | `K`             |     | 39    | `ai_bro` (stands on the tile below the marker)                                                                                  | `B`                   |
| 29    | `lock_terminal` (2x3 machine, letter = bottom-left tile)                                                                                                              | `L`             |     |       |                                                                                                                                 |                       |
| 12-15 | `gpu_rack` 2x3, `supercomputer` 3x3, `monitoring_station` 4x3, `server_tower` 1x3 (bottom-left tile; the rest of the footprint, to the right and up, must stay empty) | `G` `S` `M` `R` |     | 16-25 | other decor: `lamp`, `siren`, `canister`, `panel_controls`, `panel_dark`, `rail`, `wall_monitor`, `tv_monitor`, `gear`, `slime` | `l i c k w r m t g ~` |

`tools/level_cli.sh catalog tiles --search lamp` finds a kind; the editor's palette has a search box.

Rules the game enforces (and the editor should warn about):

- exactly one `P` and one `E`;
- a lock terminal `L` needs a laser gate (digit) near it and a laser gate needs a terminal; a gate is a vertical run of its digit;
- each AI Bro `B` needs at least `LevelData.bro_min_flat_tiles()` tiles of flat ground to pace on (`LevelData.bro_flat_span`);
- machine footprints must not overlap other things;
- lamps `l`, sirens `i` and canisters `c` must stand on a solid tile.

## Objects and their values

Catalog section `objects` lists each object type, the marker character it writes into `tiles`, and its editable `props`
(key, label, type, default, range). Types the editor must support in the inspector: `float`, `int`, `string`, `choice`
(`options` list), `bool`. Only changed values are stored under `props`.

- `ai_bro` (`B`): health_fraction, contact_damage_fraction, patrol_speed, chase_speed, jump_velocity, patrol_radius,
  sight_range, sight_height, lose_range, hit_range, hit_cooldown.
- `checkpoint` (`K`), `exit` (`E`), `player_spawn` (`P`): a name only.
- `lock_terminal` (`L`): `laser` (`auto` = the nearest gate, or `1`-`9`) and `minigame` (`random`, a minigame `id` from the
  level's `minigames` list, or a built-in kind name such as `dont_press`).
- `tank_settings` ("Pit creature settings": a marker-less object keyed on the top-left tile of any deadly pit): fish_count (the number of
  creatures, `0` = automatic), bite_fraction (their hit damage), respawn_time.

## Player and terrain values

Catalog sections `player` and `terrain` list the values (same property format). `terrain.gravity_scale` multiplies gravity for the
player, enemies and thrown objects. `terrain.background` names the background folder (see above).

## Minigames

A level's `minigames` list defines puzzles beyond the random built-ins. Each entry: `id` (unique, used by a terminal), `name`
(a label), `kind` (one of the catalog `minigames` kinds) and `params` (only values that differ from the defaults). The quiz
the kind `wrong_only` takes `questions`: a list of `{ "q": "text", "right": "answer", "wrong": ["a", "b", "c"] }`.

## Loading in the game

- `godot --path . -- --level-file=path/to/level.sablevel.json` plays a level file (also `SABOTAGE_LEVEL_FILE=path`).
- The editor's **Play** button saves to a temporary file and starts the game that way.
