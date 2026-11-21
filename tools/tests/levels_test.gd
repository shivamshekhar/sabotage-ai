extends SceneTree
## The campaign as a whole (not what is in each level: that is level_traversal_test.gd): there are levels, the first is the default, they are chained one
## after the other with the last one ending the game, each has its own title and its own full background. Exits non-zero on failure.
## Run: godot_console --headless --fixed-fps 60 --path . --script res://tools/tests/levels_test.gd

# MIN_LEVELS: the least number of levels the game has.
const MIN_LEVELS := 3

var ok := true


func _check(name: String, cond: bool, detail := "") -> void:
	print(("PASS  " if cond else "FAIL  "), name, "  ", detail)
	if not cond:
		ok = false


func _initialize() -> void:
	_main()


func _main() -> void:
	var level_ids := LevelData.level_ids()
	_check("the game has levels, the first is the default", level_ids.size() >= MIN_LEVELS and level_ids[0] == LevelData.DEFAULT_ID, str(level_ids))
	_check("the common art folder is not a level", not level_ids.has(LevelData.COMMON_FOLDER))
	var chain_ok := true
	for i in level_ids.size():
		var expected := level_ids[i + 1] if i + 1 < level_ids.size() else ""
		if LevelData.next_id(level_ids[i]) != expected:
			chain_ok = false
	_check("the levels are chained one after the other, the last one ends the game", chain_ok)
	_check("the test level is still there", LevelData.has_level(LevelData.TEST_ID))
	var titles := {}
	for id in level_ids:
		titles[LevelData.title(id)] = true
	_check("each level has its own title", titles.size() == level_ids.size(), str(titles.keys()))
	for id in level_ids:
		var dir := LevelData.background_dir(id)
		_check("level %s: its own background folder holds every layer" % id, LevelBackground.LAYERS.all(func(l: String) -> bool: return ResourceLoader.exists(dir + l + ".png")) and dir.begins_with(LevelData.art_dir(id)), dir)
	print("ALL PASS" if ok else "SOME FAILED")
	quit(0 if ok else 1)
