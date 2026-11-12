class_name InputSetup
extends RefCounted
## Registers the game's input actions in code (keyboard). The touch controls drive the same
## actions, so gameplay code only ever asks about actions.
##
## Keyboard (the arrow keys move; the left hand has the actions, mirroring the phone's four buttons):
##   move_left / move_right  Left, Right
##   move_up                 Up       climbs ladders; jumps when there is no ladder in reach
##   move_down               Down     climbs down
##   jump                    Space, W jumps (never grabs a ladder)
##   interact                E        use a computer, etc.
##   attack_light            Q        throw an object
##   attack_heavy            S
## A and D are free for future actions.


static func register() -> void:
	_add_action("move_left", [KEY_LEFT])
	_add_action("move_right", [KEY_RIGHT])
	_add_action("move_up", [KEY_UP])
	_add_action("move_down", [KEY_DOWN])
	_add_action("jump", [KEY_SPACE, KEY_W])
	_add_action("interact", [KEY_E])
	_add_action("attack_light", [KEY_Q])
	_add_action("attack_heavy", [KEY_S])


static func _add_action(action: StringName, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)
