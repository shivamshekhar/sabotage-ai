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

# L1_GROUND: the map row of the walking surface on Level 1's ground floor. Row numbers count down from
# the top, so a larger row is lower. Everything on the ground floor is placed relative to it.
const L1_GROUND := 26

# L1_PIT_DEPTH: how many tiles deep Level 1's spike pits are. They must be deeper than the player can
# jump out of (see Player.JUMP_VELOCITY and GRAVITY: jump height = JUMP_VELOCITY^2 / (2 * GRAVITY)),
# so falling in is a trap you cannot climb out of. The deadly part is the spikes at the bottom.
const L1_PIT_DEPTH := 3


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
	return Vector2(150, 1560)


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
# LEVEL 1: DATA CENTER 01. Find the exit terminal to sabotage the data center.
#
# The route is a big U. Act 1 runs left to right along the ground through spike pits, wide gaps that
# need stepping stones, spike strips, crates and stairs. Act 2 is a tower at the right end: ladders
# and hops up two tiers, then a chain of ledges climbing left. Act 3 is a corridor high up that runs
# back right to left over bottomless drops (a fall from there is deadly) to the exit.
# tools/tests/level1_test.gd proves it can be finished, can't trap the player, and that the wide
# gaps can't simply be jumped across.
# ---------------------------------------------------------------------------------------------

## Dig a deep spike pit across columns c0 to c1 of the ground floor.
static func _l1_pit(g: LevelGrid, c0: int, c1: int) -> void:
	g.carve(c0, L1_GROUND, c1, L1_GROUND + L1_PIT_DEPTH - 1)
	g.spikes(c0, c1, L1_GROUND + L1_PIT_DEPTH - 1)


static func level_1() -> Array[String]:
	var ground := L1_GROUND
	var g := LevelGrid.new(100, 30)

	# The shell: ceiling, side walls, and a ground floor four tiles thick.
	g.fill(0, 0, 99, 0, "#")
	g.fill(0, 0, 0, 29, "#")
	g.fill(99, 0, 99, 29, "#")
	g.fill(1, ground, 98, 29, "#")

	# ---- ACT 1, section 1 (columns 1 to 30): start room, crate hurdle, first pit, spike tunnel
	g.put(3, ground - 1, "P")
	g.crate_stack(9, ground - 1, 1)             # a crate to hop onto...
	g.crate_stack(10, ground - 1, 2)            # ...then a taller one, then drop down the far side
	g.put(12, ground - 1, "K")
	_l1_pit(g, 14, 16)                          # first pit: 3 wide
	g.fill(19, 21, 30, 21, "#")                 # a low ceiling over a spike strip: no room for a high jump
	g.spikes(22, 23, ground - 1)
	g.put(26, ground - 1, "L")                  # terminal 1 (a lock terminal): opens the laser one tile past it
	g.laser(29, 22, ground - 1, "1")

	# ---- ACT 1, section 2 (columns 31 to 61): a wide pit crossed on two stepping stones, then a crate gauntlet
	_l1_pit(g, 31, 44)
	g.ledge(35, 36, ground)
	g.ledge(41, 42, ground)
	g.put(46, ground - 1, "K")
	g.spikes(52, 53, ground - 1)
	g.crate_stack(56, ground - 1, 2, "O")

	# ---- ACT 1, section 3 (columns 62 to 79): crate stairs up to a raised deck, then a wide pit down to the ground
	g.crate_stack(62, ground - 1, 1)
	g.crate_stack(63, ground - 1, 2)
	g.crate_stack(64, ground - 1, 3)
	g.crate_stack(65, ground - 1, 4)
	g.fill(66, ground - 4, 70, ground - 1, "#")
	_l1_pit(g, 71, 76)

	# ---- ACT 2: the tower (columns 80 to 98)
	g.put(80, ground - 1, "K")
	g.ladder(82, 20, 25)                        # ground -> tier 1
	g.slab(83, 87, 20)                          # tier 1, left half
	g.slab(92, 97, 20)                          # tier 1, right half (4-tile gap between the halves)
	g.put(94, 19, "L")                          # terminal 2: next to its laser, a step from where you land
	g.laser(96, 15, 19, "2")                    # between the terminal and the ladder, under tier 2
	g.ladder(97, 14, 19)                        # tier 1 -> tier 2
	g.slab(91, 96, 14)                          # tier 2
	g.ledge(86, 87, 13)                         # ledges climbing up and to the left
	g.ledge(81, 82, 12)
	g.ledge(76, 77, 11)
	g.ledge(71, 72, 10)

	# ---- ACT 3: the high corridor, right to left, to the exit
	g.fill(48, 4, 72, 4, "#")                   # ceiling over the corridor
	g.fill(48, 5, 48, 9, "#")                   # wall behind the exit
	g.slab(66, 70, 9)                           # entry platform
	g.spikes(68, 68, 8)
	g.slab(57, 61, 9)                           # middle platform
	g.ceiling_spikes(58, 59, 5)
	g.slab(49, 52, 9)                           # exit platform
	g.put(50, 8, "E")

	# ---- AI Bros: each paces near a ledge or flat spot and chases you if it sees you coming
	g.put(48, ground - 1, "B")                  # by the second checkpoint
	g.put(59, ground - 1, "B")                  # in the crate gauntlet
	g.put(68, ground - 4 - 1, "B")              # on the raised deck: you meet it as you climb the crate stairs
	g.put(79, ground - 1, "B")                  # between the last pit and the tower
	g.put(59, 8, "B")                           # on the middle platform of the corridor

	_l1_decor(g)
	return g.to_rows()


## The computers you can use. "c"/"r" is the machine's bottom-left tile (the letter in the map), "laser" is
## the id of the force field it switches off (the digit in the map) and "game" picks its puzzle
## ("random" = a different silly one each time; see HackPopup.GAME_NAMES for the others). Each force field needs exactly one terminal, reachable before the field.
static func terminals(id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if id == TEST_ID:
		return out
	out.append({"c": 26, "r": L1_GROUND - 1, "laser": "1", "game": "random"})
	out.append({"c": 94, "r": 19, "laser": "2", "game": "random"})
	return out


## Background machines and lights. Decor never blocks the player, but it must not overwrite
## anything solid or any marker, so each piece is only placed where its whole footprint is empty.
## Floor-standing decor (lamps "l", sirens "i", canisters "c") must stand on something solid; the
## test in tools/tests/level1_test.gd checks that nothing floats.
static func _l1_decor(g: LevelGrid) -> void:
	var y := L1_GROUND - 1
	var machines := [
		["S", 5, y, 3, 3], ["G", 17, y, 2, 3], ["G", 54, y, 2, 3],
		["M", 58, y, 4, 3], ["R", 78, y, 1, 3], ["S", 85, y, 3, 3], ["M", 89, y, 4, 3],
		["G", 94, y, 2, 3],
	]
	for m in machines:
		var free := true
		for dc in m[3]:
			for dr in m[4]:
				if g.get_cell(m[1] + dc, m[2] - dr) != ".":
					free = false
		if free:
			g.put(m[1], m[2], m[0])
	g.fill(1, 1, 98, 1, "r")        # a rail along the ceiling
	var decor := [
		# lamps and sirens, each standing on a floor, deck, slab or ledge
		["l", 8, y], ["l", 20, y], ["l", 47, y], ["l", 70, 21], ["l", 83, 19],
		["l", 93, 13], ["l", 60, 8], ["l", 70, 8], ["i", 52, 8], ["c", 11, y],
		# wall monitors hung under the corridor ceiling, gears hung under the rail
		["m", 54, 5], ["t", 63, 5], ["g", 20, 2], ["g", 80, 2],
	]
	for d in decor:
		if g.get_cell(d[1], d[2]) == ".":
			g.put(d[1], d[2], d[0])
