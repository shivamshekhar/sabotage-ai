extends SceneTree
## The generic level test: for a level (or every level of the game) it checks that the player can play it, whatever the level looks like: the exit can
## be reached from the start, no spot is a dead end, every laser gate has its computer and really blocks the way, the power-up box can be reached, and
## nothing can fly over a gate. The checks are in lib/level_checks.gd and know nothing about where anything is placed. Exits non-zero on failure.
##
## Run: godot_console --headless --fixed-fps 60 --path . --script res://tools/tests/level_traversal_test.gd
## One level: set the environment variable LEVEL to a folder name (LEVEL=level_03) or LEVEL_FILE to a level file, for example while designing one.

var ok := true


func _initialize() -> void:
	_main()


func _main() -> void:
	var ids: Array[String] = []
	var file := OS.get_environment("LEVEL_FILE")
	if file != "":
		var loaded := LevelFile.load_file(file)
		LevelData.use_file(loaded["data"], file.get_base_dir())
		ids.append(LevelData.FILE_ID)
	elif OS.get_environment("LEVEL") != "":
		ids.append(OS.get_environment("LEVEL"))
	else:
		ids = LevelData.level_ids()
	for id in ids:
		for r in LevelChecks.run(id):
			print(("PASS  " if r["ok"] else "FAIL  "), r["name"], "  ", r["detail"])
			ok = ok and r["ok"]
	print("ALL PASS" if ok else "SOME FAILED")
	quit(0 if ok else 1)
