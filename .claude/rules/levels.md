# Level and editor rules

- Levels are data (`levels/<id>/level.sablevel.json`); tile kinds are entries in `levels/common/tile_registry.json`. A level is made with the level editor
  (`tools/level_editor.sh`) or the CLI (`tools/level_cli.sh`, docs in `tools/level_editor/CLI.md`).
- Every level can be traversed from start to exit (or ends with a boss fight): `LEVEL=<id> godot --headless --path . --script res://tools/tests/level_traversal_test.gd`
  checks it. Every laser gate is sealed from the floor to the ceiling (a vehicle with a booster must not fly over it), has its computer in front of it, and
  really blocks the way. Every level has exactly one power-up box that a player can reach.
- Every deadly pit has its warning sign on the ground before it (`PitSigns`; `tools/level_cli.sh pit-signs <file>` adds the missing ones; `solve` fails without them).
- **The editor must always be up to date.** Its palette comes from the tile registry and its inspectors from `tools/level_editor/catalog.json`. After adding a
  tile picture run `python tools/sync_editor.py`; after adding a minigame, a level-meta key or an object add it to the catalog.
  `tools/tests/editor_sync_test.gd` fails when something the game knows is missing from the editor.
