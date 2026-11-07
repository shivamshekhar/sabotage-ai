extends SceneTree
## Headless playtest: a simple bot plays level 1 with simulated key presses and reports WIN or TIMEOUT.
## Level-1 specific (it knows where the pit, ladder and exit stairs are); update it if the map changes.
## Run: godot_console --headless --fixed-fps 60 --path . --script res://tools/tests/level_bot.gd

# T: the level's tile size in pixels. It must match Level.T.
const T := 70
var main: Node
var player: Player
var level: Level
var frames := 0
var deaths := 0
var was_hurt := false
var won := false
var jump_down := false
var phase := 0
var takeoff := -1
var last_x := 0.0
var last_y := 0.0
var log_every := 120


func _initialize() -> void:
	OS.set_environment("SABOTAGE_LEVEL", "test")
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _find() -> void:
	for n in main.get_children():
		if n is Player:
			player = n
		elif n is Level:
			level = n
	level.goal_reached.connect(func() -> void:
		won = true
		print("WIN at frame ", frames, "  deaths=", deaths))


func _blocked(c: int, r: int) -> bool:
	var ch := level._cell(c, r)
	return ch == "#" or ch == "X" or ch == "O" or ch == "="


func _ground(c: int, r: int) -> bool:
	return _blocked(c, r)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 3:
		_find()
	if player == null or won:
		if won:
			quit(0)
		return false

	if jump_down:
		Input.action_release("move_up")
		jump_down = false

	var x := player.global_position.x
	var y := player.global_position.y
	var c := int(x / T)
	var r := int((y - 1.0) / T)  # row the body occupies

	var hurt: bool = player._hurt_timer > 0.0
	if hurt and not was_hurt:
		deaths += 1
		print("DEATH #", deaths, " last pos before death=(", int(last_x), ",", int(last_y), ") phase=", phase)
	was_hurt = hurt
	last_x = x
	last_y = y

	for a in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(a)

	if phase == 0 and x >= 1960.0 and y > 800.0:
		phase = 1
		print("reached ladder at frame ", frames)
	if phase == 1 and y <= 421.0:
		phase = 2
		print("top of ladder at frame ", frames, " x=", int(x))

	if phase == 2 and x > 3350.0 and y > 830.0 and player.is_on_floor():
		phase = 3
		print("landed on floor past slab at x=", int(x), " frame ", frames, "; walking back to stairs")
	if phase == 3 and x <= 3400.0:
		phase = 4
		print("at stair base, hopping right, frame ", frames)

	if phase == 4:
		# Staircase: jump near each ledge's left edge, release right mid-air at the target centre.
		var jump_xs := [3400.0, 3540.0, 3680.0, 3820.0]
		var targets := [3500.0, 3640.0, 3780.0, 3920.0]
		if player.is_on_floor():
			var st := int(round((840.0 - y) / 70.0))
			if st >= 4:
				Input.action_press("move_right")
			elif x >= jump_xs[st]:
				takeoff = st
				Input.action_press("move_right")
				Input.action_press("move_up")
				jump_down = true
			else:
				Input.action_press("move_right")
		elif takeoff >= 0 and x < targets[takeoff]:
			Input.action_press("move_right")
	elif phase == 3:
		Input.action_press("move_left")
	elif phase == 1:
		var lx := 28 * T + 35.0
		if x < lx - 6.0:
			Input.action_press("move_right")
		elif x > lx + 6.0:
			Input.action_press("move_left")
		Input.action_press("move_up")
	else:
		Input.action_press("move_right")
		var on_floor := player.is_on_floor()
		var jump := false
		if on_floor:
			if _blocked(c + 1, r):
				jump = true
			elif level._cell(c + 1, r + 1) == "^":
				jump = true  # a spike pit ahead (but don't "jump" off crates/slab edges)
			elif level._cell(c + 1, r) == "^":
				jump = true
		if jump:
			Input.action_press("move_up")
			jump_down = true

	if phase == 4 and frames % 6 == 0 and frames < 1120:
		print("  s f=", frames, " pos=(", int(x), ",", int(y), ") c=", c, " r=", r, " floor=", player.is_on_floor(), " vy=", int(player.velocity.y))
	if frames % log_every == 0:
		print("f=", frames, " pos=(", int(x), ",", int(y), ") phase=", phase)
	if frames > 4000:
		print("TIMEOUT pos=(", int(x), ",", int(y), ") deaths=", deaths, " phase=", phase)
		quit(1)
	return false

