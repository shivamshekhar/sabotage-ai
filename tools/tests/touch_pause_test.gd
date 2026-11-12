extends SceneTree
## The phone's USE button must keep working after a popup has paused the game (a bug: a finger lifted
## while paused was never seen, so the button stayed "held" and every later press did nothing).
## Exits non-zero on failure.
## Run: godot_console --headless --fixed-fps 60 --path . --script res://tools/tests/touch_pause_test.gd

# INTERACT: index of the interact button in TouchControls.FACE_BUTTONS.
const INTERACT := 1

var ok := true
var touch: TouchControls


func _check(name: String, cond: bool, detail := "") -> void:
	print(("PASS  " if cond else "FAIL  "), name, "  ", detail)
	if not cond:
		ok = false


func _initialize() -> void:
	_main()


func _tap(pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = 0
	e.position = pos
	e.pressed = pressed
	root.push_input(e, true)
	await process_frame


func _main() -> void:
	OS.set_environment("SABOTAGE_TOUCH", "1")
	InputSetup.register()
	touch = TouchControls.new()
	root.add_child(touch)
	await process_frame
	var use_at := touch.face_center(INTERACT)

	await _tap(use_at, true)
	_check("USE presses the interact action", Input.is_action_pressed("interact"))
	# The puzzle popup opens now and pauses the game; the finger is lifted while it is paused.
	paused = true
	await process_frame
	await _tap(use_at, false)
	await process_frame
	_check("pausing lets the touch controls go", not Input.is_action_pressed("interact"))
	paused = false
	await process_frame
	await process_frame
	await _tap(use_at, true)
	_check("USE works again after the popup closes", Input.is_action_pressed("interact"))
	await _tap(use_at, false)
	_check("and releases normally", not Input.is_action_pressed("interact"))
	# ...and again, to be sure it isn't a one-off.
	paused = true
	await process_frame
	await _tap(use_at, true)
	_check("taps during a pause are ignored (they belong to the popup)", not Input.is_action_pressed("interact"))
	await _tap(use_at, false)
	paused = false
	await process_frame
	await process_frame
	await _tap(use_at, true)
	_check("USE works a third time", Input.is_action_pressed("interact"))
	await _tap(use_at, false)

	OS.set_environment("SABOTAGE_TOUCH", "")
	print("ALL PASS" if ok else "SOME FAILED")
	quit(0 if ok else 1)
