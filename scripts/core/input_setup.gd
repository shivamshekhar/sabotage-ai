class_name InputSetup
extends RefCounted
## Registers the game's input actions in code (keyboard). The touch controls drive the same
## actions, so gameplay code only ever asks about actions.
##
## Keyboard:
##   move_left / move_right  A, D, Left, Right
##   move_up                 W, Up      climbs ladders; jumps when there is no ladder in reach
##   move_down               S, Down    climbs down
##   jump                    Space      jumps (never grabs a ladder)
##   interact                E
##   attack_light            J
##   attack_heavy            K


static func register() -> void:
	_add_action("move_left", [KEY_A, KEY_LEFT])
	_add_action("move_right", [KEY_D, KEY_RIGHT])
	_add_action("move_up", [KEY_W, KEY_UP])
	_add_action("move_down", [KEY_S, KEY_DOWN])
	_add_action("jump", [KEY_SPACE])
	_add_action("interact", [KEY_E])
	_add_action("attack_light", [KEY_J])
	_add_action("attack_heavy", [KEY_K])


static func _add_action(action: StringName, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)
