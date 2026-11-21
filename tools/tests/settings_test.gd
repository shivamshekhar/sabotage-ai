extends SceneTree
## The settings: the volumes (and the audio buses they reach), the key bindings (the defaults, changing a key, refusing a clash or a reserved key, keeping one key per action, the
## settings file), the block meter, and the settings window (the keys list on a PC, the touch buttons A to D on a phone). Works on a copy of the settings file, never the player's own.
## Exits non-zero on failure.
## Run: godot_console --headless --fixed-fps 60 --path . --script res://tools/tests/settings_test.gd

# TEST_FILE: the settings file the test uses.
const TEST_FILE := "user://settings_test.cfg"

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


func _key_event(key: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.pressed = true
	return event


## True if the action's keys now are exactly `expected` (one per slot).
func _keys_are(action: StringName, expected: Array) -> bool:
	var now := KeyBindings.keys(action)
	if now.size() != expected.size():
		return false
	for i in now.size():
		if now[i] != int(expected[i]):
			return false
	return true


func _has_key(action: StringName, key: Key) -> bool:
	for e in InputMap.action_get_events(action):
		if e is InputEventKey and (e as InputEventKey).physical_keycode == key:
			return true
	return false


func _main() -> void:
	Settings.file = TEST_FILE
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_FILE))
	Settings.forget()
	InputSetup.register()
	await _wait(2)

	# ---- the defaults
	_check("the volumes start at the default", is_equal_approx(Settings.music_volume, Settings.DEFAULT_VOLUME) and is_equal_approx(Settings.sfx_volume, Settings.DEFAULT_VOLUME))
	_check("every action has default keys", InputActions.ALL.all(func(a: StringName) -> bool: return KeyBindings.DEFAULT_KEYS.has(a) and KeyBindings.LABELS.has(a)))
	_check("jump is Space and W", _keys_are(InputActions.JUMP, [KEY_SPACE, KEY_W]))
	_check("the defaults are in the input map", _has_key(InputActions.ATTACK_LIGHT, KEY_Q) and _has_key(InputActions.ATTACK_HEAVY, KEY_S) and _has_key(InputActions.JUMP, KEY_W))

	# ---- the audio buses
	AudioBuses.ensure()
	var music := AudioServer.get_bus_index(AudioBuses.MUSIC)
	var sfx := AudioServer.get_bus_index(AudioBuses.SFX)
	_check("the music and sound-effect buses exist", music >= 0 and sfx >= 0)
	Settings.set_music_volume(0.5)
	_check("the music volume reaches its bus", is_equal_approx(AudioServer.get_bus_volume_db(music), AudioBuses.volume_to_db(0.5)) and not AudioServer.is_bus_mute(music))
	Settings.set_sfx_volume(0.0)
	_check("turned right down a bus is muted", AudioServer.is_bus_mute(sfx))
	Settings.set_sfx_volume(0.3)
	_check("and back on it is not", not AudioServer.is_bus_mute(sfx) and is_equal_approx(AudioServer.get_bus_volume_db(sfx), AudioBuses.volume_to_db(0.3)))
	_check("a volume is kept between 0 and 1", (func() -> bool:
		Settings.set_music_volume(7.0)
		var high := Settings.music_volume
		Settings.set_music_volume(-3.0)
		var low := Settings.music_volume
		Settings.set_music_volume(0.5)
		return is_equal_approx(high, 1.0) and is_equal_approx(low, 0.0)).call())

	_check("every block of the meter is a clear step (4 dB) from the one before, up to the files' own level at full", (func() -> bool:
		var steps_ok := is_equal_approx(AudioBuses.volume_to_db(1.0), 0.0)
		for block in range(1, 10):
			steps_ok = steps_ok and is_equal_approx(AudioBuses.volume_to_db((block + 1) / 10.0) - AudioBuses.volume_to_db(block / 10.0), AudioBuses.RANGE_DB / 10.0)
		return steps_ok and AudioBuses.volume_to_db(0.0) == AudioBuses.MUTE_DB and AudioBuses.volume_to_db(0.1) < -30.0).call())

	# ---- changing a key
	_check("a free key can be given to a slot", KeyBindings.set_key(InputActions.JUMP, 1, KEY_X) == "")
	_check("it is in the input map and the old key is gone", _has_key(InputActions.JUMP, KEY_X) and not _has_key(InputActions.JUMP, KEY_W) and _has_key(InputActions.JUMP, KEY_SPACE))
	_check("a key another action uses is refused, naming the action", KeyBindings.set_key(InputActions.INTERACT, 0, KEY_SPACE) == KeyBindings.LABELS[InputActions.JUMP] and KeyBindings.keys(InputActions.INTERACT)[0] == KEY_E)
	_check("Escape and Enter are reserved", KeyBindings.set_key(InputActions.INTERACT, 0, KEY_ESCAPE) == "RESERVED" and KeyBindings.set_key(InputActions.INTERACT, 0, KEY_ENTER) == "RESERVED")
	_check("a second key can be emptied", KeyBindings.clear(InputActions.JUMP, 1) and KeyBindings.keys(InputActions.JUMP)[1] == KeyBindings.NONE and not _has_key(InputActions.JUMP, KEY_X))
	_check("an action keeps at least one key", not KeyBindings.clear(InputActions.MOVE_LEFT, 0) and KeyBindings.keys(InputActions.MOVE_LEFT)[0] == KEY_LEFT)
	KeyBindings.set_key(InputActions.INTERACT, 1, KEY_E)
	_check("a key the action has in its other slot is left where it is", _keys_are(InputActions.INTERACT, [KEY_E, KeyBindings.NONE]))
	_check("a key has a name to show", KeyBindings.label(KEY_SPACE) != "" and KeyBindings.label(KeyBindings.NONE) == "-")

	# ---- the file
	Settings.set_music_volume(0.4)
	KeyBindings.set_key(InputActions.ATTACK_LIGHT, 1, KEY_R)
	Settings.forget()
	Settings.ensure_loaded()
	_check("the volumes come back from the file", is_equal_approx(Settings.music_volume, 0.4) and is_equal_approx(Settings.sfx_volume, 0.3))
	_check("and the keys", _keys_are(InputActions.ATTACK_LIGHT, [KEY_Q, KEY_R]) and _keys_are(InputActions.JUMP, [KEY_SPACE, KeyBindings.NONE]))
	KeyBindings.reset()
	_check("resetting brings every default key back", _keys_are(InputActions.JUMP, [KEY_SPACE, KEY_W]) and _has_key(InputActions.JUMP, KEY_W) and not _has_key(InputActions.ATTACK_LIGHT, KEY_R))

	# ---- the block meter
	var meter := SegmentedMeter.new()
	meter.size = Vector2(300.0, 40.0)
	var changes: Array[float] = []
	meter.changed.connect(func(v: float) -> void: changes.append(v))
	meter.value = 0.73
	_check("the level goes in whole blocks", is_equal_approx(meter.value, 0.7) and changes.is_empty())
	meter._set_from_x(meter.size.x)
	_check("a touch at the far end is full", is_equal_approx(meter.value, 1.0) and changes.size() == 1)
	meter._set_from_x(0.0)
	_check("a touch at the very start is silent", is_equal_approx(meter.value, 0.0) and changes.size() == 2)
	meter._set_from_x(meter.size.x * 0.55)
	_check("a touch in the middle lights up to the block it is on", meter.value > 0.4 and meter.value < 0.7, str(meter.value))
	meter._set_from_x(meter.size.x * 0.55)
	_check("the same touch again changes nothing", changes.size() == 3)
	meter.free()

	# ---- the touch buttons
	var letters: Array = TouchControls.FACE_BUTTONS.map(func(b: Dictionary) -> String: return String(b["label"]))
	_check("the phone's buttons are A, B, C and D", letters == ["A", "B", "C", "D"])

	# ---- the window on a PC
	var panel := SettingsPanel.open(root, false)
	await _wait(3)
	var closed := [false]
	panel.closed.connect(func() -> void: closed[0] = true)
	_check("the window lists two keys for every action", panel._key_buttons.size() == InputActions.ALL.size() * KeyBindings.SLOTS, str(panel._key_buttons.size()))
	var jump_second: Button = panel._key_buttons["%s:1" % InputActions.JUMP]
	_check("a key button shows its key", jump_second.text == KeyBindings.label(KEY_W))
	jump_second.pressed.emit()
	_check("pressing it waits for a key", jump_second.text == SettingsPanel.LISTENING_TEXT)
	panel._input(_key_event(KEY_X))
	_check("the next key press is the new key", KeyBindings.keys(InputActions.JUMP)[1] == KEY_X and jump_second.text == KeyBindings.label(KEY_X) and _has_key(InputActions.JUMP, KEY_X))
	jump_second.pressed.emit()
	panel._input(_key_event(KEY_E))
	_check("a clash is refused with a message and the key stays", KeyBindings.keys(InputActions.JUMP)[1] == KEY_X and panel._message.text.contains(String(KeyBindings.LABELS[InputActions.INTERACT])), panel._message.text)
	jump_second.pressed.emit()
	panel._input(_key_event(KEY_ESCAPE))
	_check("Escape while waiting cancels (the window stays)", KeyBindings.keys(InputActions.JUMP)[1] == KEY_X and not closed[0] and jump_second.text == KeyBindings.label(KEY_X))
	jump_second.pressed.emit()
	panel._input(_key_event(KEY_DELETE))
	_check("Delete empties the key", KeyBindings.keys(InputActions.JUMP)[1] == KeyBindings.NONE and jump_second.text == "-")
	panel._input(_key_event(KEY_ESCAPE))
	_check("Escape with nothing to set closes the window", closed[0])
	await _wait(3)
	_check("and it is gone", not is_instance_valid(panel))

	# ---- the window on a phone
	var phone := SettingsPanel.open(root, true)
	await _wait(3)
	_check("on a phone there are no keys to change", phone._key_buttons.is_empty())
	phone.queue_free()
	await _wait(3)

	# put everything back
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_FILE))
	Settings.file = Settings.DEFAULT_FILE
	Settings.forget()
	KeyBindings.apply()
	print("ALL PASS" if ok else "SOME FAILED")
	quit(0 if ok else 1)
