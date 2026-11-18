class_name EditorDocument
extends RefCounted
## The level being edited: the level Dictionary (the file format of tools/level_editor/FORMAT.md), the selection, the clipboard
## and the undo history. It knows nothing about the user interface (nodes only observe its signals), so it can be tested
## headless (tools/tests/editor_test.gd). Every edit is one undo step; several changes can be made one step with
## begin_edit() / end_edit().

## Emitted after an edit (or undo/redo/load). kind says what changed: "tiles", "objects", "props", "meta", "terrain", "player",
## "minigames" (a value inside a minigame), "minigames_list" (one was added, removed or renamed), "grid" (resized), or
## "all" (new document, load, undo, redo).
signal changed(kind: String)

## Emitted when the selection changes.
signal selection_changed

# HISTORY_LIMIT: most undo steps kept. Each step is a full copy of the level, so a very large level times a high limit uses
# more memory. Raise it for a longer undo history; lower it to save memory.
const HISTORY_LIMIT := 100

# MIN_GRID / MAX_GRID: smallest and largest grid side in tiles that new/resize accept. MIN_GRID keeps a level playable;
# MAX_GRID bounds the memory and the time of drawing and validating.
const MIN_GRID := 8
const MAX_GRID := 400

# SOLID: map characters lamps, sirens and canisters can stand on (the game's solid blocks, see Level.SOLID).
const SOLID := "#XO@"

# MERGE_WINDOW_MS: edits of the same value made within this many milliseconds (typing, dragging a spin box) are merged into
# one undo step. Higher: bigger undo steps; lower: more steps.
const MERGE_WINDOW_MS := 900

## The level data (see FORMAT.md).
var data: Dictionary = {}
## File path it was loaded from or saved to ("" for a new, unsaved level).
var path := ""
## True when there are changes since the last save.
var dirty := false
## The selected cells (size zero = nothing selected).
var sel := Rect2i()
## The cell of the selected thing's marker (a machine's bottom-left tile, the top of a gate, ...).
var sel_anchor := Vector2i(-1, -1)
## True when the selection is one object that has a name and values (see the inspector).
var sel_object := false

## The copied block shared by all documents ({} = empty clipboard).
static var clipboard: Dictionary = {}

var catalog: EditorCatalog

var _undo: Array[Dictionary] = []
var _redo: Array[Dictionary] = []
var _depth := 0
var _before: Dictionary = {}
var _touched := false
var _pending: Array[String] = []
var _last_merge_key := ""
var _last_merge_ms := 0


func _init() -> void:
	catalog = EditorCatalog.get_instance()
	data = LevelFile.new_level(60, 24)


# ---------------------------------------------------------------- creating, loading, saving

## Replace the level with a fresh one of the given size (floor, walls, spawn and exit).
func new_level(cols: int, rows: int) -> void:
	data = LevelFile.new_level(clampi(cols, MIN_GRID, MAX_GRID), clampi(rows, MIN_GRID, MAX_GRID))
	_reset_state("")


## A document made from a level of the game (LevelData.ids()): its map becomes the editable tiles.
static func from_builtin(level_id: String) -> EditorDocument:
	var doc := EditorDocument.new()
	var rows: Array[String] = LevelData.map(level_id)
	var d := LevelFile.new_level(8, 8)
	d["meta"] = {"id": "copy_of_" + level_id, "title": LevelData.title(level_id), "next": ""}
	var boss := str(LevelFile.value(LevelData.data_for(level_id), "meta", "boss", ""))
	if boss != "":
		(d["meta"] as Dictionary)["boss"] = boss   # (a copy of a boss level keeps its boss)
	d["grid"] = {"cols": rows[0].length(), "rows": rows.size()}
	var arr: Array = []
	for row in rows:
		arr.append(row)
	d["tiles"] = arr
	doc.data = d
	doc._reset_state("")
	doc.dirty = true
	return doc


## Take over the level of another document (used to open a built-in level without replacing this object, which the UI observes).
func adopt(other: EditorDocument) -> void:
	data = other.data
	var was_dirty := other.dirty
	_reset_state(other.path)
	dirty = was_dirty


## Load a level file. Returns {"ok": bool, "errors": Array[String]}. A file with level rule problems (for example no exit) is
## still loaded (ok = true, errors lists them); a file whose structure is broken is refused and the document stays unchanged.
func load_file(file_path: String) -> Dictionary:
	var res: Dictionary = LevelFile.load_file(file_path)
	var errors: Array[String] = []
	for e in res.get("errors", []):
		errors.append(str(e))
	var d: Dictionary = res.get("data", {})
	if d.is_empty():
		return {"ok": false, "errors": errors}
	var structure := structure_errors(d)
	if not structure.is_empty():
		return {"ok": false, "errors": structure + errors}
	data = d
	_normalize()
	_reset_state(file_path)
	return {"ok": true, "errors": errors}


## Problems that make a level Dictionary impossible to edit (grid and rows do not agree).
static func structure_errors(d: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var g: Variant = d.get("grid")
	if typeof(g) != TYPE_DICTIONARY:
		out.append("The file has no grid.")
		return out
	var cols := int((g as Dictionary).get("cols", 0))
	var rows := int((g as Dictionary).get("rows", 0))
	var tiles: Variant = d.get("tiles")
	if typeof(tiles) != TYPE_ARRAY or cols < 1 or rows < 1:
		out.append("The file has no tiles or an empty grid.")
		return out
	if (tiles as Array).size() != rows:
		out.append("The grid says %d rows but there are %d rows of tiles." % [rows, (tiles as Array).size()])
		return out
	for r in rows:
		if typeof((tiles as Array)[r]) != TYPE_STRING or ((tiles as Array)[r] as String).length() != cols:
			out.append("Row %d is not exactly %d characters." % [r, cols])
			if out.size() > 5:
				break
	return out


## Write the level to a file (or to the path it already has when file_path is empty). Returns OK or an Error code.
func save(file_path: String = "") -> Error:
	var target := file_path if file_path != "" else path
	if target == "":
		return ERR_FILE_BAD_PATH
	_prune_objects()
	var err := LevelFile.save_file(target, data)
	if err == OK:
		path = target
		dirty = false
	return err


func _reset_state(file_path: String) -> void:
	path = file_path
	dirty = false
	_undo.clear()
	_redo.clear()
	_depth = 0
	_last_merge_key = ""
	sel = Rect2i()
	sel_anchor = Vector2i(-1, -1)
	sel_object = false
	changed.emit("all")
	selection_changed.emit()


# Make loaded numbers the type the catalog says (JSON has only floats) and every section present.
func _normalize() -> void:
	var g: Dictionary = data["grid"]
	g["cols"] = int(g["cols"])
	g["rows"] = int(g["rows"])
	data["format"] = LevelFile.FORMAT_VERSION
	for section in ["meta", "terrain", "player", "objects"]:
		if typeof(data.get(section)) != TYPE_DICTIONARY:
			data[section] = {}
	if typeof(data.get("minigames")) != TYPE_ARRAY:
		data["minigames"] = []
	_coerce_dict(data["terrain"], catalog.terrain_props)
	_coerce_dict(data["player"], catalog.player_props)
	_coerce_dict(data["meta"], catalog.meta_props)
	var objects: Dictionary = data["objects"]
	for key in objects.keys():
		if typeof(objects[key]) != TYPE_DICTIONARY:
			objects.erase(key)
			continue
		var o: Dictionary = objects[key]
		if typeof(o.get("props")) == TYPE_DICTIONARY:
			_coerce_dict(o["props"], catalog.props_for_type(str(o.get("type", ""))))
	var mg: Array = data["minigames"]
	for i in range(mg.size() - 1, -1, -1):
		if typeof(mg[i]) != TYPE_DICTIONARY:
			mg.remove_at(i)
			continue
		var m: Dictionary = mg[i]
		if typeof(m.get("params")) != TYPE_DICTIONARY:
			m["params"] = {}
		_coerce_dict(m["params"], catalog.minigame_kind_entry(str(m.get("kind", ""))).get("params", []))


func _coerce_dict(d: Dictionary, defs: Array) -> void:
	for def in defs:
		var k := str((def as Dictionary)["key"])
		if d.has(k):
			d[k] = EditorCatalog.coerce(def, d[k])


# ---------------------------------------------------------------- undo / redo

## Start a group of changes that is one undo step (nest freely; the outermost end_edit() commits).
func begin_edit() -> void:
	if _depth == 0:
		_before = data.duplicate(true)
		_touched = false
		_pending.clear()
	_depth += 1


## End a group started with begin_edit(). merge_key (optional) merges consecutive edits of the same value into one undo step.
func end_edit(merge_key: String = "") -> void:
	if _depth <= 0:
		return
	_depth -= 1
	if _depth > 0:
		return
	if _touched:
		var now := Time.get_ticks_msec()
		var merge := merge_key != "" and merge_key == _last_merge_key and now - _last_merge_ms < MERGE_WINDOW_MS
		if not merge:
			_undo.append(_before)
			if _undo.size() > HISTORY_LIMIT:
				_undo.pop_front()
		_last_merge_key = merge_key
		_last_merge_ms = now
		_redo.clear()
		dirty = true
		_validate_selection()
	_before = {}
	var kinds := _pending.duplicate()
	_pending.clear()
	for k in kinds:
		changed.emit(k)


func _touch(kind: String) -> void:
	_touched = true
	if not _pending.has(kind):
		_pending.append(kind)


## True if there is something to undo.
func can_undo() -> bool:
	return not _undo.is_empty()


## True if there is something to redo.
func can_redo() -> bool:
	return not _redo.is_empty()


## Undo the last edit.
func undo() -> bool:
	if _undo.is_empty():
		return false
	_redo.append(data.duplicate(true))
	data = _undo.pop_back()
	_after_history()
	return true


## Redo the last undone edit.
func redo() -> bool:
	if _redo.is_empty():
		return false
	_undo.append(data.duplicate(true))
	data = _redo.pop_back()
	_after_history()
	return true


func _after_history() -> void:
	dirty = true
	_last_merge_key = ""
	sel = Rect2i()
	sel_anchor = Vector2i(-1, -1)
	sel_object = false
	changed.emit("all")
	selection_changed.emit()


# ---------------------------------------------------------------- reading the grid

## Columns of the grid.
func cols() -> int:
	return int((data["grid"] as Dictionary)["cols"])


## Rows of the grid.
func rows() -> int:
	return int((data["grid"] as Dictionary)["rows"])


## True if (c, r) is inside the grid.
func in_bounds(c: int, r: int) -> bool:
	return c >= 0 and r >= 0 and c < cols() and r < rows()


## The tile character at (c, r); "" outside the grid.
func get_cell(c: int, r: int) -> String:
	if not in_bounds(c, r):
		return ""
	var row: String = (data["tiles"] as Array)[r]
	return row[c]


## The lowest laser gate id (1-9) that no gate in the level uses yet ("9" if all are taken).
func next_free_gate_id() -> String:
	for id in "123456789":
		var used := false
		for row in data["tiles"]:
			if (row as String).contains(id):
				used = true
				break
		if not used:
			return id
	return "9"


## True if some tile of the level is the laser gate with this id.
func has_gate(id: String) -> bool:
	for row in data["tiles"]:
		if (row as String).contains(id):
			return true
	return false


## Give the laser gate `old` the id `new` (every tile of it). Refused (false) if another gate already has that id.
func set_gate_id(old: String, new: String) -> bool:
	if old == new or has_gate(new) or not has_gate(old):
		return false
	begin_edit()
	for r in rows():
		for c in cols():
			if get_cell(c, r) == old:
				_set_char(c, r, new)
	# lock terminals that named the old id now name the new one
	for key in (data["objects"] as Dictionary):
		var o: Dictionary = data["objects"][key]
		var props: Dictionary = o.get("props", {})
		if str(props.get("laser", "")) == old:
			props["laser"] = new
	_touch("grid")
	end_edit()
	return true


## The tile rows as a typed array (what LevelData expects).
func tile_rows() -> Array[String]:
	return LevelFile.tiles(data)


func _set_char(c: int, r: int, ch: String) -> void:
	var tiles: Array = data["tiles"]
	var row: String = tiles[r]
	if row[c] == ch:
		return
	tiles[r] = row.substr(0, c) + ch + row.substr(c + 1)
	_touch("tiles")


# ---------------------------------------------------------------- placement rules

## The letters of machines whose footprint (not counting their own letter tile) covers (c, r): an array of Vector2i letter cells.
func machines_covering(rows_arr: Array, c: int, r: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for dc in 4:
		for dr in 3:
			if dc == 0 and dr == 0:
				continue
			var lc := c - dc
			var lr := r + dr
			if lc < 0 or lr >= rows_arr.size():
				continue
			var ch: String = (rows_arr[lr] as String)[lc]
			if ch == "." or not catalog.is_machine(ch):
				continue
			var fp := catalog.footprint(ch)
			if dc < fp.x and dr < fp.y:
				out.append(Vector2i(lc, lr))
	return out


## What is wrong with putting character ch at (c, r) given the tile rows rows_arr: {} if fine, else
## {"level": "error" | "warn", "text": String}. Errors refuse the placement; warnings only colour the ghost.
func problem_for(rows_arr: Array, c: int, r: int, ch: String) -> Dictionary:
	var h := rows_arr.size()
	var w := (rows_arr[0] as String).length()
	if c < 0 or r < 0 or c >= w or r >= h:
		return {"level": "error", "text": "Outside the level."}
	if ch == ".":
		return {}
	if catalog.is_machine(ch):
		var fp := catalog.footprint(ch)
		if c + fp.x > w or r - fp.y + 1 < 0:
			return {"level": "error", "text": "The %dx%d footprint of %s leaves the level." % [fp.x, fp.y, _name_of(ch)]}
		for dc in fp.x:
			for dr in fp.y:
				if dc == 0 and dr == 0:
					continue
				var other: String = (rows_arr[r - dr] as String)[c + dc]
				if other != ".":
					return {"level": "error", "text": "%s needs free space: tile (%d,%d) is taken." % [_name_of(ch), c + dc, r - dr]}
				if not machines_covering(rows_arr, c + dc, r - dr).is_empty():
					return {"level": "error", "text": "%s overlaps another machine." % _name_of(ch)}
		# The new machine's footprint must also not cover a machine letter of an overlapping neighbour.
		for dc in fp.x:
			for dr in fp.y:
				if dc == 0 and dr == 0:
					continue
				for cover in machines_covering(rows_arr, c + dc, r - dr):
					if cover != Vector2i(c, r):
						return {"level": "error", "text": "%s overlaps another machine." % _name_of(ch)}
		return {}
	var covering := machines_covering(rows_arr, c, r)
	for lc in covering:
		if lc != Vector2i(c, r):
			return {"level": "error", "text": "Inside the footprint of the machine at (%d,%d)." % [lc.x, lc.y]}
	if ch == "B":
		var typed: Array[String] = []
		for i in h:
			var row: String = rows_arr[i]
			if i == r:
				row = row.substr(0, c) + "B" + row.substr(c + 1)
			typed.append(row)
		var span := LevelData.bro_flat_span(typed, c, r)
		if span < LevelData.bro_min_flat_tiles():
			return {"level": "warn", "text": "An AI Bro needs %d tiles of flat ground (%d here)." % [LevelData.bro_min_flat_tiles(), span]}
	elif ch == "l" or ch == "i" or ch == "c":
		if r + 1 >= h or not SOLID.contains(TileRegistry.physics_char((rows_arr[r + 1] as String)[c])):
			return {"level": "warn", "text": "%s must stand on a solid tile." % _name_of(ch)}
	return {}


## problem_for() for the current level: what is wrong with putting ch at (c, r).
func placement_problem(c: int, r: int, ch: String) -> Dictionary:
	if not in_bounds(c, r):
		return {"level": "error", "text": "Outside the level."}
	return problem_for(data["tiles"], c, r, ch)


func _name_of(ch: String) -> String:
	var e := catalog.entry_for_char(ch)
	return str(e.get("name", ch))


## True if the catalog says only one of this character may exist (player spawn, exit).
func is_unique_char(ch: String) -> bool:
	return bool(catalog.entry_for_char(ch).get("unique", false))


## Where the (single) character ch is, or (-1,-1).
func find_char(ch: String) -> Vector2i:
	var tiles: Array = data["tiles"]
	for r in tiles.size():
		var c := (tiles[r] as String).find(ch)
		if c >= 0:
			return Vector2i(c, r)
	return Vector2i(-1, -1)


# ---------------------------------------------------------------- painting

## Put ch at (c, r). Unique things (spawn, exit) move there. Returns {"ok": bool, "text": String, "level": String}; errors
## (outside the level, machine overlap) refuse the placement, warnings (Bro without room, lamp in the air) allow it.
func place(c: int, r: int, ch: String) -> Dictionary:
	if ch.length() != 1:
		return {"ok": false, "text": "Nothing to place.", "level": "error"}
	var prob := placement_problem(c, r, ch)
	if not prob.is_empty() and str(prob["level"]) == "error":
		return {"ok": false, "text": prob["text"], "level": "error"}
	begin_edit()
	if is_unique_char(ch):
		var old := find_char(ch)
		if old.x >= 0 and old != Vector2i(c, r):
			_take_object_entry(old)
			_set_char(old.x, old.y, ".")
	_set_char(c, r, ch)
	_prune_objects()
	end_edit()
	return {"ok": true, "text": str(prob.get("text", "")), "level": str(prob.get("level", ""))}


## Put ch on every cell of a list (a stroke). Returns how many cells were changed. Cells that break a rule are skipped.
func place_cells(cells: Array[Vector2i], ch: String) -> int:
	var n := 0
	begin_edit()
	for cell in cells:
		if get_cell(cell.x, cell.y) == ch:
			continue
		if bool(place(cell.x, cell.y, ch)["ok"]):
			n += 1
	end_edit()
	return n


## Remove whatever is at (c, r): a machine whose footprint covers it goes entirely.
func erase(c: int, r: int) -> void:
	if not in_bounds(c, r):
		return
	begin_edit()
	if get_cell(c, r) == ".":
		for lc in machines_covering(data["tiles"], c, r):
			_set_char(lc.x, lc.y, ".")
	else:
		_set_char(c, r, ".")
	_prune_objects()
	end_edit()


## Erase every cell in a list (a stroke).
func erase_cells(cells: Array[Vector2i]) -> void:
	begin_edit()
	for cell in cells:
		erase(cell.x, cell.y)
	end_edit()


# ---------------------------------------------------------------- things, selection

## The thing under (c, r): {} for empty space, else {"rect": Rect2i, "anchor": Vector2i, "object": bool, "char": String}.
## A thing is a machine (footprint), a laser gate (the whole vertical run), a pit (its rectangle) or one tile.
func thing_at(c: int, r: int) -> Dictionary:
	if not in_bounds(c, r):
		return {}
	var ch := get_cell(c, r)
	if ch == ".":
		var covering := machines_covering(data["tiles"], c, r)
		if covering.is_empty():
			return {}
		var lc: Vector2i = covering[0]
		var m := get_cell(lc.x, lc.y)
		var fp := catalog.footprint(m)
		return {"rect": Rect2i(lc.x, lc.y - fp.y + 1, fp.x, fp.y), "anchor": lc, "object": catalog.is_object_char(m), "char": m}
	if catalog.is_machine(ch):
		var fp2 := catalog.footprint(ch)
		return {"rect": Rect2i(c, r - fp2.y + 1, fp2.x, fp2.y), "anchor": Vector2i(c, r), "object": catalog.is_object_char(ch), "char": ch}
	if ch >= "1" and ch <= "9":
		var top := r
		while get_cell(c, top - 1) == ch:
			top -= 1
		var bottom := r
		while get_cell(c, bottom + 1) == ch:
			bottom += 1
		return {"rect": Rect2i(c, top, 1, bottom - top + 1), "anchor": Vector2i(c, top), "object": true, "char": ch}
	if SpriteLibrary.PIT_KINDS.values().has(ch):
		var rect := pit_rect_at(c, r)
		return {"rect": rect, "anchor": rect.position, "object": ch == "W", "char": ch}
	return {"rect": Rect2i(c, r, 1, 1), "anchor": Vector2i(c, r), "object": catalog.is_object_char(ch), "char": ch}


## The rectangle of the pit liquid containing (c, r), found the way the game builds pits: from the top-left cell of the block,
## right along the row and then down while whole rows match.
func pit_rect_at(c: int, r: int) -> Rect2i:
	var ch := get_cell(c, r)
	var top := r
	while get_cell(c, top - 1) == ch:
		top -= 1
	var left := c
	while get_cell(left - 1, top) == ch:
		left -= 1
	var w := 1
	while get_cell(left + w, top) == ch:
		w += 1
	var h := 1
	while true:
		var all := true
		for x in w:
			if get_cell(left + x, top + h) != ch:
				all = false
				break
		if not all:
			break
		h += 1
	return Rect2i(left, top, w, h)


## Select the thing under (c, r). Returns false (and clears the selection) if the cell is empty.
func select_thing_at(c: int, r: int) -> bool:
	var t := thing_at(c, r)
	if t.is_empty():
		clear_selection()
		return false
	select_rect(t["rect"], t["anchor"], bool(t["object"]))
	return true


## Select a rectangle of cells (for moving, copying or deleting). anchor / is_object describe a single object inside it.
func select_rect(rect: Rect2i, anchor: Vector2i = Vector2i(-1, -1), is_object: bool = false) -> void:
	sel = rect
	sel_anchor = anchor
	sel_object = is_object
	selection_changed.emit()


## Forget the selection.
func clear_selection() -> void:
	if sel.size == Vector2i.ZERO and sel_anchor.x < 0:
		return
	sel = Rect2i()
	sel_anchor = Vector2i(-1, -1)
	sel_object = false
	selection_changed.emit()


## True if something is selected.
func has_selection() -> bool:
	return sel.size.x > 0 and sel.size.y > 0


func _validate_selection() -> void:
	if not has_selection():
		return
	if sel_object and (not in_bounds(sel_anchor.x, sel_anchor.y) or not catalog.is_object_char(get_cell(sel_anchor.x, sel_anchor.y))):
		clear_selection()
	elif not in_bounds(sel.position.x, sel.position.y):
		clear_selection()


# ---------------------------------------------------------------- blocks: move, copy, paste, delete

## A copy of the cells of rect as a block: {"w", "h", "rows": Array[String], "objects": {"dc,dr": entry},
## "anchor": Vector2i (relative to the block), "object": bool}.
func take_block(rect: Rect2i) -> Dictionary:
	var rows_out: Array[String] = []
	for r in range(rect.position.y, rect.end.y):
		var s := ""
		for c in range(rect.position.x, rect.end.x):
			s += get_cell(c, r)
		rows_out.append(s)
	var objs := {}
	for key in (data["objects"] as Dictionary):
		var parts := (key as String).split(",")
		var oc := int(parts[0])
		var orow := int(parts[1])
		if rect.has_point(Vector2i(oc, orow)):
			objs["%d,%d" % [oc - rect.position.x, orow - rect.position.y]] = (data["objects"][key] as Dictionary).duplicate(true)
	var rel_anchor := sel_anchor - rect.position if sel_anchor.x >= 0 else Vector2i(-1, -1)
	return {"w": rect.size.x, "h": rect.size.y, "rows": rows_out, "objects": objs, "anchor": rel_anchor, "object": sel_object}


# Apply a block onto copies of the rows/objects. Returns {"rows", "objects", "dest", "problem"}; problem is {} or an error.
func _simulate(rows_in: Array, objs_in: Dictionary, block: Dictionary, at: Vector2i, clear_rect: Rect2i) -> Dictionary:
	var rows_sim: Array = rows_in.duplicate()
	var objs: Dictionary = objs_in.duplicate(true)
	var dest := Rect2i(at, Vector2i(int(block["w"]), int(block["h"])))
	var w := (rows_sim[0] as String).length()
	if dest.position.x < 0 or dest.position.y < 0 or dest.end.x > w or dest.end.y > rows_sim.size():
		return {"rows": rows_sim, "objects": objs, "dest": dest, "problem": {"level": "error", "text": "Outside the level."}}
	if clear_rect.size.x > 0:
		for r in range(clear_rect.position.y, clear_rect.end.y):
			var row: String = rows_sim[r]
			var blanks := ".".repeat(clear_rect.size.x)
			rows_sim[r] = row.substr(0, clear_rect.position.x) + blanks + row.substr(clear_rect.end.x)
		for key in objs.keys():
			var p := (key as String).split(",")
			if clear_rect.has_point(Vector2i(int(p[0]), int(p[1]))):
				objs.erase(key)
	var brows: Array = block["rows"]
	for dr in dest.size.y:
		var s: String = rows_sim[dest.position.y + dr]
		var src: String = brows[dr]
		for dc in dest.size.x:
			if src[dc] != ".":
				s = s.substr(0, dest.position.x + dc) + src[dc] + s.substr(dest.position.x + dc + 1)
		rows_sim[dest.position.y + dr] = s
	for key in (block["objects"] as Dictionary):
		var p2 := (key as String).split(",")
		objs["%d,%d" % [dest.position.x + int(p2[0]), dest.position.y + int(p2[1])]] = (block["objects"][key] as Dictionary).duplicate(true)
	# Rules: one spawn and one exit; machine footprints and Bro/lamp rules for what arrived.
	for ch in ["P", "E"]:
		var n := 0
		for row in rows_sim:
			n += (row as String).count(ch)
		if n > 1:
			return {"rows": rows_sim, "objects": objs, "dest": dest, "problem": {"level": "error", "text": "There can be only one %s." % _name_of(ch)}}
	var worst := {}
	for dr in dest.size.y:
		for dc in dest.size.x:
			var cc := dest.position.x + dc
			var rr := dest.position.y + dr
			var ch2: String = (rows_sim[rr] as String)[cc]
			if ch2 == ".":
				continue
			var prob := problem_for(rows_sim, cc, rr, ch2)
			if prob.is_empty():
				continue
			if str(prob["level"]) == "error":
				return {"rows": rows_sim, "objects": objs, "dest": dest, "problem": prob}
			worst = prob
	return {"rows": rows_sim, "objects": objs, "dest": dest, "problem": worst}


## Check moving (or copying) the cells of rect by d. Returns {"ok": bool, "level": String, "text": String, "dest": Rect2i}.
func preview_move(rect: Rect2i, d: Vector2i, copy: bool) -> Dictionary:
	var block := take_block(rect)
	var sim := _simulate(data["tiles"], data["objects"], block, rect.position + d, Rect2i() if copy else rect)
	var prob: Dictionary = sim["problem"]
	return {"ok": prob.is_empty() or str(prob["level"]) != "error", "level": str(prob.get("level", "")),
		"text": str(prob.get("text", "")), "dest": sim["dest"]}


func _apply_block(block: Dictionary, at: Vector2i, clear_rect: Rect2i, select_result: bool) -> Dictionary:
	var sim := _simulate(data["tiles"], data["objects"], block, at, clear_rect)
	var prob: Dictionary = sim["problem"]
	if not prob.is_empty() and str(prob["level"]) == "error":
		return {"ok": false, "text": prob["text"], "dest": sim["dest"]}
	begin_edit()
	data["tiles"] = _to_variant_array(sim["rows"])
	data["objects"] = sim["objects"]
	_touch("tiles")
	_touch("objects")
	_prune_objects()
	end_edit()
	var dest: Rect2i = sim["dest"]
	if select_result:
		var anc: Vector2i = block["anchor"]
		select_rect(dest, dest.position + anc if anc.x >= 0 else Vector2i(-1, -1), bool(block["object"]))
	return {"ok": true, "text": str(prob.get("text", "")), "dest": dest}


func _to_variant_array(a: Array) -> Array:
	var out: Array = []
	for s in a:
		out.append(str(s))
	return out


## Move (or copy) the cells of rect by d and select the result. Returns {"ok": bool, "text": String}.
func move_region(rect: Rect2i, d: Vector2i, copy: bool) -> Dictionary:
	if d == Vector2i.ZERO:
		return {"ok": true, "text": ""}
	return _apply_block(take_block(rect), rect.position + d, Rect2i() if copy else rect, true)


## Move the selection by d (arrow-key nudge). Returns {"ok", "text"}.
func nudge_selection(d: Vector2i) -> Dictionary:
	if not has_selection():
		return {"ok": false, "text": "Nothing selected."}
	return move_region(sel, d, false)


## Put a copy of the selected cells on the clipboard.
func copy_selection() -> bool:
	if not has_selection():
		return false
	clipboard = take_block(sel)
	return true


## Copy the selected cells to the clipboard and empty them.
func cut_selection() -> bool:
	if not copy_selection():
		return false
	delete_selection()
	return true


## True if the clipboard holds something.
func can_paste() -> bool:
	return not clipboard.is_empty()


## Paste the clipboard with its top-left at `at` (it becomes the selection). Returns {"ok", "text"}.
func paste_at(at: Vector2i) -> Dictionary:
	if clipboard.is_empty():
		return {"ok": false, "text": "The clipboard is empty."}
	return _apply_block(clipboard, at, Rect2i(), true)


## Check pasting at `at`: {"ok", "level", "text", "dest"}.
func preview_paste(at: Vector2i) -> Dictionary:
	if clipboard.is_empty():
		return {"ok": false, "level": "error", "text": "The clipboard is empty.", "dest": Rect2i()}
	var sim := _simulate(data["tiles"], data["objects"], clipboard, at, Rect2i())
	var prob: Dictionary = sim["problem"]
	return {"ok": prob.is_empty() or str(prob["level"]) != "error", "level": str(prob.get("level", "")),
		"text": str(prob.get("text", "")), "dest": sim["dest"]}


## Empty every selected cell (machines whose footprint is selected go too).
func delete_selection() -> void:
	if not has_selection():
		return
	begin_edit()
	for r in range(sel.position.y, sel.end.y):
		for c in range(sel.position.x, sel.end.x):
			if in_bounds(c, r) and get_cell(c, r) != ".":
				_set_char(c, r, ".")
	_prune_objects()
	end_edit()
	clear_selection()


## Duplicate the selection next to itself (to the right, then left, below, above). Returns {"ok", "text"}.
func duplicate_selection() -> Dictionary:
	if not has_selection():
		return {"ok": false, "text": "Nothing selected."}
	var w := sel.size.x
	var h := sel.size.y
	var last := {"ok": false, "text": ""}
	for d in [Vector2i(w, 0), Vector2i(-w, 0), Vector2i(0, h), Vector2i(0, -h), Vector2i(w * 2, 0)]:
		var pv := preview_move(sel, d, true)
		if bool(pv["ok"]):
			return move_region(sel, d, true)
		last = pv
	return {"ok": false, "text": str(last.get("text", "No room to duplicate."))}


# ---------------------------------------------------------------- objects: names and values

## The type of the object whose marker is at (c, r) ("ai_bro", "tank_settings"...), or "" if none.
func object_type_at(c: int, r: int) -> String:
	var ch := get_cell(c, r)
	if ch in ["A", "F", "N", "W"]:   # any deadly pit: the settings of its creatures
		return "tank_settings"
	var e := catalog.entry_for_char(ch)
	if str(e.get("kind", "")) == "object":
		return str(e.get("type", ""))
	return ""


## The stored entry of the object at (c, r) ({} if it has only defaults).
func object_entry(c: int, r: int) -> Dictionary:
	return LevelFile.object_at(data, c, r)


## The object's name ("" if unnamed).
func object_name(c: int, r: int) -> String:
	return str(object_entry(c, r).get("name", ""))


## Set the object's name (cut to LevelFile.MAX_NAME_LENGTH).
func set_object_name(c: int, r: int, new_name: String) -> void:
	var type := object_type_at(c, r)
	if type == "":
		return
	var clean := new_name.strip_edges().left(LevelFile.MAX_NAME_LENGTH)
	if clean == object_name(c, r):
		return
	begin_edit()
	var entry := _ensure_entry(c, r, type)
	if clean == "":
		entry.erase("name")
	else:
		entry["name"] = clean
	_cleanup_entry(c, r)
	_touch("objects")
	end_edit("name:%d,%d" % [c, r])


## The current value of a prop of the object at (c, r): the stored value or the catalog default.
func get_prop(c: int, r: int, key: String) -> Variant:
	var type := object_type_at(c, r)
	var e := object_entry(c, r)
	var props: Variant = e.get("props")
	if typeof(props) == TYPE_DICTIONARY and (props as Dictionary).has(key):
		return (props as Dictionary)[key]
	return EditorCatalog.default_of(catalog.props_for_type(type), key)


## Set a prop of the object at (c, r). A value equal to the catalog default is not stored (the stored one is removed).
func set_prop(c: int, r: int, key: String, value: Variant) -> void:
	var type := object_type_at(c, r)
	if type == "":
		return
	var defs := catalog.props_for_type(type)
	var def_value: Variant = EditorCatalog.default_of(defs, key)
	if _same_value(get_prop(c, r, key), value):
		return
	begin_edit()
	var entry := _ensure_entry(c, r, type)
	var props: Dictionary = entry["props"]
	if _same_value(def_value, value):
		props.erase(key)
	else:
		props[key] = value
	_cleanup_entry(c, r)
	_touch("props")
	end_edit("prop:%d,%d:%s" % [c, r, key])


## Put a prop back to its catalog default.
func reset_prop(c: int, r: int, key: String) -> void:
	var def_value: Variant = EditorCatalog.default_of(catalog.props_for_type(object_type_at(c, r)), key)
	set_prop(c, r, key, def_value)


## True if the object's prop differs from the catalog default.
func is_prop_changed(c: int, r: int, key: String) -> bool:
	var type := object_type_at(c, r)
	return not _same_value(get_prop(c, r, key), EditorCatalog.default_of(catalog.props_for_type(type), key))


func _same_value(a: Variant, b: Variant) -> bool:
	if (typeof(a) == TYPE_FLOAT or typeof(a) == TYPE_INT) and (typeof(b) == TYPE_FLOAT or typeof(b) == TYPE_INT):
		return is_equal_approx(float(a), float(b))
	return a == b


func _ensure_entry(c: int, r: int, type: String) -> Dictionary:
	var key := "%d,%d" % [c, r]
	var objects: Dictionary = data["objects"]
	if not objects.has(key):
		objects[key] = {"type": type, "props": {}}
	var e: Dictionary = objects[key]
	e["type"] = type
	if typeof(e.get("props")) != TYPE_DICTIONARY:
		e["props"] = {}
	return e


func _cleanup_entry(c: int, r: int) -> void:
	var key := "%d,%d" % [c, r]
	var objects: Dictionary = data["objects"]
	if not objects.has(key):
		return
	var e: Dictionary = objects[key]
	if str(e.get("name", "")) == "" and (e.get("props", {}) as Dictionary).is_empty():
		objects.erase(key)


func _take_object_entry(cell: Vector2i) -> Dictionary:
	var key := "%d,%d" % [cell.x, cell.y]
	var objects: Dictionary = data["objects"]
	if objects.has(key):
		var e: Dictionary = objects[key]
		objects.erase(key)
		_touch("objects")
		return e
	return {}


# Remove entries whose marker is gone, whose type no longer matches the tile, or that hold nothing.
func _prune_objects() -> void:
	var objects: Dictionary = data["objects"]
	for key in objects.keys():
		var parts := (key as String).split(",")
		var removable := parts.size() != 2
		if not removable:
			var c := int(parts[0])
			var r := int(parts[1])
			var e: Dictionary = objects[key]
			removable = object_type_at(c, r) == "" or object_type_at(c, r) != str(e.get("type", ""))
			if not removable and str(e.get("name", "")) == "" and (e.get("props", {}) as Dictionary).is_empty():
				removable = true
		if removable:
			objects.erase(key)
			_touch("objects")


# ---------------------------------------------------------------- meta, terrain, player

## The value of a level-wide setting in section "meta", "terrain" or "player" (the catalog default when not stored).
func get_setting(section: String, key: String) -> Variant:
	var d: Dictionary = data.get(section, {})
	if d.has(key):
		return d[key]
	return EditorCatalog.default_of(_defs_for(section), key)


## Set a level-wide setting. Player values equal to the default are not stored; meta and terrain are always stored.
func set_setting(section: String, key: String, value: Variant) -> void:
	if _same_value(get_setting(section, key), value) and (section == "player" or (data[section] as Dictionary).has(key)):
		return
	begin_edit()
	var d: Dictionary = data[section]
	if section == "player" and _same_value(EditorCatalog.default_of(_defs_for(section), key), value):
		d.erase(key)
	else:
		d[key] = value
	_touch(section)
	end_edit("%s:%s" % [section, key])


## Put a setting back to its default.
func reset_setting(section: String, key: String) -> void:
	set_setting(section, key, EditorCatalog.default_of(_defs_for(section), key))


## True if the setting differs from its default.
func is_setting_changed(section: String, key: String) -> bool:
	return not _same_value(get_setting(section, key), EditorCatalog.default_of(_defs_for(section), key))


func _defs_for(section: String) -> Array:
	match section:
		"meta":
			return catalog.meta_props
		"terrain":
			return catalog.terrain_props
		"player":
			return catalog.player_props
	return []


## Resize the grid to cols x rows. offset is where the old level's top-left corner goes in the new grid (negative crops the
## left/top). New cells are empty; objects move with their tiles.
func resize(new_cols: int, new_rows: int, offset: Vector2i = Vector2i.ZERO) -> void:
	new_cols = clampi(new_cols, MIN_GRID, MAX_GRID)
	new_rows = clampi(new_rows, MIN_GRID, MAX_GRID)
	begin_edit()
	var old_tiles: Array = data["tiles"]
	var out: Array = []
	for r in new_rows:
		var src_r := r - offset.y
		var s := ""
		for c in new_cols:
			var src_c := c - offset.x
			if src_r >= 0 and src_r < old_tiles.size() and src_c >= 0 and src_c < (old_tiles[src_r] as String).length():
				s += (old_tiles[src_r] as String)[src_c]
			else:
				s += "."
		out.append(s)
	var objs := {}
	for key in (data["objects"] as Dictionary):
		var p := (key as String).split(",")
		var nc := int(p[0]) + offset.x
		var nr := int(p[1]) + offset.y
		if nc >= 0 and nr >= 0 and nc < new_cols and nr < new_rows:
			objs["%d,%d" % [nc, nr]] = data["objects"][key]
	data["tiles"] = out
	data["objects"] = objs
	data["grid"] = {"cols": new_cols, "rows": new_rows}
	_touch("grid")
	_touch("tiles")
	_prune_objects()
	end_edit()
	clear_selection()


# ---------------------------------------------------------------- minigames

## The level's minigame definitions (live array).
func minigames() -> Array:
	return data["minigames"]


## A minigame id not used yet, starting from base.
func unique_minigame_id(base: String) -> String:
	var clean := base.strip_edges().to_lower().replace(" ", "_")
	if clean == "":
		clean = "puzzle"
	var id := clean
	var n := 2
	while not LevelFile.minigame(data, id).is_empty():
		id = "%s_%d" % [clean, n]
		n += 1
	return id


## Add a minigame of the given kind. Returns its index.
func add_minigame(kind: String) -> int:
	begin_edit()
	var entry := catalog.minigame_kind_entry(kind)
	var m := {"id": unique_minigame_id(kind), "name": str(entry.get("name", kind)), "kind": kind, "params": {}}
	if bool(entry.get("questions", false)):
		m["questions"] = [{"q": "Question?", "right": "Right answer", "wrong": ["Wrong answer"]}]
	minigames().append(m)
	_touch("minigames_list")
	end_edit()
	return minigames().size() - 1


## Duplicate minigame i (new id). Returns the new index.
func duplicate_minigame(i: int) -> int:
	if i < 0 or i >= minigames().size():
		return -1
	begin_edit()
	var copy: Dictionary = (minigames()[i] as Dictionary).duplicate(true)
	copy["id"] = unique_minigame_id(str(copy["id"]))
	copy["name"] = str(copy.get("name", "")) + " copy"
	minigames().insert(i + 1, copy)
	_touch("minigames_list")
	end_edit()
	return i + 1


## Delete minigame i. Lock terminals that used it fall back to "random".
func delete_minigame(i: int) -> void:
	if i < 0 or i >= minigames().size():
		return
	begin_edit()
	var id := str((minigames()[i] as Dictionary).get("id", ""))
	minigames().remove_at(i)
	_rewrite_terminal_refs(id, "random")
	_touch("minigames_list")
	end_edit()


## Set the id, name or kind of minigame i. Changing the id updates the lock terminals that used it. Returns an error text or "".
func set_minigame_field(i: int, key: String, value: String) -> String:
	if i < 0 or i >= minigames().size():
		return "No such minigame."
	var m: Dictionary = minigames()[i]
	if str(m.get(key, "")) == value:
		return ""
	if key == "id":
		var clean := value.strip_edges()
		if clean == "":
			return "The id cannot be empty."
		for j in minigames().size():
			if j != i and str((minigames()[j] as Dictionary).get("id", "")) == clean:
				return "Another minigame already has the id '%s'." % clean
		begin_edit()
		_rewrite_terminal_refs(str(m["id"]), clean)
		m["id"] = clean
		_touch("minigames_list")
		end_edit("mg_id:%d" % i)
		return ""
	begin_edit()
	m[key] = value
	if key == "kind":
		m["params"] = {}
		if bool(catalog.minigame_kind_entry(value).get("questions", false)):
			if not m.has("questions"):
				m["questions"] = [{"q": "Question?", "right": "Right answer", "wrong": ["Wrong answer"]}]
		else:
			m.erase("questions")
		_touch("minigames_list")
	else:
		_touch("minigames")
	end_edit("mg_%s:%d" % [key, i])
	return ""


## The value of a minigame parameter (stored value or the catalog default).
func get_minigame_param(i: int, key: String) -> Variant:
	var m: Dictionary = minigames()[i]
	var params: Dictionary = m.get("params", {})
	if params.has(key):
		return params[key]
	return EditorCatalog.default_of(catalog.minigame_kind_entry(str(m.get("kind", ""))).get("params", []), key)


## Set a minigame parameter (a value equal to the default is not stored).
func set_minigame_param(i: int, key: String, value: Variant) -> void:
	if i < 0 or i >= minigames().size():
		return
	var m: Dictionary = minigames()[i]
	var defs: Array = catalog.minigame_kind_entry(str(m.get("kind", ""))).get("params", [])
	begin_edit()
	if typeof(m.get("params")) != TYPE_DICTIONARY:
		m["params"] = {}
	var params: Dictionary = m["params"]
	if _same_value(EditorCatalog.default_of(defs, key), value):
		params.erase(key)
	else:
		params[key] = value
	_touch("minigames")
	end_edit("mg_param:%d:%s" % [i, key])


## The questions of minigame i (live array; only kinds with "questions": true have any).
func questions(i: int) -> Array:
	var m: Dictionary = minigames()[i]
	if typeof(m.get("questions")) != TYPE_ARRAY:
		return []
	return m["questions"]


## Add a blank question to minigame i.
func add_question(i: int) -> void:
	begin_edit()
	var m: Dictionary = minigames()[i]
	if typeof(m.get("questions")) != TYPE_ARRAY:
		m["questions"] = []
	(m["questions"] as Array).append({"q": "New question?", "right": "Right answer", "wrong": ["Wrong answer"]})
	_touch("minigames_list")
	end_edit()


## Remove question q of minigame i.
func remove_question(i: int, q: int) -> void:
	var qs := questions(i)
	if q < 0 or q >= qs.size():
		return
	begin_edit()
	qs.remove_at(q)
	_touch("minigames_list")
	end_edit()


## Set the "q" or "right" text of question q of minigame i.
func set_question_text(i: int, q: int, key: String, text: String) -> void:
	var qs := questions(i)
	if q < 0 or q >= qs.size() or str((qs[q] as Dictionary).get(key, "")) == text:
		return
	begin_edit()
	(qs[q] as Dictionary)[key] = text
	_touch("minigames")
	end_edit("mg_q:%d:%d:%s" % [i, q, key])


## Add a wrong answer to question q of minigame i.
func add_wrong_answer(i: int, q: int) -> void:
	var qs := questions(i)
	if q < 0 or q >= qs.size():
		return
	begin_edit()
	var qd: Dictionary = qs[q]
	if typeof(qd.get("wrong")) != TYPE_ARRAY:
		qd["wrong"] = []
	(qd["wrong"] as Array).append("Another wrong answer")
	_touch("minigames_list")
	end_edit()


## Remove wrong answer w of question q of minigame i.
func remove_wrong_answer(i: int, q: int, w: int) -> void:
	var qs := questions(i)
	if q < 0 or q >= qs.size():
		return
	var wrong: Array = (qs[q] as Dictionary).get("wrong", [])
	if w < 0 or w >= wrong.size():
		return
	begin_edit()
	wrong.remove_at(w)
	_touch("minigames_list")
	end_edit()


## Set the text of wrong answer w of question q of minigame i.
func set_wrong_answer(i: int, q: int, w: int, text: String) -> void:
	var qs := questions(i)
	if q < 0 or q >= qs.size():
		return
	var wrong: Array = (qs[q] as Dictionary).get("wrong", [])
	if w < 0 or w >= wrong.size() or str(wrong[w]) == text:
		return
	begin_edit()
	wrong[w] = text
	_touch("minigames")
	end_edit("mg_w:%d:%d:%d" % [i, q, w])


## The values a lock terminal's puzzle can be: "random", the level's minigame ids, then the built-in kinds.
func minigame_choices() -> Array[String]:
	var out: Array[String] = ["random"]
	for m in minigames():
		out.append(str((m as Dictionary).get("id", "")))
	for k in catalog.minigame_kind_names():
		if not out.has(k):
			out.append(k)
	return out


func _rewrite_terminal_refs(old_id: String, new_id: String) -> void:
	var objects: Dictionary = data["objects"]
	for key in objects.keys():
		var e: Dictionary = objects[key]
		if str(e.get("type", "")) != "lock_terminal":
			continue
		var props: Dictionary = e.get("props", {})
		if str(props.get("minigame", "")) == old_id:
			if new_id == "random":
				props.erase("minigame")
			else:
				props["minigame"] = new_id
			_touch("objects")
	_prune_objects()


# ---------------------------------------------------------------- validation

## Everything wrong with the level: an array of {"level": "error" | "warn", "text": String, "cell": Vector2i} (cell is (-1,-1)
## when the problem is not at a tile). It adds editor-only checks to LevelFile.validate().
func validate() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var rx := RegEx.new()
	rx.compile("\\((\\d+),\\s*(\\d+)\\)")
	for e in LevelFile.validate(data):
		var cell := Vector2i(-1, -1)
		var m := rx.search(e)
		if m != null:
			cell = Vector2i(int(m.get_string(1)), int(m.get_string(2)))
		out.append({"level": "error", "text": e, "cell": cell})
	var tiles: Array = data["tiles"]
	var h := tiles.size()
	var w := cols()
	# Machine footprints: cells covered by a machine must be empty and covered once.
	var covered := {}
	var spawns: Array[Vector2i] = []
	var exits: Array[Vector2i] = []
	var gate_cells := {}   # id -> Array[Vector2i]
	for r in h:
		var row: String = tiles[r]
		for c in w:
			var ch := row[c]
			if ch == ".":
				continue
			if ch == "P":
				spawns.append(Vector2i(c, r))
			elif ch == "E":
				exits.append(Vector2i(c, r))
			elif ch >= "1" and ch <= "9":
				if not gate_cells.has(ch):
					gate_cells[ch] = []
				(gate_cells[ch] as Array).append(Vector2i(c, r))
			if catalog.is_machine(ch):
				var fp := catalog.footprint(ch)
				if c + fp.x > w or r - fp.y + 1 < 0:
					out.append({"level": "error", "text": "%s at (%d,%d) leaves the level." % [_name_of(ch), c, r], "cell": Vector2i(c, r)})
				else:
					for dc in fp.x:
						for dr in fp.y:
							if dc == 0 and dr == 0:
								continue
							var k := Vector2i(c + dc, r - dr)
							if not covered.has(k):
								covered[k] = []
							(covered[k] as Array).append(Vector2i(c, r))
			elif (ch == "l" or ch == "i" or ch == "c") and (r + 1 >= h or not SOLID.contains(TileRegistry.physics_char((tiles[r + 1] as String)[c]))):
				out.append({"level": "warn", "text": "%s at (%d,%d) is not on solid ground." % [_name_of(ch), c, r], "cell": Vector2i(c, r)})
	for r in h:
		var row2: String = tiles[r]
		for c in w:
			var k2 := Vector2i(c, r)
			if not covered.has(k2):
				continue
			var letters: Array = covered[k2]
			if row2[c] != ".":
				out.append({"level": "error", "text": "Tile '%s' at (%d,%d) is inside the footprint of the machine at (%d,%d)." % [row2[c], c, r, (letters[0] as Vector2i).x, (letters[0] as Vector2i).y], "cell": k2})
			elif letters.size() > 1:
				out.append({"level": "error", "text": "Machines at (%d,%d) and (%d,%d) overlap." % [(letters[0] as Vector2i).x, (letters[0] as Vector2i).y, (letters[1] as Vector2i).x, (letters[1] as Vector2i).y], "cell": k2})
	for i in range(1, spawns.size()):
		out.append({"level": "error", "text": "Second player spawn at (%d,%d): only one is allowed." % [spawns[i].x, spawns[i].y], "cell": spawns[i]})
	for i in range(1, exits.size()):
		out.append({"level": "error", "text": "Second exit at (%d,%d): only one is allowed." % [exits[i].x, exits[i].y], "cell": exits[i]})
	for id in gate_cells:
		var cells: Array = gate_cells[id]
		var first: Vector2i = cells[0]
		for i in cells.size():
			var cc: Vector2i = cells[i]
			if cc.x != first.x or cc.y != first.y + i:
				out.append({"level": "warn", "text": "Laser gate %s is not one vertical run (the game wants a single column)." % id, "cell": cc})
				break
	# Terminals: explicit gate ids and puzzle references must exist.
	var objects: Dictionary = data["objects"]
	for key in objects:
		var e2: Dictionary = objects[key]
		if str(e2.get("type", "")) != "lock_terminal":
			continue
		var parts := (key as String).split(",")
		var cell2 := Vector2i(int(parts[0]), int(parts[1]))
		var props: Dictionary = e2.get("props", {})
		var laser := str(props.get("laser", "auto"))
		if laser != "auto" and not gate_cells.has(laser):
			out.append({"level": "warn", "text": "Lock terminal at (%d,%d) opens laser gate %s, which is not in the level." % [cell2.x, cell2.y, laser], "cell": cell2})
		var puzzle := str(props.get("minigame", "random"))
		if not minigame_choices().has(puzzle):
			out.append({"level": "warn", "text": "Lock terminal at (%d,%d) uses the unknown puzzle '%s'." % [cell2.x, cell2.y, puzzle], "cell": cell2})
	# Minigames: unique ids, quiz kinds need questions.
	var seen := {}
	for i in minigames().size():
		var mg: Dictionary = minigames()[i]
		var id2 := str(mg.get("id", ""))
		if id2 == "" or seen.has(id2):
			out.append({"level": "error", "text": "Minigame %d has an empty or duplicate id '%s'." % [i + 1, id2], "cell": Vector2i(-1, -1)})
		seen[id2] = true
		var kind := catalog.minigame_kind_entry(str(mg.get("kind", "")))
		if kind.is_empty():
			out.append({"level": "error", "text": "Minigame '%s' has the unknown kind '%s'." % [id2, str(mg.get("kind", ""))], "cell": Vector2i(-1, -1)})
		elif bool(kind.get("questions", false)):
			var qs := questions(i)
			if qs.is_empty():
				out.append({"level": "warn", "text": "Minigame '%s' has no questions." % id2, "cell": Vector2i(-1, -1)})
			for q in qs:
				if (q as Dictionary).get("wrong", []).is_empty():
					out.append({"level": "warn", "text": "A question of minigame '%s' has no wrong answers." % id2, "cell": Vector2i(-1, -1)})
					break
	return out


## Why the level cannot be play-tested ("" if it can): no or several spawns/exits, or a broken grid.
func unplayable_reason() -> String:
	var structure := structure_errors(data)
	if not structure.is_empty():
		return structure[0]
	var spawns := 0
	var exits := 0
	for row in (data["tiles"] as Array):
		spawns += (row as String).count("P")
		exits += (row as String).count("E")
	if spawns != 1:
		return "The level needs exactly one player spawn (it has %d)." % spawns
	if exits != 1 and not (exits == 0 and str((data.get("meta", {}) as Dictionary).get("boss", "")) != ""):
		return "The level needs exactly one exit (it has %d)." % exits
	return ""
