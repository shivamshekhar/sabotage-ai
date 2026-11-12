extends SceneTree
## Level 1 checks. Exits non-zero on failure.
##  1. Structure: one spawn, one exit, rows the same width, the right amount of everything for a level five
##     times the size of the original, everything standing on something, each laser gate close to its
##     computer with nothing in between.
##  2. LevelSolver proves the exit is reachable and that no spot reachable on the way is a dead end.
##  3. Lasers: with every gate on you cannot finish; computer k can be reached while gates k.. are on.
##  4. Difficulty: with the stepping stones or the ladders removed, the exit is NOT reachable, so the
##     wide pits cannot simply be jumped and the towers cannot be skipped.
##  5. Calibration: the solver's jump model lands within a few pixels of the real Player's jump,
##     so (2) and (3) say something about the real game.
## Run: godot_console --headless --fixed-fps 60 --path . --script res://tools/tests/level1_test.gd
## (it takes about a minute: the solver simulates tens of thousands of jumps)

# LAND_TOLERANCE: how far in pixels the solver's landing may differ from the engine's in the
# calibration jump. Larger accepts a rougher model of the player's physics.
const LAND_TOLERANCE := 20.0

# SCALE / ORIGINAL_*: how much the original (one floor) Level 1 had of each thing. The level must have at least
# SCALE times as many pits and enemies.
const SCALE := 3.5
const ORIGINAL_PITS := 3
const ORIGINAL_ENEMIES := 5
const ORIGINAL_LADDERS := 2

# CAL_X / CAL_Y: where the calibration jumps start (feet position) on the test level's long ground
# floor. Any flat open stretch of the test level will do.
const CAL_X := 300.0
const CAL_Y := 840.0

var ok := true
var main: Node
var player: Player
var frames := 0
var stage := 0
var t := 0
var hold_frames := 0
var jumped := false
var cal_results: Array[float] = []
var cal_patterns := [[9999], [16]]
var cal_index := 0


func _check(name: String, cond: bool, detail := "") -> void:
	print(("PASS  " if cond else "FAIL  "), name, "  ", detail)
	if not cond:
		ok = false


## The map with the lasers in on_ids turned into solid wall and the other lasers removed.
func _lasers_as_walls(rows: Array[String], on_ids: Array) -> Array[String]:
	var out: Array[String] = []
	for line in rows:
		var chars := line.split("")
		for i in chars.size():
			if chars[i] >= "1" and chars[i] <= "9":
				chars[i] = "#" if on_ids.has(chars[i]) else "."
		out.append("".join(chars))
	return out


func _remove_chars(rows: Array[String], chars: String) -> Array[String]:
	var out: Array[String] = []
	for line in rows:
		var chars_arr := line.split("")
		for i in chars_arr.size():
			if chars.contains(chars_arr[i]):
				chars_arr[i] = "."
		out.append("".join(chars_arr))
	return out


## The map without its stepping stones: the ledges of a pit sit on its floor's walking-surface row (or a couple of rows above it).
func _remove_stones(rows: Array[String]) -> Array[String]:
	var out: Array[String] = rows.duplicate()
	for f in LevelData.L1_FLOORS:
		for r in range(LevelData.l1_surface_row(f) - 2, LevelData.l1_surface_row(f) + 1):
			out[r] = out[r].replace("=", ".")
	return out


func _solve(rows: Array[String]) -> LevelSolver:
	var solver := LevelSolver.new(rows)
	solver.solve()
	return solver


func _count(rows: Array[String], chars: String) -> int:
	var n := 0
	for line in rows:
		for ch in chars:
			n += line.count(ch)
	return n


## How many separate pits (rectangles of one liquid) the map has.
func _count_pits(rows: Array[String]) -> int:
	var seen := {}
	var n := 0
	for r in rows.size():
		for c in rows[r].length():
			var ch := rows[r][c]
			if "AFNW".contains(ch) and not seen.has(Vector2i(c, r)):
				n += 1
				var stack := [Vector2i(c, r)]
				while not stack.is_empty():
					var p: Vector2i = stack.pop_back()
					if seen.has(p) or p.y < 0 or p.y >= rows.size() or p.x < 0 or p.x >= rows[p.y].length() or rows[p.y][p.x] != ch:
						continue
					seen[p] = true
					for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
						stack.append(p + d)
	return n


func _initialize() -> void:
	var rows := LevelData.level_1()
	var map_cols := rows[0].length()

	# 1. Structure
	var widths_ok := true
	for r in rows:
		if r.length() != map_cols:
			widths_ok = false
	_check("rows all the same width", widths_ok)
	_check("exactly one spawn", _count(rows, "P") == 1, str(_count(rows, "P")))
	_check("exactly one exit", _count(rows, "E") == 1, str(_count(rows, "E")))
	_check("the map is %d x %d tiles" % [map_cols, rows.size()], map_cols * rows.size() >= 3 * 100 * 30, "%.1f times the original area" % (map_cols * rows.size() / 3000.0))
	var pits := _count_pits(rows)
	var enemies := _count(rows, "B")
	var ladders := LevelSolver.new(rows).ladders.size()
	_check("at least %.1f times as many pits as the original" % SCALE, pits >= SCALE * ORIGINAL_PITS, "%d pits" % pits)
	_check("at least %.1f times as many enemies" % SCALE, enemies >= SCALE * ORIGINAL_ENEMIES, "%d enemies" % enemies)
	_check("a tower of ladders on every floor but the top", ladders >= (LevelData.L1_FLOORS - 1) * ORIGINAL_LADDERS, "%d ladders" % ladders)
	var cramped := LevelData.bros_without_room(rows)
	_check("every AI Bro stands on at least %d tiles of flat ground to pace on" % LevelData.bro_min_flat_tiles(), cramped.is_empty(), str(cramped))
	var narrow: Array[String] = ["#####", "#...#", "#...#", "#.B.#", "#####"]
	var wide: Array[String] = ["###############", "#.............#", "#.............#", "#......B......#", "###############"]
	_check("the room check refuses a cramped spot and accepts a roomy one", LevelData.bros_without_room(narrow).size() == 1 and LevelData.bros_without_room(wide).is_empty(), "%d and %d tiles" % [LevelData.bro_flat_span(narrow, 2, 3), LevelData.bro_flat_span(wide, 7, 3)])
	var kinds := {}
	for ch in "AFNW":
		if _count(rows, ch) > 0:
			kinds[ch] = true
	_check("all four kinds of deadly pit are used", kinds.size() == 4, str(kinds.keys()))
	_check("ordinary spikes are still there", _count(rows, "^") > 0)
	for r in rows.size():
		for c in map_cols:
			var below := rows[r + 1][c] if r + 1 < rows.size() else "#"
			if rows[r][c] == "B" or rows[r][c] == "K":
				if not "#XO=".contains(below):
					_check("%s (%d,%d) stands on something" % [rows[r][c], c, r], false)
	for id in LevelData.ids():
		var m := LevelData.map(id)
		var floating: Array[String] = []
		for r in m.size():
			for c in m[r].length():
				if "lic".contains(m[r][c]):
					var below := m[r + 1][c] if r + 1 < m.size() else "#"
					var ladder_top := below == "H" and m[r][c] != "H"
					if not ("#XO=".contains(below) or ladder_top):
						floating.append("%s at (%d,%d)" % [m[r][c], c, r])
		_check("level %s: lamps, sirens and canisters stand on something" % id, floating.is_empty(), str(floating))

	# 1b. Lasers and computers
	var terminals := LevelData.terminals("1")
	var laser_cells := {}   # id -> Array of Vector2i
	for r in rows.size():
		for c in map_cols:
			var ch := rows[r][c]
			if ch >= "1" and ch <= "9":
				if not laser_cells.has(ch):
					laser_cells[ch] = []
				laser_cells[ch].append(Vector2i(c, r))
	_check("every laser has exactly one computer", terminals.size() == laser_cells.size() and laser_cells.size() >= 2 * (LevelData.L1_FLOORS - 1) + 1, "%d computers, %d lasers" % [terminals.size(), laser_cells.size()])
	var close_ok := true
	var detail := ""
	for t in terminals:
		var cells: Array = laser_cells.get(t["laser"], [])
		if cells.is_empty() or not HackPopup.has_game(t["game"]):
			close_ok = false
			continue
		var lc: int = cells[0].x
		var tr: int = t["r"]
		# between the computer's footprint and the gate: the same flat floor, nothing in the way
		var from_c: int = (t["c"] + 2) if lc > t["c"] else (lc + 1)
		var to_c: int = (lc - 1) if lc > t["c"] else (t["c"] - 1)
		if to_c - from_c + 1 > 3:
			close_ok = false
			detail += " laser %s is %d tiles from its computer;" % [t["laser"], to_c - from_c + 1]
		for c in range(from_c, to_c + 1):
			if "#XO=H".contains(rows[tr][c]) or not "#=".contains(rows[tr + 1][c]):
				close_ok = false
				detail += " laser %s: something between at column %d;" % [t["laser"], c]
	_check("each computer is within three tiles of its gate on the same flat floor, nothing between", close_ok, detail)
	# Room around each computer: nothing in its 2x3 footprint, and a clear tile on both sides (the gate is a tile away)
	var crowded := []
	for t in terminals:
		for dr in range(0, 3):
			for dc in range(-1, 3):
				var ch := rows[t["r"] - dr][t["c"] + dc]
				var is_letter: bool = dc == 0 and dr == 0
				if ch != "." and not is_letter:
					crowded.append("%s at (%d,%d) next to the computer at (%d,%d)" % [ch, t["c"] + dc, t["r"] - dr, t["c"], t["r"]])
	_check("nothing overlaps or crowds a lock terminal", crowded.is_empty(), str(crowded))
	var on_letters := true
	for t in terminals:
		if rows[t["r"]][t["c"]] != "L":
			on_letters = false
	_check("every computer sits on a lock-terminal letter", on_letters)

	# 2. Solve the whole level
	var t0 := Time.get_ticks_msec()
	var solver := _solve(rows)
	var route := solver.route()
	_check("the exit is reachable from the start", not route.is_empty(), "%d nodes in %d ms" % [solver.nodes.size(), Time.get_ticks_msec() - t0])
	var stuck := solver.stuck_nodes()
	_check("no reachable spot is a dead end", stuck.is_empty(), "%d stuck, first %s" % [stuck.size(), stuck.slice(0, 3)])
	var coreach := solver.coreachable()
	var bad_checkpoints := []
	for r in rows.size():
		for c in map_cols:
			if rows[r][c] == "K" and not coreach.has(solver.key_for((c + 0.5) * 70.0, (r + 1) * 70.0)):
				bad_checkpoints.append(Vector2i(c, r))
	_check("every checkpoint can still finish", bad_checkpoints.is_empty(), str(bad_checkpoints))

	# 3. Lasers: every gate on = no finish; computer k reachable while gate k and the later ones are on
	var ids: Array = laser_cells.keys()
	ids.sort()
	var all_on := _solve(_lasers_as_walls(rows, ids))
	_check("with every laser gate on the exit cannot be reached", all_on.route().is_empty())
	for k in ids.size():
		var on_ids: Array = ids.slice(k)
		var world := _solve(_lasers_as_walls(rows, on_ids))
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
		_check("gates %s to 9 on: the computer for gate %s can be reached" % [ids[k], ids[k]], reached)

	# 4. Difficulty
	var no_stones := _solve(_remove_stones(rows))
	_check("the wide pits cannot be jumped without their stepping stones", no_stones.route().is_empty())
	var no_ladders := _solve(_remove_chars(rows, "H"))
	_check("the towers cannot be skipped without their ladders", no_ladders.route().is_empty())

	# 4. Calibration against the real Player
	OS.set_environment("SABOTAGE_LEVEL", "test")
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	var model := LevelSolver.new(LevelData.test_level())
	for pat in cal_patterns:
		var hold: int = pat[0]
		var res := model._simulate(CAL_X, CAL_Y, 0.0, true, [1, hold, 0])
		cal_results.append(res[0].x if not res.is_empty() else -1.0)


func _process(_d: float) -> bool:
	frames += 1
	if frames == 3:
		for n in main.get_children():
			if n is Player:
				player = n
		_start_cal()
		return false
	if player == null or frames < 8:
		return false
	t += 1
	# Press right all the way, release after the pattern's hold, jump on the first frame.
	var hold: int = cal_patterns[cal_index][0]
	if t == 1:
		Input.action_press("jump")
	elif t == 2:
		Input.action_release("jump")
	if t <= hold:
		Input.action_press("move_right")
	else:
		Input.action_release("move_right")
	if t > 3 and player.is_on_floor():
		var got := player.global_position.x - 0.0
		var want := cal_results[cal_index]
		_check("solver jump %d lands where the engine does" % cal_index,
			absf(got - want) <= LAND_TOLERANCE, "engine x=%.0f solver x=%.0f" % [got, want])
		cal_index += 1
		Input.action_release("move_right")
		if cal_index >= cal_patterns.size():
			print("ALL PASS" if ok else "SOME FAILED")
			quit(0 if ok else 1)
			return true
		_start_cal()
	if t > 300:
		_check("calibration jump finished", false)
		quit(1)
		return true
	return false


func _start_cal() -> void:
	t = 0
	player.global_position = Vector2(CAL_X, CAL_Y)
	player.velocity = Vector2.ZERO
	Input.action_release("move_right")
