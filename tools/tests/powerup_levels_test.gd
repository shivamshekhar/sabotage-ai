extends SceneTree
## The power-up boxes and the laser gates of every level, with the real physics: a player jumping from the spot the level solver found really comes
## down on the box (and opens it), jumping from the floor far below does not reach it, and a mech flying at a laser gate is stopped by it.
## (That a box exists and is reachable, and that a gate is sealed, is also checked without physics by level_traversal_test.gd.) Exits non-zero on failure.
## Run: godot_console --headless --fixed-fps 60 --path . --script res://tools/tests/powerup_levels_test.gd

# SPOTS_TO_TRY / START_OFFSETS / DELAYS: the jumps tried: from the nearest few spots the solver found, starting a few pixels before the spot, running
# for a few frames before jumping. One success is enough.
const SPOTS_TO_TRY := 3
const START_OFFSETS := [0.0, 30.0, 60.0]
const DELAYS := [0, 4, 8, 12]

# FLIGHT_BURSTS: how many times the mech holds the booster while flying at a gate.
const FLIGHT_BURSTS := 6

var ok := true


func _check(name: String, cond: bool, detail := "") -> void:
	print(("PASS  " if cond else "FAIL  "), name, "  ", detail)
	if not cond:
		ok = false


func _initialize() -> void:
	_main()


func _wait(frames: int) -> void:
	for i in frames:
		await process_frame


func _load(id: String) -> Node:
	LevelData.selected_id = id
	var main = load(AssetPaths.MAIN_SCENE).instantiate()
	root.add_child(main)
	await _wait(3)
	LevelData.selected_id = ""
	return main


func _main() -> void:
	InputSetup.register()
	await _wait(2)
	var ids := LevelData.level_ids()

	for id in ids:
		var box_cell: Vector2i = LevelChecks.boxes(id)[0]
		var spots := LevelChecks.box_jump_spots(id, box_cell)
		var reached := false
		var tries := 0
		for spot in spots.slice(0, SPOTS_TO_TRY):
			for start in START_OFFSETS:
				for delay in DELAYS:
					if reached:
						break
					tries += 1
					reached = await _try_jump(id, box_cell, spot, start, delay)
		_check("%s: a player jumping from a spot the solver found comes down on the power-up box (%d tries)" % [id, tries], reached)

	for id in ids:
		# from the floor far below the box, a jump does not reach it
		var box_cell: Vector2i = LevelChecks.boxes(id)[0]
		var main = await _load(id)
		var player: Player = get_first_node_in_group(Groups.PLAYER)
		var box: PowerUpBox = get_first_node_in_group(Groups.POWERUP_BOXES)
		var rows := LevelData.map(id)
		var floor_row := box_cell.y + 1
		while floor_row < rows.size() and not Level.SOLID.contains(rows[floor_row][box_cell.x]):
			floor_row += 1
		player.global_position = Vector2((box_cell.x + 0.5) * Level.T, floor_row * Level.T)
		player.velocity = Vector2.ZERO
		await _wait(20)
		Input.action_press(InputActions.JUMP)
		await _wait(30)
		Input.action_release(InputActions.JUMP)
		await _wait(60)
		_check("%s: a jump from the floor far below does not reach the power-up box" % id, is_instance_valid(box) and not box._breaking and player.mech == null)
		main.queue_free()
		await _wait(3)

	for id in ids:
		var rows := LevelData.map(id)
		var seen := {}
		for r in rows.size():
			for c in rows[r].length():
				if rows[r][c] >= "1" and rows[r][c] <= "9" and not seen.has(c):
					seen[c] = r
		for c in seen:
			var bottom: int = seen[c]
			while bottom + 1 < rows.size() and rows[bottom + 1][c] >= "1" and rows[bottom + 1][c] <= "9":
				bottom += 1
			var main = await _load(id)
			var player: Player = get_first_node_in_group(Groups.PLAYER)
			player.board_mech()
			player._invuln_timer = 99.0
			var start_col: int = c - 9      # a few tiles before the gate, on the floor of the gate's own corridor
			player.global_position = Vector2((start_col + 0.5) * Level.T, (bottom + 1) * Level.T)
			player.velocity = Vector2.ZERO
			await _wait(60)
			Input.action_press(InputActions.MOVE_RIGHT)
			for k in FLIGHT_BURSTS:
				Input.action_press(InputActions.JUMP)
				await _wait(80)
				Input.action_release(InputActions.JUMP)
				await _wait(70)
			Input.action_release(InputActions.MOVE_RIGHT)
			_check("%s: a mech flying at the gate in column %d is stopped by it" % [id, c], player.global_position.x < (c + 0.5) * Level.T, "x %.0f, gate x %.0f" % [player.global_position.x, (c + 0.5) * Level.T])
			main.queue_free()
			await _wait(3)

	print("ALL PASS" if ok else "SOME FAILED")
	quit(0 if ok else 1)


## One jump: a fresh level, the player at `spot` (a bit before it by `start` px, on the side away from the box), running at the box and jumping after
## `delay` frames. True if the box opened.
func _try_jump(id: String, box_cell: Vector2i, spot: Vector2, start: float, delay: int) -> bool:
	var main = await _load(id)
	var player: Player = get_first_node_in_group(Groups.PLAYER)
	var box: PowerUpBox = get_first_node_in_group(Groups.POWERUP_BOXES)
	var opened := [false]
	box.opened.connect(func(_kind: String) -> void: opened[0] = true)
	var towards := 1.0 if (box_cell.x + 0.5) * Level.T > spot.x else -1.0
	player.global_position = Vector2(spot.x - towards * start, spot.y)
	player.velocity = Vector2.ZERO
	await _wait(15)
	var action := InputActions.MOVE_RIGHT if towards > 0.0 else InputActions.MOVE_LEFT
	Input.action_press(action)
	await _wait(delay)
	Input.action_press(InputActions.JUMP)
	await _wait(8)
	Input.action_release(InputActions.JUMP)
	await _wait(55)
	Input.action_release(action)
	main.queue_free()
	await _wait(3)
	return opened[0]
