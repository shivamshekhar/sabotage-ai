extends SceneTree
## The level command-line tool (tools/level_editor/cli_commands.gd): make, edit and check a level. Exits non-zero on failure.
## Run: godot_console --headless --path . --script res://tools/tests/level_cli_test.gd

const FILE := "user://cli_test.sablevel.json"
const PLAN := '[["flat",8,"PK"],["hurdle"],["flat",4],["pit",3,"A"],["flat",4],["rise",4],["flat",8,"B"],["tunnel","1"],["flat",7,"B"],["drop",3],["flat",6,"K"],["exit"]]'

var ok := true


func _check(name: String, cond: bool, detail := "") -> void:
	print(("PASS  " if cond else "FAIL  "), name, "  ", detail)
	if not cond:
		ok = false


func _initialize() -> void:
	var r := LevelCli.run(["new", FILE, "--cols", "40", "--rows", "20", "--title", "T"])
	_check("new makes a valid level", r["ok"] and r["problems"].is_empty() and r["cols"] == 40, str(r))
	r = LevelCli.run(["set-tile", FILE, "10", "15", "#"])
	_check("set-tile", r["ok"], str(r))
	r = LevelCli.run(["set-tile", FILE, "99", "15", "#"])
	_check("a tile outside the level is refused", not r["ok"])
	r = LevelCli.run(["fill", FILE, "12", "15", "14", "15", "="])
	_check("fill", r["ok"] and r["changed"] == 3, str(r))
	r = LevelCli.run(["place", FILE, "checkpoint", "20", "15"])
	_check("place a checkpoint", r["ok"], str(r))
	r = LevelCli.run(["place", FILE, "ai_bro", "25", "15", "--name", "Gus", "--prop", "chase_speed=222"])
	_check("place a named Bro with a value", r["ok"] and r["stored"].has("chase_speed"), str(r))
	r = LevelCli.run(["place", FILE, "ai_bro", "26", "15", "--prop", "nonsense=1"])
	_check("an unknown value is refused", not r["ok"])
	r = LevelCli.run(["set", FILE, "player", "speed=450", "max_health=120"])
	_check("set player values", r["ok"] and r["now"]["speed"] == 450.0, str(r))
	r = LevelCli.run(["set", FILE, "terrain", "gravity_scale=0.5"])
	_check("set terrain values", r["ok"], str(r))
	r = LevelCli.run(["minigame", FILE, "add", "--id", "m1", "--kind", "mash", "--param", "taps_needed=4"])
	_check("add a minigame", r["ok"], str(r))
	r = LevelCli.run(["minigame", FILE, "list"])
	_check("list minigames", r["ok"] and r["minigames"].size() == 1)
	r = LevelCli.run(["minigame", FILE, "remove", "--id", "m1"])
	_check("remove a minigame", r["ok"])
	r = LevelCli.run(["remove", FILE, "20", "15"])
	_check("remove", r["ok"])
	r = LevelCli.run(["show", FILE, "--rows", "14-19", "--cols", "0-30"])
	_check("show draws the map", r["ok"] and r["map"].size() == 8, str(r))
	r = LevelCli.run(["validate", FILE])
	_check("validate", r["ok"], str(r))

	# a level built from a plan, then solved
	var plan_file := "user://cli_plan.sablevel.json"
	r = LevelCli.run(["from-plan", plan_file, "--plan", PLAN, "--id", "demo"])
	_check("from-plan builds a valid level", r["ok"] and r["problems"].is_empty(), str(r))
	r = LevelCli.run(["solve", plan_file])
	_check("and it can be solved", r["ok"], str(r))
	r = LevelCli.run(["from-plan", plan_file, "--plan", '[["warp"],["exit"]]'])
	_check("an unknown piece is refused", not r["ok"])
	r = LevelCli.run(["from-plan", plan_file, "--plan", '[["flat",8,"PK"]]'])
	_check("a plan without an exit is refused", not r["ok"])
	r = LevelCli.run(["info", plan_file])
	_check("info counts things", r["ok"] and r["counts"]["bros"] >= 2, str(r["counts"]))

	# a built-in level as a file, and the reference data
	r = LevelCli.run(["convert", "level_02", "user://cli_l2.sablevel.json"])
	_check("convert a built-in level", r["ok"] and r["problems"].is_empty(), str(r))
	r = LevelCli.run(["list"])
	_check("list shows the levels of the game", r["ok"] and r["levels"].size() >= 3 and r["levels"][0]["id"] == LevelData.DEFAULT_ID, str(r.get("levels", []).size()))
	# a level made inside levels/<id>/ gets that id and its own background folder
	var folder := LevelData.LEVELS_DIR + "zz_cli_test"
	r = LevelCli.run(["new", folder + "/level.sablevel.json", "--cols", "30", "--rows", "16"])
	var made := LevelFile.load_file(folder + "/level.sablevel.json")
	_check("a level in levels/<id>/ takes the folder name as its id", r["ok"] and (made["data"]["meta"] as Dictionary)["id"] == "zz_cli_test", str(r))
	_check("and gets its own background folder, copied from the first level's", r["needs_import"] and FileAccess.file_exists(folder + "/background/far.png"))
	for f in DirAccess.get_files_at(folder + "/background"):
		DirAccess.remove_absolute(folder + "/background/" + f)
	DirAccess.remove_absolute(folder + "/background")
	DirAccess.remove_absolute(folder + "/level.sablevel.json")
	DirAccess.remove_absolute(folder)
	_check("(test level folder removed again)", not DirAccess.dir_exists_absolute(folder))
	r = LevelCli.run(["catalog", "objects"])
	_check("catalog lists objects", r["ok"] and r["objects"].size() >= 5)
	r = LevelCli.run(["pieces"])
	_check("pieces lists the pieces", r["ok"] and r["pieces"].has("flat") and r["pieces"].has("tunnel"))
	r = LevelCli.run(["nonsense"])
	_check("an unknown command is an error", not r["ok"])

	print("ALL PASS" if ok else "SOME FAILED")
	quit(0 if ok else 1)
