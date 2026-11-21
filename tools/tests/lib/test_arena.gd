class_name TestArena
extends RefCounted
## A small level built only for the tests of single elements (the mech, a power-up box, spikes, a ladder, steps, a wall): flat ground with a wall at the left
## end, a spike strip, a ladder against a raised platform, a pit and some crates. The tests of how something behaves use this instead of the real levels,
## so they keep working however the real levels are redesigned. (Whether the real levels can be played is level_traversal_test.gd's job.)
##
##   TestArena.use()                      # the next Main plays the arena
##   var main = load(AssetPaths.MAIN_SCENE).instantiate()

const FILE := "res://tools/tests/fixtures/arena.sablevel.json"

# Where things are, in pixels (the arena's own map is in the file; these are the numbers the tests need).
const FLOOR_ROW := 15                                   # the row the player stands in on the flat ground
const FLOOR_Y := (FLOOR_ROW + 1) * float(Level.T)      # the y of the feet there
const SPAWN_X := 3.5 * Level.T
const WALL_X := float(Level.T)                          # the right edge of the left wall
const SPIKES_X := 26.5 * Level.T                        # the middle of a spike strip on the flat ground
const LADDER_X := 42.5 * Level.T                        # the ladder's column (against the raised platform)
const FLAT_X := 20.5 * Level.T                          # a spot on flat, empty ground


## Make the arena the level the next Main plays.
static func use() -> void:
	var loaded := LevelFile.load_file(FILE)
	LevelData.use_file(loaded["data"], FILE.get_base_dir())
	LevelData.selected_id = LevelData.FILE_ID
