extends SceneTree
## The level editor's document model (tools/level_editor/editor_document.gd), without any window: new level, painting and
## erasing, objects (place, move, name, values), undo/redo, saving and loading, built-in levels, minigames and validation.
## Exits non-zero on failure.
## Run: godot_console --headless --fixed-fps 60 --path . --script res://tools/tests/editor_test.gd

# TEMP_FILE: where the round-trip test writes its level (user:// is the project's private folder).
const TEMP_FILE := "user://editor_test.sablevel.json"

var ok := true


func _check(label: String, cond: bool, detail := "") -> void:
	print(("PASS  " if cond else "FAIL  "), label, "  ", detail)
	if not cond:
		ok = false


func _initialize() -> void:
	_main()


func _canon(d: Dictionary) -> String:
	return JSON.stringify(d, "", true)


func _errors(doc: EditorDocument) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e in doc.validate():
		if str(e["level"]) == "error":
			out.append(e)
	return out


func _write_text(text: String) -> void:
	var f := FileAccess.open(TEMP_FILE, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _remove_temp() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_FILE))


func _main() -> void:
	var doc := EditorDocument.new()

	# --- new level
	doc.new_level(40, 20)
	_check("new level size", doc.cols() == 40 and doc.rows() == 20, "%dx%d" % [doc.cols(), doc.rows()])
	_check("new level is valid", _errors(doc).is_empty(), str(_errors(doc)))
	_check("new level has spawn and exit", doc.find_char("P").x >= 0 and doc.find_char("E").x >= 0)
	_check("new level is playable", doc.unplayable_reason() == "")

	# --- tiles
	var r0 := doc.place(10, 5, "#")
	_check("place a ground tile", bool(r0["ok"]) and doc.get_cell(10, 5) == "#")
	var stroke: Array[Vector2i] = [Vector2i(11, 5), Vector2i(12, 5), Vector2i(13, 5)]
	doc.place_cells(stroke, "=")
	_check("paint a stroke", doc.get_cell(12, 5) == "=")
	doc.erase(10, 5)
	_check("erase a tile", doc.get_cell(10, 5) == ".")
	_check("outside placement refused", not bool(doc.place(-1, 3, "#")["ok"]) and not bool(doc.place(40, 3, "#")["ok"]))

	# --- objects: place, move, name, values
	var bro_cell := Vector2i(20, doc.rows() - 5)
	doc.place(bro_cell.x, bro_cell.y, "B")
	_check("place an AI Bro", doc.get_cell(bro_cell.x, bro_cell.y) == "B")
	_check("object type", doc.object_type_at(bro_cell.x, bro_cell.y) == "ai_bro")
	_check("bro has room on the floor", doc.placement_problem(bro_cell.x, bro_cell.y, "B").is_empty())
	_check("bro on a 1-tile ledge warns", str(doc.placement_problem(11, 4, "B").get("level", "")) == "warn")
	doc.set_object_name(bro_cell.x, bro_cell.y, "Lobby Bro")
	_check("rename an object", doc.object_name(bro_cell.x, bro_cell.y) == "Lobby Bro")
	doc.set_prop(bro_cell.x, bro_cell.y, "chase_speed", 200.0)
	doc.set_prop(bro_cell.x, bro_cell.y, "patrol_speed", 90.0)   # equal to the default
	var props: Dictionary = doc.object_entry(bro_cell.x, bro_cell.y).get("props", {})
	_check("only non-default values are stored", props.size() == 1 and props.has("chase_speed"), str(props))
	_check("get_prop gives the stored value", is_equal_approx(float(doc.get_prop(bro_cell.x, bro_cell.y, "chase_speed")), 200.0))
	_check("get_prop gives the default", is_equal_approx(float(doc.get_prop(bro_cell.x, bro_cell.y, "hit_range")), 75.0))
	doc.reset_prop(bro_cell.x, bro_cell.y, "chase_speed")
	_check("reset removes the stored value", not doc.is_prop_changed(bro_cell.x, bro_cell.y, "chase_speed") and (doc.object_entry(bro_cell.x, bro_cell.y).get("props", {}) as Dictionary).is_empty())
	doc.set_prop(bro_cell.x, bro_cell.y, "chase_speed", 210.0)

	var moved := doc.move_region(Rect2i(bro_cell, Vector2i.ONE), Vector2i(3, 0), false)
	var new_cell := bro_cell + Vector2i(3, 0)
	_check("move an object", bool(moved["ok"]) and doc.get_cell(new_cell.x, new_cell.y) == "B" and doc.get_cell(bro_cell.x, bro_cell.y) == ".")
	_check("object data moves with it", doc.object_name(new_cell.x, new_cell.y) == "Lobby Bro" and is_equal_approx(float(doc.get_prop(new_cell.x, new_cell.y, "chase_speed")), 210.0))
	_check("old object entry is gone", doc.object_entry(bro_cell.x, bro_cell.y).is_empty())
	doc.erase(new_cell.x, new_cell.y)
	_check("erasing an object drops its data", (doc.data["objects"] as Dictionary).is_empty())

	# --- machines
	var g := doc.place(5, 10, "G")
	_check("place a machine", bool(g["ok"]))
	_check("machine blocks a tile in its footprint", not bool(doc.place(6, 10, "#")["ok"]))
	_check("machine blocks a second machine", not bool(doc.place(6, 10, "R")["ok"]))
	_check("thing_at finds a machine from its footprint", Rect2i(doc.thing_at(6, 8)["rect"]) == Rect2i(5, 8, 2, 3))
	doc.erase(6, 9)
	_check("erasing in the footprint removes the machine", doc.get_cell(5, 10) == ".")
	_check("lamp not on solid ground warns", str(doc.placement_problem(30, 3, "l").get("level", "")) == "warn")

	# --- piranha tank settings attach to the pit
	var pit_cells: Array[Vector2i] = [Vector2i(25, 15), Vector2i(26, 15), Vector2i(25, 16), Vector2i(26, 16)]
	doc.place_cells(pit_cells, "W")
	_check("a pit is one thing", Rect2i(doc.thing_at(26, 16)["rect"]) == Rect2i(25, 15, 2, 2) and bool(doc.thing_at(26, 16)["object"]))
	doc.set_prop(25, 15, "fish_count", 4)
	_check("tank settings are stored on the pit", doc.object_type_at(25, 15) == "tank_settings" and int(doc.get_prop(25, 15, "fish_count")) == 4)
	doc.move_region(Rect2i(25, 15, 2, 2), Vector2i(-3, 0), false)
	_check("tank settings move with the pit", int(doc.get_prop(22, 15, "fish_count")) == 4 and doc.object_entry(25, 15).is_empty())
	doc.undo()
	doc.undo()
	doc.undo()
	_check("palette has no marker-less items", not EditorCatalog.get_instance().palette_items().any(func(e: Dictionary) -> bool: return str(e.get("char", "")) == ""))

	# --- unique things, validation of a second spawn
	var old_spawn := doc.find_char("P")
	doc.place(8, 4, "P")
	_check("placing a spawn moves the old one", doc.find_char("P") == Vector2i(8, 4) and doc.get_cell(old_spawn.x, old_spawn.y) == ".")
	var rows_before: Array = (doc.data["tiles"] as Array).duplicate()
	var row3: String = (doc.data["tiles"] as Array)[3]
	(doc.data["tiles"] as Array)[3] = row3.substr(0, 25) + "P" + row3.substr(26)   # force a second spawn by hand
	var found := false
	for e in _errors(doc):
		if str(e["text"]).contains("Second player spawn"):
			found = true
	_check("validation catches a second spawn", found)
	_check("a second spawn makes the level unplayable", doc.unplayable_reason() != "")
	(doc.data["tiles"] as Array)[3] = rows_before[3]
	_check("valid again", _errors(doc).is_empty(), str(_errors(doc)))

	# --- undo / redo
	var snapshot := _canon(doc.data)
	doc.place(15, 6, "#")
	doc.place(16, 6, "#")
	_check("undo available", doc.can_undo())
	doc.undo()
	_check("undo one edit", doc.get_cell(16, 6) == "." and doc.get_cell(15, 6) == "#")
	doc.undo()
	_check("undo second edit", doc.get_cell(15, 6) == "." and _canon(doc.data) == snapshot)
	doc.redo()
	doc.redo()
	_check("redo both", doc.get_cell(15, 6) == "#" and doc.get_cell(16, 6) == "#")
	doc.begin_edit()
	doc.place(17, 6, "#")
	doc.place(18, 6, "#")
	doc.end_edit()
	doc.undo()
	_check("a group is one undo step", doc.get_cell(17, 6) == "." and doc.get_cell(18, 6) == "." and doc.get_cell(16, 6) == "#")
	doc.place(1, 1, "O")
	_check("an edit clears redo", not doc.can_redo())
	for i in EditorDocument.HISTORY_LIMIT + 20:
		doc.place(2 + i % 30, 7, "#" if i % 2 == 0 else ".")
	var steps := 0
	while doc.undo():
		steps += 1
	_check("history is limited", steps <= EditorDocument.HISTORY_LIMIT, "steps=%d" % steps)

	# --- copy / paste / delete / duplicate
	doc.new_level(40, 20)
	var row_cells: Array[Vector2i] = [Vector2i(10, 8), Vector2i(11, 8), Vector2i(12, 8)]
	doc.place_cells(row_cells, "#")
	doc.select_rect(Rect2i(10, 8, 3, 1))
	doc.copy_selection()
	var pv := doc.paste_at(Vector2i(20, 8))
	_check("paste a block", bool(pv["ok"]) and doc.get_cell(22, 8) == "#" and doc.sel == Rect2i(20, 8, 3, 1))
	doc.delete_selection()
	_check("delete the selection", doc.get_cell(21, 8) == "." and not doc.has_selection())
	doc.select_rect(Rect2i(10, 8, 1, 1))
	var dup := doc.duplicate_selection()
	_check("duplicate", bool(dup["ok"]))
	var cp := doc.move_region(Rect2i(10, 8, 3, 1), Vector2i(0, -2), true)
	_check("copy-move keeps the source", bool(cp["ok"]) and doc.get_cell(10, 8) == "#" and doc.get_cell(10, 6) == "#")
	_check("move outside is refused", not bool(doc.move_region(Rect2i(10, 8, 3, 1), Vector2i(100, 0), false)["ok"]))

	# --- settings
	doc.set_setting("terrain", "gravity_scale", 1.5)
	doc.set_setting("player", "max_health", 150)
	doc.set_setting("player", "speed", 380.0)   # default: not stored
	doc.set_setting("meta", "title", "MY LEVEL")
	_check("terrain value stored", is_equal_approx(float((doc.data["terrain"] as Dictionary)["gravity_scale"]), 1.5))
	_check("player stores only non-defaults", (doc.data["player"] as Dictionary).size() == 1 and int((doc.data["player"] as Dictionary)["max_health"]) == 150)
	doc.reset_setting("player", "max_health")
	_check("player reset", (doc.data["player"] as Dictionary).is_empty())

	# --- resize
	doc.place(5, 15, "B")
	doc.set_object_name(5, 15, "Mover")
	doc.resize(50, 25, Vector2i(2, 3))
	_check("resize with offset", doc.cols() == 50 and doc.rows() == 25 and doc.get_cell(7, 18) == "B" and doc.object_name(7, 18) == "Mover")
	_check("rows match the grid", (doc.data["tiles"] as Array).size() == 25 and ((doc.data["tiles"] as Array)[0] as String).length() == 50)

	# --- minigames
	doc.new_level(40, 20)
	var m := doc.add_minigame("wrong_only")
	_check("add a minigame", doc.minigames().size() == 1 and str(doc.minigames()[m]["kind"]) == "wrong_only")
	_check("quiz kinds get a question", doc.questions(m).size() == 1)
	doc.set_minigame_field(m, "name", "Riddles")
	doc.set_minigame_param(m, "rounds", 3)
	doc.set_minigame_param(m, "rounds", 2)   # default again
	_check("default params are not stored", (doc.minigames()[m]["params"] as Dictionary).is_empty())
	doc.set_minigame_param(m, "rounds", 4)
	doc.set_question_text(m, 0, "q", "Is water wet?")
	doc.add_wrong_answer(m, 0)
	doc.set_wrong_answer(m, 0, 1, "Maybe")
	_check("edit questions", str(doc.questions(m)[0]["q"]) == "Is water wet?" and (doc.questions(m)[0]["wrong"] as Array).size() == 2)
	var d2 := doc.duplicate_minigame(m)
	_check("duplicate gets a new id", d2 == 1 and str(doc.minigames()[1]["id"]) != str(doc.minigames()[0]["id"]))
	_check("duplicate ids are refused", doc.set_minigame_field(1, "id", str(doc.minigames()[0]["id"])) != "")
	var old_id := str(doc.minigames()[0]["id"])
	var term_cell := Vector2i(10, 15)
	doc.place(term_cell.x, term_cell.y, "L")
	doc.place(30, 14, "1")
	doc.set_prop(term_cell.x, term_cell.y, "minigame", old_id)
	_check("terminal can use a level minigame", doc.minigame_choices().has(old_id) and doc.minigame_choices().has("timing"))
	doc.set_minigame_field(0, "id", "riddles")
	_check("renaming an id updates terminals", str(doc.get_prop(term_cell.x, term_cell.y, "minigame")) == "riddles")
	doc.delete_minigame(1)
	doc.delete_minigame(0)
	_check("delete minigames", doc.minigames().is_empty())
	_check("terminal falls back to random", str(doc.get_prop(term_cell.x, term_cell.y, "minigame")) == "random")
	doc.undo()
	_check("undo of a delete", doc.minigames().size() == 1)

	# --- save and reload
	doc.set_setting("terrain", "background", "background")
	doc.set_object_name(term_cell.x, term_cell.y, "Gate keeper")
	doc.set_prop(term_cell.x, term_cell.y, "laser", "1")
	var save_err := doc.save(TEMP_FILE)
	_check("save", save_err == OK and not doc.dirty and doc.path == TEMP_FILE)
	var doc2 := EditorDocument.new()
	var res := doc2.load_file(TEMP_FILE)
	_check("load", bool(res["ok"]), str(res["errors"]))
	_check("round trip is equal", _canon(doc2.data) == _canon(doc.data))
	_check("loaded object data", doc2.object_name(term_cell.x, term_cell.y) == "Gate keeper")

	# --- bad files never crash
	_write_text("{ not json")
	var res_bad := doc2.load_file(TEMP_FILE)
	_check("bad json is refused", not bool(res_bad["ok"]) and not (res_bad["errors"] as Array).is_empty())
	_check("document survives a bad file", doc2.cols() == 40)
	_write_text('{"format":1,"grid":{"cols":5,"rows":5},"tiles":["....."]}')
	var res_bad2 := doc2.load_file(TEMP_FILE)
	_check("mismatched grid is refused", not bool(res_bad2["ok"]))
	var res_missing := doc2.load_file("user://does_not_exist.sablevel.json")
	_check("missing file is refused", not bool(res_missing["ok"]))
	_remove_temp()

	# --- built-in levels
	for id in LevelData.ids():
		var b := EditorDocument.from_builtin(id)
		var rows := LevelData.map(id)
		_check("built-in '%s' converted" % id, b.cols() == rows[0].length() and b.rows() == rows.size() and LevelFile.tiles(b.data) == rows)
		var level_errors := LevelFile.validate(b.data)
		_check("built-in '%s' validates" % id, level_errors.is_empty(), str(level_errors))
		_check("built-in '%s' has no editor errors" % id, _errors(b).is_empty(), str(_errors(b).slice(0, 3)))
		b.save(TEMP_FILE)
		var b2 := EditorDocument.new()
		var rb := b2.load_file(TEMP_FILE)
		_check("built-in '%s' round trip" % id, bool(rb["ok"]) and _canon(b2.data) == _canon(b.data))
		_remove_temp()

	# --- catalog
	var cat := EditorCatalog.get_instance()
	_check("catalog has items in every group", cat.groups().size() >= 6 and cat.palette_items().size() > 25)
	var gate_items := cat.palette_items().filter(func(e: Dictionary) -> bool: return str(e.get("type", "")) == "laser_gate")
	_check("the palette has ONE laser gate item (its id is picked for you)", gate_items.size() == 1 and bool(gate_items[0].get("auto_id", false)), str(gate_items.size()))
	_check("but every gate id can still be drawn and named", not cat.entry_for_char("7").is_empty())
	var gd := EditorDocument.new()
	_check("a new gate gets the lowest free id", gd.next_free_gate_id() == "1")
	gd.place(10, 18, "1")
	gd.place(10, 17, "1")
	_check("the next gate gets the next id", gd.next_free_gate_id() == "2")
	_check("a gate id can be changed to a free one", gd.set_gate_id("1", "5") and gd.get_cell(10, 18) == "5" and gd.get_cell(10, 17) == "5" and not gd.has_gate("1"))
	gd.place(14, 18, "2")
	_check("but not to one another gate uses", not gd.set_gate_id("5", "2") and gd.has_gate("5"))
	_check("backgrounds are listed", EditorCatalog.backgrounds().has("background") and EditorCatalog.backgrounds().has(LevelData.level_dir(LevelData.DEFAULT_ID) + "background"))
	print("preview supported by the game: ", EditorMinigames.game_can_preview())

	await _ui_smoke()
	print("ALL PASS" if ok else "SOME FAILED")
	quit(0 if ok else 1)


func _mouse(canvas: EditorCanvas, cell: Vector2i, button: MouseButton, pressed: bool) -> void:
	var pos := canvas.pan + (Vector2(cell) + Vector2(0.5, 0.5)) * EditorCanvas.T * canvas.zoom
	var e := InputEventMouseButton.new()
	e.position = pos
	e.button_index = button
	e.pressed = pressed
	canvas._gui_input(e)


func _motion(canvas: EditorCanvas, cell: Vector2i) -> void:
	var e := InputEventMouseMotion.new()
	e.position = canvas.pan + (Vector2(cell) + Vector2(0.5, 0.5)) * EditorCanvas.T * canvas.zoom
	canvas._gui_input(e)


## Builds the whole editor window headless and drives the canvas with synthetic mouse events.
func _ui_smoke() -> void:
	var scene: PackedScene = load("res://tools/level_editor/level_editor.tscn")
	var ed: Control = scene.instantiate()
	root.add_child(ed)
	for i in 4:
		await process_frame
	var canvas: EditorCanvas = ed.canvas
	var d: EditorDocument = ed.doc
	_check("editor window builds", canvas != null and d != null and ed.palette != null and ed.inspector != null and ed.minigames != null)
	d.new_level(40, 20)
	canvas.zoom = 0.5
	canvas.pan = Vector2(10, 10)
	# paint a stroke with the ground armed
	canvas.set_armed(EditorCatalog.get_instance().entry_for_char("#"))
	canvas.set_tool(EditorCanvas.Tool.PAINT)
	_motion(canvas, Vector2i(10, 6))
	_mouse(canvas, Vector2i(10, 6), MOUSE_BUTTON_LEFT, true)
	_motion(canvas, Vector2i(14, 6))
	_mouse(canvas, Vector2i(14, 6), MOUSE_BUTTON_LEFT, false)
	_check("painting a stroke", d.get_cell(10, 6) == "#" and d.get_cell(12, 6) == "#" and d.get_cell(14, 6) == "#")
	d.undo()
	_check("a stroke is one undo step", d.get_cell(10, 6) == "." and d.get_cell(14, 6) == ".")
	# a rectangle fill
	canvas.set_tool(EditorCanvas.Tool.RECT)
	_mouse(canvas, Vector2i(5, 3), MOUSE_BUTTON_LEFT, true)
	_motion(canvas, Vector2i(7, 4))
	_mouse(canvas, Vector2i(7, 4), MOUSE_BUTTON_LEFT, false)
	_check("rectangle tool", d.get_cell(5, 3) == "#" and d.get_cell(7, 4) == "#" and d.get_cell(8, 4) == ".")
	# right click erases
	_mouse(canvas, Vector2i(5, 3), MOUSE_BUTTON_RIGHT, true)
	_mouse(canvas, Vector2i(5, 3), MOUSE_BUTTON_RIGHT, false)
	_check("right click erases", d.get_cell(5, 3) == ".")
	# select the spawn and drag it
	var spawn := d.find_char("P")
	canvas.set_tool(EditorCanvas.Tool.SELECT)
	_mouse(canvas, spawn, MOUSE_BUTTON_LEFT, true)
	_check("click selects an object", d.has_selection() and d.sel_object and d.sel_anchor == spawn)
	_motion(canvas, spawn + Vector2i(4, 0))
	_mouse(canvas, spawn + Vector2i(4, 0), MOUSE_BUTTON_LEFT, false)
	_check("drag moves the object", d.get_cell(spawn.x + 4, spawn.y) == "P" and d.get_cell(spawn.x, spawn.y) == ".")
	await process_frame
	_check("the inspector shows the selection", ed.inspector._content.get_child_count() > 2)
	# armed machine placement is validated
	canvas.set_armed(EditorCatalog.get_instance().entry_for_char("S"))
	canvas.set_tool(EditorCanvas.Tool.PAINT)
	_mouse(canvas, Vector2i(20, 15), MOUSE_BUTTON_LEFT, true)
	_mouse(canvas, Vector2i(20, 15), MOUSE_BUTTON_LEFT, false)
	_check("machine placed with the mouse", d.get_cell(20, 15) == "S")
	await process_frame
	_check("validation list refreshes", ed.problems.error_count() == 0)
	ed._open_builtin("test")
	await process_frame
	_check("opening a built-in level in the window", d.cols() > 10 and d.path == "" and d.dirty)
	ed.queue_free()
	await process_frame
