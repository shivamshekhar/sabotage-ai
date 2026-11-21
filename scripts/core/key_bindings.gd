class_name KeyBindings
extends RefCounted
## Which keys trigger which action (the keyboard; the touch controls drive the same actions). Every action has SLOTS keys it answers to (the second may be empty): the
## defaults are in DEFAULT_KEYS, and the keys the player has set (Settings.key_overrides, kept in the settings file) replace them. apply() puts the result in Godot's input
## map, so gameplay code still only asks about actions.
##
##   KeyBindings.set_key(InputActions.JUMP, 1, KEY_X)      # returns the action that already uses X, or "" when it is set

# SLOTS: how many keys one action can have.
const SLOTS := 2

# DEFAULT_KEYS: the keys of every action before the player changes anything (physical keys: they are in the same place on every keyboard layout).
# The arrow keys move; the left hand has the actions, mirroring the phone's four buttons; W also jumps.
const DEFAULT_KEYS := {
	InputActions.MOVE_LEFT: [KEY_LEFT],
	InputActions.MOVE_RIGHT: [KEY_RIGHT],
	InputActions.MOVE_UP: [KEY_UP],
	InputActions.MOVE_DOWN: [KEY_DOWN],
	InputActions.JUMP: [KEY_SPACE, KEY_W],
	InputActions.INTERACT: [KEY_E],
	InputActions.ATTACK_LIGHT: [KEY_Q],
	InputActions.ATTACK_HEAVY: [KEY_S],
}

# LABELS: what each action is called in the settings.
const LABELS := {
	InputActions.MOVE_LEFT: "MOVE LEFT",
	InputActions.MOVE_RIGHT: "MOVE RIGHT",
	InputActions.MOVE_UP: "UP / CLIMB",
	InputActions.MOVE_DOWN: "DOWN",
	InputActions.JUMP: "JUMP",
	InputActions.INTERACT: "USE",
	InputActions.ATTACK_LIGHT: "LIGHT ATTACK",
	InputActions.ATTACK_HEAVY: "HEAVY ATTACK",
}

# RESERVED: keys no action can use: Escape (it leaves a dialog) and Enter (it starts the game).
const RESERVED := [KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER]

# NONE: the value of an empty slot.
const NONE := 0


## The keys of an action now, one per slot (NONE for an empty one).
static func keys(action: StringName) -> Array[int]:
	Settings.ensure_loaded()
	var source: Array = Settings.key_overrides.get(String(action), DEFAULT_KEYS.get(action, []))
	var out: Array[int] = []
	for slot in SLOTS:
		out.append(int(source[slot]) if slot < source.size() else NONE)
	return out


## Put every action's keys in Godot's input map (replacing what was there).
static func apply() -> void:
	for action in InputActions.ALL:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_erase_events(action)
		for key in keys(action):
			if key != NONE:
				var event := InputEventKey.new()
				event.physical_keycode = key as Key
				InputMap.action_add_event(action, event)


## The action (other than `action`) that already uses `key`, or "" if none does.
static func conflict(action: StringName, key: int) -> StringName:
	for other in InputActions.ALL:
		if other != action and keys(other).has(key):
			return other
	return &""


## Give `action` the key `key` in slot `slot`. Returns "" when it is set; otherwise the reason it was refused: the action that has the key already, or RESERVED.
static func set_key(action: StringName, slot: int, key: int) -> String:
	if RESERVED.has(key):
		return "RESERVED"
	var other := conflict(action, key)
	if other != &"":
		return String(LABELS.get(other, other))
	var current := keys(action)
	if current[1 - slot] == key:       # the action has it in its other slot already: nothing to do
		return ""
	current[slot] = key
	_store(action, current)
	return ""


## Empty slot `slot` of `action`. Refused (false) if it is the action's only key: an action must keep one.
static func clear(action: StringName, slot: int) -> bool:
	var current := keys(action)
	var left := current.filter(func(k: int) -> bool: return k != NONE).size()
	if current[slot] == NONE or left <= 1:
		return false
	current[slot] = NONE
	_store(action, current)
	return true


## Every action back to its default keys.
static func reset() -> void:
	Settings.key_overrides = {}
	Settings.save()
	apply()


## What a key is called on the player's keyboard ("Space", "E", "Left").
static func label(key: int) -> String:
	if key == NONE:
		return "-"
	var text := ""
	if DisplayServer.get_name() != "headless":
		text = OS.get_keycode_string(DisplayServer.keyboard_get_label_from_physical(key as Key))
	if text == "":
		text = OS.get_keycode_string(key as Key)
	return text.to_upper()


static func _store(action: StringName, current: Array[int]) -> void:
	Settings.key_overrides[String(action)] = current
	Settings.save()
	apply()
