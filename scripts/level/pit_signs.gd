class_name PitSigns
extends RefCounted
## The warning signs before the deadly pits. Every pit has a small signboard on the ground tile just before it (on the side the player comes from),
## showing what is in it: a green skull for toxic waste, a flame for lava, the radiation trefoil for nuclear waste, a piranha with open jaws for the
## piranha tank. A sign is an ordinary decor tile (the registry kinds `decor_sign_pit_*`, pictures made by tools/art/generate_pit_signs.py), so the
## level editor offers them too; this class only knows WHERE they belong, so that the level generator, the `pit-signs` command of the level CLI
## and the level checks (tools/tests/lib/level_checks.gd) agree.
##
##   for spot in PitSigns.missing(rows):          # rows: the tile map, one string per row, one character per tile
##       grid.put(spot["col"], spot["row"], spot["char"])

# SIGN_KEYS: the registry key of the sign that goes with each pit liquid (the letters of the tile map: A toxic waste, F lava, N nuclear waste, W piranha tank).
const SIGN_KEYS := {"A": "decor_sign_pit_poison", "F": "decor_sign_pit_fire", "N": "decor_sign_pit_nuclear", "W": "decor_sign_pit_piranha"}

# MAX_BACK: how many tiles back from the pit's edge a sign may stand when the tile right before the pit is taken (a lamp, a crate, a machine). Further
# back than this it no longer says "the pit is here".
const MAX_BACK := 4

# MAX_CLIMB: how many tiles of solid wall above the pit's ground level the sign may stand on top of (a pit right behind a block the player climbs and
# jumps from has its sign on top of the block, where the jump starts).
const MAX_CLIMB := 6


## The map character of the sign for a pit liquid letter ("" if the letter is not a pit).
static func sign_char(liquid: String) -> String:
	if not SIGN_KEYS.has(liquid):
		return ""
	return str(TileRegistry.kind_for_key(str(SIGN_KEYS[liquid])).get("char", ""))


## Every sign the map should have: {"col", "row", "liquid", "char", "present"}, one for each pit that has a tile of solid ground in front of it (to the left,
## on the side the player comes from) with room for a sign above it. `present` says whether the sign is already there.
static func spots(rows: Array[String]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for r in range(2, rows.size()):
		var row := rows[r]
		var c := 0
		while c < row.length():
			var liquid := row[c]
			if not SIGN_KEYS.has(liquid) or rows[r - 1][c] == liquid:    # (only the top row of a pit counts)
				c += 1
				continue
			var edge := c
			while c < row.length() and row[c] == liquid:
				c += 1
			var spot := _spot_before(rows, edge, r, liquid)
			if not spot.is_empty():
				out.append(spot)
	return out


## The signs that are not there yet.
static func missing(rows: Array[String]) -> Array[Dictionary]:
	return spots(rows).filter(func(s: Dictionary) -> bool: return not bool(s["present"]))


## The place for the sign of the pit whose top row is `r` and whose left edge is column `edge`: on the nearest tile of solid ground to the left (the
## ground's top is the row above the pit's top; if a wall rises there, the top of the wall) that has the sign already above it or nothing at all.
static func _spot_before(rows: Array[String], edge: int, r: int, liquid: String) -> Dictionary:
	var wanted := sign_char(liquid)
	for c in range(edge - 1, edge - 1 - MAX_BACK, -1):
		if c < 1 or SIGN_KEYS.has(rows[r][c]):
			break
		if not _solid(rows[r - 1][c]):
			break
		var top := r - 1                                     # the top of the solid stack standing on this column
		while top > 1 and r - 1 - top < MAX_CLIMB and _solid(rows[top - 1][c]):
			top -= 1
		var above := rows[top - 1][c]
		if above == wanted or (above == "." and not _under_machine(rows[top - 1], c)):
			return {"col": c, "row": top - 1, "liquid": liquid, "char": wanted, "present": above == wanted}
	return {}


## True if the tile at column `c` of `row` is part of a machine's footprint: a machine is marked only by the letter on its bottom-left tile and covers the
## tiles to the right of it (see LevelGrid.MACHINE_WIDTHS).
static func _under_machine(row: String, c: int) -> bool:
	for back in range(1, 4):
		if c - back < 0:
			break
		var letter := row[c - back]
		if LevelGrid.MACHINE_WIDTHS.has(letter) and int(LevelGrid.MACHINE_WIDTHS[letter]) > back:
			return true
	return false


static func _solid(ch: String) -> bool:
	return ch != "" and Level.SOLID.contains(TileRegistry.physics_char(ch))
