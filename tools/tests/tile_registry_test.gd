extends SceneTree
## The tile registry (levels/common/tile_registry.json) and the CSV tile format: the registry is consistent, the built-in tiles keep
## their numbers and characters, level files round-trip, kinds that are only registry entries work in the game, and nothing
## breaks with thousands of tile kinds. Exits non-zero on failure.
## Run: godot_console --headless --fixed-fps 60 --path . --script res://tools/tests/tile_registry_test.gd

# SYNTHETIC_KINDS: how many made-up kinds the scale test adds on top of the registry file ("1000+ types of tiles").
const SYNTHETIC_KINDS := 2500

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


func _main() -> void:
	InputSetup.register()
	# ---- the registry file
	var kinds := TileRegistry.kinds()
	var ids := {}
	var keys := {}
	var chars := {}
	var bad := []
	for k in kinds:
		if ids.has(int(k["id"])) or keys.has(str(k["key"])) or chars.has(str(k["char"])):
			bad.append(k["key"])
		ids[int(k["id"])] = true
		keys[str(k["key"])] = true
		chars[str(k["char"])] = true
		if not k.has("name") or not k.has("group") or (not k.has("char_builtin") and not k.has("type") and not k.has("behavior") and k["id"] > 99):
			if k["id"] > 99 and not k.has("behavior"):
				bad.append("%s has no behavior" % k["key"])
	_check("every tile kind has its own id, key and character", bad.is_empty(), str(bad))
	_check("there is room for more than the game's own tiles", kinds.size() > 100, str(kinds.size()))
	var permanent := {1: "#", 2: "=", 3: "H", 4: "X", 6: "^", 8: "A", 26: "P", 27: "E", 28: "K", 29: "L", 30: "1", 38: "9", 39: "B", 0: "."}
	var moved := []
	for id in permanent:
		if TileRegistry.char_for_id(int(id)) != permanent[id]:
			moved.append(id)
	_check("the game's own tiles keep their numbers (ground = 1, ladder = 3, AI Bro = 39 ...)", moved.is_empty(), str(moved))
	var generic := kinds.filter(func(k: Dictionary) -> bool: return TileRegistry.is_generic(str(k["char"])))
	_check("kinds without a built-in character have a behaviour and a sprite", generic.size() > 50 and generic.all(func(k: Dictionary) -> bool: return str(k.get("behavior", "")) in ["solid", "decor", "machine", "barrier", "powerup"] and (k.get("sprite", {}) as Dictionary).size() > 0), str(generic.size()))
	_check("a generic kind's character is outside everything the game types", generic.all(func(k: Dictionary) -> bool: return str(k["char"]).unicode_at(0) >= TileRegistry.PRIVATE_BASE))
	var solid := generic.filter(func(k: Dictionary) -> bool: return str(k["behavior"]) == "solid")
	var decor := generic.filter(func(k: Dictionary) -> bool: return str(k["behavior"]) == "decor")
	_check("physics: a solid kind is solid, a decor kind is nothing, built-in tiles are themselves", TileRegistry.physics_char(str(solid[0]["char"])) == TileRegistry.SOLID_CHAR and TileRegistry.physics_char(str(decor[0]["char"])) == "." and TileRegistry.physics_char("#") == "#" and TileRegistry.physics_char("B") == "B")

	# ---- the CSV format
	var rows: Array[String] = ["#" + str(solid[0]["char"]) + str(decor[0]["char"]) + "B.", "..1.."]
	var csv := LevelFile.encode_rows(rows)
	_check("tiles are CSV rows of tile numbers", csv[0] == "1,%d,%d,39,0" % [int(solid[0]["id"]), int(decor[0]["id"])] and csv[1] == "0,0,30,0,0", str(csv))
	var back := LevelFile.decode_rows(csv)
	_check("and decode back to the same map", back["rows"] == rows and back["errors"].is_empty())
	var odd := LevelFile.decode_rows(["1, 1,,0,", "0,x,0,0"])
	_check("spaces and blank entries are ignored, a bad entry is reported", odd["rows"][0] == "##." and not (odd["errors"] as Array).is_empty())
	var unknown := LevelFile.decode_rows(["1,99999,0"])
	_check("an unknown tile number is reported and becomes empty", unknown["rows"][0] == "#.." and (unknown["errors"] as Array).size() == 1, str(unknown["errors"]))
	var level := LevelFile.new_level(30, 12)
	var text := LevelFile.to_text(level)
	_check("a level file stores the tile numbers and what each is called", text.contains('"tile_keys"') and text.contains('"format": 2') and text.contains('"1,'), "")
	var parsed := LevelFile.parse(text)
	_check("and reads back exactly", parsed["ok"] and LevelFile.tiles(parsed["data"]) == LevelFile.tiles(level), str(parsed["errors"]))
	_check("writing it again gives the same text", LevelFile.to_text(parsed["data"]) == text)
	var wrong_key := text.replace('"1": "ground"', '"1": "banana"')
	_check("a number whose name differs from the registry is reported", not LevelFile.parse(wrong_key)["ok"])
	var old_text := '{"format": 1, "grid": {"cols": 6, "rows": 6}, "tiles": ["######", "#....#", "#.P.E#", "######", "######", "######"]}'
	var old := LevelFile.parse(old_text)
	_check("a version 1 file (text rows) is still read, and written as version 2", LevelFile.tiles(old["data"])[2] == "#.P.E#" and LevelFile.to_text(old["data"]).contains('"format": 2'))
	for id in LevelData.level_ids():
		var d := LevelData.data_for(id)
		var again := LevelFile.parse(LevelFile.to_text(d))
		_check("level %s round-trips through the file format" % id, again["ok"] and LevelFile.tiles(again["data"]) == LevelFile.tiles(d), str(again["errors"]))

	# ---- thousands of kinds
	var many: Array = []
	for i in SYNTHETIC_KINDS:
		many.append({"id": 20000 + i, "key": "synthetic_%d" % i, "name": "Synthetic %d" % i, "group": "Synthetic", "behavior": "solid" if i % 3 == 0 else "decor", "sprite": {"tile": "ground_single"}})
	var before := TileRegistry.kinds().size()
	var t0 := Time.get_ticks_msec()
	TileRegistry.add_kinds(many)
	_check("the registry takes %d more kinds" % SYNTHETIC_KINDS, TileRegistry.kinds().size() == before + SYNTHETIC_KINDS, "%d kinds, %d ms" % [TileRegistry.kinds().size(), Time.get_ticks_msec() - t0])
	var big_rows: Array[String] = []
	var used := 0
	for r in 12:
		var line := ""
		for c in 400:
			var id := 20000 + ((r * 400 + c) * 7) % SYNTHETIC_KINDS
			line += TileRegistry.char_for_id(id)
			used += 1
		big_rows.append(line)
	var big_csv := LevelFile.encode_rows(big_rows)
	_check("a map using thousands of different tiles survives the CSV round trip", LevelFile.decode_rows(big_csv)["rows"] == big_rows)
	var distinct := {}
	for line in big_rows:
		for i in line.length():
			distinct[line[i]] = true
	_check("with %d different kinds in it" % distinct.size(), distinct.size() > 1000, str(distinct.size()))
	var physics := TileRegistry.physics_rows(big_rows)
	_check("and physics_rows() reduces them all to solid or nothing", physics.size() == 12 and physics.all(func(row: String) -> bool: return row.count("@") + row.count(".") == row.length()))
	_check("a kind added in code is found by key, number and character", TileRegistry.kind_for_key("synthetic_5")["id"] == 20005 and TileRegistry.id_for_char(TileRegistry.char_for_id(20005)) == 20005)

	# ---- the game builds a level made of registry-only kinds: a floor of solid blocks, a decor picture
	var floor_kind: Dictionary = solid[0]
	var decor_kind: Dictionary = decor[0]
	var lv := LevelFile.new_level(30, 14)
	var tiles: Array = lv["tiles"]
	for r in tiles.size():
		tiles[r] = (tiles[r] as String).replace("#", str(floor_kind["char"]))
	var row10: String = tiles[10]
	tiles[10] = row10.substr(0, 8) + str(decor_kind["char"]) + row10.substr(9)
	lv["meta"] = {"id": "generic", "title": "GENERIC", "next": ""}
	_check("such a level is valid", LevelFile.validate(lv).is_empty(), str(LevelFile.validate(lv)))
	var path := ProjectSettings.globalize_path("user://generic_kinds.sablevel.json")
	LevelFile.save_file(path, lv)
	OS.set_environment("SABOTAGE_LEVEL_FILE", path)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _wait(60)
	var player: Player
	var level_node: Level
	for n in main.get_children():
		if n is Player:
			player = n
		elif n is Level:
			level_node = n
	_check("the player stands on a floor made of a registry-only solid kind", player != null and player.is_on_floor(), "y=%.0f" % player.global_position.y)
	var pictures := 0
	for n in level_node.get_children():
		if n is Sprite2D and (n as Sprite2D).position == Vector2(8 * Level.T, 10 * Level.T):
			pictures += 1
	_check("and the decor kind is drawn where it was placed", pictures == 1, str(pictures))
	main.queue_free()
	await _wait(5)
	OS.set_environment("SABOTAGE_LEVEL_FILE", "")
	LevelData.file_data = {}
	DirAccess.remove_absolute(path)

	# ---- CSV import and export from the command line tool
	var file := "user://csv_cli.sablevel.json"
	var csv_file := "user://csv_cli.csv"
	LevelCli.run(["new", file, "--cols", "20", "--rows", "10"])
	var r := LevelCli.run(["set-tile", file, "5", "5", str(decor[0]["key"])])
	_check("a tile can be set by its key", r["ok"], str(r))
	r = LevelCli.run(["set-tile", file, "6", "5", "1"])
	_check("or by its number", r["ok"])
	r = LevelCli.run(["set-tile", file, "7", "5", "#"])
	_check("or by its built-in character", r["ok"])
	r = LevelCli.run(["set-tile", file, "8", "5", "no_such_tile"])
	_check("an unknown tile is refused", not r["ok"])
	r = LevelCli.run(["export-csv", file, csv_file])
	_check("the tiles export as a CSV file", r["ok"] and FileAccess.get_file_as_string(csv_file).split("\n")[5].split(",")[5] == str(int(decor[0]["id"])), str(r))
	r = LevelCli.run(["new", "user://csv_cli2.sablevel.json", "--cols", "12", "--rows", "12"])
	r = LevelCli.run(["import-csv", "user://csv_cli2.sablevel.json", csv_file])
	var imported := LevelFile.load_file("user://csv_cli2.sablevel.json")
	_check("and a CSV file imports as the level's tiles", r["ok"] and LevelFile.tiles(imported["data"]) == LevelFile.tiles(LevelFile.load_file(file)["data"]) and int(imported["data"]["grid"]["cols"]) == 20, str(r))
	r = LevelCli.run(["catalog", "tiles", "--search", "lamp"])
	_check("the tile catalog can be searched", r["ok"] and r["matched"] >= 2 and r["tile_count"] > 100, str(r.get("matched")))

	print("ALL PASS" if ok else "SOME FAILED")
	quit(0 if ok else 1)
