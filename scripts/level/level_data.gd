class_name LevelData
extends RefCounted
## Where levels come from. Every level of the real game is a level file (*.sablevel.json; the format is in
## tools/level_editor/FORMAT.md) in its own folder:
##
##   levels/<id>/level.sablevel.json   the level: tiles, objects, player and terrain values, puzzles, title, next level
##   levels/<id>/background/           that level's parallax background layers (see LevelBackground.LAYERS)
##   levels/common/                    art every level shares: tiles/, machines/, pit_hazards/ (see SpriteLibrary)
##
## The ids are the folder names (level_01, level_02, ...). The game starts on DEFAULT_ID and finishing a level loads the one
## named in its meta.next. Two ids are special:
##   "test"   the original prototype level, kept exactly as it was as a small sandbox for the automated tests, built in code
##            below. Do not change its map.
##   "file"   a level file given on the command line (`-- --level-file=path`, see use_file()).
## Play one with the environment variable SABOTAGE_LEVEL=<id> (see docs/level-design.md). New levels are made with the level
## editor (tools/level_editor.sh) or the level command-line tool (tools/level_cli.sh).
##
## Tiles are kinds in levels/common/tile_registry.json (TileRegistry): level files store their numbers as CSV; inside the game each kind is one
## character. The kinds the game has always had keep the characters below; any other kind (a solid block, a decor picture) is only a
## registry entry with a private character, and TileRegistry.physics_rows() reduces a map to what each tile does.
##
## Legend
##   .  empty              #  ground (auto-picks start/middle/end/fill)
##   =  one-way ledge      H  ladder
##   ^  floor spikes       v  ceiling spikes
##   X  metal crate        O  orange crate
##   P  player spawn       E  exit terminal
##   A F N W  deadly pit liquids: toxic waste, lava, nuclear waste, a tank of robotic piranhas. Whoever falls in
##        dies (ordinary spikes ^ v only hurt).
##   K  checkpoint (a green beacon: touching it sets where you respawn)
##   B  an AI Bro enemy, standing on the tile below the marker
##   1-9  a laser force field (a solid wall while on). Its id is the digit; the computer that switches it off is the lock
##        terminal paired with it (see terminals())
## Machines (decor). The letter marks the BOTTOM-LEFT tile; the rest of the footprint
## (to the right and up) must be left as '.'.
##   G  GPU rack 2x3        S  supercomputer 3x3
##   M  monitoring station 4x3     R  server tower 1x3
##   L  lock terminal 2x3: the gate computers listed in terminals(), not for decoration
## Other background decor
##   k controls panel   w dark panel   r ceiling rail   m monitor   t tv monitor
##   g gear   i siren   l lamp   c canister   ~ slime
##
## The `_s_*` pieces and seq_build_plan() further down are the level builder behind `tools/level_cli.sh from-plan`.

# LEVELS_DIR / LEVEL_FILE_NAME: where the levels are (one folder each) and what the file in each folder is called.
const LEVELS_DIR := AssetPaths.LEVELS
const LEVEL_FILE_NAME := "level.sablevel.json"

# COMMON_FOLDER: the folder inside LEVELS_DIR that holds the art shared by all levels; it is not a level.
const COMMON_FOLDER := "common"

# DEFAULT_ID: the level the game starts on when SABOTAGE_LEVEL is not set.
const DEFAULT_ID := "level_01"

# TEST_ID: the id of the test level (what to put in SABOTAGE_LEVEL to play it).
const TEST_ID := "test"

# FILE_ID: the id under which a level loaded from a level file given on the command line is played (see use_file()).
const FILE_ID := "file"

## Multiplier on gravity for the player, enemies and thrown objects in the level being played (1 = normal). Level sets it
## when it starts, from the terrain section of the level file.
static var gravity_scale := 1.0

## The level loaded from a file (see use_file()): the parsed file, empty when none is loaded.
static var file_data := {}

## The folder that file was loaded from (its background/ folder is looked for there).
static var file_dir := ""

## The level to play next when the game restarts after a level is finished; empty = use SABOTAGE_LEVEL or the default.
static var selected_id := ""

## The id of the level being played (set by Level when it starts).
static var current_id := DEFAULT_ID

static var _cache := {}   # level id -> parsed level file


## The ids of the levels of the real game: every folder in levels/ that holds a level file, in name order.
static func level_ids() -> Array[String]:
	var out: Array[String] = []
	for folder in DirAccess.get_directories_at(LEVELS_DIR):
		if folder != COMMON_FOLDER and FileAccess.file_exists(file_path(folder)):
			out.append(folder)
	out.sort()
	return out


## Every level id the game can play: the levels, then the test level.
static func ids() -> Array[String]:
	var out := level_ids()
	out.append(TEST_ID)
	return out


static func has_level(id: String) -> bool:
	return ids().has(id) or (id == FILE_ID and not file_data.is_empty())


## True for a level of the real game (a folder in levels/), false for the test level and a level file.
static func is_campaign(id: String) -> bool:
	return level_ids().has(id)


## The folder of a level ("res://levels/<id>/") and its level file.
static func level_dir(id: String) -> String:
	return LEVELS_DIR + id + "/"


static func file_path(id: String) -> String:
	return level_dir(id) + LEVEL_FILE_NAME


## Play a level file (parsed by LevelFile) instead of a level of the game: afterwards the level id FILE_ID is playable. `dir` is
## the folder the file is in. Returns the errors found (empty = fine).
static func use_file(data: Dictionary, dir: String = "") -> Array[String]:
	var errors := LevelFile.validate(data)
	file_data = data
	file_dir = dir
	return errors


## The parsed level file of a level (cached); empty for the test level.
static func data_for(id: String) -> Dictionary:
	if id == FILE_ID:
		return file_data
	if id == TEST_ID or not level_ids().has(id):
		return {}
	if not _cache.has(id):
		_cache[id] = LevelFile.load_file(file_path(id))["data"]
	return _cache[id]


## Forget the level files read so far (after editing them).
static func clear_cache() -> void:
	_cache.clear()


## The name of the level (shown by the level editor and in the "Next:" line when a level is finished; it is not drawn in the level).
static func title(id: String) -> String:
	if id == TEST_ID:
		return "TEST LEVEL"
	return str(LevelFile.value(data_for(id), "meta", "title", id.to_upper()))


# STAGES_PER_WORLD: how many levels make a world in the numbering shown on the HUD, as in Super Mario Bros: the six levels of the first world
# (the five data centers and the boss) are 1-1 to 1-6, and the next level would be 2-1. Higher: more levels per world.
const STAGES_PER_WORLD := 6


## The level's number as the HUD shows it, "world-stage" like Super Mario Bros ("1-1", "1-2", ...): the position of the level in the
## game (see STAGES_PER_WORLD), unless the level file names its own in meta "stage" (for a level that is not part of the count). The test level
## is "TEST".
static func stage_label(id: String) -> String:
	if id == TEST_ID:
		return "TEST"
	var own := str(LevelFile.value(data_for(id), "meta", "stage", ""))
	if own != "":
		return own
	var index := level_ids().find(id)
	if index < 0:
		return "-"
	return "%d-%d" % [index / STAGES_PER_WORLD + 1, index % STAGES_PER_WORLD + 1]


## The map of a level, as rows of text (top row first). An unknown id gives the test level.
static func map(id: String) -> Array[String]:
	var data := data_for(id)
	if data.is_empty():
		return test_level()
	return LevelFile.tiles(data)


## The next level to play when `id` is finished ("" = the game is complete and starts again from the beginning).
static func next_id(id: String) -> String:
	return str(LevelFile.value(data_for(id), "meta", "next", ""))


## The folder of the background layers of a level (ending in "/"): terrain.background in its level file is a folder, relative to
## the level's own folder (the default, "background", is the folder next to the level file) or a full res:// path. If that
## folder has no layers (a level file kept somewhere else), the first level's background is used.
static func background_dir(id: String) -> String:
	var rel := str(LevelFile.value(data_for(id), "terrain", "background", "background"))
	return resolve_background(rel, file_dir if id == FILE_ID else level_dir(id))


## The background folder (ending in "/") for a terrain.background value `rel`, for a level file in the folder `base`.
static func resolve_background(rel: String, base: String) -> String:
	var dir := rel if rel.begins_with("res://") else base.path_join(rel)
	if not dir.ends_with("/"):
		dir += "/"
	if not ResourceLoader.exists(dir + "far.png"):
		dir = level_dir(DEFAULT_ID) + "background/"
	return dir



static func _d(n: int) -> String:
	return ".".repeat(n)


# ---------------------------------------------------------------------------------------------
# TEST LEVEL: the original prototype level. Kept exactly as it was; do not change it.
# Act 1: start room + spike pit. Act 2: ladder up to the hazard corridor.
# Act 3: ledge staircase to the exit terminal.
# ---------------------------------------------------------------------------------------------
static func test_level() -> Array[String]:
	var m: Array[String] = []
	m.append("#".repeat(60))                                                            # 0  ceiling
	m.append("#" + "r".repeat(58) + "#")                                                # 1  ceiling rail
	m.append("#" + _d(58) + "#")                                                        # 2
	m.append("#" + _d(7) + "g" + _d(13) + "g" + _d(7) + "." + _d(28) + "#")             # 3  gears
	m.append("#" + _d(32) + "m" + _d(4) + "t" + _d(4) + "m" + _d(11) + "m" + "." + "t" + "." + "#")  # 4  monitors
	m.append("#" + _d(30) + "l" + _d(3) + "^^" + "." + "i" + _d(2) + "^^" + _d(2) + "l" + _d(13) + "#")  # 5  corridor hazards
	m.append("#" + _d(27) + "H" + "#".repeat(19) + _d(11) + "#")                         # 6  ladder top + upper slab
	m.append("#" + _d(27) + "H" + _d(17) + "O" + _d(9) + "E" + _d(2) + "#")              # 7  exit
	m.append("#" + _d(27) + "H" + _d(17) + "O" + _d(8) + "===" + "." + "#")              # 8
	m.append("#" + _d(27) + "H" + _d(17) + "O" + _d(6) + "==" + _d(4) + "#")                # 9
	m.append("#" + _d(9) + "X" + _d(17) + "H" + _d(17) + "O" + _d(4) + "==" + _d(6) + "#")  # 10
	m.append("#" + ".lP." + "S.." + "." + "XX" + _d(4) + "===" + _d(3) + "cc" + "." + "i" + _d(3) + "H" + _d(2) + "M..." + _d(1) + "G.R" + _d(2) + "S.." + _d(2) + "O" + _d(2) + "==" + "~".repeat(7) + "." + "#")  # 11  machines
	m.append("#".repeat(14) + "^".repeat(5) + "#".repeat(41))                           # 12 floor + spike pit
	m.append("#".repeat(60))                                                            # 13 floor fill
	return m


# ---- the pieces. Each draws itself starting at column c, on walking-surface row g, and returns the next free column.

static func _s_flat(grid: LevelGrid, c: int, n: int, g: int, mark: String) -> int:
	if mark.contains("K"):
		grid.put(c + 1, g - 1, "K")
	if mark.contains("B"):
		grid.put(c + n / 2, g - 1, "B")
	return c + n


## Two crates to hop onto and down from.
static func _s_hurdle(grid: LevelGrid, c: int, g: int) -> int:
	grid.crate_stack(c, g - 1, 1)
	grid.crate_stack(c + 1, g - 1, 2)
	return c + 3


## A deadly pit w wide.
static func _s_pit(grid: LevelGrid, c: int, g: int, w: int, liquid: String) -> int:
	grid.pit(c, c + w - 1, g, liquid)
	return c + w


## A low-ceilinged tunnel with a strip of spikes, then a lock terminal and its laser gate (sealed up to the ceiling).
static func _s_tunnel(grid: LevelGrid, c: int, g: int, laser_id: String) -> int:
	grid.fill(c, g - 5, c + 11, g - 5, "#")
	grid.spikes(c + 3, c + 4, g - 1)
	grid.put(c + 7, g - 1, "L")
	grid.laser(c + 10, g - 4, g - 1, laser_id)
	grid.fill(c + 10, 2, c + 10, g - 6, "#")     # a pillar from the slab up to the ceiling: nothing can fly over the gate
	return c + 12


## A low tunnel with spikes and an AI Bro waiting inside, no gate.
static func _s_tunnel_plain(grid: LevelGrid, c: int, g: int) -> int:
	grid.fill(c, g - 5, c + 13, g - 5, "#")
	grid.spikes(c + 4, c + 5, g - 1)
	grid.spikes(c + 10, c + 10, g - 1)
	grid.put(c + 7, g - 1, "B")
	return c + 14


## A wide pit crossed on stepping stones: two-tile ledges with four-tile gaps between them.
static func _s_stones(grid: LevelGrid, c: int, g: int, w: int, liquid: String) -> int:
	grid.pit(c, c + w - 1, g, liquid)
	var s := c + 4
	while s + 1 < c + w - 2:
		grid.ledge(s, s + 1, g)
		s += 6
	return c + w


## Crates and a spike strip to jump.
static func _s_gauntlet(grid: LevelGrid, c: int, g: int) -> int:
	grid.crate_stack(c + 4, g - 1, 1, "O")
	grid.spikes(c + 7, c + 8, g - 1)
	grid.crate_stack(c + 11, g - 1, 2, "O")
	return c + 16


## Crate stairs up to a raised deck (7 wide, with an AI Bro pacing on it), then a wide pit down to the floor.
static func _s_deck(grid: LevelGrid, c: int, g: int, liquid: String) -> int:
	for i in 4:
		grid.crate_stack(c + i, g - 1, i + 1)
	grid.fill(c + 4, g - 4, c + 10, g - 1, "#")
	grid.put(c + 7, g - 5, "B")
	grid.pit(c + 11, c + 16, g, liquid)
	return c + 20


## Three short strips of spikes in a row, with an AI Bro between the first two.
static func _s_spikes(grid: LevelGrid, c: int, g: int) -> int:
	grid.spikes(c + 2, c + 3, g - 1)
	grid.spikes(c + 8, c + 8, g - 1)
	grid.spikes(c + 12, c + 13, g - 1)
	grid.put(c + 5, g - 1, "B")
	return c + 15


## A little pyramid of crates: up three, down three.
static func _s_pyramid(grid: LevelGrid, c: int, g: int) -> int:
	for i in 5:
		grid.crate_stack(c + i, g - 1, [1, 2, 3, 2, 1][i])
	return c + 5


## A tall wall of solid ground with a ladder up its near side: climb it, cross the top (a spike in the middle) and
## drop down the far side. You cannot jump a wall this high.
static func _s_ladder_wall(grid: LevelGrid, c: int, g: int) -> int:
	grid.ladder(c, g - 6, g - 1)
	grid.fill(c + 1, g - 6, c + 3, g - 1, "#")
	grid.spikes(c + 2, c + 2, g - 7)
	return c + 6


## Ground that steps up one tile at a time, a flat top six tiles wide with an AI Bro pacing on it, and back down.
static func _s_terrace(grid: LevelGrid, c: int, g: int) -> int:
	var heights := [1, 2, 3, 3, 3, 3, 3, 3, 2, 1]
	for i in heights.size():
		grid.fill(c + i, g - heights[i], c + i, g - 1, "#")
	grid.put(c + 5, g - 4, "B")
	return c + 11


## A wide pit crossed on one-way ledges at different heights: level, up, up, then back down to the far side.
static func _s_gallery(grid: LevelGrid, c: int, g: int, liquid: String) -> int:
	grid.pit(c, c + 19, g, liquid)
	grid.ledge(c + 3, c + 4, g)
	grid.ledge(c + 8, c + 9, g - 1)
	grid.ledge(c + 13, c + 14, g - 2)
	grid.ledge(c + 17, c + 18, g - 1)
	return c + 20


## The computers you can use, found by reading the map: every lock terminal ("L") belongs to the nearest laser
## gate (a digit) and switches it off. "c"/"r" is the terminal's bottom-left tile, "laser" the gate's id and
## "game" which puzzle to show ("random" = a different silly one each time; see HackPopup.GAME_NAMES). The level file may say
## which gate a computer opens and which puzzle it shows.
static func terminals(id: String) -> Array[Dictionary]:
	if id == TEST_ID:
		return []
	var data := data_for(id)
	var found := terminals_in(map(id))
	for t in found:
		var props: Dictionary = LevelFile.object_at(data, t["c"], t["r"]).get("props", {})
		if str(props.get("laser", "auto")) != "auto":
			t["laser"] = str(props["laser"])
		if props.has("minigame"):
			t["game"] = str(props["minigame"])
	return found


static func terminals_in(rows: Array[String]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var lasers: Array[Vector3i] = []   # column, row, id as a number
	for r in rows.size():
		for c in rows[r].length():
			var ch := rows[r][c]
			if ch >= "1" and ch <= "9":
				lasers.append(Vector3i(c, r, int(ch)))
	for r in rows.size():
		for c in rows[r].length():
			if rows[r][c] != "L":
				continue
			var best := -1
			var best_dist := 1 << 30
			for l in lasers:
				var dist := absi(l.x - c) + absi(l.y - r) * 4
				if dist < best_dist:
					best_dist = dist
					best = l.z
			if best >= 0:
				out.append({"c": c, "r": r, "laser": str(best), "game": "random"})
	return out


## The fewest contiguous tiles of flat ground an AI Bro needs to pace back and forth: its beat (PATROL_RADIUS each side
## of its spot) plus its own width, rounded up to whole tiles.
static func bro_min_flat_tiles() -> int:
	return ceili((2.0 * AIBro.PATROL_RADIUS + AIBro.BODY_SIZE.x) / Level.T)


## True if a Bro could stand in tile (c, r): ground under it, and nothing solid, no gate and no liquid in it or the
## two tiles above. Floor spikes do not count against it (Bros are immune to them).
static func bro_can_stand(rows: Array[String], c: int, r: int) -> bool:
	return _can_stand(TileRegistry.physics_rows(rows), c, r)


static func _can_stand(rows: Array[String], c: int, r: int) -> bool:   # `rows` are physics rows (see TileRegistry.physics_rows)
	if c < 0 or c >= rows[r].length() or r < 2 or r + 1 >= rows.size():
		return false
	if not "#=@".contains(rows[r + 1][c]):
		return false
	for dr in range(0, 3):
		if "#@XOH=123456789AFNW".contains(rows[r - dr][c]):
			return false
	return true


## How many contiguous tiles of flat ground (in the row of tile (c, r)) the Bro marked there can pace on, counting its own.
static func bro_flat_span(rows: Array[String], c: int, r: int) -> int:
	return _flat_span(TileRegistry.physics_rows(rows), c, r)


static func _flat_span(rows: Array[String], c: int, r: int) -> int:
	if not _can_stand(rows, c, r):
		return 0
	var n := 1
	var x := c - 1
	while _can_stand(rows, x, r):
		n += 1
		x -= 1
	x = c + 1
	while _can_stand(rows, x, r):
		n += 1
		x += 1
	return n


## Every Bro marker ("B") in the map that does not have bro_min_flat_tiles() of flat ground to pace on.
static func bros_without_room(rows: Array[String]) -> Array[String]:
	var bad: Array[String] = []
	var need := bro_min_flat_tiles()
	var physics := TileRegistry.physics_rows(rows)
	for r in rows.size():
		for c in rows[r].length():
			if rows[r][c] == "B" and _flat_span(physics, c, r) < need:
				bad.append("(%d,%d) has %d of %d tiles" % [c, r, _flat_span(physics, c, r), need])
	return bad


## True if the footprint (columns c to c+w-1, rows g-height to g-1) is empty, stands on solid ground, and has one empty
## column of margin on each side too (a lamp or canister in the margin is fine); and no machine already placed
## reaches into it.
static func _clear_for(grid: LevelGrid, c: int, w: int, g: int, height: int) -> bool:
	for dc in range(-1, w + 1):
		var in_footprint := dc >= 0 and dc < w
		for dr in range(1, height + 1):
			var ch := grid.get_cell(c + dc, g - dr)
			if in_footprint and ch != ".":
				return false
			if not in_footprint and ch != "." and ch != "l" and ch != "c":
				return false
			if _inside_machine(grid, c + dc, g - dr):
				return false
	for dc in w:
		if grid.get_cell(c + dc, g) != "#":
			return false
	return true


## True if cell (c, r) is part of the footprint of a machine whose letter is to its left (in this row or in one of the
## rows below it, where tall machines have their letters).
static func _inside_machine(grid: LevelGrid, c: int, r: int) -> bool:
	for dr in range(0, 4):
		for dc in range(0, 4):
			if dc == 0 and dr == 0:
				continue
			var letter := grid.get_cell(c - dc, r + dr)
			if LevelGrid.MACHINE_WIDTHS.has(letter) and LevelGrid.MACHINE_WIDTHS[letter] > dc and dr < 3:
				return true
	return false


# ---------------------------------------------------------------------------------------------
# THE LEVEL BUILDER: levels are put together from pieces (the `_s_*` functions above, plus "rise", "climb", "drop" and "arena"
# below that change the height of the ground). A level is a plan, a list of pieces left to right, and seq_build_plan() draws
# it. This is what `tools/level_cli.sh from-plan` uses to make a level file, and tools/tests/levels_test.gd proves the
# levels it makes can be finished and cannot trap the player.
# ---------------------------------------------------------------------------------------------

# SEQ_TOP_MARGIN: empty rows kept above the highest ground of a level (room for the tallest tunnel and for jumps).
const SEQ_TOP_MARGIN := 12

# SEQ_SLAB: how many rows thick the ground is. Deadly pits are carved 3 deep into it, so it must be at least 4.
const SEQ_SLAB := 4



## The pieces a plan can use (the first word of each entry): what they build, their parameters, how many columns they take
## and how they change the ground height. Used by the command-line level tool (tools/level_editor/CLI.md).
const SEQ_PIECES := {
	"flat": {"params": "columns, marks", "doc": "Flat ground. Marks (a string): K checkpoint, B AI Bro in the middle (needs 7+ columns for the Bro), P player spawn.", "columns": "n"},
	"hurdle": {"params": "", "doc": "Two crates to hop onto and down from.", "columns": "3"},
	"pit": {"params": "width, liquid", "doc": "A deadly pit (liquid A toxic, F lava, N nuclear, W piranha tank). 3 or 4 wide is a fair jump.", "columns": "width"},
	"stones": {"params": "width, liquid", "doc": "A wide deadly pit crossed on two-tile stepping-stone ledges. Width 14 or 20.", "columns": "width"},
	"gallery": {"params": "liquid", "doc": "A 20-wide pit crossed on one-way ledges at rising and falling heights.", "columns": "20"},
	"spikes": {"params": "", "doc": "Three strips of floor spikes with an AI Bro between the first two.", "columns": "15"},
	"gauntlet": {"params": "", "doc": "Crates and a spike strip to jump.", "columns": "16"},
	"pyramid": {"params": "", "doc": "A pyramid of crates to climb over (1, 2, 3, 2, 1 high).", "columns": "5"},
	"terrace": {"params": "", "doc": "Ground that steps up to a flat top (with an AI Bro) and back down.", "columns": "11"},
	"deck": {"params": "liquid", "doc": "Crate stairs up to a raised 7-wide deck with an AI Bro, then a 6-wide pit down to the floor.", "columns": "20"},
	"ladder_wall": {"params": "", "doc": "A 6-high wall with a ladder up its near side; climb, cross the top (a spike), drop down.", "columns": "6"},
	"tunnel": {"params": "laser id 1-9", "doc": "A low-ceilinged tunnel with spikes, a lock terminal and its laser gate. Each gate id may be used once per level.", "columns": "12"},
	"tunnel_plain": {"params": "", "doc": "A low tunnel with spikes and an AI Bro inside.", "columns": "14"},
	"arena": {"params": "", "doc": "A 14-wide flat arena with a checkpoint and two AI Bros.", "columns": "14"},
	"rise": {"params": "rows (1-8)", "doc": "A ladder up a cliff: the ground after it is that many rows higher.", "columns": "3"},
	"climb": {"params": "rows (1-4)", "doc": "A staircase of one-way ledges rising one row each: the ground after it is that many rows higher.", "columns": "3 + 5 * rows"},
	"drop": {"params": "rows (1-6)", "doc": "A cliff down: the ground after it is that many rows lower (keep it at 6 or less; more kills).", "columns": "3"},
	"exit": {"params": "", "doc": "The exit terminal on a flat 5-column end. Every level plan ends with this exactly once.", "columns": "5"},
}


## How many columns a piece takes.
static func _seq_len(entry: Array) -> int:
	match entry[0]:
		"flat", "pit", "stones":
			return int(entry[1])
		"climb":
			return 3 + 5 * int(entry[1])
		"hurdle", "rise", "drop":
			return 3
		"tunnel":
			return 12
		"tunnel_plain":
			return 14
		"gauntlet":
			return 16
		"deck", "gallery":
			return 20
		"spikes":
			return 15
		"pyramid", "exit":
			return 5
		"ladder_wall":
			return 6
		"terrace":
			return 11
		"arena":
			return 14
	return 0


## How much the ground height changes after a piece: negative = up (rows), positive = down.
static func _seq_dg(entry: Array) -> int:
	match entry[0]:
		"rise", "climb":
			return -int(entry[1])
		"drop":
			return int(entry[1])
	return 0


## Ledges rising one row at a time (a staircase of one-way ledges), h of them, ending where the higher ground begins.
static func _s_climb(grid: LevelGrid, c: int, g: int, h: int) -> int:
	for i in h:
		grid.ledge(c + 3 + 5 * i, c + 4 + 5 * i, g - 1 - i)
	return c + 3 + 5 * h


## A ladder up the near side of a cliff h rows high: the ground to its right is h rows higher.
static func _s_rise(grid: LevelGrid, c: int, g: int, h: int) -> int:
	grid.ladder(c, g - h, g - 1)
	return c + 3


## A bigger flat arena with two AI Bros and a checkpoint, for the end of a level.
static func _s_arena(grid: LevelGrid, c: int, g: int) -> int:
	grid.put(c + 1, g - 1, "K")
	grid.put(c + 4, g - 1, "B")
	grid.put(c + 10, g - 1, "B")
	return c + 14


## Build a level from any plan (a list of pieces, see SEQ_PIECES). `machines` are the decor machine letters
## placed along the floor, `liquid_default` the pit liquid for pieces that name none, `label` names the level in
## error messages. Returns {"rows": Array[String], "start_row": int}. Nothing is cached.
static func seq_build_plan(plan: Array, machines: Array, liquid_default: String, label: String) -> Dictionary:
	var id := label
	# first pass: how wide, and how high and low the ground goes
	var width := 2
	var rel := 0
	var lowest := 0
	var highest := 0
	for entry in plan:
		width += _seq_len(entry)
		rel += _seq_dg(entry)
		lowest = maxi(lowest, rel)
		highest = mini(highest, rel)
	var start_g := SEQ_TOP_MARGIN - highest
	var rows := start_g + lowest + SEQ_SLAB + 2
	var grid := LevelGrid.new(width, rows)
	var surfaces: Array[int] = []
	surfaces.resize(width)
	surfaces.fill(start_g)
	var c := 1
	var g := start_g
	for entry in plan:
		var kind: String = entry[0]
		var n := _seq_len(entry)
		grid.carve(c, 0, width - 2, rows - 1)          # clear everything to the right, then lay ground for this piece
		var fill_to := c + n - 1
		match kind:
			"rise":
				grid.fill(c, g, c, rows - 1, "#")                   # the ladder stands on the old ground
				grid.fill(c + 1, g - int(entry[1]), width - 2, rows - 1, "#")   # the cliff and the higher ground
				fill_to = -1
			"climb":
				grid.fill(c, g, c + n - 1, rows - 1, "#")           # old ground under the ledges
				grid.fill(c + n, g - int(entry[1]), width - 2, rows - 1, "#")   # the higher ground after them
				fill_to = -1
			"drop":
				grid.fill(c, g, c + 2, rows - 1, "#")
				grid.fill(c + 3, g + int(entry[1]), width - 2, rows - 1, "#")
				fill_to = -1
			_:
				grid.fill(c, g, width - 2, rows - 1, "#")           # ground for the rest of the level at this height
		var start := c
		match kind:
			"flat":
				c = _s_flat(grid, c, int(entry[1]), g, str(entry[2]) if entry.size() > 2 else "")
				if entry.size() > 2 and str(entry[2]).contains("P"):
					grid.put(start + 2, g - 1, "P")
			"hurdle":
				c = _s_hurdle(grid, c, g)
			"pit":
				c = _s_pit(grid, c, g, int(entry[1]), str(entry[2]) if entry.size() > 2 else liquid_default)
			"tunnel":
				c = _s_tunnel(grid, c, g, str(entry[1]))
			"tunnel_plain":
				c = _s_tunnel_plain(grid, c, g)
			"stones":
				c = _s_stones(grid, c, g, int(entry[1]), str(entry[2]) if entry.size() > 2 else liquid_default)
			"gauntlet":
				c = _s_gauntlet(grid, c, g)
			"deck":
				c = _s_deck(grid, c, g, str(entry[1]) if entry.size() > 1 else liquid_default)
			"spikes":
				c = _s_spikes(grid, c, g)
			"pyramid":
				c = _s_pyramid(grid, c, g)
			"ladder_wall":
				c = _s_ladder_wall(grid, c, g)
			"terrace":
				c = _s_terrace(grid, c, g)
			"gallery":
				c = _s_gallery(grid, c, g, str(entry[1]) if entry.size() > 1 else liquid_default)
			"climb":
				c = _s_climb(grid, c, g, int(entry[1]))
			"rise":
				c = _s_rise(grid, c, g, int(entry[1]))
			"drop":
				c = start + 3
			"arena":
				c = _s_arena(grid, c, g)
			"exit":
				grid.put(c + 2, g - 1, "E")
				c += 5
		if c - start != n:
			push_error("%s: piece '%s' is %d columns, expected %d" % [id, kind, c - start, n])
		for x in range(start, mini(c, width)):
			surfaces[x] = g
		g += _seq_dg(entry)
		if fill_to == -1 and kind != "drop":
			pass
	# the shell: ceiling, side walls, a rail along the ceiling
	grid.fill(0, 0, width - 1, 0, "#")
	grid.fill(0, 0, 0, rows - 1, "#")
	grid.fill(width - 1, 0, width - 1, rows - 1, "#")
	grid.fill(1, 1, width - 2, 1, "r")
	for spot in PitSigns.missing(grid.to_rows()):     # a warning sign on the ground before every deadly pit (first, so the decor leaves its tile free)
		grid.put(int(spot["col"]), int(spot["row"]), str(spot["char"]))
	_seq_decor(grid, surfaces, machines)
	var built := {"rows": grid.to_rows(), "start_row": start_g}
	var bad := bros_without_room(built["rows"])
	if not bad.is_empty():
		push_error("%s: AI Bros without enough flat ground to pace: %s" % [id, bad])
	return built


## Machines, lamps and canisters along the floor of one of the short levels, wherever there is room (a whole flat footprint,
## a tile clear on each side, standing on solid ground at one height).
static func _seq_decor(grid: LevelGrid, surfaces: Array[int], machines: Array) -> void:
	var widths := {"S": 3, "G": 2, "R": 1, "M": 4}
	var n := 0
	var c := 3
	while c < grid.cols - 3:
		if _seq_clear_for(grid, surfaces, c, 1, 1):
			grid.put(c, surfaces[c] - 1, "l" if n % 3 != 2 else "c")
			n += 1
			c += 10
		else:
			c += 1
	c = 2
	var i := 0
	while c < grid.cols - 8:
		var letter: String = machines[i % machines.size()]
		var w: int = widths[letter]
		if _seq_clear_for(grid, surfaces, c, w, 3):
			grid.put(c, surfaces[c] - 1, letter)
			c += w + 2
			i += 1
		else:
			c += 1


## True if columns c to c+w-1 all have ground at the same height with the footprint above them empty and a clear column of
## margin each side (see _clear_for).
static func _seq_clear_for(grid: LevelGrid, surfaces: Array[int], c: int, w: int, height: int) -> bool:
	var g := surfaces[c]
	for dc in range(-1, w + 1):
		if c + dc < 1 or c + dc >= grid.cols - 1 or surfaces[c + dc] != g:
			return false
	return _clear_for(grid, c, w, g, height)
