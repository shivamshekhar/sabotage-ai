extends SceneTree
## Level 1 checks. Exits non-zero on failure.
##  1. Structure: one spawn, one exit, rows the same width, checkpoints on solid ground.
##  2. LevelSolver proves the exit is reachable and that no spot reachable on the way is a dead end.
##  3. Difficulty: with the stepping stones or the first ladder removed, the exit is NOT reachable,
##     so the wide pits cannot simply be jumped and the tower cannot be skipped.
##  4. Calibration: the solver's jump model lands within a few pixels of the real Player's jump,
##     so (2) and (3) say something about the real game.
## Run: godot_console --headless --fixed-fps 60 --path . --script res://tools/tests/level1_test.gd
## (it takes a minute or two: the solver simulates tens of thousands of jumps)

# LAND_TOLERANCE: how far in pixels the solver's landing may differ from the engine's in the
# calibration jump. Larger accepts a rougher model of the player's physics.
const LAND_TOLERANCE := 20.0

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


func _map_without(rows: Array[String], c0: int, r0: int, c1: int, r1: int) -> Array[String]:
	var out: Array[String] = []
	for r in rows.size():
		var line := rows[r]
		if r >= r0 and r <= r1:
			var chars := line.split("")
			for c in range(c0, c1 + 1):
				chars[c] = "."
			line = "".join(chars)
		out.append(line)
	return out


func _initialize() -> void:
	var rows := LevelData.level_1()

	# 1. Structure
	var spawns := 0
	var exits := 0
	for r in rows:
		if r.length() != rows[0].length():
			_check("rows all the same width", false, r)
		spawns += r.count("P")
		exits += r.count("E")
	_check("exactly one spawn", spawns == 1, str(spawns))
	_check("exactly one exit", exits == 1, str(exits))
	var map_cols := rows[0].length()
	for r in rows.size():
		for c in map_cols:
			if rows[r][c] == "K":
				var below := rows[r + 1][c]
				_check("checkpoint (%d,%d) stands on solid ground" % [c, r], below == "#" or below == "X" or below == "O" or below == "=")

	# 2. Solve
	var solver := LevelSolver.new(rows)
	solver.solve()
	var route := solver.route()
	_check("the exit is reachable from the start", not route.is_empty(), "%d nodes" % solver.nodes.size())
	var stuck := solver.stuck_nodes()
	_check("no reachable spot is a dead end", stuck.is_empty(), "%d stuck, first %s" % [stuck.size(), stuck.slice(0, 3)])
	# Every checkpoint must itself be solvable (respawning there never strands the player).
	var coreach := solver.coreachable()
	for r in rows.size():
		for c in map_cols:
			if rows[r][c] == "K":
				var k := solver.key_for((c + 0.5) * 70.0, (r + 1) * 70.0)
				_check("checkpoint (%d,%d) can still finish" % [c, r], coreach.has(k))

	# 3. Difficulty
	var no_stones := LevelSolver.new(_map_without(rows, 35, LevelData.L1_GROUND, 42, LevelData.L1_GROUND))
	no_stones.solve()
	_check("the wide pit cannot be jumped without its stepping stones", no_stones.route().is_empty())
	var no_ladder := LevelSolver.new(_map_without(rows, 82, 20, 82, 25))
	no_ladder.solve()
	_check("the tower cannot be skipped without the ladder", no_ladder.route().is_empty())

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
