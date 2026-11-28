extends SceneTree
## The warning signs before the deadly pits: where PitSigns puts them (on the solid ground just before a pit, or on top of a wall that rises there, never on
## something that is already in the way), that each liquid gets its own sign, that the signs are registered tiles with pictures, that the level generator
## and the level CLI add them, and that every level of the game has them. Exits non-zero on failure.
## Run: godot_console --headless --fixed-fps 60 --path . --script res://tools/tests/pit_signs_test.gd

var ok := true


func _check(name: String, cond: bool, detail := "") -> void:
	print(("PASS  " if cond else "FAIL  "), name, "  ", detail)
	if not cond:
		ok = false


func _initialize() -> void:
	_main()


## A small map from text rows (a space is air).
func _rows(lines: Array) -> Array[String]:
	var out: Array[String] = []
	for line in lines:
		out.append(str(line).replace(" ", "."))
	return out


func _main() -> void:
	# ---- the four signs exist as tiles, with a picture each
	for liquid in "AFNW":
		var key: String = PitSigns.SIGN_KEYS[liquid]
		var kind := TileRegistry.kind_for_key(key)
		var tile_name := str((kind.get("sprite", {}) as Dictionary).get("tile", ""))
		_check("pit %s has a registered sign tile (%s) that is decor with a picture" % [liquid, key], not kind.is_empty() and str(kind["behavior"]) == "decor" and tile_name != "" and SpriteLibrary.tile(tile_name) != null and SpriteLibrary.tile(tile_name).get_width() == Level.T)
	var chars := {}
	for liquid in "AFNW":
		chars[PitSigns.sign_char(liquid)] = true
	_check("each liquid has its own sign", chars.size() == 4 and not chars.has(""))

	# ---- where a sign goes
	var rows := _rows([
		"          ",
		"          ",
		"          ",
		"##### ####",    # row 3: the ground, with the pit carved out (col 5)
		"#####A####",    # row 4: the liquid
		"##########",
	])
	var found := PitSigns.spots(rows)
	_check("a pit has one sign, on the last ground tile before it, in the air above it", found.size() == 1 and found[0]["col"] == 4 and found[0]["row"] == 2 and found[0]["liquid"] == "A" and not found[0]["present"], str(found))
	_check("with the right picture for the liquid", found[0]["char"] == PitSigns.sign_char("A"))
	var with_sign := rows.duplicate()
	with_sign[2] = "    " + PitSigns.sign_char("A") + "     "
	_check("a sign that is already there is found and not asked for again", PitSigns.spots(with_sign)[0]["present"] and PitSigns.missing(with_sign).is_empty())

	var blocked := _rows([
		"           ",
		"           ",
		"   cl      ",
		"##### #####",
		"#####F#####",
		"###########",
	])
	var spot := PitSigns.spots(blocked)[0]
	_check("a lamp or a canister right before the pit is not built over: the sign stands on the next free tile back", spot["col"] == 2 and spot["row"] == 2, str(spot))

	var machine := _rows([
		"           ",
		"           ",
		"   G       ",
		"##### #####",
		"#####A#####",
		"###########",
	])
	spot = PitSigns.spots(machine)[0]
	_check("nor on a machine's footprint (a machine is marked only on its bottom-left tile)", spot["col"] == 2, str(spot))

	var wall := _rows([
		"            ",
		"      ##    ",
		"      ##    ",
		"      ##    ",
		"######## ###",
		"########N###",
		"############",
	])
	spot = PitSigns.spots(wall)[0]
	_check("a pit right behind a wall has its sign on top of the wall, where the jump starts", spot["col"] == 7 and spot["row"] == 0, str(spot))

	var two := _rows([
		"                  ",
		"                  ",
		"                  ",
		"### ####### #### #",
		"###W#######N####W#",
		"##################",
	])
	var both := PitSigns.spots(two)
	_check("every pit gets its own sign, in its own liquid's picture", both.size() == 3 and both.map(func(s: Dictionary) -> String: return s["liquid"]) == ["W", "N", "W"], str(both))
	_check("a wide pit has one sign, not one per tile", PitSigns.spots(_rows(["          ", "          ", "          ", "##    ####", "##NNNN####", "##########"])).size() == 1)
	_check("a pit with no ground before it (the level's wall) has no sign", PitSigns.spots(_rows(["      ", "      ", "      ", "  ####", "WW####", "######"])).is_empty())

	# ---- the level generator and the CLI add them
	var built := LevelData.seq_build_plan([["flat", 8, "PK"], ["pit", 3, "F"], ["flat", 6], ["pit", 4, "N"], ["flat", 8, "B"], ["exit"]], ["S", "G"], "A", "signs_test")
	var built_rows: Array[String] = []
	built_rows.assign(built["rows"])
	var signs_in_plan := PitSigns.spots(built_rows)
	_check("a generated level has a sign before each of its pits", signs_in_plan.size() == 2 and PitSigns.missing(built_rows).is_empty(), str(signs_in_plan))
	var data := {"tiles": rows.duplicate()}
	var report := LevelCli._pit_signs_cmd(data)
	_check("the CLI command adds the missing sign", report["ok"] and report["changed"] == 1 and PitSigns.missing(_to_rows(data)).is_empty(), str(report))
	_check("and running it again adds nothing", LevelCli._pit_signs_cmd(data)["changed"] == 0)

	# ---- the two red lights on every sign glow and dim in turn
	LevelData.selected_id = "level_01"
	var main = load(AssetPaths.MAIN_SCENE).instantiate()
	root.add_child(main)
	for i in 5:
		await process_frame
	LevelData.selected_id = ""
	var lights: Array[GlowPulse] = []
	_collect_lights(main, lights)
	var signs_in_level := PitSigns.spots(LevelData.map("level_01")).size()
	_check("every sign has two red lights", lights.size() == 2 * signs_in_level and signs_in_level > 0, "%d lights, %d signs" % [lights.size(), signs_in_level])
	var first := lights[0]
	var second := lights[1]
	for n in main.get_children():
		if n is Level:
			(n as Level).sleeper.wake_all()       # (the lights sleep while they are far from the camera: here they are watched at work)
	_check("they sit on the two top corners of the board, one on each side", first.position.x < Level.T / 2.0 and second.position.x > Level.T / 2.0 and absf(first.position.y - second.position.y) < 0.01 and first.position.y < 6.0)
	_check("and are red", first.self_modulate.r > 0.9 and first.self_modulate.g < 0.3 and first.self_modulate.b < 0.3)
	var alternate := 0
	var seen_first_bright := false
	var seen_second_bright := false
	var widest := 0.0
	for k in int(GlowPulse.PERIOD * 60.0 * 2.0):
		await process_frame
		var a := first.brightness()
		var b := second.brightness()
		widest = maxf(widest, absf(a - b))
		seen_first_bright = seen_first_bright or (a > 0.8 and b < 0.3)
		seen_second_bright = seen_second_bright or (b > 0.8 and a < 0.3)
	_check("they glow and dim in turn: each is bright while the other is dim", seen_first_bright and seen_second_bright, "largest difference %.2f" % widest)
	main.queue_free()
	await process_frame

	# ---- the real levels
	for id in LevelData.level_ids():
		var level_rows := LevelData.map(id)
		_check("%s: every pit has its sign" % id, PitSigns.missing(level_rows).is_empty(), str(PitSigns.missing(level_rows)))
	print("ALL PASS" if ok else "SOME FAILED")
	quit(0 if ok else 1)


func _to_rows(data: Dictionary) -> Array[String]:
	var out: Array[String] = []
	out.assign(data["tiles"])
	return out


func _collect_lights(node: Node, out: Array[GlowPulse]) -> void:
	if node is ExitDoor:
		return          # (the exit door's lamp is a glow too, but not a sign's)
	if node is GlowPulse:
		out.append(node)
	for child in node.get_children():
		_collect_lights(child, out)
