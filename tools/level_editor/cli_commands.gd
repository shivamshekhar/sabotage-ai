class_name LevelCli
extends RefCounted
## The command-line side of the level editor: everything a person can do in the editor window with a level file, as commands that
## print JSON, so a script or an AI assistant can create and check levels without the GUI. Run it with
## `tools/level_cli.sh <command> ...` (see tools/level_editor/CLI.md). `run()` takes the arguments and returns the result; the
## `level_cli.gd` script prints it.
##
## File paths: absolute, `res://...`, `user://...`, or relative to the project root. Commands that change a file change it in
## place and report any problems the level now has.

# CATALOG_PATH: the list of everything a level can contain, with default values (also what the editor is built from).
const CATALOG_PATH := "res://tools/level_editor/catalog.json"

# DEFAULT_COLS / DEFAULT_ROWS: the size of a level made with `new` when none is given, in tiles.
const DEFAULT_COLS := 60
const DEFAULT_ROWS := 24

# DEFAULT_THEME: the decor machines `from-plan` places along the floor when no --theme is given.
const DEFAULT_THEME := ["S", "G", "R", "M", "G"]

const HELP := """level_cli: create and check level files (*.sablevel.json) from the command line.
Every command prints one JSON object; its "ok" field says whether it worked. File paths are absolute, res://, user:// or relative
to the project root. Commands that change a file change it in place and add the level's current "problems" to the result.

Where levels live: levels/<id>/level.sablevel.json, with the level's background layers in levels/<id>/background/ (levels/common/
holds the art every level shares). Give `new` / `from-plan` a file of that form and the level's id is the folder name and its
background/ folder is created (copied from level_01's, or --background-from <id>); `needs_import` in the result says Godot has to
import the copied images (tools/level_cli.sh does that for you). Chain levels with `set <file> meta next=<id>`.

Make a level
  new <file> [--cols N] [--rows N] [--id ID] [--title TEXT] [--next ID]      an empty level: floor, walls, spawn, exit
  from-plan <file> --plan <json | @planfile> [--theme S,G,R,M] [--liquid A|F|N|W] [--id ID] [--title TEXT] [--next ID]
                                                                               a whole level built from pieces (see `pieces`)
  convert <level id> <file>                                                   an existing level (or `test`) copied to a new file
  list                                                                        the levels of the game, in order of id
  upgrade <file>                                                              rewrite a level file in the current format
  export-csv <file> <csv> | import-csv <file> <csv>                           the tiles as a CSV grid of tile numbers (spreadsheet, Tiled...)
Edit a level
  set-tile <file> <col> <row> <tile>             one tile: a tile number (12), key (ground, decor_lamp_pole_green) or built-in map character (#)
  fill <file> <col0> <row0> <col1> <row1> <tile> a rectangle of tiles ('0' / '.' erases)
  place <file> <type> <col> <row> [--name TEXT] [--prop key=value ...] [--id DIGIT --height N]
                                                 put an object: ai_bro, checkpoint, exit, player_spawn, lock_terminal, laser_gate
                                                 (laser_gate needs --id 1-9 and --height: it grows upward from <row>), tank_settings
  remove <file> <col> <row>                      erase the tile and forget the object there
  set <file> player|terrain|meta key=value ...   player values, terrain values (gravity_scale ...), title/id/next
  minigame <file> add --id ID --kind KIND [--name TEXT] [--param key=value ...] [--question "q|right|wrong1|wrong2|wrong3" ...]
  minigame <file> list | remove --id ID
Check a level
  info <file> [--solve]      size, counts of everything, problems (and whether it can be finished)
  validate <file>            the problems only (exit code 1 if there are any)
  solve <file>               can the exit be reached, are there dead ends, do the laser gates work in order (exit code 1 if not)
  show <file> [--rows a-b] [--cols a-b]   the tiles as text with a column ruler
Learn what exists
  catalog [section]          tiles (--group X, --search X, --limit N: there are many), objects and their values, player/terrain values, minigame kinds
  pieces                     the pieces from-plan understands, with an example plan
  help
"""

const EXAMPLE_PLAN := [["flat", 8, "PK"], ["hurdle"], ["flat", 4], ["pit", 3, "A"], ["flat", 4], ["spikes"], ["flat", 3, "K"], ["rise", 5], ["flat", 8, "B"], ["tunnel", "1"], ["flat", 7, "B"], ["drop", 3], ["flat", 6, "K"], ["exit"]]


## Run one command. `args` are the words after the program name. Returns {"ok": bool, ...}; the command's own data is in the other keys.
static func run(args: Array) -> Dictionary:
	if args.is_empty():
		return {"ok": true, "help": HELP}
	var command := str(args[0])
	var parsed := _parse(args.slice(1))
	var pos: Array = parsed["pos"]
	var flags: Dictionary = parsed["flags"]
	match command:
		"help", "--help", "-h":
			return {"ok": true, "help": HELP}
		"catalog":
			return _catalog(str(pos[0]) if pos.size() > 0 else "", flags)
		"pieces":
			return _pieces()
		"list":
			return _list()
		"upgrade":
			return _edit(pos, 1, func(_d: Dictionary) -> Dictionary: return {"ok": true, "note": "rewritten in the current file format (CSV tile numbers)"})
		"export-csv":
			return _export_csv(pos)
		"import-csv":
			return _edit(pos, 2, func(d: Dictionary) -> Dictionary: return _import_csv_cmd(d, pos))
		"new":
			return _new(pos, flags)
		"from-plan":
			return _from_plan(pos, flags)
		"convert":
			return _convert(pos)
		"info":
			return _info(pos, flags)
		"validate":
			return _validate(pos)
		"solve":
			return _solve(pos)
		"show":
			return _show(pos, flags)
		"set-tile":
			return _edit(pos, 4, func(d: Dictionary) -> Dictionary: return _set_tile_cmd(d, pos))
		"fill":
			return _edit(pos, 6, func(d: Dictionary) -> Dictionary: return _fill_cmd(d, pos))
		"place":
			return _edit(pos, 4, func(d: Dictionary) -> Dictionary: return _place_cmd(d, pos, flags))
		"remove":
			return _edit(pos, 3, func(d: Dictionary) -> Dictionary: return _remove_cmd(d, pos))
		"set":
			return _edit(pos, 3, func(d: Dictionary) -> Dictionary: return _set_cmd(d, pos))
		"minigame":
			return _edit(pos, 2, func(d: Dictionary) -> Dictionary: return _minigame_cmd(d, pos, flags))
	return {"ok": false, "error": "Unknown command '%s'. Run `help`." % command}


# ---------------------------------------------------------------------------------------------------------------------
# argument parsing and file helpers
# ---------------------------------------------------------------------------------------------------------------------

## Split words into positional arguments and `--flag value` / `--flag=value` flags (a flag may repeat: its values are listed).
static func _parse(words: Array) -> Dictionary:
	var pos: Array = []
	var flags := {}
	var i := 0
	while i < words.size():
		var w := str(words[i])
		if w.begins_with("--") and w.length() > 2:
			var key := w.substr(2)
			var value := "true"
			if key.contains("="):
				value = key.get_slice("=", 1)
				key = key.get_slice("=", 0)
			elif i + 1 < words.size() and not str(words[i + 1]).begins_with("--"):
				value = str(words[i + 1])
				i += 1
			if not flags.has(key):
				flags[key] = []
			flags[key].append(value)
		else:
			pos.append(w)
		i += 1
	return {"pos": pos, "flags": flags}


static func _flag(flags: Dictionary, key: String, fallback: String = "") -> String:
	if flags.has(key):
		return str(flags[key][0])
	return fallback


static func _path(p: String) -> String:
	if p.begins_with("res://") or p.begins_with("user://") or p.is_absolute_path():
		return p
	return "res://" + p


static func _load(path: String) -> Dictionary:
	var loaded := LevelFile.load_file(_path(path))
	if (loaded["data"] as Dictionary).is_empty():
		return {"ok": false, "error": "Cannot read %s: %s" % [path, loaded["errors"]]}
	return {"ok": true, "data": loaded["data"]}


static func _save(path: String, data: Dictionary) -> Dictionary:
	var target := _path(path)
	var dir := target.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	var err := LevelFile.save_file(target, data)
	if err != OK:
		return {"ok": false, "error": "Cannot write %s (error %d)" % [path, err]}
	return {"ok": true}


## Load a file, apply `change`, save, and report the level's problems. `needed` is how many positional arguments the command needs.
static func _edit(pos: Array, needed: int, change: Callable) -> Dictionary:
	if pos.size() < needed:
		return {"ok": false, "error": "Missing arguments. Run `help`."}
	var loaded := _load(str(pos[0]))
	if not loaded["ok"]:
		return loaded
	var data: Dictionary = loaded["data"]
	var result: Dictionary = change.call(data)
	if not result.get("ok", false):
		return result
	var saved := _save(str(pos[0]), data)
	if not saved["ok"]:
		return saved
	result["problems"] = LevelFile.validate(data)
	return result


static func _catalog_data() -> Dictionary:
	var text := FileAccess.get_file_as_string(CATALOG_PATH)
	var parsed: Variant = JSON.parse_string(text)
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


## The map character a command-line tile argument means: all digits = a tile number (as in the CSV files), one other character = that
## map character, anything else = a tile key such as "ground" (see `catalog tiles`). Returns "" if there is no such tile.
static func _tile_char(text: String) -> String:
	if text.is_valid_int():
		return TileRegistry.char_for_id(int(text))
	if text.length() == 1:
		return text if not TileRegistry.kind_for_char(text).is_empty() else ""
	return str(TileRegistry.kind_for_key(text).get("char", ""))


## The catalog entry (a Dictionary) in `section` whose `field` equals `value`, or {}. Placeable objects are kinds of the tile
## registry (levels/common/tile_registry.json); the other sections are in the editor catalog.
static func _entry(section: String, field: String, value: String) -> Dictionary:
	if section == "objects":
		for k in TileRegistry.kinds():
			if str((k as Dictionary).get(field, "")) == value:
				return k
	for e in _catalog_data().get(section, []):
		if str((e as Dictionary).get(field, "")) == value:
			return e
	return {}


## A command-line text value as the type the catalog says (float, int, bool, string, choice).
static func _coerce(prop: Dictionary, text: String) -> Variant:
	match str(prop.get("type", "string")):
		"float":
			return float(text)
		"int":
			return int(text)
		"bool":
			return text.to_lower() in ["true", "1", "yes"]
	return text


## Check and convert key=value words against a list of catalog props. Returns {"ok", "values", "error"}.
static func _values(props: Array, words: Array, what: String) -> Dictionary:
	var out := {}
	for w in words:
		var text := str(w)
		if not text.contains("="):
			return {"ok": false, "error": "'%s' is not key=value." % text}
		var key := text.get_slice("=", 0)
		var raw := text.substr(key.length() + 1)
		var found := {}
		for p in props:
			if str((p as Dictionary)["key"]) == key:
				found = p
		if found.is_empty():
			var keys: Array = []
			for p in props:
				keys.append((p as Dictionary)["key"])
			return {"ok": false, "error": "%s has no value '%s'. Its values: %s" % [what, key, ", ".join(PackedStringArray(keys))]}
		var value: Variant = _coerce(found, raw)
		if found.has("options") and not (found["options"] as Array).has(str(value)):
			return {"ok": false, "error": "%s '%s' must be one of %s." % [what, key, str(found["options"])]}
		out[key] = value
	return {"ok": true, "values": out}


## Only the values that differ from the catalog defaults (that is all a level file stores).
static func _changed_only(props: Array, values: Dictionary) -> Dictionary:
	var out := {}
	for p in props:
		var key := str((p as Dictionary)["key"])
		if values.has(key) and values[key] != (p as Dictionary).get("default"):
			out[key] = values[key]
	return out


static func _row_set(data: Dictionary, c: int, r: int, ch: String) -> String:
	var tiles: Array = data["tiles"]
	if r < 0 or r >= tiles.size() or c < 0 or c >= (tiles[r] as String).length():
		return "Tile (%d, %d) is outside the %d x %d level." % [c, r, (tiles[0] as String).length(), tiles.size()]
	var row: String = tiles[r]
	tiles[r] = row.substr(0, c) + ch + row.substr(c + 1)
	return ""


static func _counts(rows: Array[String]) -> Dictionary:
	var n := {"bros": 0, "checkpoints": 0, "lasers": 0, "terminals": 0, "pit_cells": 0, "spike_cells": 0, "ladder_cells": 0, "ledge_cells": 0}
	var gates := {}
	for line in rows:
		n["bros"] += line.count("B")
		n["checkpoints"] += line.count("K")
		n["terminals"] += line.count("L")
		for ch in line:
			if ch >= "1" and ch <= "9":
				gates[ch] = true
		for ch in "AFNW":
			n["pit_cells"] += line.count(ch)
		n["spike_cells"] += line.count("^") + line.count("v")
		n["ladder_cells"] += line.count("H")
		n["ledge_cells"] += line.count("=")
	n["lasers"] = gates.size()
	return n


# ---------------------------------------------------------------------------------------------------------------------
# commands that make a level
# ---------------------------------------------------------------------------------------------------------------------

static func _meta(data: Dictionary, flags: Dictionary) -> void:
	var meta: Dictionary = data["meta"]
	if flags.has("id"):
		meta["id"] = _flag(flags, "id")
	if flags.has("title"):
		meta["title"] = _flag(flags, "title")
	if flags.has("next"):
		meta["next"] = _flag(flags, "next")


## For a file at levels/<id>/level.sablevel.json: the level's id is the folder name (unless --id is given) and the level gets its
## own background/ folder, copied from another level's (--background-from <id>, default the first level) if it has none yet.
## Returns true if the background images were copied, which Godot has to import before the game can show them (the
## `tools/level_cli.sh` wrapper does that).
static func _setup_level_folder(path: String, data: Dictionary, flags: Dictionary) -> bool:
	var target := _path(path)
	if not target.begins_with(LevelData.LEVELS_DIR) or target.get_file() != LevelData.LEVEL_FILE_NAME:
		return false
	var folder := target.get_base_dir()
	if not flags.has("id"):
		(data["meta"] as Dictionary)["id"] = folder.get_file()
	var background := folder + "/background"
	if DirAccess.dir_exists_absolute(background):
		return false
	var source := LevelData.level_dir(_flag(flags, "background-from", LevelData.DEFAULT_ID)) + "background"
	DirAccess.make_dir_recursive_absolute(background)
	var copied := false
	for f in DirAccess.get_files_at(source):
		if f.ends_with(".png"):
			DirAccess.copy_absolute(source + "/" + f, background + "/" + f)
			copied = true
	return copied


static func _new(pos: Array, flags: Dictionary) -> Dictionary:
	if pos.is_empty():
		return {"ok": false, "error": "Usage: new <file> [--cols N] [--rows N] ..."}
	var cols := int(_flag(flags, "cols", str(DEFAULT_COLS)))
	var rows := int(_flag(flags, "rows", str(DEFAULT_ROWS)))
	if cols < 8 or rows < 8:
		return {"ok": false, "error": "A level must be at least 8 x 8 tiles."}
	var data := LevelFile.new_level(cols, rows)
	_meta(data, flags)
	var needs_import := _setup_level_folder(str(pos[0]), data, flags)
	var saved := _save(str(pos[0]), data)
	if not saved["ok"]:
		return saved
	return {"ok": true, "file": str(pos[0]), "cols": cols, "rows": rows, "needs_import": needs_import, "problems": LevelFile.validate(data)}


## export-csv <file> <csv>: the level's tiles as a plain CSV grid of tile numbers (open it in a spreadsheet or any tile editor).
static func _export_csv(pos: Array) -> Dictionary:
	if pos.size() < 2:
		return {"ok": false, "error": "Usage: export-csv <level file> <csv file>"}
	var loaded := _load(str(pos[0]))
	if not loaded["ok"]:
		return loaded
	var rows := LevelFile.encode_rows(LevelFile.tiles(loaded["data"]))
	var f := FileAccess.open(_path(str(pos[1])), FileAccess.WRITE)
	if f == null:
		return {"ok": false, "error": "Cannot write %s" % str(pos[1])}
	f.store_string("\n".join(rows) + "\n")
	return {"ok": true, "csv": str(pos[1]), "rows": rows.size()}


## import-csv <file> <csv>: replace the level's tiles with a CSV grid of tile numbers (the size of the level follows the CSV).
static func _import_csv_cmd(data: Dictionary, pos: Array) -> Dictionary:
	var text := FileAccess.get_file_as_string(_path(str(pos[1])))
	if text == "":
		return {"ok": false, "error": "Cannot read %s" % str(pos[1])}
	var csv_rows: Array = []
	for line in text.split("\n"):
		if line.strip_edges() != "":
			csv_rows.append(line)
	var decoded := LevelFile.decode_rows(csv_rows)
	if not (decoded["errors"] as Array).is_empty():
		return {"ok": false, "error": "The CSV has problems.", "problems": decoded["errors"]}
	var rows: Array = decoded["rows"]
	for r in rows:
		if (r as String).length() != (rows[0] as String).length():
			return {"ok": false, "error": "The CSV rows are not all the same length."}
	data["tiles"] = rows
	data["grid"] = {"cols": (rows[0] as String).length(), "rows": rows.size()}
	return {"ok": true, "cols": (rows[0] as String).length(), "rows": rows.size()}


static func _list() -> Dictionary:
	var levels: Array = []
	for id in LevelData.level_ids():
		var data := LevelData.data_for(id)
		var rows := LevelFile.tiles(data)
		levels.append({"id": id, "title": LevelData.title(id), "next": LevelData.next_id(id), "cols": (data["grid"] as Dictionary).get("cols", 0),
			"rows": rows.size(), "file": LevelData.file_path(id), "background": LevelData.background_dir(id)})
	return {"ok": true, "default": LevelData.DEFAULT_ID, "levels": levels}


static func _check_plan(plan: Array) -> String:
	if plan.is_empty():
		return "The plan is empty."
	var gates := {}
	var exits := 0
	for i in plan.size():
		var entry: Variant = plan[i]
		if typeof(entry) != TYPE_ARRAY or (entry as Array).is_empty():
			return "Plan entry %d is not a list like [\"flat\", 8]." % i
		var kind := str((entry as Array)[0])
		if not LevelData.SEQ_PIECES.has(kind):
			return "Plan entry %d: unknown piece '%s'. Run `pieces`." % [i, kind]
		if kind == "exit":
			exits += 1
			if i != plan.size() - 1:
				return "The exit piece must be the last entry."
		if ["flat", "pit", "stones", "rise", "climb", "drop"].has(kind) and (entry as Array).size() < 2:
			return "Plan entry %d ('%s') needs a number." % [i, kind]
		if kind == "tunnel":
			if (entry as Array).size() < 2 or not str((entry as Array)[1]) in ["1", "2", "3", "4", "5", "6", "7", "8", "9"]:
				return "Plan entry %d: a tunnel needs a laser id 1-9, e.g. [\"tunnel\", \"1\"]." % i
			if gates.has(str((entry as Array)[1])):
				return "Laser id %s is used by two tunnels." % str((entry as Array)[1])
			gates[str((entry as Array)[1])] = true
	if exits != 1:
		return "The plan must end with exactly one [\"exit\"]."
	return ""


static func _from_plan(pos: Array, flags: Dictionary) -> Dictionary:
	if pos.is_empty() or not flags.has("plan"):
		return {"ok": false, "error": "Usage: from-plan <file> --plan <json or @planfile> [--theme S,G,R,M] [--liquid A]"}
	var text := _flag(flags, "plan")
	if text.begins_with("@"):
		text = FileAccess.get_file_as_string(_path(text.substr(1)))
	var plan: Variant = JSON.parse_string(text)
	if typeof(plan) != TYPE_ARRAY:
		return {"ok": false, "error": "--plan is not a JSON list of pieces."}
	var bad := _check_plan(plan)
	if bad != "":
		return {"ok": false, "error": bad}
	var machines: Array = DEFAULT_THEME
	if flags.has("theme"):
		machines = _flag(flags, "theme").split(",")
	var built := LevelData.seq_build_plan(plan, machines, _flag(flags, "liquid", "A"), str(pos[0]))
	var rows: Array = built["rows"]
	var data := LevelFile.new_level(8, 8)
	data["grid"] = {"cols": (rows[0] as String).length(), "rows": rows.size()}
	data["tiles"] = rows
	_meta(data, flags)
	var needs_import := _setup_level_folder(str(pos[0]), data, flags)
	var saved := _save(str(pos[0]), data)
	if not saved["ok"]:
		return saved
	return {"ok": true, "file": str(pos[0]), "cols": (rows[0] as String).length(), "rows": rows.size(), "needs_import": needs_import, "problems": LevelFile.validate(data)}


static func _convert(pos: Array) -> Dictionary:
	if pos.size() < 2:
		return {"ok": false, "error": "Usage: convert <level id> <file>"}
	var id := str(pos[0])
	if id == LevelData.FILE_ID or not LevelData.has_level(id):
		return {"ok": false, "error": "No level '%s'. Ids: %s" % [id, str(LevelData.ids())]}
	var rows := LevelData.map(id)
	var data := LevelFile.new_level(8, 8)
	data["grid"] = {"cols": rows[0].length(), "rows": rows.size()}
	data["tiles"] = rows
	data["meta"] = {"id": id, "title": LevelData.title(id), "next": LevelData.next_id(id)}
	var saved := _save(str(pos[1]), data)
	if not saved["ok"]:
		return saved
	return {"ok": true, "file": str(pos[1]), "cols": rows[0].length(), "rows": rows.size(), "problems": LevelFile.validate(data)}


# ---------------------------------------------------------------------------------------------------------------------
# commands that check a level
# ---------------------------------------------------------------------------------------------------------------------

static func _solve_report(rows: Array[String]) -> Dictionary:
	var t0 := Time.get_ticks_msec()
	var solver := LevelSolver.new(rows)
	solver.solve()
	var route := solver.route()
	var stuck := solver.stuck_nodes()
	var report := {"exit_reachable": not route.is_empty(), "route_steps": route.size(), "nodes": solver.nodes.size(),
		"dead_end_spots": stuck.size(), "dead_end_examples": [] as Array}
	for p in stuck.slice(0, 5):
		(report["dead_end_examples"] as Array).append("tile column %d, row %d" % [int(p.x / 70.0), int(p.y / 70.0) - 1])
	# laser gates: all on = no finish; the computer for gate k can be reached while gates k.. are on
	var gate_ids := {}
	for line in rows:
		for ch in line:
			if ch >= "1" and ch <= "9":
				gate_ids[ch] = true
	var ids: Array = gate_ids.keys()
	ids.sort()
	var gate_problems: Array = []
	if not ids.is_empty():
		if not _solve_rows(_gates_as_walls(rows, ids)).route().is_empty():
			gate_problems.append("the exit can be reached with every laser gate on")
		var terminals := LevelData.terminals_in(rows)
		for k in ids.size():
			var world := _solve_rows(_gates_as_walls(rows, ids.slice(k)))
			var zone := Rect2()
			for t in terminals:
				if t["laser"] == ids[k]:
					zone = Rect2(t["c"] * 70 - 40, (t["r"] - 2) * 70, 2 * 70 + 80, 3 * 70)
			var reached := false
			for key in world.nodes:
				var p: Vector2 = world.nodes[key]
				if Rect2(p.x - 30, p.y - 128, 60, 128).intersects(zone):
					reached = true
					break
			if not reached:
				gate_problems.append("the computer for gate %s cannot be reached before gate %s" % [ids[k], ids[k]])
	report["laser_gate_problems"] = gate_problems
	report["ms"] = Time.get_ticks_msec() - t0
	report["ok"] = report["exit_reachable"] and stuck.is_empty() and gate_problems.is_empty()
	return report


static func _solve_rows(rows: Array[String]) -> LevelSolver:
	var solver := LevelSolver.new(rows)
	solver.solve()
	return solver


static func _gates_as_walls(rows: Array[String], on_ids: Array) -> Array[String]:
	var out: Array[String] = []
	for line in rows:
		var a := line.split("")
		for i in a.size():
			if a[i] >= "1" and a[i] <= "9":
				a[i] = "#" if on_ids.has(a[i]) else "."
		out.append("".join(a))
	return out


static func _info(pos: Array, flags: Dictionary) -> Dictionary:
	if pos.is_empty():
		return {"ok": false, "error": "Usage: info <file> [--solve]"}
	var loaded := _load(str(pos[0]))
	if not loaded["ok"]:
		return loaded
	var data: Dictionary = loaded["data"]
	var rows := LevelFile.tiles(data)
	var out := {"ok": true, "file": str(pos[0]), "meta": data["meta"], "cols": (data["grid"] as Dictionary).get("cols", 0),
		"rows": rows.size(), "counts": _counts(rows), "player": data["player"], "terrain": data["terrain"],
		"objects": (data["objects"] as Dictionary).size(), "minigames": (data["minigames"] as Array).size(), "problems": LevelFile.validate(data)}
	if flags.has("solve") and (out["problems"] as Array).is_empty():
		out["solve"] = _solve_report(rows)
	return out


static func _validate(pos: Array) -> Dictionary:
	if pos.is_empty():
		return {"ok": false, "error": "Usage: validate <file>"}
	var loaded := _load(str(pos[0]))
	if not loaded["ok"]:
		return loaded
	var problems := LevelFile.validate(loaded["data"])
	return {"ok": problems.is_empty(), "problems": problems}


static func _solve(pos: Array) -> Dictionary:
	if pos.is_empty():
		return {"ok": false, "error": "Usage: solve <file>"}
	var loaded := _load(str(pos[0]))
	if not loaded["ok"]:
		return loaded
	var problems := LevelFile.validate(loaded["data"])
	if not problems.is_empty():
		return {"ok": false, "error": "The level has problems; fix them first.", "problems": problems}
	return _solve_report(LevelFile.tiles(loaded["data"]))


static func _range(text: String, limit: int) -> Vector2i:
	if text == "":
		return Vector2i(0, limit - 1)
	var a := int(text.get_slice("-", 0))
	var b := int(text.get_slice("-", 1)) if text.contains("-") else a
	return Vector2i(clampi(a, 0, limit - 1), clampi(b, 0, limit - 1))


static func _show(pos: Array, flags: Dictionary) -> Dictionary:
	if pos.is_empty():
		return {"ok": false, "error": "Usage: show <file> [--rows a-b] [--cols a-b]"}
	var loaded := _load(str(pos[0]))
	if not loaded["ok"]:
		return loaded
	var rows := LevelFile.tiles(loaded["data"])
	var cols: Vector2i = _range(_flag(flags, "cols"), rows[0].length())
	var rws: Vector2i = _range(_flag(flags, "rows"), rows.size())
	var tens := "    "
	var ones := "    "
	for c in range(cols.x, cols.y + 1):
		tens += str((c / 10) % 10) if c % 10 == 0 else " "
		ones += str(c % 10)
	var lines: Array = [tens, ones]
	for r in range(rws.x, rws.y + 1):
		lines.append("%3d %s" % [r, _printable(rows[r].substr(cols.x, cols.y - cols.x + 1))])
	return {"ok": true, "map": lines, "legend": _legend(rows)}


## A map row as plain text: tiles without a built-in character (the registry's solid blocks and decor) show as '@' and '*'.
static func _printable(row: String) -> String:
	var out := ""
	for i in row.length():
		var ch := row[i]
		if TileRegistry.is_generic(ch):
			out += "@" if TileRegistry.physics_char(ch) == TileRegistry.SOLID_CHAR else "*"
		else:
			out += ch
	return out


## The tile kinds the level uses beyond the built-in ones, with how many tiles of each ('@' = a solid block kind, '*' = decor).
static func _legend(rows: Array[String]) -> Dictionary:
	var counts := {}
	for row in rows:
		for i in row.length():
			if TileRegistry.is_generic(row[i]):
				var key := str(TileRegistry.kind_for_char(row[i]).get("key", "unknown"))
				counts[key] = int(counts.get(key, 0)) + 1
	return {"@ = solid block kinds, * = decor kinds; used": counts} if not counts.is_empty() else {}


# ---------------------------------------------------------------------------------------------------------------------
# commands that edit a level
# ---------------------------------------------------------------------------------------------------------------------

static func _set_tile_cmd(data: Dictionary, pos: Array) -> Dictionary:
	var ch := _tile_char(str(pos[3]))
	if ch == "":
		return {"ok": false, "error": "'%s' is not a tile (a number, a map character or a key; see `catalog tiles`)." % str(pos[3])}
	var err := _row_set(data, int(pos[1]), int(pos[2]), ch)
	return {"ok": err == "", "error": err, "changed": 1}


static func _fill_cmd(data: Dictionary, pos: Array) -> Dictionary:
	var ch := _tile_char(str(pos[5]))
	if ch == "":
		return {"ok": false, "error": "'%s' is not a tile (a number, a map character or a key; see `catalog tiles`)." % str(pos[5])}
	var c0 := mini(int(pos[1]), int(pos[3]))
	var c1 := maxi(int(pos[1]), int(pos[3]))
	var r0 := mini(int(pos[2]), int(pos[4]))
	var r1 := maxi(int(pos[2]), int(pos[4]))
	for r in range(r0, r1 + 1):
		for c in range(c0, c1 + 1):
			var err := _row_set(data, c, r, ch)
			if err != "":
				return {"ok": false, "error": err}
	return {"ok": true, "changed": (c1 - c0 + 1) * (r1 - r0 + 1)}


static func _clear_object(data: Dictionary, c: int, r: int) -> void:
	(data["objects"] as Dictionary).erase("%d,%d" % [c, r])


static func _place_cmd(data: Dictionary, pos: Array, flags: Dictionary) -> Dictionary:
	var kind := str(pos[1])
	var c := int(pos[2])
	var r := int(pos[3])
	var entry := _entry("objects", "type", kind)
	if entry.is_empty():
		return {"ok": false, "error": "Unknown object type '%s'. Types: ai_bro, checkpoint, exit, player_spawn, lock_terminal, laser_gate, tank_settings." % kind}
	var objects: Dictionary = data["objects"]
	if kind == "laser_gate":
		var id := _flag(flags, "id")
		var height := int(_flag(flags, "height", "4"))
		if not id in ["1", "2", "3", "4", "5", "6", "7", "8", "9"]:
			return {"ok": false, "error": "laser_gate needs --id 1-9."}
		for k in height:
			var err := _row_set(data, c, r - k, id)
			if err != "":
				return {"ok": false, "error": err}
		return {"ok": true, "placed": "laser gate %s, %d tiles tall, bottom at (%d, %d)" % [id, height, c, r]}
	var marker := str(entry.get("char", ""))
	if marker != "":
		if bool(entry.get("unique", false)):
			for rr in (data["tiles"] as Array).size():
				var row: String = data["tiles"][rr]
				var cc := row.find(marker)
				while cc >= 0:
					data["tiles"][rr] = row.substr(0, cc) + "." + row.substr(cc + 1)
					_clear_object(data, cc, rr)
					row = data["tiles"][rr]
					cc = row.find(marker)
		var err2 := _row_set(data, c, r, marker)
		if err2 != "":
			return {"ok": false, "error": err2}
	var props: Array = entry.get("props", [])
	var parsed := _values(props, flags.get("prop", []), kind)
	if not parsed["ok"]:
		return parsed
	var stored := _changed_only(props, parsed["values"])
	var key := "%d,%d" % [c, r]
	if _flag(flags, "name") != "" or not stored.is_empty() or marker == "":
		objects[key] = {"type": kind, "name": _flag(flags, "name"), "props": stored}
	else:
		objects.erase(key)
	return {"ok": true, "placed": "%s at (%d, %d)" % [kind, c, r], "stored": stored}


static func _remove_cmd(data: Dictionary, pos: Array) -> Dictionary:
	var err := _row_set(data, int(pos[1]), int(pos[2]), ".")
	_clear_object(data, int(pos[1]), int(pos[2]))
	return {"ok": err == "", "error": err}


static func _set_cmd(data: Dictionary, pos: Array) -> Dictionary:
	var section := str(pos[1])
	if not section in ["player", "terrain", "meta"]:
		return {"ok": false, "error": "set needs player, terrain or meta."}
	var props: Array = _catalog_data().get(section, [])
	var parsed := _values(props, pos.slice(2), section)
	if not parsed["ok"]:
		return parsed
	var target: Dictionary = data[section]
	for key in parsed["values"]:
		target[key] = parsed["values"][key]
	return {"ok": true, "now": target}


static func _minigame_cmd(data: Dictionary, pos: Array, flags: Dictionary) -> Dictionary:
	var action := str(pos[1])
	var list: Array = data["minigames"]
	match action:
		"list":
			return {"ok": true, "minigames": list}
		"remove":
			var id := _flag(flags, "id")
			for i in list.size():
				if str((list[i] as Dictionary).get("id", "")) == id:
					list.remove_at(i)
					return {"ok": true, "removed": id}
			return {"ok": false, "error": "No minigame '%s'." % id}
		"add":
			var id2 := _flag(flags, "id")
			var kind := _flag(flags, "kind")
			var spec := _entry("minigames", "kind", kind)
			if id2 == "" or spec.is_empty():
				return {"ok": false, "error": "minigame add needs --id and --kind (one of the catalog's minigame kinds)."}
			for m in list:
				if str((m as Dictionary).get("id", "")) == id2:
					return {"ok": false, "error": "There is already a minigame '%s'." % id2}
			var parsed := _values(spec.get("params", []), flags.get("param", []), kind)
			if not parsed["ok"]:
				return parsed
			var def := {"id": id2, "name": _flag(flags, "name", str(spec.get("name", kind))), "kind": kind,
				"params": _changed_only(spec.get("params", []), parsed["values"])}
			var questions: Array = []
			for q in flags.get("question", []):
				var parts := str(q).split("|")
				if parts.size() < 3:
					return {"ok": false, "error": "A question is \"question|right answer|wrong1|wrong2|...\"."}
				questions.append({"q": parts[0], "right": parts[1], "wrong": Array(parts.slice(2))})
			if not questions.is_empty():
				if not bool(spec.get("questions", false)):
					return {"ok": false, "error": "Only the wrong_only and jokes kinds take questions."}
				def["questions"] = questions
			list.append(def)
			return {"ok": true, "added": def}
	return {"ok": false, "error": "minigame needs add, list or remove."}


# ---------------------------------------------------------------------------------------------------------------------
# commands that describe what exists
# ---------------------------------------------------------------------------------------------------------------------

static func _props_summary(props: Array) -> Array:
	var out: Array = []
	for p in props:
		var d: Dictionary = p
		var item := {"key": d["key"], "type": d["type"], "default": d["default"]}
		if d.has("min"):
			item["range"] = [d["min"], d.get("max", null)]
		if d.has("options"):
			item["options"] = d["options"]
		out.append(item)
	return out


static func _catalog(section: String, flags: Dictionary) -> Dictionary:
	var cat := _catalog_data()
	if cat.is_empty():
		return {"ok": false, "error": "Cannot read " + CATALOG_PATH}
	var out := {"ok": true}
	if section == "" or section == "tiles":
		# There can be thousands of tiles: list the ones asked for (--group NAME, --search TEXT; at most --limit N, default 60).
		var wanted_group := _flag(flags, "group").to_lower()
		var query := _flag(flags, "search").to_lower()
		var limit := int(_flag(flags, "limit", "60"))
		var groups := {}
		var tiles: Array = []
		var matched := 0
		for k in TileRegistry.kinds():
			var kind: Dictionary = k
			groups[str(kind.get("group", ""))] = int(groups.get(str(kind.get("group", "")), 0)) + 1
			var text := ("%s %s %s" % [kind["key"], kind.get("name", ""), kind.get("group", "")]).to_lower()
			if (wanted_group != "" and not str(kind.get("group", "")).to_lower().contains(wanted_group)) or (query != "" and not text.contains(query)):
				continue
			matched += 1
			if tiles.size() < limit:
				tiles.append({"id": kind["id"], "key": kind["key"], "name": kind.get("name", ""), "group": kind.get("group", ""),
					"behavior": kind.get("behavior", "built-in (map character '%s')" % str(kind["char"]))})
		out["tile_count"] = TileRegistry.kinds().size()
		out["groups"] = groups
		out["matched"] = matched
		out["tiles"] = tiles
		out["note"] = "Use a tile by its number, key or (for built-in ones) map character: set-tile <file> <col> <row> ground. Narrow with --group, --search, --limit."
	if section == "" or section == "objects":
		var objects: Array = []
		for k in TileRegistry.kinds():
			var kind2: Dictionary = k
			if kind2.has("type") and not bool(kind2.get("hidden", false)):
				objects.append({"type": kind2["type"], "key": kind2["key"], "char": kind2["char"], "name": kind2["name"], "values": _props_summary(kind2.get("props", []))})
		for o in cat["objects"]:
			objects.append({"type": o["type"], "char": o.get("char", ""), "name": o["name"], "values": _props_summary(o.get("props", []))})
		out["objects"] = objects
	for sec in ["player", "terrain", "meta"]:
		if section == "" or section == sec:
			out[sec] = _props_summary(cat[sec])
	if section == "" or section == "minigames":
		var kinds: Array = []
		for m in cat["minigames"]:
			kinds.append({"kind": m["kind"], "name": m["name"], "params": _props_summary(m["params"]), "questions": m.get("questions", false)})
		out["minigames"] = kinds
	return out


static func _pieces() -> Dictionary:
	var pieces := {}
	for k in LevelData.SEQ_PIECES:
		pieces[k] = LevelData.SEQ_PIECES[k]
	return {"ok": true, "pieces": pieces, "example_plan": EXAMPLE_PLAN, "notes": [
		"A plan is a JSON list; entries are [piece, parameters...], e.g. [\"pit\", 4, \"F\"].",
		"The first flat should have marks containing P (the player spawn); end the plan with [\"exit\"] exactly once.",
		"Every piece starts and ends on flat ground, so any order works. Keep drops to 6 rows or less and give each tunnel its own laser id.",
		"AI Bros in flats need at least 7 columns. Aim for 100-140 columns in total (about a minute or two of play).",
		"After from-plan run `solve` to prove the level can be finished."]}
