extends SceneTree
## Headless test of the phone controls: 8-way D-pad, four face buttons, multi-touch, sliding,
## forgiving touch areas, corner anchoring on wide screens, no stuck inputs, and that the
## overlay is hidden on PC. Exits non-zero on failure.
## Run: godot_console --headless --fixed-fps 60 --path . --script res://tools/tests/touch_test.gd

# JUMP: index of the jump button in TouchControls.FACE_BUTTONS. If you reorder that list,
# update the four button indices here.
const JUMP := 0

# INTERACT: index of the interact button in TouchControls.FACE_BUTTONS.
const INTERACT := 1

# LIGHT: index of the light-attack button in TouchControls.FACE_BUTTONS.
const LIGHT := 2

# HEAVY: index of the heavy-attack button in TouchControls.FACE_BUTTONS.
const HEAVY := 3

# FACE_ACTIONS: the input action each face button should press, in the same order.
const FACE_ACTIONS := ["jump", "interact", "attack_light", "attack_heavy"]

# ALL_ACTIONS: every action the touch controls can press. The test checks that only the
# expected ones are down after each simulated touch.
const ALL_ACTIONS := ["move_left", "move_right", "move_up", "move_down", "jump", "interact", "attack_light", "attack_heavy"]

var main: Node
var touch: TouchControls
var frames := 0
var ok := true


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _check(name: String, cond: bool, detail := "") -> void:
	print(("PASS  " if cond else "FAIL  "), name, "  ", detail)
	if not cond:
		ok = false


# Deliver events straight to the viewport (same path as a real touch), then let a frame pass.
# `true` = positions are already in game coordinates (headless's window is only 64x64).
func _touch(index: int, pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = pos
	e.pressed = pressed
	root.push_input(e, true)
	await process_frame


func _drag(index: int, pos: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = index
	e.position = pos
	root.push_input(e, true)
	await process_frame


func _pad(offset: Vector2) -> Vector2:
	return touch.dpad_center() + offset


func _pressed() -> Array:
	var on := []
	for a in ALL_ACTIONS:
		if Input.is_action_pressed(a):
			on.append(a)
	return on


func _only(actions: Array) -> bool:
	var on := _pressed()
	on.sort()
	var want := actions.duplicate()
	want.sort()
	return on == want


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
	# --- the overlay is a phone feature: main must not create it on PC
	var created_by_main := false
	for n in main.get_children():
		if n is TouchControls:
			created_by_main = true
	if OS.get_environment("SABOTAGE_TOUCH") == "" and not OS.has_feature("mobile"):
		_check("overlay is hidden on PC (main does not create it)", not created_by_main and not TouchControls.should_show())

	touch = TouchControls.new()
	root.add_child(touch)
	await process_frame
	await _run()
	print("ALL PASS" if ok else "SOME FAILED")
	quit(0 if ok else 1)


func _run() -> void:
	# ---------------- layout
	touch.layout(Vector2(1280, 720))
	var pad_left := touch.dpad_center().x - TouchControls.DPAD_RADIUS
	_check("D-pad sits at the left edge", pad_left >= 0.0 and pad_left < 100.0, "left=%d" % int(pad_left))
	_check("D-pad is at the bottom", touch.dpad_center().y + TouchControls.DPAD_RADIUS <= 720.0 and touch.dpad_center().y > 400.0)
	var right_most := 0.0
	var all_visible := true
	for i in 4:
		var c := touch.face_center(i)
		right_most = maxf(right_most, c.x + TouchControls.FACE_RADIUS)
		if c.x - TouchControls.FACE_RADIUS < 640.0 or c.y - TouchControls.FACE_RADIUS < 0.0 or c.y + TouchControls.FACE_RADIUS > 720.0:
			all_visible = false
	_check("the 4 buttons hug the right edge (16:9)", right_most > 1280 - 100 and right_most <= 1280, "right=%d" % int(right_most))
	_check("the 4 buttons are on the right half and on screen", all_visible)
	touch.layout(Vector2(1600, 720))
	right_most = 0.0
	for i in 4:
		right_most = maxf(right_most, touch.face_center(i).x + TouchControls.FACE_RADIUS)
	_check("buttons still hug the right edge on a wide screen", right_most > 1600 - 100 and right_most <= 1600, "right=%d of 1600" % int(right_most))
	_check("D-pad still at the left edge on a wide screen", touch.dpad_center().x - TouchControls.DPAD_RADIUS < 100.0)
	touch.layout(Vector2(1280, 720))
	var centers_distinct := true
	for i in 4:
		for j in range(i + 1, 4):
			if touch.face_center(i).distance_to(touch.face_center(j)) < TouchControls.FACE_RADIUS * 1.6:
				centers_distinct = false
	_check("face buttons don't overlap each other", centers_distinct)

	# ---------------- D-pad
	await _touch(0, _pad(Vector2(100, 0)), true)
	_check("D-pad right -> move_right only", _only(["move_right"]), str(_pressed()))
	await _drag(0, _pad(Vector2(70, -70)))
	_check("D-pad up-right -> right AND up (diagonal)", _only(["move_right", "move_up"]), str(_pressed()))
	await _drag(0, _pad(Vector2(-100, 0)))
	_check("slide to left -> left only", _only(["move_left"]), str(_pressed()))
	await _drag(0, _pad(Vector2(0, 100)))
	_check("slide to down -> down only", _only(["move_down"]), str(_pressed()))
	await _drag(0, _pad(Vector2(0, -100)))
	_check("slide to up -> up only", _only(["move_up"]), str(_pressed()))
	await _drag(0, _pad(Vector2(8, 4)))
	_check("thumb in the centre dead zone -> nothing", _only([]), str(_pressed()))
	await _drag(0, _pad(Vector2(300, 0)))
	_check("thumb dragged far past the pad still steers", _only(["move_right"]), str(_pressed()))
	await _touch(0, _pad(Vector2(300, 0)), false)
	_check("lifting the thumb releases the D-pad", _only([]), str(_pressed()))

	await _touch(0, _pad(Vector2(TouchControls.DPAD_RADIUS + 20.0, 0)), true)
	_check("a touch just outside the pad still grabs it", _only(["move_right"]), str(_pressed()))
	await _touch(0, _pad(Vector2(TouchControls.DPAD_RADIUS + 20.0, 0)), false)
	await _touch(0, _pad(Vector2(TouchControls.DPAD_RADIUS + 200.0, 0)), true)
	_check("a touch far from the pad does nothing", _only([]), str(_pressed()))
	await _touch(0, _pad(Vector2(TouchControls.DPAD_RADIUS + 200.0, 0)), false)

	# ---------------- face buttons
	for i in 4:
		await _touch(0, touch.face_center(i), true)
		_check("tap %s -> %s only" % [["JUMP", "USE", "LIGHT", "HEAVY"][i], FACE_ACTIONS[i]], _only([FACE_ACTIONS[i]]), str(_pressed()))
		await _touch(0, touch.face_center(i), false)
		_check("  ...and lifting releases it", _only([]), str(_pressed()))

	# ---------------- multi-touch
	await _touch(0, _pad(Vector2(100, 0)), true)                 # thumb 1 on the D-pad
	await _touch(1, touch.face_center(JUMP), true)               # thumb 2 on JUMP
	_check("D-pad right + JUMP together", _only(["move_right", "jump"]), str(_pressed()))
	await _touch(1, touch.face_center(JUMP), false)
	_check("lifting JUMP keeps the D-pad held", _only(["move_right"]), str(_pressed()))
	await _touch(1, touch.face_center(LIGHT), true)
	_check("D-pad right + LIGHT attack together", _only(["move_right", "attack_light"]), str(_pressed()))
	await _touch(1, touch.face_center(LIGHT), false)
	await _touch(0, _pad(Vector2(100, 0)), false)

	# a second finger landing on the pad while the first holds it must not steer twice
	await _touch(0, _pad(Vector2(100, 0)), true)
	await _touch(1, _pad(Vector2(-100, 0)), true)
	_check("a second finger on a taken D-pad is ignored", _only(["move_right"]), str(_pressed()))
	await _touch(1, _pad(Vector2(-100, 0)), false)
	await _touch(0, _pad(Vector2(100, 0)), false)
	_check("everything released afterwards", _only([]), str(_pressed()))

	# ---------------- sliding between face buttons
	await _touch(1, touch.face_center(JUMP), true)
	await _drag(1, touch.face_center(LIGHT))
	_check("sliding JUMP -> LIGHT switches buttons", _only(["attack_light"]), str(_pressed()))
	await _drag(1, Vector2(640, 100))
	_check("sliding onto empty space releases", _only([]), str(_pressed()))
	await _touch(1, Vector2(640, 100), false)

	# ---------------- forgiving edge and a clear miss
	var c := touch.face_center(HEAVY)
	await _touch(1, c + Vector2(TouchControls.FACE_RADIUS + 6.0, 0), true)
	_check("a touch just outside a button still counts", _only(["attack_heavy"]), str(_pressed()))
	await _touch(1, c + Vector2(TouchControls.FACE_RADIUS + 6.0, 0), false)
	await _touch(1, Vector2(640, 200), true)
	_check("a touch in empty space does nothing", _only([]), str(_pressed()))
	await _touch(1, Vector2(640, 200), false)

	# ---------------- two fingers on one button
	await _touch(0, touch.face_center(JUMP), true)
	await _touch(1, touch.face_center(JUMP), true)
	await _touch(0, touch.face_center(JUMP), false)
	_check("two fingers on one button: held until both lift", _only(["jump"]), str(_pressed()))
	await _touch(1, touch.face_center(JUMP), false)
	_check("released after both lift", _only([]), str(_pressed()))

	_check("no inputs left stuck", _only([]), str(_pressed()))
