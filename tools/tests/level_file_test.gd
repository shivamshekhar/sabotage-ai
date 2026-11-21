extends SceneTree
## Level files (*.sablevel.json): read, written, checked, and played by the game with their tuned values. Exits non-zero on failure.
## Run: godot_console --headless --fixed-fps 60 --path . --script res://tools/tests/level_file_test.gd

var ok := true
var main: Node


func _check(name: String, cond: bool, detail := "") -> void:
	print(("PASS  " if cond else "FAIL  "), name, "  ", detail)
	if not cond:
		ok = false


func _initialize() -> void:
	_main()


func _wait(frames: int) -> void:
	for i in frames:
		await process_frame


func _set_tile(d: Dictionary, c: int, r: int, ch: String) -> void:
	var row: String = d["tiles"][r]
	d["tiles"][r] = row.substr(0, c) + ch + row.substr(c + 1)


func _sample() -> Dictionary:
	var d := LevelFile.new_level(60, 24)
	_set_tile(d, 20, 19, "B")
	_set_tile(d, 30, 19, "L")
	for r in range(16, 20):
		_set_tile(d, 34, r, "1")
	d["objects"]["20,19"] = {"type": "ai_bro", "name": "Lobby Bro", "props": {"chase_speed": 123.0, "health_fraction": 0.5}}
	d["objects"]["30,19"] = {"type": "lock_terminal", "props": {"minigame": "quick"}}
	d["minigames"] = [{"id": "quick", "name": "Quick mash", "kind": "mash", "params": {"taps_needed": 3, "time_limit": 9.0}}]
	d["player"] = {"name": "Tester", "speed": 500.0, "max_health": 150, "jump_velocity": -900.0}
	d["terrain"] = {"gravity_scale": 0.5, "fall_death_height": 1234.0, "pit_death_delay": 0.5, "background": "background"}
	d["meta"] = {"id": "sample", "title": "SAMPLE LEVEL", "next": ""}
	return d


func _main() -> void:
	InputSetup.register()
	# ---- reading, writing and checking
	var fresh := LevelFile.new_level(40, 20)
	_check("a fresh level is valid", LevelFile.validate(fresh).is_empty(), str(LevelFile.validate(fresh)))
	var data := _sample()
	_check("the sample level is valid", LevelFile.validate(data).is_empty(), str(LevelFile.validate(data)))
	var path := ProjectSettings.globalize_path("user://sample_test.sablevel.json")
	_check("a level can be saved", LevelFile.save_file(path, data) == OK)
	var loaded := LevelFile.load_file(path)
	_check("and read back", loaded["ok"] and (loaded["data"] as Dictionary)["tiles"] == data["tiles"] and (loaded["data"] as Dictionary)["objects"] == data["objects"], str(loaded["errors"]))
	var once := LevelFile.to_text(loaded["data"])
	_check("the text form is stable (save, load, save, load, save gives the same text)", LevelFile.to_text(LevelFile.parse(once)["data"]) == once)
	var bad := LevelFile.parse("{ this is not json")
	_check("a broken file is reported, not crashed on", not bad["ok"] and not (bad["errors"] as Array).is_empty())
	var two_spawns := _sample()
	_set_tile(two_spawns, 10, 19, "P")
	_check("a second spawn is an error", not LevelFile.validate(two_spawns).is_empty())
	var cramped := _sample()
	_set_tile(cramped, 19, 19, "#")
	_set_tile(cramped, 21, 19, "#")
	var found := LevelFile.validate(cramped)
	_check("a Bro without room to pace is an error", found.any(func(e: String) -> bool: return e.begins_with("AI Bro")), str(found))
	var no_computer := _sample()
	_set_tile(no_computer, 30, 19, ".")
	_check("a laser gate with no computer is an error", not LevelFile.validate(no_computer).is_empty())

	# ---- playing it: the game reads the tuned values
	OS.set_environment("SABOTAGE_LEVEL_FILE", path)
	main = load(AssetPaths.MAIN_SCENE).instantiate()
	root.add_child(main)
	await _wait(8)
	var level: Level
	var player: Player
	var bro: AIBro
	for n in main.get_children():
		if n is Level:
			level = n
		elif n is Player:
			player = n
		elif n is AIBro:
			bro = n
	for n in level.get_children():
		if n is AIBro:
			bro = n
	_check("the game plays the level file", level != null and level.level_id == LevelData.FILE_ID)
	_check("with its title", LevelData.title(LevelData.FILE_ID) == "SAMPLE LEVEL")
	_check("the player's values come from the file", player.run_speed == 500.0 and player.max_health == 150 and player.health == 150 and player.jump_speed == -900.0, "%s %s" % [player.run_speed, player.max_health])
	_check("and the player's name", player.display_name == "Tester")
	_check("the terrain gravity scale is applied", LevelData.gravity_scale == 0.5)
	_check("and the deadly fall height", player.fall_death_px == 1234.0)
	_check("the Bro has the name and values set for it", bro != null and bro.display_name == "Lobby Bro" and bro.chase_speed == 123.0 and bro.max_health == 50, "%s" % [bro.chase_speed if bro else "none"])
	var plain := AIBro.new()
	_check("a Bro nobody changed keeps the defaults", plain.chase_speed == AIBro.CHASE_SPEED)
	plain.free()
	var terminals := LevelData.terminals(LevelData.FILE_ID)
	_check("the computer shows the puzzle the file names", terminals.size() == 1 and terminals[0]["game"] == "quick", str(terminals))

	# ---- the puzzle defined in the file, with its own settings
	var popup := HackPopup.open(main, "1", "quick")
	await _wait(3)
	_check("a puzzle defined in the file opens by its id", popup.game is MashGame)
	var needed: int = int(popup.game._p("taps_needed", -1))
	_check("with the file's settings", needed == 3, str(needed))
	var solved := [false]
	popup.game.solved.connect(func() -> void: solved[0] = true)
	await popup.game.auto_solve()
	await _wait(3)
	_check("and it is solved with that many taps", solved[0])
	popup.close_popup()
	var definition := {"kind": "wrong_only", "params": {"rounds": 1}, "questions": [{"q": "What is 1 + 1?", "right": "2", "wrong": ["3", "4", "5"]}]}
	var quiz := HackPopup.open_definition(main, "1", definition)
	await _wait(3)
	_check("a quiz takes its own questions", quiz.game is WrongOnlyGame and quiz.game.bank.size() == 1 and str(quiz.game.bank[0]["q"]) == "What is 1 + 1?")
	quiz.close_popup()
	await _wait(3)

	main.queue_free()
	await _wait(5)
	OS.set_environment("SABOTAGE_LEVEL_FILE", "")
	LevelData.file_data = {}
	LevelData.gravity_scale = 1.0
	print("ALL PASS" if ok else "SOME FAILED")
	quit(0 if ok else 1)
