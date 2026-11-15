class_name LevelFile
extends RefCounted
## Reading, writing and checking level files (*.sablevel.json; the format is described in tools/level_editor/FORMAT.md).
## The game plays them (see LevelData.use_file()), and the level editor in tools/level_editor/ makes them.

# FORMAT_VERSION: the version written to files. Version 2 stores the tiles as CSV rows of tile numbers (see encode_rows());
# version 1 (a text row of map characters) is still read, and is written as version 2 the next time the level is saved.
const FORMAT_VERSION := 2
const OLDEST_FORMAT := 1

# MAX_NAME_LENGTH: longest name an object or the player may have (the player's is cut to Player.MAX_NAME_LENGTH anyway).
const MAX_NAME_LENGTH := 24


## A fresh, valid level: a floor with walls, the player at the left and the exit at the right.
static func new_level(cols: int = 60, rows: int = 24) -> Dictionary:
	var g := LevelGrid.new(cols, rows)
	g.fill(0, 0, cols - 1, 0, "#")
	g.fill(0, 0, 0, rows - 1, "#")
	g.fill(cols - 1, 0, cols - 1, rows - 1, "#")
	g.fill(1, rows - 4, cols - 2, rows - 1, "#")
	g.put(3, rows - 5, "P")
	g.put(cols - 4, rows - 5, "E")
	return {
		"format": FORMAT_VERSION,
		"meta": {"id": "my_level", "title": "NEW LEVEL", "next": ""},
		"grid": {"cols": cols, "rows": rows},
		"terrain": {"gravity_scale": 1.0, "fall_death_height": 700.0, "pit_death_delay": 0.5, "background": "background"},
		"player": {},
		"tiles": g.to_rows(),
		"objects": {},
		"minigames": [],
	}


## Parse the text of a level file. Returns {"ok": bool, "errors": Array[String], "data": Dictionary}. The data has every
## section present (missing ones are filled with empty or default values); errors list everything that is wrong.
static func parse(text: String) -> Dictionary:
	var result := {"ok": false, "errors": [] as Array[String], "data": {}}
	var json := JSON.new()
	if json.parse(text) != OK:
		result["errors"].append("Not valid JSON: %s (line %d)." % [json.get_error_message(), json.get_error_line()])
		return result
	if typeof(json.data) != TYPE_DICTIONARY:
		result["errors"].append("The file is not a JSON object.")
		return result
	var data: Dictionary = json.data
	var defaults := {"meta": {"id": "my_level", "title": "NEW LEVEL", "next": ""}, "grid": {}, "terrain": {}, "player": {}, "objects": {}}
	for key in defaults:
		if not data.has(key) or typeof(data[key]) != TYPE_DICTIONARY:
			data[key] = defaults[key]
	for key in ["tiles", "minigames"]:
		if not data.has(key) or typeof(data[key]) != TYPE_ARRAY:
			data[key] = []
	var errors: Array[String] = []
	var file_format := int(data.get("format", OLDEST_FORMAT))   # a file without a version is the old text format
	if file_format >= 2 and file_format <= FORMAT_VERSION:
		# the tiles are CSV rows of tile numbers: in memory they are map characters (one per tile)
		var decoded := decode_rows(data["tiles"], data.get("tile_keys", {}))
		data["tiles"] = decoded["rows"]
		errors.append_array(decoded["errors"])
	data.erase("tile_keys")
	data["format"] = FORMAT_VERSION if file_format >= OLDEST_FORMAT and file_format <= FORMAT_VERSION else file_format
	errors.append_array(validate(data))
	result["data"] = data
	result["errors"] = errors
	result["ok"] = errors.is_empty()
	return result


## Read and parse a level file from disk.
static func load_file(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {"ok": false, "errors": ["Cannot open %s (error %d)" % [path, FileAccess.get_open_error()]], "data": {}}
	return parse(f.get_as_text())


## The level as text, ready to write to a file. The tiles are written as CSV rows of tile numbers, and `tile_keys` lists the name
## of each number used, so the file can be read (and checked against the registry) without it.
static func to_text(data: Dictionary) -> String:
	var out := data.duplicate(true)
	var rows := tiles(data)
	out["tiles"] = encode_rows(rows)
	var grid: Dictionary = out.get("grid", {})
	out["grid"] = {"cols": int(grid.get("cols", 0)), "rows": int(grid.get("rows", 0))}   # whole numbers, not 105.0
	var keys := {}
	for row in rows:
		for i in row.length():
			var id := TileRegistry.id_for_char(row[i])
			if id > 0:
				keys[str(id)] = str(TileRegistry.kind_for_id(id).get("key", ""))
	out["tile_keys"] = keys
	out["format"] = FORMAT_VERSION
	return JSON.stringify(out, "\t", true) + "\n"


## Map rows (one character per tile, as the game uses them) as CSV rows of tile numbers, like "0,0,1,1,2". An unknown character is
## written as 0 (nothing).
static func encode_rows(rows: Array[String]) -> Array[String]:
	var out: Array[String] = []
	for row in rows:
		var ids := PackedStringArray()
		for i in row.length():
			ids.append(str(maxi(TileRegistry.id_for_char(row[i]), 0)))
		out.append(",".join(ids))
	return out


## The reverse of encode_rows(): CSV rows (spaces are ignored, so are blank trailing commas) to map rows. `keys` is the file's
## tile_keys (optional): a number whose key differs from the registry's is reported. Returns {"rows": Array[String], "errors":
## Array[String]}; an unknown tile number is reported and becomes nothing.
static func decode_rows(csv_rows: Array, keys: Variant = {}) -> Dictionary:
	var rows: Array[String] = []
	var errors: Array[String] = []
	var unknown := {}
	for r in csv_rows.size():
		var parts := str(csv_rows[r]).split(",")
		var line := ""
		for p in parts:
			var token := p.strip_edges()
			if token == "":
				continue
			if not token.is_valid_int():
				errors.append("Row %d: '%s' is not a tile number." % [r, token])
				line += "."
				continue
			var ch := TileRegistry.char_for_id(int(token))
			if ch == "":
				unknown[int(token)] = true
				ch = "."
			line += ch
		rows.append(line)
	for id in unknown:
		errors.append("Unknown tile number %d (it is not in levels/common/tile_registry.json); those tiles became empty." % id)
	if typeof(keys) == TYPE_DICTIONARY:
		for id_text in (keys as Dictionary):
			var kind := TileRegistry.kind_for_id(int(str(id_text)))
			if not kind.is_empty() and str(kind["key"]) != str((keys as Dictionary)[id_text]):
				errors.append("Tile %s is '%s' in the file but '%s' in the registry." % [str(id_text), str((keys as Dictionary)[id_text]), str(kind["key"])])
	return {"rows": rows, "errors": errors}


## Write a level file. Returns OK or an Error code.
static func save_file(path: String, data: Dictionary) -> Error:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(to_text(data))
	return OK


## Everything wrong with a level (empty if it is playable). These are the rules the game relies on; the editor shows them.
static func validate(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if int(data.get("format", 0)) < OLDEST_FORMAT or int(data.get("format", 0)) > FORMAT_VERSION:
		errors.append("Unsupported format version %s (this game reads versions %d to %d)." % [str(data.get("format")), OLDEST_FORMAT, FORMAT_VERSION])
	var tiles: Array = data.get("tiles", [])
	var cols := int((data.get("grid", {}) as Dictionary).get("cols", 0))
	var rows := int((data.get("grid", {}) as Dictionary).get("rows", 0))
	if tiles.size() != rows or rows < 3 or cols < 3:
		errors.append("The grid says %d x %d but there are %d rows of tiles." % [cols, rows, tiles.size()])
		return errors
	for r in tiles.size():
		if typeof(tiles[r]) != TYPE_STRING or (tiles[r] as String).length() != cols:
			errors.append("Row %d is not exactly %d characters." % [r, cols])
	if not errors.is_empty():
		return errors
	var spawns := 0
	var exits := 0
	var gates := {}
	for row in tiles:
		spawns += (row as String).count("P")
		exits += (row as String).count("E")
	if spawns != 1:
		errors.append("There must be exactly one player spawn (P); there are %d." % spawns)
	if exits != 1:
		errors.append("There must be exactly one exit (E); there are %d." % exits)
	var rows_text: Array[String] = []
	for row in tiles:
		rows_text.append(row)
		for ch in (row as String):
			if ch >= "1" and ch <= "9":
				gates[ch] = true
	var terminals := LevelData.terminals_in(rows_text)
	for t in terminals:
		if not gates.has(t["laser"]):
			errors.append("A lock terminal at (%d, %d) has no laser gate." % [t["c"], t["r"]])
	var terminal_gates := {}
	for t in terminals:
		terminal_gates[t["laser"]] = true
	for id in gates:
		if not terminal_gates.has(id):
			errors.append("Laser gate %s has no lock terminal." % id)
	for problem in LevelData.bros_without_room(rows_text):
		errors.append("AI Bro %s" % problem)
	return errors


## The tiles of a level as an Array[String] (what Level and LevelData work with).
static func tiles(data: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for row in data.get("tiles", []):
		out.append(str(row))
	return out


## A section value with its default: player and terrain values fall back to the game's own defaults when missing.
static func value(data: Dictionary, section: String, key: String, fallback: Variant) -> Variant:
	var s: Variant = data.get(section, {})
	if typeof(s) == TYPE_DICTIONARY and (s as Dictionary).has(key):
		return (s as Dictionary)[key]
	return fallback


## The extra information stored for the object on tile (c, r): {} if there is none. Keys: "type", "name", "props".
static func object_at(data: Dictionary, c: int, r: int) -> Dictionary:
	var objects: Variant = data.get("objects", {})
	if typeof(objects) == TYPE_DICTIONARY and (objects as Dictionary).has("%d,%d" % [c, r]):
		var o: Variant = (objects as Dictionary)["%d,%d" % [c, r]]
		if typeof(o) == TYPE_DICTIONARY:
			return o
	return {}


## The definition of a minigame by id, or {} if the level has none with that id.
static func minigame(data: Dictionary, id: String) -> Dictionary:
	for m in data.get("minigames", []):
		if typeof(m) == TYPE_DICTIONARY and str((m as Dictionary).get("id", "")) == id:
			return m
	return {}
