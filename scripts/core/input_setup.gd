class_name InputSetup
extends RefCounted
## Registers the game's input actions in code (keyboard). The touch controls drive the same
## actions, so gameplay code only ever asks about actions. The keys themselves are KeyBindings'
## (the defaults, or what the player set in the settings), and the settings are loaded here too.
##
## Default keys (the arrow keys move; the left hand has the actions, mirroring the phone's four buttons):
##   move_left / move_right  Left, Right
##   move_up                 Up       climbs ladders; jumps when there is no ladder in reach
##   move_down               Down     climbs down
##   jump                    Space, W jumps (never grabs a ladder)
##   interact                E        use a computer, etc.
##   attack_light            Q        throw an object (the laser in the mech)
##   attack_heavy            S        (the missile in the mech)
## A and D are free for future actions.


static func register() -> void:
	for action in InputActions.ALL:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	Settings.apply()
