extends SceneTree
## The exit door: the leaves slide apart as the player comes near (and close if they go away), the lamp turns green, the player walks into the doorway by themselves (their
## controls are ignored, nothing hurts them), fades into the dark, the door closes and only then is the level finished (goal_reached, once). Also with the mech on. Played in the
## test arena (its exit is a door on a raised platform). Exits non-zero on failure.
## Run: godot_console --headless --fixed-fps 60 --path . --script res://tools/tests/door_test.gd

# WAIT_CAP: the most frames to wait for a condition before giving up.
const WAIT_CAP := 900

# NEAR / FAR: how far (px) from the door's middle the player is put to be near it (inside the approach zone, outside the enter zone) and far from it.
const NEAR := 110.0
const FAR := 420.0

var ok := true
var level: Level
var player: Player
var door: ExitDoor
var goals := 0


func _check(name: String, cond: bool, detail := "") -> void:
	print(("PASS  " if cond else "FAIL  "), name, "  ", detail)
	if not cond:
		ok = false


func _initialize() -> void:
	_main()


func _wait(frames: int) -> void:
	for i in frames:
		await process_frame


func _wait_until(cond: Callable) -> void:
	var n := 0
	while not cond.call() and n < WAIT_CAP:
		await process_frame
		n += 1


## Put the player standing on the door's platform, `away` px to the left of its middle.
func _stand_at(away: float) -> void:
	player.global_position = Vector2(door.global_position.x - away, door.global_position.y - 1.0)
	player.velocity = Vector2.ZERO
	await _wait(10)


func _main() -> void:
	InputSetup.register()
	await _wait(2)
	TestArena.use()
	var main = load(AssetPaths.MAIN_SCENE).instantiate()
	root.add_child(main)
	await _wait(5)
	player = get_first_node_in_group(Groups.PLAYER)
	for n in main.get_children():
		if n is Level:
			level = n
	for n in level.get_children():
		if n is ExitDoor:
			door = n
	_check("the level has an exit door", door != null)
	level.goal_reached.connect(func() -> void: goals += 1)
	var standing_at: Vector2 = door.global_position
	_check("it stands on the floor of the exit's tile, in the middle of it", is_equal_approx(fposmod(standing_at.x, float(Level.T)), Level.T / 2.0) and is_equal_approx(fposmod(standing_at.y, float(Level.T)), 0.0), str(standing_at))

	# ---- it opens when the player comes near and closes when they go away
	await _stand_at(FAR)
	_check("far away the door is shut", not door.is_open())
	await _stand_at(NEAR)
	_check("near it the door opens", door.is_open())
	await _wait(int(ExitDoor.OPEN_TIME * 60.0) + 5)
	_check("its leaves slide apart", is_equal_approx(door._leaf_left.position.x, -ExitDoor.LEAF_TRAVEL) and is_equal_approx(door._leaf_right.position.x, ExitDoor.LEAF_TRAVEL))
	_check("and the lamp turns green", door._lamp.self_modulate.is_equal_approx(ExitDoor.LAMP_OPEN))
	_check("without finishing the level", goals == 0 and player.modulate.a == 1.0)
	await _stand_at(FAR)
	await _wait(int(ExitDoor.CLOSE_TIME * 60.0) + 5)
	_check("the door closes when they go away", not door.is_open() and is_equal_approx(door._leaf_left.position.x, 0.0) and door._lamp.self_modulate.is_equal_approx(ExitDoor.LAMP_SHUT))

	# ---- walking in on foot
	await _walk_in("on foot")
	main.queue_free()
	await _wait(3)

	# ---- and in the mech
	TestArena.use()
	main = load(AssetPaths.MAIN_SCENE).instantiate()
	root.add_child(main)
	await _wait(5)
	player = get_first_node_in_group(Groups.PLAYER)
	for n in main.get_children():
		if n is Level:
			level = n
	for n in level.get_children():
		if n is ExitDoor:
			door = n
	goals = 0
	level.goal_reached.connect(func() -> void: goals += 1)
	player.board_mech()
	await _wait(5)
	await _walk_in("in the mech")

	print("ALL PASS" if ok else "SOME FAILED")
	quit(0 if ok else 1)


## Walk right into the door holding the move button, with the other buttons pressed on the way (they must do nothing), and check what happens.
func _walk_in(who: String) -> void:
	await _stand_at(FAR)
	Input.action_press(InputActions.MOVE_RIGHT)
	await _wait_until(func() -> bool: return player.is_walking_to())
	_check("%s: the door takes the player in when they reach the doorway" % who, player.is_walking_to() and door.is_open(), str(player.global_position.x - door.global_position.x))
	Input.action_release(InputActions.MOVE_RIGHT)
	Input.action_press(InputActions.MOVE_LEFT)
	Input.action_press(InputActions.JUMP)
	await _wait_until(func() -> bool: return not player.is_walking_to())
	var gap := absf(player.global_position.x - door.global_position.x)
	var lifted := absf(player.global_position.y - door.global_position.y)      # (a jump or the booster would have lifted them: the controls do nothing)
	_check("%s: the controls are ignored, the player walks on to the middle of the door (or as far as a wall lets them)" % who, (gap <= Player.SCRIPTED_WALK_ARRIVE + 1.0 or player.is_on_wall()) and lifted <= 4.0, "gap %.1f lifted %.1f" % [gap, lifted])
	Input.action_release(InputActions.MOVE_LEFT)
	Input.action_release(InputActions.JUMP)
	_check("%s: the level is not finished yet, they are still to vanish" % who, goals == 0)
	await _wait_until(func() -> bool: return goals > 0)
	_check("%s: the level is finished once they have gone in and the door has closed" % who, goals == 1 and player.modulate.a <= 0.01 and not door.is_open(), "goals %d alpha %.2f" % [goals, player.modulate.a])
	await _wait(30)
	_check("%s: and only once" % who, goals == 1)
