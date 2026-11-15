extends SceneTree
## Every level in levels/ (see LevelData.level_ids()): well-formed, short, finishable, no dead ends, laser gates in order, nothing
## skippable, enemies with room to pace. Exits non-zero on failure.
## Run: godot_console --headless --fixed-fps 60 --path . --script res://tools/tests/levels_test.gd

# MAX_COLUMNS: the widest a short level may be. At the player's running speed a level this wide takes well under a minute
# of pure running, so with the obstacles it stays within a couple of minutes. Higher: allows longer levels.
const MAX_COLUMNS := 150

# MIN_PITS / MIN_ENEMIES: the least each level must offer, so none of them is empty.
const MIN_PITS := 2
const MIN_ENEMIES := 4

var ok := true


func _check(name: String, cond: bool, detail := "") -> void:
	print(("PASS  " if cond else "FAIL  "), name, "  ", detail)
	if not cond:
		ok = false


func _initialize() -> void:
	_main()


func _count(rows: Array[String], chars: String) -> int:
	var n := 0
	for line in rows:
		for ch in chars:
			n += line.count(ch)
	return n


func _solve(rows: Array[String]) -> LevelSolver:
	var solver := LevelSolver.new(rows)
	solver.solve()
	return solver


func _remove(rows: Array[String], chars: String) -> Array[String]:
	var out: Array[String] = []
	for line in rows:
		var a := line.split("")
		for i in a.size():
			if chars.contains(a[i]):
				a[i] = "."
		out.append("".join(a))
	return out


func _gates_as_walls(rows: Array[String], on_ids: Array) -> Array[String]:
	var out: Array[String] = []
	for line in rows:
		var a := line.split("")
		for i in a.size():
			if a[i] >= "1" and a[i] <= "9":
				a[i] = "#" if on_ids.has(a[i]) else "."
		out.append("".join(a))
	return out


func _main() -> void:
	var level_ids := LevelData.level_ids()
	_check("the game has levels, the first is the default", level_ids.size() >= 3 and level_ids[0] == LevelData.DEFAULT_ID, str(level_ids))
	_check("the common art folder is not a level", not level_ids.has("common"))
	var chain_ok := true
	for i in level_ids.size():
		var expected := level_ids[i + 1] if i + 1 < level_ids.size() else ""
		if LevelData.next_id(level_ids[i]) != expected:
			chain_ok = false
	_check("the levels are chained one after the other, the last one ends the game", chain_ok)
	_check("the test level is still there", LevelData.has_level("test"))
	var titles := {}
	for id in level_ids:
		titles[LevelData.title(id)] = true
	_check("each level has its own title", titles.size() == level_ids.size(), str(titles.keys()))
	for id in level_ids:
		_check("level %s: its own background folder holds every layer" % id, LevelBackground.LAYERS.all(func(l: String) -> bool: return ResourceLoader.exists(LevelData.background_dir(id) + l + ".png")) and LevelData.background_dir(id).begins_with(LevelData.level_dir(id)), LevelData.background_dir(id))

	for id in level_ids:
		var rows := LevelData.map(id)
		var cols := rows[0].length()
		var tag := "level %s: " % id
		var even := true
		for r in rows:
			if r.length() != cols:
				even = false
		_check(tag + "all rows the same width", even)
		_check(tag + "exactly one spawn and one exit", _count(rows, "P") == 1 and _count(rows, "E") == 1)
		_check(tag + "short enough (%d columns)" % cols, cols <= MAX_COLUMNS)
		_check(tag + "has pits and enemies", _count(rows, "AFNW") > 0 and _count(rows, "B") >= MIN_ENEMIES, "%d pit cells, %d Bros" % [_count(rows, "AFNW"), _count(rows, "B")])
		var cramped := LevelData.bros_without_room(rows)
		_check(tag + "every AI Bro has room to pace", cramped.is_empty(), str(cramped))
		var terminals := LevelData.terminals(id)
		var gates := {}
		for line in rows:
			for ch in line:
				if ch >= "1" and ch <= "9":
					gates[ch] = true
		_check(tag + "every laser gate has a computer", terminals.size() == gates.size() and gates.size() > 0, "%d computers, %d gates" % [terminals.size(), gates.size()])
		var floating := []
		for r in rows.size():
			for c in cols:
				if "lic".contains(rows[r][c]) and not "#XO=".contains(rows[r + 1][c] if r + 1 < rows.size() else "#"):
					floating.append(Vector2i(c, r))
		_check(tag + "lamps and canisters stand on something", floating.is_empty(), str(floating))
		# nothing crowds a lock terminal
		var crowded := []
		for t in terminals:
			for dr in range(0, 3):
				for dc in range(-1, 3):
					var ch := rows[t["r"] - dr][t["c"] + dc]
					if ch != "." and not (dc == 0 and dr == 0):
						crowded.append("%s next to the computer at (%d,%d)" % [ch, t["c"], t["r"]])
		_check(tag + "nothing overlaps or crowds a lock terminal", crowded.is_empty(), str(crowded))

		var solver := _solve(rows)
		var route := solver.route()
		_check(tag + "the exit can be reached", not route.is_empty(), "%d steps" % route.size())
		var stuck := solver.stuck_nodes()
		_check(tag + "no reachable spot is a dead end", stuck.is_empty(), "%d stuck, first %s" % [stuck.size(), stuck.slice(0, 3)])
		var bad_checkpoints := []
		var coreach := solver.coreachable()
		for r in rows.size():
			for c in cols:
				if rows[r][c] == "K" and not coreach.has(solver.key_for((c + 0.5) * 70.0, (r + 1) * 70.0)):
					bad_checkpoints.append(Vector2i(c, r))
		_check(tag + "every checkpoint can still finish", bad_checkpoints.is_empty(), str(bad_checkpoints))

		var ids: Array = gates.keys()
		ids.sort()
		_check(tag + "with every gate on the exit cannot be reached", _solve(_gates_as_walls(rows, ids)).route().is_empty())
		for k in ids.size():
			var world := _solve(_gates_as_walls(rows, ids.slice(k)))
			var term: Dictionary = {}
			for t in terminals:
				if t["laser"] == ids[k]:
					term = t
			var zone := Rect2(term["c"] * 70 - 40, (term["r"] - 2) * 70, 2 * 70 + 80, 3 * 70)
			var reached := false
			for key in world.nodes:
				var p: Vector2 = world.nodes[key]
				if Rect2(p.x - 30, p.y - 128, 60, 128).intersects(zone):
					reached = true
					break
			_check(tag + "gates %s onwards on: the computer for gate %s can be reached" % [ids[k], ids[k]], reached)

		if _count(rows, "=") > 0:
			_check(tag + "the ledges cannot be skipped", _solve(_remove(rows, "=")).route().is_empty())
		if _count(rows, "H") > 0:
			_check(tag + "the ladders cannot be skipped", _solve(_remove(rows, "H")).route().is_empty())

	print("ALL PASS" if ok else "SOME FAILED")
	quit(0 if ok else 1)
