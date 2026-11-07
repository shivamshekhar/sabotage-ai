extends SceneTree
## Headless test (phone mode): the player is never hidden behind the on-screen controls. At the
## spawn, in the middle, near the exit and at both ends of the level it checks that the player's
## body doesn't overlap the D-pad or any of the four buttons. Exits non-zero on failure.
## Run: godot_console --headless --fixed-fps 60 --path . --script res://tools/tests/hud_clearance_test.gd

# BODY_HALF_W: half the width of the player's hitbox. Must match Player.BODY_SIZE.x / 2.
const BODY_HALF_W := 30.0

# BODY_H: the height of the player's hitbox. Must match Player.BODY_SIZE.y.
const BODY_H := 128.0

var main: Node
var player: Player
var touch: TouchControls
var cam: Camera2D
var frames := 0
var ok := true


func _initialize() -> void:
	OS.set_environment("SABOTAGE_TOUCH", "1")   # phone mode: main creates the controls + side padding
	OS.set_environment("SABOTAGE_LEVEL", "test")
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _check(name: String, cond: bool, detail := "") -> void:
	print(("PASS  " if cond else "FAIL  "), name, "  ", detail)
	if not cond:
		ok = false


func _wait(n: int) -> void:
	for i in n:
		await process_frame


## Shortest distance from a circle to the player's body rectangle (0 = touching or overlapping).
func _gap(circle_center: Vector2, radius: float, body: Rect2) -> float:
	var nearest := Vector2(
		clampf(circle_center.x, body.position.x, body.end.x),
		clampf(circle_center.y, body.position.y, body.end.y))
	return maxf(0.0, circle_center.distance_to(nearest) - radius)


func _process(_d: float) -> bool:
	# _process must not contain `await` (a coroutine's return value makes Godot quit).
	frames += 1
	if frames == 5:
		_main()
	if frames > 3000:
		print("FAIL  test timed out before finishing")
		quit(1)
	return false


func _main() -> void:
	for n in main.get_children():
		if n is Player:
			player = n
		elif n is TouchControls:
			touch = n
	cam = root.get_camera_2d()
	# Standing on the exit ledge would fire the level-complete banner and a scene reload, which a test
	# (with no real current scene) can't do. Detach main's handler; this test only measures positions.
	for n in main.get_children():
		if n is Level:
			for c in n.goal_reached.get_connections():
				n.goal_reached.disconnect(c["callable"])
	_check("phone mode created the controls", touch != null)
	_check("camera may scroll past both level ends", cam.limit_left < 0 and cam.limit_right > 4200,
		"limits %d .. %d" % [cam.limit_left, cam.limit_right])
	await _wait(120)

	var spots := [
		["at the spawn (left end)", player.spawn],
		["early in the level", Vector2(700, 840)],
		["middle of the level", Vector2(2100, 840)],
		["on the upper corridor", Vector2(2900, 420)],
		["on the exit ledge", Vector2(3955, 560)],
		["on the floor at the far right end", Vector2(4120, 840)],
	]
	var view := root.get_visible_rect().size
	for s in spots:
		player.global_position = s[1]
		player.velocity = Vector2.ZERO
		player.health = Player.MAX_HEALTH
		await _wait(150)   # let the smoothed camera settle
		var view_left: float = cam.get_screen_center_position().x - view.x / 2.0
		var view_top: float = cam.get_screen_center_position().y - view.y / 2.0
		var feet: Vector2 = player.global_position - Vector2(view_left, view_top)
		var body := Rect2(feet.x - BODY_HALF_W, feet.y - BODY_H, BODY_HALF_W * 2.0, BODY_H)
		var worst := INF
		var worst_name := ""
		var pad_gap := _gap(touch.dpad_center(), TouchControls.DPAD_RADIUS, body)
		worst = pad_gap
		worst_name = "D-pad"
		for i in 4:
			var g := _gap(touch.face_center(i), TouchControls.FACE_RADIUS, body)
			if g < worst:
				worst = g
				worst_name = "button %d" % i
		_check("player clear of the controls %s" % s[0], worst > 0.0,
			"screen x=%d, nearest control: %s, gap=%dpx" % [int(feet.x), worst_name, int(worst)])

	print("ALL PASS" if ok else "SOME FAILED")
	quit(0 if ok else 1)
