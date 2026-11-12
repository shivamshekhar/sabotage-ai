extends SceneTree
## Prints what the solver finds for a level. Usage:
##   SABOTAGE_LEVEL=test godot --headless --path . --script res://tools/solve_level.gd
## Not a pass/fail test; use it while designing a level. See level1_test.gd for the checks.


func _init() -> void:
	var id := OS.get_environment("SABOTAGE_LEVEL")
	if id == "":
		id = LevelData.DEFAULT_ID
	var map := LevelData.map(id)
	var floor_env := OS.get_environment("SABOTAGE_FLOOR")
	if floor_env != "":
		map = LevelData.l1_floor_map(int(floor_env))   # one floor of Level 1 on its own
		id = "1 floor " + floor_env
	if OS.get_environment("SABOTAGE_PRINT") != "":
		for row in map:
			print(row)
	var t0 := Time.get_ticks_msec()
	var solver := LevelSolver.new(map)
	solver.solve()
	var ms := Time.get_ticks_msec() - t0
	print("level %s: %d nodes, %d sims, %d ms" % [id, solver.nodes.size(), solver.sim_count, ms])
	var route := solver.route()
	print("exit reachable: ", not route.is_empty(), " (", route.size(), " steps)")
	var stuck := solver.stuck_nodes()
	print("stuck nodes: ", stuck.size())
	# Summarise stuck nodes per region (tile column/row).
	var seen := {}
	for p in stuck:
		var cell := Vector2i(int(p.x / 70), int(p.y / 70))
		seen[cell] = true
	var cells := seen.keys()
	cells.sort()
	print("stuck cells (col,row of feet): ", cells.slice(0, 60))
	# Furthest reachable column on each row.
	var best := {}
	for k in solver.nodes:
		var p: Vector2 = solver.nodes[k]
		var r := int(p.y / 70)
		var c := int(p.x / 70)
		if not best.has(r):
			best[r] = [c, c]
		else:
			best[r] = [mini(best[r][0], c), maxi(best[r][1], c)]
	var rs := best.keys()
	rs.sort()
	for r in rs:
		print("  feet row %d: columns %d..%d" % [r, best[r][0], best[r][1]])
	quit()
