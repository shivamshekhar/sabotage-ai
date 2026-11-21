class_name InputActions
extends RefCounted
## The names of the game's input actions (see KeyBindings for the keys that trigger them and TouchControls for the phone buttons). Gameplay code
## only ever asks about actions, never about keys: use these names instead of writing the action as a string.

const MOVE_LEFT := &"move_left"
const MOVE_RIGHT := &"move_right"
const MOVE_UP := &"move_up"            # climbs ladders; jumps when there is no ladder in reach
const MOVE_DOWN := &"move_down"
const JUMP := &"jump"
const INTERACT := &"interact"          # use a computer
const ATTACK_LIGHT := &"attack_light"  # throw an object (the laser in the mech)
const ATTACK_HEAVY := &"attack_heavy"  # (the missile in the mech)

# ALL: every action, in the order the game registers them.
const ALL: Array[StringName] = [MOVE_LEFT, MOVE_RIGHT, MOVE_UP, MOVE_DOWN, JUMP, INTERACT, ATTACK_LIGHT, ATTACK_HEAVY]
