extends SceneTree
## Headless test of the keyboard bindings and the jump / climb / action rules. Exits non-zero on failure.
## Run: godot_console --headless --fixed-fps 60 --path . --script res://tools/tests/controls_test.gd

# LX: the x position of the centre of the ladder in level 1 (see ladder_test.gd).
const LX := 1995.0

var main: Node
var player: Player
var frames := 0
var ok := true


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _check(name: String, cond: bool, detail := "") -> void:
	print(("PASS  " if cond else "FAIL  "), name, "  ", detail)
	if not cond:
		ok = false


func _wait(n: int) -> void:
	for i in n:
		await process_frame


func _tp(x: float, y: float) -> void:
	player.global_position = Vector2(x, y)
	player.velocity = Vector2.ZERO


func _has_key(action: String, keycode: Key) -> bool:
	for e in InputMap.action_get_events(action):
		if e is InputEventKey and e.physical_keycode == keycode:
			return true
	return false


func _release_all() -> void:
	for a in ["move_left", "move_right", "move_up", "move_down", "jump", "interact", "attack_light", "attack_heavy"]:
		Input.action_release(a)


func _process(_d: float) -> bool:
	# _process must not contain `await` (a coroutine's return value makes Godot quit).
	frames += 1
	if frames == 5:
		_main()
	if frames > 900:
		print("FAIL  test timed out before finishing")
		quit(1)
	return false


func _main() -> void:
	for n in main.get_children():
		if n is Player:
			player = n

	# ---- key bindings
	_check("Space is bound to jump", _has_key("jump", KEY_SPACE))
	_check("W and Up are bound to move_up", _has_key("move_up", KEY_W) and _has_key("move_up", KEY_UP))
	_check("E is bound to interact", _has_key("interact", KEY_E))
	_check("J is bound to light attack", _has_key("attack_light", KEY_J))
	_check("K is bound to heavy attack", _has_key("attack_heavy", KEY_K))
	_check("A/D/arrows still move", _has_key("move_left", KEY_A) and _has_key("move_right", KEY_D) and _has_key("move_left", KEY_LEFT) and _has_key("move_right", KEY_RIGHT))

	# ---- Space jumps
	_tp(300.0, 840.0)
	await _wait(8)
	var floor_y := player.global_position.y
	Input.action_press("jump")
	await _wait(8)
	_check("Space (jump) lifts the player off the floor", player.global_position.y < floor_y - 20.0,
		"y=%d from %d" % [int(player.global_position.y), int(floor_y)])
	_release_all()
	await _wait(80)

	# ---- Up still jumps too
	_tp(300.0, 840.0)
	await _wait(8)
	Input.action_press("move_up")
	await _wait(8)
	_check("Up still jumps (when no ladder is in reach)", player.global_position.y < floor_y - 20.0)
	_release_all()
	await _wait(80)

	# ---- jump never grabs a ladder, Up does
	_tp(LX + 15.0, 840.0)
	await _wait(8)
	Input.action_press("jump")
	await _wait(8)
	_check("Space at a ladder's bottom jumps (does not climb)", not player.climbing and player.global_position.y < 835.0,
		"climbing=%s y=%d" % [player.climbing, int(player.global_position.y)])
	_release_all()
	await _wait(80)
	_tp(LX + 15.0, 840.0)
	await _wait(8)
	Input.action_press("move_up")
	await _wait(8)
	_check("Up at a ladder's bottom climbs", player.climbing)
	_release_all()

	# ---- can't jump while on a ladder
	await _wait(5)
	var y_on_ladder := player.global_position.y
	Input.action_press("jump")
	await _wait(10)
	_check("jump is ignored while climbing", player.climbing and absf(player.global_position.y - y_on_ladder) < 2.0,
		"climbing=%s y=%d (was %d)" % [player.climbing, int(player.global_position.y), int(y_on_ladder)])
	_release_all()

	# ---- unimplemented actions are safe no-ops
	_check("interact() exists", player.has_method("interact"))
	_check("attack_light() exists", player.has_method("attack_light"))
	_check("attack_heavy() exists", player.has_method("attack_heavy"))
	var before := player.global_position
	player.interact()
	player.attack_light()
	player.attack_heavy()
	for a in ["interact", "attack_light", "attack_heavy"]:
		Input.action_press(a)
	await _wait(10)
	_release_all()
	_check("pressing interact / light / heavy does nothing yet (and doesn't crash)", player.global_position.distance_to(before) < 2.0 and player.health == Player.MAX_HEALTH)

	print("ALL PASS" if ok else "SOME FAILED")
	quit(0 if ok else 1)
