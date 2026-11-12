extends SceneTree
## Things that keep sprites from wobbling: physics interpolation is on, the camera follows in the physics step,
## and a player standing still stays perfectly still (no flicker between "on the floor" and "in the air").
## Exits non-zero on failure.
## Run: godot_console --headless --fixed-fps 60 --path . --script res://tools/tests/smooth_test.gd

# STILL_FRAMES: how long the standing-still check runs. Gravity only shows up as a flicker over a few frames.
const STILL_FRAMES := 240

# MAX_DRIFT: the most in pixels the standing player's height may change after settling. A real wobble is a
# fraction of a pixel per frame, so this must be tiny.
const MAX_DRIFT := 0.01

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


func _main() -> void:
	InputSetup.register()
	_check("physics interpolation is on", ProjectSettings.get_setting("physics/common/physics_interpolation", false) == true)
	_check("2D transforms snap to whole pixels", ProjectSettings.get_setting("rendering/2d/snap/snap_2d_transforms_to_pixel", false) == true)

	OS.set_environment("SABOTAGE_LEVEL", "test")
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _wait(5)
	var cam: Camera2D = null
	var player: Player = null
	for n in main.get_children():
		if n is Player:
			player = n
	for n in player.get_children():
		if n is Camera2D:
			cam = n
	_check("the camera follows in the physics step, like the player", cam != null and cam.process_callback == Camera2D.CAMERA2D_PROCESS_PHYSICS)

	# Standing still: height and floor contact must not change from frame to frame.
	await _wait(60)
	var y0 := player.global_position.y
	var drift := 0.0
	var air_frames := 0
	for i in STILL_FRAMES:
		await _wait(1)
		drift = maxf(drift, absf(player.global_position.y - y0))
		if not player.is_on_floor():
			air_frames += 1
	_check("a player standing still does not move vertically", drift <= MAX_DRIFT, "drift %.4f px" % drift)
	_check("and never flickers into 'in the air'", air_frames == 0, "%d frames" % air_frames)

	# A respawn is a teleport: it must not be smeared across the level by interpolation.
	player.die("health")
	await _wait(2)
	_check("after a respawn the player is at the spawn point", player.global_position.distance_to(player.spawn) < 1.0)

	print("ALL PASS" if ok else "SOME FAILED")
	quit(0 if ok else 1)
