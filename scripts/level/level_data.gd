class_name LevelData
extends RefCounted
## Level layouts as ASCII tile maps. One character = one tile (Level.T pixels).
##
## There are two levels:
##   "1"     the real first level, DATA CENTER 01. This is what the game starts on.
##   "test"  the original prototype level, kept exactly as it was as a small sandbox for trying out
##           mechanics and for the automated tests. Do not change its map.
## Run the test level with the environment variable SABOTAGE_LEVEL=test (see README.md).
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
##   1-9  a laser force field (a solid wall while on). Its id is the digit; the computer that
##        switches it off is listed in terminals()
## Machines (decor). The letter marks the BOTTOM-LEFT tile; the rest of the footprint
## (to the right and up) must be left as '.'.
##   G  GPU rack 2x3        S  supercomputer 3x3
##   M  monitoring station 4x3     R  server tower 1x3
##   L  lock terminal 2x3: the gate computers listed in terminals(), not for decoration
## Other background decor
##   k controls panel   w dark panel   r ceiling rail   m monitor   t tv monitor
##   g gear   i siren   l lamp   c canister   ~ slime
##
## Level 1 is drawn with LevelGrid calls; the test level is built from strings. Either way the
## result is rows of text, and Level validates that every row has the same width.

# DEFAULT_ID: the level the game starts on when SABOTAGE_LEVEL is not set.
const DEFAULT_ID := "1"

# TEST_ID: the id of the test level (what to put in SABOTAGE_LEVEL to play it).
const TEST_ID := "test"

## All level ids, the default first.
static func ids() -> Array[String]:
	return [DEFAULT_ID, TEST_ID]


static func has_level(id: String) -> bool:
	return ids().has(id)


## The name drawn faintly on the background of the level.
static func title(id: String) -> String:
	match id:
		TEST_ID:
			return "TEST LEVEL"
	return "DATA CENTER 01"


## Where the title is drawn, in world pixels (top-left of the text). Chosen per level so it is
## visible near the start.
static func title_position(id: String) -> Vector2:
	match id:
		TEST_ID:
			return Vector2(150, 260)
	return Vector2(150, l1_surface_row(0) * Level.T - 260.0)


## The map of a level, as rows of text (top row first). Unknown ids give the default level.
static func map(id: String) -> Array[String]:
	match id:
		TEST_ID:
			return test_level()
	return level_1()


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


# ---------------------------------------------------------------------------------------------
# LEVEL 1: DATA CENTER 01. Find the exit terminal on the top floor to sabotage the data center.
#
# Four floors, stacked. Floor 0 (the bottom) runs left to right through pits, spikes, crates and laser gates
# to a tower at the right end: ladders and hops up two tiers, then a chain of ledges climbing left onto
# floor 1, which runs right to left to a tower at the left end, and so on, zig-zagging up. Floor 4 ends at the
# exit terminal. Every floor is built from the same kind of pieces (see the _s_* functions), each of which
# starts and ends on flat floor, so any order is joinable. The odd floors are drawn as even floors and then
# mirrored. tools/tests/level1_test.gd proves each floor can be finished, can't trap the player, and that its
# wide pits and its tower can't simply be jumped or skipped.
# ---------------------------------------------------------------------------------------------

# L1_FLOORS: how many floors Level 1 has. L1_SPACING: rows between one floor's walking surface and the next
# (the height of a tower; it also decides how far you fall off a floor into a tower shaft, which is deadly).
const L1_FLOORS := 4
const L1_SPACING := 17

# L1_MARGIN: columns of floor to the left of a floor's course (where the previous floor's tower arrives).
# L1_COURSE: columns of obstacle course on each floor. L1_WIDTH: the map width. The three are tied together
# so that a tower's top lands exactly at the start of the next floor's course (the tower is 20 columns wide):
#     L1_WIDTH = L1_COURSE + 2 * L1_MARGIN - 9      and      L1_MARGIN >= 29
# Change one and the other two must follow, or the towers will no longer meet the floors above them.
const L1_MARGIN := 29
const L1_COURSE := 104
const L1_WIDTH := 153

# L1_TOP_SURFACE: the map row of the top floor's walking surface. The others follow, L1_SPACING rows apart.
const L1_TOP_SURFACE := 12

# L1_BLOCK_GROUND / L1_BLOCK_ROWS: when a floor is drawn on its own (before being pasted into the map) its walking
# surface is on row L1_BLOCK_GROUND of a grid L1_BLOCK_ROWS rows tall (room for the tower above it).
const L1_BLOCK_GROUND := 20
const L1_BLOCK_ROWS := 24

# L1_SLAB: how many rows thick each floor is. The deadly pits are carved into it (3 deep), so it must be at least 4.
const L1_SLAB := 4

# L1_LIQUIDS: the deadly-pit liquid of each floor (map characters, see SpriteLibrary.PIT_KINDS).
const L1_LIQUIDS := ["A", "F", "N", "W"]


## Map row of the walking surface of a floor (0 = the bottom floor).
static func l1_surface_row(floor_index: int) -> int:
	return L1_TOP_SURFACE + (L1_FLOORS - 1 - floor_index) * L1_SPACING


## The plan of a floor: its pieces left to right. Each entry is [piece name, parameters...]; see _l1_block().
## A "flat" entry is [flat, columns, mark] where the mark contains "K" (a checkpoint), "B" (an AI Bro) or both. A flat
## that holds a Bro must be wide enough for it to pace (see bro_min_flat_tiles()).
## Every floor is at most L1_COURSE columns long (the last piece of the top floor is the exit).
static func _l1_plan(floor_index: int) -> Array:
	match floor_index:
		0:
			return [["flat", 5, "K"], ["hurdle"], ["flat", 3], ["pit", 3], ["flat", 3], ["tunnel"], ["flat", 2],
				["stones", 14], ["flat", 7, "B"], ["gauntlet"], ["flat", 3], ["ladder_wall"], ["flat", 7, "KB"],
				["deck"]]
		1:
			return [["flat", 5, "K"], ["spikes"], ["flat", 3, "K"], ["gallery"], ["flat", 7, "B"], ["tunnel"],
				["flat", 3], ["pit", 3], ["flat", 3], ["ladder_wall"], ["flat", 7, "KB"], ["gauntlet"], ["flat", 3]]
		2:
			return [["flat", 5, "K"], ["tunnel_plain"], ["flat", 3, "K"], ["pit", 4], ["flat", 2], ["flat", 7, "B"],
				["stones", 20], ["flat", 3, "K"], ["tunnel"], ["flat", 7, "B"], ["ladder_wall"], ["deck"]]
	return [["flat", 5, "K"], ["terrace"], ["flat", 7, "B"], ["pit", 4], ["flat", 3], ["stones", 14],
		["flat", 7, "B"], ["gallery"], ["flat", 7, "KB"], ["tunnel"], ["flat", 3], ["pyramid"], ["exit"]]


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


## A low-ceilinged tunnel with a strip of spikes, then a lock terminal and its laser gate.
static func _s_tunnel(grid: LevelGrid, c: int, g: int, laser_id: String) -> int:
	grid.fill(c, g - 5, c + 11, g - 5, "#")
	grid.spikes(c + 3, c + 4, g - 1)
	grid.put(c + 7, g - 1, "L")
	grid.laser(c + 10, g - 4, g - 1, laser_id)
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


## The tower at the end of a floor: ladders and ledges up to the floor above. `ce` is the course's last column.
## The tower is 20 columns wide (ce + 1 to ce + 19, then the wall). Its top lands on the next floor's first
## flat column: a chain of ledges climbing back towards the course, ending 17 rows above g.
static func _l1_tower(grid: LevelGrid, ce: int, g: int, laser_id: String) -> void:
	grid.put(ce + 1, g - 1, "K")
	grid.put(ce + 11, g - 1, "B")                  # an AI Bro pacing on the floor under the tiers
	grid.ladder(ce + 3, g - 6, g - 1)              # floor -> tier 1
	grid.slab(ce + 4, ce + 8, g - 6)               # tier 1, left half
	grid.slab(ce + 13, ce + 18, g - 6)             # tier 1, right half (a four-tile gap between the halves)
	grid.put(ce + 14, g - 7, "L")                  # the lock terminal, a tile clear of its gate
	grid.laser(ce + 17, g - 11, g - 7, laser_id)   # the gate: under tier 2, between the terminal and the ladder
	grid.ladder(ce + 18, g - 12, g - 7)            # tier 1 -> tier 2
	grid.slab(ce + 12, ce + 17, g - 12)            # tier 2
	grid.ledge(ce + 7, ce + 8, g - 13)             # ledges climbing up and to the left
	grid.ledge(ce + 2, ce + 3, g - 14)
	grid.ledge(ce - 3, ce - 2, g - 15)
	grid.ledge(ce - 8, ce - 7, g - 16)


## Draw one floor on its own, facing right, with its walking surface on row L1_BLOCK_GROUND. Floors 0 to 3
## end in a tower; the top floor ends at the exit.
static func _l1_block(floor_index: int) -> LevelGrid:
	var g := L1_BLOCK_GROUND
	var grid := LevelGrid.new(L1_WIDTH, L1_BLOCK_ROWS)
	var first := 1 if floor_index == 0 else L1_MARGIN
	grid.fill(first, g, L1_WIDTH - 2, g + L1_SLAB - 1, "#")
	var liquid: String = L1_LIQUIDS[floor_index]
	var lasers := [str(2 * floor_index + 1), str(2 * floor_index + 2)]
	var c := L1_MARGIN
	if floor_index == 0:
		grid.put(3, g - 1, "P")
		grid.put(18, g - 1, "B")                     # a lone Bro to meet near the start
		grid.put(24, g - 1, "K")
	var ce := L1_MARGIN + L1_COURSE - 1
	for entry in _l1_plan(floor_index):
		var kind: String = entry[0]
		match kind:
			"flat":
				c = _s_flat(grid, c, entry[1], g, entry[2] if entry.size() > 2 else "")
			"hurdle":
				c = _s_hurdle(grid, c, g)
			"pit":
				c = _s_pit(grid, c, g, entry[1], entry[2] if entry.size() > 2 else liquid)
			"tunnel":
				c = _s_tunnel(grid, c, g, lasers[0])
			"tunnel_plain":
				c = _s_tunnel_plain(grid, c, g)
			"stones":
				c = _s_stones(grid, c, g, entry[1], entry[2] if entry.size() > 2 else liquid)
			"gauntlet":
				c = _s_gauntlet(grid, c, g)
			"deck":
				c = _s_deck(grid, c, g, entry[1] if entry.size() > 1 else liquid)
			"spikes":
				c = _s_spikes(grid, c, g)
			"pyramid":
				c = _s_pyramid(grid, c, g)
			"ladder_wall":
				c = _s_ladder_wall(grid, c, g)
			"terrace":
				c = _s_terrace(grid, c, g)
			"gallery":
				c = _s_gallery(grid, c, g, entry[1] if entry.size() > 1 else liquid)
			"exit":
				grid.put(c + 2, g - 1, "E")
				c += 5
	if c > ce + 1:
		push_error("Level 1 floor %d is %d columns too long" % [floor_index, c - ce - 1])
	if floor_index < L1_FLOORS - 1:
		_l1_tower(grid, ce, g, lasers[1])
	_l1_decor(grid, g, first + 2, L1_WIDTH - 3, floor_index)
	var bad := bros_without_room(grid.to_rows())
	if not bad.is_empty():
		push_error("Level 1 floor %d: AI Bros without enough flat ground to pace: %s" % [floor_index, bad])
	return grid


## Floor `floor_index` as it sits in the map (odd floors are mirrored), alone in its own grid.
static func _l1_floor_grid(floor_index: int) -> LevelGrid:
	var block := _l1_block(floor_index)
	return block.mirrored() if floor_index % 2 == 1 else block


static var _l1_cache: Array[String] = []


static func level_1() -> Array[String]:
	if not _l1_cache.is_empty():
		return _l1_cache.duplicate()
	var rows := l1_surface_row(0) + L1_SLAB
	var g := LevelGrid.new(L1_WIDTH, rows)
	for f in L1_FLOORS:
		g.paste(_l1_floor_grid(f), 0, l1_surface_row(f) - L1_BLOCK_GROUND)
	# The shell: ceiling, side walls.
	g.fill(0, 0, L1_WIDTH - 1, 0, "#")
	g.fill(0, 0, 0, rows - 1, "#")
	g.fill(L1_WIDTH - 1, 0, L1_WIDTH - 1, rows - 1, "#")
	g.fill(1, 1, L1_WIDTH - 2, 1, "r")             # a rail along the ceiling
	_l1_cache = g.to_rows()
	return _l1_cache.duplicate()


## One floor on its own, for tests and the solver: its pieces and tower, a start marker (P) at its first flat
## column, and an exit marker (E) at the top of its tower (the top floor already has its real exit). The top of
## a tower is the next floor's first piece of walking surface, drawn here as a small stand-in slab.
static func l1_floor_map(floor_index: int) -> Array[String]:
	# Empty rows are added below the floor so that stepping off its end is a deadly drop, as it is in the real
	# level (where the shaft below is a whole floor deep), rather than a harmless step down.
	var g := LevelGrid.new(L1_WIDTH, L1_BLOCK_ROWS + L1_SPACING)
	g.paste(_l1_floor_grid(floor_index), 0, 0)
	var mirrored := floor_index % 2 == 1
	var ce := L1_MARGIN + L1_COURSE - 1
	var top := L1_BLOCK_GROUND - L1_SPACING
	if floor_index < L1_FLOORS - 1:
		var slab_from := ce - 14
		var slab_to := ce - 9
		var e_col := ce - 12
		if mirrored:
			slab_from = L1_WIDTH - 1 - (ce - 9)
			slab_to = L1_WIDTH - 1 - (ce - 14)
			e_col = L1_WIDTH - 1 - (ce - 12)
		g.fill(slab_from, top, slab_to, top + 2, "#")
		g.put(e_col, top - 1, "E")
	if floor_index > 0:
		# the previous floor's tower arrives at the start of the course; stand the player on its first flat tile
		g.put((L1_WIDTH - 1 - (L1_MARGIN + 3)) if mirrored else (L1_MARGIN + 3), L1_BLOCK_GROUND - 1, "P")
	# walls
	g.fill(0, 0, 0, g.rows - 1, "#")
	g.fill(L1_WIDTH - 1, 0, L1_WIDTH - 1, g.rows - 1, "#")
	g.fill(0, g.rows - 1, L1_WIDTH - 1, g.rows - 1, "#")
	return g.to_rows()


## The computers you can use, found by reading the map: every lock terminal ("L") belongs to the nearest laser
## gate (a digit) and switches it off. "c"/"r" is the terminal's bottom-left tile, "laser" the gate's id and
## "game" which puzzle to show ("random" = a different silly one each time; see HackPopup.GAME_NAMES).
static func terminals(id: String) -> Array[Dictionary]:
	if id == TEST_ID:
		return []
	return terminals_in(map(id))


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
	if c < 0 or c >= rows[r].length() or r < 2 or r + 1 >= rows.size():
		return false
	if not "#=".contains(rows[r + 1][c]):
		return false
	for dr in range(0, 3):
		if "#XOH=123456789AFNW".contains(rows[r - dr][c]):
			return false
	return true


## How many contiguous tiles of flat ground (in the row of tile (c, r)) the Bro marked there can pace on, counting its own.
static func bro_flat_span(rows: Array[String], c: int, r: int) -> int:
	if not bro_can_stand(rows, c, r):
		return 0
	var n := 1
	var x := c - 1
	while bro_can_stand(rows, x, r):
		n += 1
		x -= 1
	x = c + 1
	while bro_can_stand(rows, x, r):
		n += 1
		x += 1
	return n


## Every Bro marker ("B") in the map that does not have bro_min_flat_tiles() of flat ground to pace on.
static func bros_without_room(rows: Array[String]) -> Array[String]:
	var bad: Array[String] = []
	var need := bro_min_flat_tiles()
	for r in rows.size():
		for c in rows[r].length():
			if rows[r][c] == "B" and bro_flat_span(rows, c, r) < need:
				bad.append("(%d,%d) has %d of %d tiles" % [c, r, bro_flat_span(rows, c, r), need])
	return bad


## Background machines and lights for one floor drawn on its own: they stand on the floor between columns
## c_from and c_to, wherever their whole footprint is free and a tile clear of anything else (a crate, a gate,
## a computer, a ladder, another machine). Each floor has its own mix of machines so they don't all look alike.
## Floor-standing decor (lamps "l", canisters "c") must stand on something solid; tools/tests/level1_test.gd
## checks that nothing floats and that nothing crowds a lock terminal.
static func _l1_decor(grid: LevelGrid, g: int, c_from: int, c_to: int, floor_index: int) -> void:
	var themes := [
		["S", "G", "R", "M", "G", "S", "R"],   # floor 0: a mixed server room
		["G", "G", "R", "G", "M", "G"],        # floor 1: a GPU farm
		["R", "R", "S", "M", "R", "S"],        # floor 2: tower racks and supercomputers
		["M", "S", "G", "M", "S", "G"],        # floor 3: control room
	]
	var machines: Array = themes[floor_index % themes.size()]
	var widths := {"S": 3, "G": 2, "R": 1, "M": 4}
	# single-tile lamps and canisters first (they sit on the floor), then machines
	var c := c_from + 3 + floor_index
	var n := 0
	while c < c_to:
		if _l1_clear_for(grid, c, 1, g, 1):
			grid.put(c, g - 1, "l" if (n + floor_index) % 3 != 2 else "c")
			n += 1
			c += 10 + floor_index
		else:
			c += 1
	c = c_from
	var i := floor_index
	while c < c_to - 6:
		var letter: String = machines[i % machines.size()]
		var w: int = widths[letter]
		if _l1_clear_for(grid, c, w, g, 3):
			grid.put(c, g - 1, letter)
			c += w + 2
			i += 1
		else:
			c += 1


## True if the footprint (columns c to c+w-1, rows g-height to g-1) is empty, stands on solid ground, and has one empty
## column of margin on each side too (a lamp or canister in the margin is fine); and no machine already placed
## reaches into it.
static func _l1_clear_for(grid: LevelGrid, c: int, w: int, g: int, height: int) -> bool:
	for dc in range(-1, w + 1):
		var in_footprint := dc >= 0 and dc < w
		for dr in range(1, height + 1):
			var ch := grid.get_cell(c + dc, g - dr)
			if in_footprint and ch != ".":
				return false
			if not in_footprint and ch != "." and ch != "l" and ch != "c":
				return false
			if _l1_inside_machine(grid, c + dc, g - dr):
				return false
	for dc in w:
		if grid.get_cell(c + dc, g) != "#":
			return false
	return true


## True if cell (c, r) is part of the footprint of a machine whose letter is to its left (in this row or in one of the
## rows below it, where tall machines have their letters).
static func _l1_inside_machine(grid: LevelGrid, c: int, r: int) -> bool:
	for dr in range(0, 4):
		for dc in range(0, 4):
			if dc == 0 and dr == 0:
				continue
			var letter := grid.get_cell(c - dc, r + dr)
			if LevelGrid.MACHINE_WIDTHS.has(letter) and LevelGrid.MACHINE_WIDTHS[letter] > dc and dr < 3:
				return true
	return false
