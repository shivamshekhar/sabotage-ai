# sabotage.ai level editor

A desktop WYSIWYG editor, written in GDScript, that runs inside this Godot project (so it uses the game's own sprites and
classes). It makes and edits level files (`*.sablevel.json`, format in [FORMAT.md](FORMAT.md)) that the game can play.

## Run

```
tools/level_editor.sh                      # Git Bash; finds Godot like tools/run_tests.sh (GODOT env var or the winget install)
godot --path . res://tools/level_editor/level_editor.tscn
```

After adding a new `class_name` script run `godot --headless --path . --import` twice so the class cache sees it.

## The window

* **Drawer (left):** every item of the catalog by group (Terrain, Hazards, Decor machines, Decor, Gameplay, Enemies) with its
  sprite and name, and a search box (Ctrl+F). Click an item to arm it. Groups fold; Ctrl+B hides the drawer.
* **Canvas (middle, tab "Level"):** the level drawn as the game draws it (auto-tiled ground, ladders, ledges, machines with
  their LEDs, pits as liquid, the player and Bro sprites, the faint background). Middle mouse or Space+drag pans, the wheel
  zooms, `F` fits the level, `G` toggles the grid, the status bar shows the tile under the mouse.
* **Minigames (tab "Minigames"):** the minigame designer (see below).
* **Inspector (right):** an object selected: its type, name and values with a Reset button per value (changed values are
  highlighted). A block selected: copy / cut / delete. Nothing selected: tabs **Level** (id, title, next level, grid size with
  resize offset), **Player** (the player's values) and **Terrain** (gravity scale, fall height, pit delay, background folder).
* **Validation list (bottom):** errors and warnings; click one to jump to the tile.
* **Toolbar and status bar:** tools, undo/redo, zoom, Play; the status bar tells what the tool will do.

## Tools and shortcuts

| key | what |
|---|---|
| `V` Select | click a thing to select it (a machine by its whole footprint, a laser gate as its whole run, a pit as its whole rectangle), drag it to move (`Ctrl` = copy), drag on empty space to box-select a group |
| `B` Paint | click or drag to place the armed item; objects and machines are placed with one click |
| `R` Rectangle / `L` Line | drag to fill an area or draw a line (`Shift` = outline only) |
| `E` Eraser | click or drag; right click erases with any tool; machines are removed whole |
| `I` Eyedropper | arm the item under the mouse |
| `Esc` | put the armed item down / cancel a drag / deselect |
| `Delete`, `Ctrl+D`, arrows | delete, duplicate, nudge the selection by one tile |
| `Ctrl+C` / `Ctrl+X` / `Ctrl+V` | copy, cut, paste at the mouse (the paste is then selected) |
| `Ctrl+Z` / `Ctrl+Y` (or `Ctrl+Shift+Z`) | undo / redo (every edit, a drag or a stroke is one step; 100 steps) |
| `Ctrl+N` `Ctrl+O` `Ctrl+S` `Ctrl+Shift+S` `Ctrl+Q` | new, open, save, save as, quit (unsaved changes are asked about) |
| `F5` | play-test |
| `F1` | the shortcut list |

A thing that is armed under the cursor, or being dragged, is drawn **semi-transparent** with a ghost at the drop position; it
turns **red** when the placement is refused (outside the level, a machine footprint that is not free, a second spawn) and
**yellow** when it is allowed but breaks a rule the validation list will complain about (an AI Bro without enough flat
ground, a lamp that is not on solid ground). While a selection is dragged its original place is dimmed.

## Files

* **File > New** asks for the size and starts a level with a floor, walls, the spawn and the exit.
* **File > Open game level** opens a level of the game (`levels/<id>/level.sablevel.json`) for editing in place: Save overwrites its
  file. The test level (built in code) is converted to the editor format so you can start from
  it; use Save as to keep it. **Open recent** remembers the last files. A copy of unsaved work is written to
  `user://level_editor_autosave.sablevel.json` every minute (**File > Recover autosave**).
* A broken file never crashes the editor: the errors are shown and the current level stays.
* **Play** (F5) writes the level to `user://level_editor_playtest.sablevel.json` and starts the game with
  `-- --level-file=<that file>`. It refuses when the level has no (or several) spawn or exit.

## Minigame designer

The list on the left holds the level's `minigames` (Add by kind, Duplicate, Delete). The details: unique id (renaming it
updates the lock terminals that use it), name, kind, the kind's parameters (generated from the catalog), and for the quiz
kinds (`"questions": true`) a list of questions with the right answer and any number of wrong answers. **Preview** runs the real
puzzle through `HackPopup.open_definition(parent, laser_id, definition)`; the button is disabled when the game does not have it.
A lock terminal's *Puzzle* value is a drop-down of `random`, the level's minigame ids and the built-in kind names.

## How the registry and catalog drive the editor

Every tile and placeable object is a kind in `levels/common/tile_registry.json` (see FORMAT.md); `catalog.json` lists the rest
(player/terrain/meta values, puzzle kinds, the pit creature settings). The editor has no per-tile code.

* Each kind becomes a drawer item: `name`, `group` (the drawer section: groups with more than 24 kinds start folded and load their
  icons when opened, and the search box finds any kind, so thousands of tiles are fine), `sprite` (the icon and the picture on the
  canvas: `tile`, `machine`, `pit` or `character`), `footprint` [w, h] for a machine, `unique` (only one exists), `hidden` (drawn
  but not in the drawer: the laser gates 2-9; the one "Laser gate" item gives a new gate the lowest unused id, change it in the
  inspector). `behavior` `solid` or `decor` is all a new block or picture needs; the canvas draws it from its sprite.
* `props` of an object are the inspector fields: `key`, `label`, `type` (`float`, `int` with `min`/`max`/`step`; `string`;
  `choice` with `options`; `bool`) and `default`. Only values that differ from the default are written to the file.
* `player`, `terrain` and `meta` in `catalog.json` are the same kind of list for the inspector tabs, `minigames` lists the kinds
  with their `params` (and `questions: true`).

### Adding a new tile

* A solid block, a decor picture or a decor machine: add an entry to `tile_registry.json` (new permanent `id`, `key`, `name`, `group`,
  `behavior`, `sprite`). That is all: the editor, the game, the CLI and the files know it.
* An object with behaviour of its own (a new enemy, say): teach the game (a map character in `level_data.gd` / `level.gd`, reading
  `objects["col,row"].props`), then add a registry entry with `type`, `char`, `props`. If it needs a rule (a footprint, a "needs
  ground" check) add `footprint`, or extend `EditorDocument.problem_for()` / `validate()`.

## Code map

| file | role |
|---|---|
| `editor_document.gd` | the model: level data, selection, undo/redo, clipboard, placement rules, validation, minigame editing (no UI; tested by `tools/tests/editor_test.gd`) |
| `editor_catalog.gd` | reads the tile registry and `catalog.json` |
| `editor_canvas.gd` | the level view and the tools |
| `editor_palette.gd`, `level_inspector.gd`, `editor_prop_form.gd` | drawer, inspector, catalog-driven value widgets |
| `editor_minigames.gd`, `editor_problems.gd`, `editor_dialogs.gd`, `editor_theme.gd` | designer, validation list, dialogs, look |
| `level_editor.gd` / `.tscn` | the window and the menus |

Environment variable `SABOTAGE_EDITOR_DEMO=1|move|ghost|minigames` opens a level of the game with something selected (used for
screenshots).
