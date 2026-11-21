extends SceneTree
## The pause menu of the game screen: the menu button in the HUD's corner and Esc open it, the game stops (the player does not move while it is open), its buttons are in the usual
## order (RESUME with the focus, SETTINGS, QUIT TO TITLE), Esc and RESUME carry on, SETTINGS opens the settings window and comes back, and QUIT TO TITLE asks first (CANCEL is the
## default) and then leaves the game for the title (the score starts over). Played in the test arena. Exits non-zero on failure.
## Run: godot_console --headless --fixed-fps 60 --path . --script res://tools/tests/pause_menu_test.gd

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


func _esc() -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_ESCAPE
	event.pressed = true
	return event


func _find_menu(main: Node) -> PauseMenu:
	for n in main.get_children():
		if n is PauseMenu:
			return n
	return null


func _button_texts(menu: PauseMenu) -> Array:
	var out := []
	for b in menu.find_children("*", "Button", true, false):
		out.append((b as Button).text)
	return out


func _main() -> void:
	Settings.file = "user://pause_test_settings.cfg"
	Settings.forget()
	InputSetup.register()
	await _wait(2)
	TestArena.use()
	var main = load(AssetPaths.MAIN_SCENE).instantiate()
	root.add_child(main)
	await _wait(5)
	var player: Player = get_first_node_in_group(Groups.PLAYER)
	var hud: Hud = main.get_node("Hud")
	var button: Button = hud.find_child("MenuButton", true, false)

	# ---- the button
	_check("the HUD has a menu button", button != null and button is PauseButton)
	var view := root.get_visible_rect().size
	_check("in the top-right corner of the screen", button.get_global_rect().position.x > view.x - 160.0 and button.get_global_rect().position.y < 60.0, str(button.get_global_rect()))
	_check("it cannot take the keyboard focus (Space and Enter would press it)", button.focus_mode == Control.FOCUS_NONE)

	# ---- opening it stops the game
	button.pressed.emit()
	await _wait(3)
	var menu := _find_menu(main)
	_check("pressing it opens the pause menu and pauses the game", menu != null and paused)
	_check("the buttons are in the usual order: resume, settings, quit", _button_texts(menu) == ["RESUME", "SETTINGS", "QUIT TO TITLE"], str(_button_texts(menu)))
	_check("the first one, RESUME, has the focus", menu._resume.has_focus())
	_check("a second press does not open a second menu", PauseMenu.open(main) == null)
	var x := player.global_position.x
	Input.action_press(InputActions.MOVE_RIGHT)
	await _wait(20)
	Input.action_release(InputActions.MOVE_RIGHT)
	_check("the player does not move while it is open", is_equal_approx(player.global_position.x, x))

	# ---- Esc carries on
	menu._input(_esc())
	await _wait(3)
	_check("Esc resumes: the menu is gone and the game runs", not is_instance_valid(menu) and not paused)
	Input.action_press(InputActions.MOVE_RIGHT)
	await _wait(20)
	Input.action_release(InputActions.MOVE_RIGHT)
	_check("and the player moves again", player.global_position.x > x + 20.0, "%.0f -> %.0f" % [x, player.global_position.x])

	# ---- Esc opens it too (the HUD takes the key when nothing else did)
	hud._unhandled_input(_esc())
	await _wait(3)
	menu = _find_menu(main)
	_check("Esc in the game opens the menu", menu != null and paused)
	menu._resume.pressed.emit()
	await _wait(3)
	_check("the RESUME button carries on", not is_instance_valid(menu) and not paused)

	# ---- settings
	button.pressed.emit()
	await _wait(3)
	menu = _find_menu(main)
	menu._settings_button.pressed.emit()
	await _wait(3)
	_check("SETTINGS opens the settings window over the menu", menu._settings != null and is_instance_valid(menu._settings) and paused)
	menu._input(_esc())
	_check("Esc then belongs to the settings window, not the menu", is_instance_valid(menu) and paused)
	menu._settings._close()
	await _wait(3)
	_check("closing the settings comes back to the menu", menu._settings == null and is_instance_valid(menu) and paused and menu._settings_button.has_focus())

	# ---- quitting asks first
	menu.find_children("*", "Button", true, false).back().pressed.emit()
	await _wait(3)
	_check("QUIT TO TITLE asks 'are you sure', with CANCEL first and in focus", _button_texts(menu) == ["CANCEL", "QUIT"] and menu._asking, str(_button_texts(menu)))
	menu._input(_esc())
	await _wait(3)
	_check("Esc (or CANCEL) goes back to the menu without quitting", _button_texts(menu) == ["RESUME", "SETTINGS", "QUIT TO TITLE"] and paused and is_instance_valid(menu))
	menu.find_children("*", "Button", true, false).back().pressed.emit()
	await _wait(3)
	GameStats.score = 1234
	var quit_button: Button = menu.find_children("*", "Button", true, false).back()
	_check("the last button is QUIT", quit_button.text == "QUIT")
	menu.quit_to_title()
	_check("quitting leaves the game running state clean: not paused, the score starts over, the title is asked for",
			not paused and GameStats.score == 0 and TitleScreen.requested and LevelData.selected_id == "")
	TitleScreen.requested = false

	Settings.file = Settings.DEFAULT_FILE
	Settings.forget()
	print("ALL PASS" if ok else "SOME FAILED")
	quit(0 if ok else 1)
