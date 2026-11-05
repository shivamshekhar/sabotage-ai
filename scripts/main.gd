extends Node2D
## Boots the prototype: input actions, level, player, camera, touch controls.

const LevelScript := preload("res://scripts/level.gd")
const PlayerScript := preload("res://scripts/player.gd")
const TouchControlsScript := preload("res://scripts/touch_controls.gd")


func _ready() -> void:
	_setup_input()

	add_child(LevelScript.new())

	var player := PlayerScript.new()
	player.position = Vector2(140, LevelScript.FLOOR_Y)
	add_child(player)

	var cam := Camera2D.new()
	cam.position_smoothing_enabled = true
	cam.limit_left = 0
	cam.limit_right = LevelScript.WORLD_W
	cam.limit_top = -20
	cam.limit_bottom = 700
	player.add_child(cam)
	cam.make_current()

	add_child(TouchControlsScript.new())


func _setup_input() -> void:
	_add_action("move_left", [KEY_A, KEY_LEFT])
	_add_action("move_right", [KEY_D, KEY_RIGHT])
	_add_action("jump", [KEY_SPACE, KEY_W, KEY_UP])


func _add_action(action: StringName, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)
