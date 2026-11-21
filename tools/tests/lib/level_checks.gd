class_name LevelChecks
extends RefCounted
## Generic checks for ANY level, given only its id (a folder in levels/, or LevelData.FILE_ID after LevelData.use_file()). They never look at where
## things are placed: they ask whether the level can be played. Can the player get from the start to the exit? Is there a spot they can reach and
## never leave? Does every laser gate have its computer in front of it, and does a gate really block the way? Can the power-up box be reached?
## Each check returns a result {"name": String, "ok": bool, "detail": String}; run() returns all of them. The level solver (level_solver.gd) walks
## the level the way the player moves.
##
##   for r in LevelChecks.run("level_03"):
##       print(("PASS  " if r["ok"] else "FAIL  ") + r["name"])
##
## Boss levels (meta "boss") are arenas: there is nothing to traverse, so only the structure checks apply to them.
## `campaign` is true for the game's own levels, which must also have exactly one power-up box; a level made for a test or a draft has none.

# The player's jump (pixels), worked out from the player's own numbers: how high a standing jump takes the feet.
const JUMP_HEIGHT := Player.JUMP_VELOCITY * Player.JUMP_VELOCITY / (2.0 * Player.GRAVITY)

# BOX_REACH_X: how far sideways (pixels) from the spot a player jumps from the middle of a power-up box may be and still be reachable by a jump
# (a standing jump carries the player about this far while they rise to the box's height).
const BOX_REACH_X := 230.0

# GATE_CHARS: the map characters of the laser gates (the digits 1-9 are the gate ids).
const GATE_FIRST := "1"
const GATE_LAST := "9"


static func _result(name: String, ok: bool, detail := "") -> Dictionary:
	return {"name": name, "ok": ok, "detail": detail}


static func _count(rows: Array[String], chars: String) -> int:
	var n := 0
	for line in rows:
		for ch in chars:
			n += line.count(ch)
	return n


static func _is_gate(ch: String) -> bool:
	return ch >= GATE_FIRST and ch <= GATE_LAST


static func _solve(rows: Array[String]) -> LevelSolver:
	var solver := LevelSolver.new(rows)
	solver.solve()
	return solver


static func _gates_as_walls(rows: Array[String], on_ids: Array) -> Array[String]:
	var out: Array[String] = []
	for line in rows:
		var a := line.split("")
		for i in a.size():
			if _is_gate(a[i]):
				a[i] = "#" if on_ids.has(a[i]) else "."
		out.append("".join(a))
	return out


## Every check for the level `id`.
static func run(id: String, campaign := true) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var rows := LevelData.map(id)
	var tag := "%s: " % id
	var even := rows.all(func(r: String) -> bool: return r.length() == rows[0].length())
	out.append(_result(tag + "all rows are the same width", even))
	var is_boss := BossFight.boss_of(id) != ""
	out.append(_result(tag + "one start, and %s" % ("no exit (the boss ends it)" if is_boss else "one exit"),
			_count(rows, "P") == 1 and _count(rows, "E") == (0 if is_boss else 1)))
	if campaign:
		out.append_array(_box_checks(id, rows))
	out.append_array(_gate_seal_checks(id, rows))
	out.append(_sign_check(id, rows))
	if is_boss:
		return out
	out.append(_door_room_check(id, rows))
	out.append(_result(tag + "every AI Bro has room to pace", LevelData.bros_without_room(rows).is_empty(), str(LevelData.bros_without_room(rows))))
	out.append_array(_traversal_checks(id, rows))
	out.append_array(_gate_checks(id, rows))
	return out


## The exit door has room: it is as tall and wide as ExitDoor.SIZE, standing on the exit's tile, so the tiles above it (and beside it, over its height) must not be solid.
static func _door_room_check(id: String, rows: Array[String]) -> Dictionary:
	var blocked := []
	var tiles_high := ceili(ExitDoor.SIZE.y / Level.T)
	var tiles_aside := ceili((ExitDoor.SIZE.x / 2.0 - Level.T / 2.0) / Level.T)
	for r in rows.size():
		var c := rows[r].find("E")
		if c < 0:
			continue
		for up in tiles_high:
			for side in range(-tiles_aside, tiles_aside + 1):
				var rr := r - up
				var cc := c + side
				var cell := "#" if rr < 0 or cc < 0 or cc >= rows[rr].length() else rows[rr][cc]
				if (up > 0 or side != 0) and (Level.SOLID.contains(cell) or cell == "="):
					blocked.append(Vector2i(cc, rr))
	return _result("%s: the exit door has room (%d tiles up, %d beside it)" % [id, tiles_high, tiles_aside], blocked.is_empty(), str(blocked))


## The player can get from the start to the exit, and never gets stuck on the way.
static func _traversal_checks(id: String, rows: Array[String]) -> Array[Dictionary]:
	var tag := "%s: " % id
	var out: Array[Dictionary] = []
	var solver := _solve(rows)
	var route := solver.route()
	out.append(_result(tag + "the exit can be reached from the start", not route.is_empty(), "%d steps" % route.size()))
	var stuck := solver.stuck_nodes()
	out.append(_result(tag + "no spot the player can reach is a dead end", stuck.is_empty(), "%d stuck, first %s" % [stuck.size(), stuck.slice(0, 3)]))
	var coreach := solver.coreachable()
	var bad := []
	for r in rows.size():
		for c in rows[r].length():
			if rows[r][c] == "K" and not coreach.has(solver.key_for((c + 0.5) * Level.T, (r + 1) * Level.T)):
				bad.append(Vector2i(c, r))
	out.append(_result(tag + "from every checkpoint the exit can still be reached", bad.is_empty(), str(bad)))
	return out


## Every laser gate has a computer, the computer can be reached before its gate, and a closed gate really stops the way to the exit.
static func _gate_checks(id: String, rows: Array[String]) -> Array[Dictionary]:
	var tag := "%s: " % id
	var out: Array[Dictionary] = []
	var gates := {}
	for line in rows:
		for ch in line:
			if _is_gate(ch):
				gates[ch] = true
	var ids: Array = gates.keys()
	ids.sort()
	var terminals := LevelData.terminals(id)
	out.append(_result(tag + "every laser gate has a computer", terminals.size() == gates.size(), "%d computers, %d gates" % [terminals.size(), gates.size()]))
	if ids.is_empty():
		return out
	out.append(_result(tag + "with every gate closed the exit cannot be reached (no way round a gate)", _solve(_gates_as_walls(rows, ids)).route().is_empty()))
	for k in ids.size():
		var world := _solve(_gates_as_walls(rows, ids.slice(k)))
		var computer := {}
		for t in terminals:
			if t["laser"] == ids[k]:
				computer = t
		var zone := Rect2(computer["c"] * Level.T - 40, (computer["r"] - 2) * Level.T, 2 * Level.T + 80, 3 * Level.T) if not computer.is_empty() else Rect2()
		var reached := false
		for key in world.nodes:
			var p: Vector2 = world.nodes[key]
			if Rect2(p.x - Player.BODY_SIZE.x / 2.0, p.y - Player.BODY_SIZE.y, Player.BODY_SIZE.x, Player.BODY_SIZE.y).intersects(zone):
				reached = true
				break
		out.append(_result(tag + "with gates %s onwards closed, the computer for gate %s can be reached" % [ids[k], ids[k]], reached))
	return out


## Every gate is sealed from the floor to the ceiling: above the slab over a gate there must be solid tiles all the way up, or a vehicle with a booster
## could fly over it.
static func _gate_seal_checks(id: String, rows: Array[String]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var top_of := {}
	for r in rows.size():
		for c in rows[r].length():
			if _is_gate(rows[r][c]) and not top_of.has(c):
				top_of[c] = r
	for c in top_of:
		var open_row := -1
		for r in range(2, int(top_of[c])):
			if not Level.SOLID.contains(rows[r][c]):
				open_row = r
				break
		out.append(_result("%s: the laser gate in column %d is sealed up to the ceiling (nothing can pass over it)" % [id, c], open_row < 0, "open at row %d" % open_row))
	return out


## The cells (column, row) of the power-up boxes of a level.
static func boxes(id: String) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var box_char := str(TileRegistry.kind_for_key("powerup_box").get("char", ""))
	var rows := LevelData.map(id)
	for r in rows.size():
		for c in rows[r].length():
			if box_char != "" and rows[r][c] == box_char:
				out.append(Vector2i(c, r))
	return out


## The standing spots the player can reach from which a jump can bring their body to touch the box in cell `box` (any level; found by the solver):
## below the box's top, close enough sideways, and no further below it than a jump plus the body's height reaches. Nearest first.
static func box_jump_spots(id: String, box: Vector2i) -> Array[Vector2]:
	var rows := LevelData.map(id)
	var solver := _solve(rows)
	var centre := Vector2((box.x + 0.5) * Level.T, (box.y + 0.5) * Level.T)
	var top := centre.y - PowerUpBox.HALF
	var spots: Array[Vector2] = []
	for key in solver.nodes:
		var p: Vector2 = solver.nodes[key]
		var rise := p.y - top
		if rise > 0.0 and p.y - JUMP_HEIGHT - Player.BODY_SIZE.y <= centre.y + PowerUpBox.HALF and absf(p.x - centre.x) <= BOX_REACH_X:
			spots.append(p)
	spots.sort_custom(func(a: Vector2, b: Vector2) -> bool: return absf(a.x - centre.x) < absf(b.x - centre.x))
	return spots


## Every deadly pit has its warning sign on the ground just before it (see PitSigns; `level_cli pit-signs <file>` adds the missing ones).
static func _sign_check(id: String, rows: Array[String]) -> Dictionary:
	var missing := PitSigns.missing(rows)
	return _result("%s: every deadly pit has its warning sign before it" % id, missing.is_empty(),
			"missing at %s" % str(missing.map(func(s: Dictionary) -> String: return "col %d, row %d (%s)" % [s["col"], s["row"], s["liquid"]])))


## One power-up box, and a player can reach it (the solver finds a spot to jump onto it from).
static func _box_checks(id: String, rows: Array[String]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var found := boxes(id)
	out.append(_result("%s: exactly one power-up box" % id, found.size() == 1, str(found)))
	if found.size() == 1:
		out.append(_result("%s: the power-up box can be reached by a jump" % id, not box_jump_spots(id, found[0]).is_empty()))
	return out
