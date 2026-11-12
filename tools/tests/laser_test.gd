extends SceneTree
## Laser force fields, computers and the puzzle popup, played in Level 1. Exits non-zero on failure.
## Run: godot_console --headless --fixed-fps 60 --path . --script res://tools/tests/laser_test.gd

# The test plays the first floor's tunnel gate (laser 1) and its computer. Where they are is read from the map
# (see _find_gate_one()): NEAR_X is a spot in front of the computer, FEET_Y the floor's feet y, and
# LASER_LEFT_EDGE the x of the left face of the gate's wall (LaserField.BEAM_WIDTH wide, centred in its column).
var NEAR_X := 0.0
var FEET_Y := 0.0
var LASER_LEFT_EDGE := 0.0

var main: Node
var level: Level
var player: Player
var ok := true


func _check(name: String, cond: bool, detail := "") -> void:
	print(("PASS  " if cond else "FAIL  "), name, "  ", detail)
	if not cond:
		ok = false


func _find_gate_one() -> void:
	var rows := LevelData.level_1()
	for t in LevelData.terminals("1"):
		if t["laser"] == "1":
			NEAR_X = (t["c"] + 1.0) * 70.0
			FEET_Y = (t["r"] + 1) * 70.0
	for r in rows.size():
		for c in rows[r].length():
			if rows[r][c] == "1":
				LASER_LEFT_EDGE = c * 70 + 35 - LaserField.BEAM_WIDTH / 2.0


func _initialize() -> void:
	_find_gate_one()
	OS.set_environment("SABOTAGE_LEVEL", "1")
	HackPopup.force_game = "sequence"   # the level asks for a random puzzle; this test plays the memory one
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_main()


func _wait(frames: int) -> void:
	for i in frames:
		await process_frame


func _release_all() -> void:
	for a in ["move_left", "move_right", "move_up", "move_down", "jump", "interact"]:
		Input.action_release(a)


func _tp(x: float, y: float) -> void:
	player.global_position = Vector2(x, y)
	player.velocity = Vector2.ZERO


func _main() -> void:
	await _wait(5)
	for n in main.get_children():
		if n is Player:
			player = n
		elif n is Level:
			level = n
	var asked: Array = []
	level.hack_requested.connect(func(id: String, g: String) -> void: asked.append([id, g]))

	# The laser is a wall.
	_check("laser 1 starts on", level.laser_is_on("1"))
	_tp(NEAR_X, FEET_Y)
	await _wait(10)
	Input.action_press("move_right")
	await _wait(120)
	_release_all()
	var lock_screens: Array = level._lock_screens["1"]
	_check("the gate computer has exactly one live screen", lock_screens.size() == 1, str(lock_screens.size()))
	var lock_screen: MonitorScreen = lock_screens[0]
	_check("its screen shows locked while the laser is on", lock_screen.locked and lock_screen.lock_text() == MonitorScreen.LOCKED_TEXT)
	var lr := lock_screen.layout_rects()
	_check("the lock text fits the screen at a readable size",
		lock_screen.fitted_font_size(lock_screen.lock_text(), MonitorScreen.FONT_BODY, lr["label"].size.x, lr["label"].size.y) >= MonitorScreen.MIN_FONT_SIZE)
	_check("a laser that is on stops the player", player.global_position.x <= LASER_LEFT_EDGE - 30.0 + 1.0,
		"x=%.0f, wall face at %.0f" % [player.global_position.x, LASER_LEFT_EDGE])

	# Using the computer asks for its puzzle; using it from far away does nothing.
	_tp(NEAR_X - 900.0, FEET_Y)
	_check("far from a computer, use does nothing", not level.try_interact(player.global_position))
	_tp(NEAR_X, FEET_Y)
	await _wait(10)
	Input.action_press("interact")
	await _wait(3)
	_release_all()
	await _wait(3)
	_check("using the computer asks for its puzzle", asked == [["1", "random"]], str(asked))
	var popup: HackPopup = null
	for n in main.get_children():
		if n is HackPopup:
			popup = n
	_check("a popup opened and the game is paused", popup != null and paused)

	# Solve the memory puzzle.
	var game := popup.game as SequenceGame
	var waited := 0
	while not game.accepting() and waited < 600:
		await _wait(1)
		waited += 1
	_check("the sequence is shown, then accepts input", game.accepting())
	var wrong := (game.sequence()[0] + 1) % 4
	game.press(wrong)
	await _wait(5)
	_check("a wrong pad restarts the puzzle", not game.accepting())
	waited = 0
	while not game.accepting() and waited < 600:
		await _wait(1)
		waited += 1
	for i in game.sequence().duplicate():
		game.press(i)
	waited = 0
	while is_instance_valid(popup) and waited < 300:
		await _wait(1)
		waited += 1
	_check("solving the puzzle closes the popup and unpauses", not is_instance_valid(popup) or popup.is_queued_for_deletion())
	await _wait(5)
	_check("the game is running again", not paused)
	_check("the laser is off", not level.laser_is_on("1"))
	_check("and its computer's screen now shows access granted", not lock_screen.locked and lock_screen.lock_text() == MonitorScreen.UNLOCKED_TEXT)
	await _wait(40)

	# Now the player can walk through.
	_tp(NEAR_X + 90.0, FEET_Y)   # just short of the wall; the deep pit starts a little beyond it
	await _wait(10)
	Input.action_press("move_right")
	await _wait(30)
	_release_all()
	_check("with the laser off the player walks through", player.global_position.x > LASER_LEFT_EDGE + 20.0,
		"x=%.0f" % player.global_position.x)
	_check("a computer whose laser is off does nothing", not level.try_interact(Vector2(NEAR_X, FEET_Y)))

	# The timing puzzle on its own.
	var timing := TimingGame.new()
	root.add_child(timing)
	var done := [false]
	timing.solved.connect(func() -> void: done[0] = true)
	await _wait(2)
	timing.press()   # a miss: the marker is still at the far left, the zone never is
	await _wait(70)  # a miss restarts the puzzle after a short pause
	for i in TimingGame.HITS_NEEDED:
		timing.aim()
		timing.press()
	_check("aiming at the green zone three times solves the timing puzzle", done[0])

	print("ALL PASS" if ok else "SOME FAILED")
	quit(0 if ok else 1)
