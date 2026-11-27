extends SceneTree
## The title screen: the logo, the menu (settings work, the others say "coming soon"), the prompt for the keyboard or for a phone, the distant backdrop, and the start: Enter (or
## a tap on a phone) makes the hero walk to the door and go in, the screen goes white, and the game is about to start (ScreenFlash). Also that a level chosen in the environment skips
## the title. The real start (changing the scene) is switched off here. Exits non-zero on failure.
## Run: godot_console --headless --fixed-fps 60 --path . --script res://tools/tests/title_test.gd

# WAIT_CAP: the most frames to wait for a condition before giving up.
const WAIT_CAP := 900

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


func _wait_until(cond: Callable) -> void:
	var n := 0
	while not cond.call() and n < WAIT_CAP:
		await process_frame
		n += 1


func _enter() -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = KEY_ENTER
	event.pressed = true
	return event


func _tap() -> InputEventScreenTouch:
	var event := InputEventScreenTouch.new()
	event.pressed = true
	event.position = Vector2(640.0, 360.0)
	return event


## A title screen that does not really start the game.
func _make_title() -> TitleScreen:
	var title: TitleScreen = load(AssetPaths.TITLE_SCENE).instantiate()
	title.launch_game = false
	root.add_child(title)
	return title


func _main() -> void:
	Settings.file = "user://title_test_settings.cfg"
	Settings.forget()
	InputSetup.register()
	await _wait(2)

	# ---- skipping the title
	_check("the title is not skipped by default", not TitleScreen.should_skip())
	OS.set_environment("SABOTAGE_NO_TITLE", "1")
	_check("SABOTAGE_NO_TITLE skips it", TitleScreen.should_skip())
	OS.set_environment("SABOTAGE_NO_TITLE", "")
	OS.set_environment("SABOTAGE_LEVEL", "level_02")
	_check("so does choosing a level", TitleScreen.should_skip())
	OS.set_environment("SABOTAGE_LEVEL", "")

	# ---- the screen on a PC
	var title := _make_title()
	await _wait(10)
	_check("it is the game's starting scene", ProjectSettings.get_setting("application/run/main_scene") == AssetPaths.TITLE_SCENE)
	_check("the logo is there", title._logo.texture != null and title._logo.size.x > 0.0)
	_check("the prompt says to press Enter", title._prompt.text == TitleScreen.PROMPT_KEYBOARD % KeyBindings.label(KeyBindings.START_KEYS[0]))
	var buttons: Array[Button] = []
	for c in title._menu.find_children("*", "Button", true, false):
		buttons.append(c)
	_check("the menu has a button for every entry", buttons.size() == TitleMenu.ENTRIES.size(), str(buttons.size()))
	var soon_tags := 0
	for b in buttons:
		soon_tags += b.get_child_count()
	_check("the ones that do not work yet are tagged", soon_tags == TitleMenu.ENTRIES.filter(func(e: Dictionary) -> bool: return not e["ready"]).size())
	_check("the distant backdrop is built (a viewport with the real pits in it)", title.find_children("*", "SubViewport", true, false).size() == 1 and title.find_children("*", "PitHazard", true, false).size() >= 3)
	_check("the hero stands left of the door", title._hero.position.x < title._door.position.x - 100.0)
	title._on_menu(&"levels")
	_check("a menu entry that does not work yet says coming soon", title._soon.modulate.a > 0.9 and title._settings == null)
	title._on_menu(&"settings")
	await _wait(3)
	_check("settings opens the settings window", title._settings != null and is_instance_valid(title._settings))
	title._unhandled_input(_enter())
	_check("Enter does not start the game while the settings are open", not title._started)
	title._settings._close()
	await _wait(3)
	_check("and it can be closed", title._settings == null)

	# ---- starting with Enter
	var starting := [false]
	title.game_starting.connect(func() -> void: starting[0] = true)
	title._unhandled_input(_tap())
	_check("a tap does nothing on a PC", not title._started)
	title._unhandled_input(_enter())
	_check("Enter starts it: the door opens", title._started and title._door.is_open())
	await _wait_until(func() -> bool: return title._hero.position.x > title._door.position.x - 60.0)
	_check("the hero walks towards the door by himself", title._hero.position.x > title._door.position.x - 60.0)
	await _wait_until(func() -> bool: return starting[0])
	_check("he goes in (he has faded away) and the game is about to start", starting[0] and title._hero.modulate.a <= 0.01)
	_check("the screen is white and the next scene clears away from it", ScreenFlash.arriving and is_instance_valid(ScreenFlash._layer))
	_check("the menu and the prompt have gone", title._menu.modulate.a <= 0.01 and title._prompt.modulate.a <= 0.01)
	ScreenFlash.arriving = false
	if is_instance_valid(ScreenFlash._layer):
		ScreenFlash._layer.queue_free()
	title.queue_free()
	await _wait(3)

	# ---- the screen on a phone
	OS.set_environment("SABOTAGE_TOUCH", "1")
	var phone := _make_title()
	await _wait(10)
	_check("on a phone the prompt says to tap", phone._prompt.text == TitleScreen.PROMPT_TOUCH)
	phone._unhandled_input(_tap())
	_check("a tap anywhere starts it", phone._started)
	OS.set_environment("SABOTAGE_TOUCH", "")
	phone.queue_free()
	await _wait(3)
	ScreenFlash.arriving = false

	Settings.file = Settings.DEFAULT_FILE
	Settings.forget()
	print("ALL PASS" if ok else "SOME FAILED")
	quit(0 if ok else 1)
