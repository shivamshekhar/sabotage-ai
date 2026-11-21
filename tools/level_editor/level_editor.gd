extends Control
## The sabotage.ai level editor window: menus, toolbar, the palette drawer, the canvas, the inspector, the minigame designer, the
## validation list and the status bar. It wires the parts together; all level changes go through EditorDocument.
## Run: godot --path . res://tools/level_editor/level_editor.tscn   (or tools/level_editor.sh)

# Menu command ids.
enum Cmd {
	NEW, OPEN, SAVE, SAVE_AS, RECOVER, QUIT,
	UNDO, REDO, CUT, COPY, PASTE, DUPLICATE, DELETE, DESELECT,
	GRID, BACKGROUND, FIT, ZOOM_IN, ZOOM_OUT, ZOOM_100, DRAWER,
	HELP, ABOUT, PLAY,
}

# CONFIG_PATH: where the editor remembers recent files and the last folder.
const CONFIG_PATH := "user://level_editor.cfg"

# AUTOSAVE_PATH: where the recovery copy of unsaved work is written.
const AUTOSAVE_PATH := "user://level_editor_autosave.sablevel.json"

# PLAYTEST_PATH: the temporary level file the Play button writes and hands to the game.
const PLAYTEST_PATH := "user://level_editor_playtest.sablevel.json"

# AUTOSAVE_SECONDS: how often unsaved changes are copied to AUTOSAVE_PATH. Lower: less work lost after a crash, more disk writes.
const AUTOSAVE_SECONDS := 60.0

# MAX_RECENT: how many recent files the File menu remembers.
const MAX_RECENT := 8

# DEFAULT_WINDOW: window size used when the editor opens in a window of the default size. The user may resize it freely.
const DEFAULT_WINDOW := Vector2i(1500, 880)

# MIN_WINDOW: smallest window size, so the drawer, canvas and inspector never overlap.
const MIN_WINDOW := Vector2i(1100, 640)

var doc: EditorDocument
var catalog: EditorCatalog
var canvas: EditorCanvas
var palette: EditorPalette
var inspector: LevelInspector
var problems: EditorProblems
var minigames: EditorMinigames
var tabs: TabContainer

var _title_label: Label
var _hint_label: Label
var _cell_label: Label
var _zoom_label: Label
var _tool_buttons: Dictionary = {}
var _recent_menu: PopupMenu
var _builtin_menu: PopupMenu
var _file_menu: PopupMenu
var _edit_menu: PopupMenu
var _view_menu: PopupMenu
var _file_dialog: FileDialog
var _pending_after_save := Callable()
var _recent: Array[String] = []
var _last_dir := ""
var _play_pid := 0
var _autosave: Timer


func _ready() -> void:
	var win := get_window()
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	win.min_size = MIN_WINDOW
	if DisplayServer.get_name() != "headless" and not OS.has_feature("movie") and win.size.x < 1400:
		win.size = DEFAULT_WINDOW
		win.move_to_center()
	get_tree().auto_accept_quit = false
	theme = EditorTheme.build()
	catalog = EditorCatalog.get_instance()
	doc = EditorDocument.new()
	_load_config()
	_build_ui()
	doc.changed.connect(_on_doc_changed)
	doc.selection_changed.connect(_update_title)
	canvas.set_document(doc)
	inspector.set_document(doc)
	problems.set_document(doc)
	minigames.set_document(doc)
	problems.refresh()
	canvas.fit_view.call_deferred()
	_update_title()
	_autosave = Timer.new()
	_autosave.wait_time = AUTOSAVE_SECONDS
	_autosave.timeout.connect(_do_autosave)
	add_child(_autosave)
	_autosave.start()
	_select_tool(EditorCanvas.Tool.SELECT)
	if OS.get_environment("SABOTAGE_EDITOR_DEMO") != "":
		_demo.call_deferred(OS.get_environment("SABOTAGE_EDITOR_DEMO"))


# ---------------------------------------------------------------- UI construction

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = EditorTheme.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 2)
	add_child(root)
	root.add_child(_build_menu_bar())
	root.add_child(_build_toolbar())

	var middle := HSplitContainer.new()
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(middle)
	palette = EditorPalette.new()
	palette.item_picked.connect(_on_item_picked)
	middle.add_child(palette)

	var right_split := HSplitContainer.new()
	right_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle.add_child(right_split)
	tabs = TabContainer.new()
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_split.add_child(tabs)
	canvas = EditorCanvas.new()
	canvas.name = "Level"
	canvas.hint.connect(_set_hint)
	canvas.cell_hovered.connect(_on_cell_hovered)
	canvas.entry_picked.connect(_on_entry_picked)
	canvas.disarm_requested.connect(_disarm)
	tabs.add_child(canvas)
	minigames = EditorMinigames.new()
	minigames.name = "Minigames"
	minigames.status.connect(_set_hint)
	tabs.add_child(minigames)
	inspector = LevelInspector.new()
	right_split.add_child(inspector)

	problems = EditorProblems.new()
	problems.jump_requested.connect(_jump_to)
	root.add_child(problems)
	root.add_child(_build_status_bar())

	_file_dialog = FileDialog.new()
	_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_file_dialog.add_filter("*.sablevel.json", "sabotage.ai level")
	_file_dialog.use_native_dialog = false
	_file_dialog.min_size = Vector2i(760, 480)
	_file_dialog.file_selected.connect(_on_file_chosen)
	add_child(_file_dialog)


func _menu(menu_title: String, bar: HBoxContainer) -> PopupMenu:
	var mb := MenuButton.new()
	mb.text = menu_title
	mb.flat = true
	bar.add_child(mb)
	var pm := mb.get_popup()
	pm.id_pressed.connect(_on_command)
	return pm


func _build_menu_bar() -> Control:
	var bar := HBoxContainer.new()
	_file_menu = _menu("File", bar)
	_file_menu.add_item("New...    Ctrl+N", Cmd.NEW)
	_file_menu.add_item("Open...    Ctrl+O", Cmd.OPEN)
	_builtin_menu = PopupMenu.new()
	_builtin_menu.name = "BuiltinMenu"
	_builtin_menu.id_pressed.connect(_on_builtin_chosen)
	_file_menu.add_child(_builtin_menu)
	_file_menu.add_submenu_node_item("Open game level", _builtin_menu)
	_recent_menu = PopupMenu.new()
	_recent_menu.name = "RecentMenu"
	_recent_menu.id_pressed.connect(_on_recent_chosen)
	_file_menu.add_child(_recent_menu)
	_file_menu.add_submenu_node_item("Open recent", _recent_menu)
	_file_menu.add_separator()
	_file_menu.add_item("Save    Ctrl+S", Cmd.SAVE)
	_file_menu.add_item("Save as...    Ctrl+Shift+S", Cmd.SAVE_AS)
	_file_menu.add_item("Recover autosave", Cmd.RECOVER)
	_file_menu.add_separator()
	_file_menu.add_item("Play-test    F5", Cmd.PLAY)
	_file_menu.add_separator()
	_file_menu.add_item("Quit    Ctrl+Q", Cmd.QUIT)
	_file_menu.about_to_popup.connect(_refresh_file_menu)

	_edit_menu = _menu("Edit", bar)
	_edit_menu.add_item("Undo    Ctrl+Z", Cmd.UNDO)
	_edit_menu.add_item("Redo    Ctrl+Y", Cmd.REDO)
	_edit_menu.add_separator()
	_edit_menu.add_item("Cut    Ctrl+X", Cmd.CUT)
	_edit_menu.add_item("Copy    Ctrl+C", Cmd.COPY)
	_edit_menu.add_item("Paste    Ctrl+V", Cmd.PASTE)
	_edit_menu.add_item("Duplicate    Ctrl+D", Cmd.DUPLICATE)
	_edit_menu.add_item("Delete    Del", Cmd.DELETE)
	_edit_menu.add_item("Deselect    Esc", Cmd.DESELECT)
	_edit_menu.about_to_popup.connect(_refresh_edit_menu)

	_view_menu = _menu("View", bar)
	_view_menu.add_check_item("Grid    G", Cmd.GRID)
	_view_menu.add_check_item("Background preview", Cmd.BACKGROUND)
	_view_menu.add_check_item("Palette drawer    Ctrl+B", Cmd.DRAWER)
	_view_menu.add_separator()
	_view_menu.add_item("Fit level    F", Cmd.FIT)
	_view_menu.add_item("Zoom in    +", Cmd.ZOOM_IN)
	_view_menu.add_item("Zoom out    -", Cmd.ZOOM_OUT)
	_view_menu.add_item("Zoom 100%    1", Cmd.ZOOM_100)
	_view_menu.set_item_checked(_view_menu.get_item_index(Cmd.GRID), true)
	_view_menu.set_item_checked(_view_menu.get_item_index(Cmd.BACKGROUND), true)
	_view_menu.set_item_checked(_view_menu.get_item_index(Cmd.DRAWER), true)

	var help := _menu("Help", bar)
	help.add_item("Shortcuts    F1", Cmd.HELP)
	help.add_item("About", Cmd.ABOUT)

	_title_label = Label.new()
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_title_label.add_theme_color_override("font_color", EditorTheme.DIM_TEXT)
	bar.add_child(_title_label)
	return bar


func _build_toolbar() -> Control:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 4)
	var drawer := Button.new()
	drawer.text = "Drawer"
	drawer.tooltip_text = "Hide or show the palette drawer (Ctrl+B)"
	drawer.focus_mode = Control.FOCUS_NONE
	drawer.pressed.connect(func() -> void: _on_command(Cmd.DRAWER))
	bar.add_child(drawer)
	bar.add_child(VSeparator.new())
	var group := ButtonGroup.new()
	var defs := [
		[EditorCanvas.Tool.SELECT, "Select", "Select and move things (V)"],
		[EditorCanvas.Tool.PAINT, "Paint", "Paint the armed item (B)"],
		[EditorCanvas.Tool.RECT, "Rect", "Fill a rectangle (R); Shift = outline"],
		[EditorCanvas.Tool.LINE, "Line", "Draw a line (L)"],
		[EditorCanvas.Tool.ERASER, "Eraser", "Erase (E); right click erases with any tool"],
		[EditorCanvas.Tool.EYEDROPPER, "Eyedrop", "Pick the item under the mouse (I)"],
	]
	for d in defs:
		var b := Button.new()
		b.text = str(d[1])
		b.tooltip_text = str(d[2])
		b.toggle_mode = true
		b.button_group = group
		b.focus_mode = Control.FOCUS_NONE
		var t: EditorCanvas.Tool = d[0]
		b.pressed.connect(func() -> void: _select_tool(t))
		bar.add_child(b)
		_tool_buttons[t] = b
	bar.add_child(VSeparator.new())
	_tb("Undo", "Undo (Ctrl+Z)", bar, func() -> void: _on_command(Cmd.UNDO))
	_tb("Redo", "Redo (Ctrl+Y)", bar, func() -> void: _on_command(Cmd.REDO))
	bar.add_child(VSeparator.new())
	_tb("-", "Zoom out", bar, func() -> void: _on_command(Cmd.ZOOM_OUT))
	_zoom_label = Label.new()
	_zoom_label.custom_minimum_size = Vector2(48, 0)
	_zoom_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(_zoom_label)
	_tb("+", "Zoom in", bar, func() -> void: _on_command(Cmd.ZOOM_IN))
	_tb("Fit", "Fit the whole level in the view (F)", bar, func() -> void: _on_command(Cmd.FIT))
	_tb("Grid", "Show or hide the grid (G)", bar, func() -> void: _on_command(Cmd.GRID))
	bar.add_child(VSeparator.new())
	var play := _tb("Play (F5)", "Save to a temporary file and start the game on it", bar, func() -> void: _on_command(Cmd.PLAY))
	play.add_theme_color_override("font_color", EditorTheme.ACCENT)
	return bar


func _tb(text: String, tip: String, parent: Container, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(action)
	parent.add_child(b)
	return b


func _build_status_bar() -> Control:
	var bar := HBoxContainer.new()
	_hint_label = Label.new()
	_hint_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hint_label.clip_text = true
	_hint_label.add_theme_color_override("font_color", EditorTheme.DIM_TEXT)
	bar.add_child(_hint_label)
	_cell_label = Label.new()
	_cell_label.custom_minimum_size = Vector2(300, 0)
	_cell_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bar.add_child(_cell_label)
	return bar


# ---------------------------------------------------------------- state sync

func _on_doc_changed(_kind: String) -> void:
	_update_title()


func _update_title() -> void:
	var file := doc.path.get_file() if doc.path != "" else "(unsaved level)"
	var text := "%s%s   %d x %d" % [file, " *" if doc.dirty else "", doc.cols(), doc.rows()]
	if _title_label != null:
		_title_label.text = text
	get_window().title = "sabotage.ai level editor - " + text
	if _zoom_label != null and canvas != null:
		_zoom_label.text = "%d%%" % roundi(canvas.zoom * 100.0)


func _set_hint(text: String) -> void:
	_hint_label.text = text


func _on_cell_hovered(cell: Vector2i) -> void:
	if cell.x < 0:
		_cell_label.text = ""
	else:
		var ch := doc.get_cell(cell.x, cell.y)
		var e := catalog.entry_for_char(ch)
		var thing := doc.thing_at(cell.x, cell.y)
		if ch == "." and not thing.is_empty():
			e = catalog.entry_for_char(str(thing["char"]))
		_cell_label.text = "(%d, %d)  %s" % [cell.x, cell.y, str(e.get("name", "empty")) if not thing.is_empty() else "empty"]
	_zoom_label.text = "%d%%" % roundi(canvas.zoom * 100.0)


func _process(_delta: float) -> void:
	if canvas != null and _zoom_label != null:
		var z := "%d%%" % roundi(canvas.zoom * 100.0)
		if _zoom_label.text != z:
			_zoom_label.text = z


func _select_tool(t: EditorCanvas.Tool) -> void:
	canvas.set_tool(t)
	(_tool_buttons[t] as Button).set_pressed_no_signal(true)


func _on_item_picked(entry: Dictionary) -> void:
	canvas.set_armed(entry)
	if canvas.tool == EditorCanvas.Tool.SELECT or canvas.tool == EditorCanvas.Tool.ERASER or canvas.tool == EditorCanvas.Tool.EYEDROPPER:
		_select_tool(EditorCanvas.Tool.PAINT)
	tabs.current_tab = 0
	doc.clear_selection()
	_set_hint("%s armed: click on the canvas to place it, Esc to put it down." % str(entry["name"]))


func _on_entry_picked(entry: Dictionary) -> void:
	palette.show_armed(entry)
	_on_item_picked(entry)


func _disarm() -> void:
	canvas.set_armed({})
	palette.clear_armed()
	_select_tool(EditorCanvas.Tool.SELECT)


func _jump_to(cell: Vector2i) -> void:
	tabs.current_tab = 0
	canvas.jump_to(cell)
	doc.select_thing_at(cell.x, cell.y)


# ---------------------------------------------------------------- commands

func _on_command(id: int) -> void:
	match id:
		Cmd.NEW:
			_guard_unsaved(func() -> void: EditorDialogs.new_level(self, _create_level))
		Cmd.OPEN:
			_guard_unsaved(_show_open_dialog)
		Cmd.SAVE:
			_save()
		Cmd.SAVE_AS:
			_show_save_dialog()
		Cmd.RECOVER:
			_guard_unsaved(_recover_autosave)
		Cmd.QUIT:
			_request_quit()
		Cmd.PLAY:
			_play()
		Cmd.UNDO:
			if not doc.undo():
				_set_hint("Nothing to undo.")
		Cmd.REDO:
			if not doc.redo():
				_set_hint("Nothing to redo.")
		Cmd.CUT:
			if doc.cut_selection():
				_set_hint("Cut.")
		Cmd.COPY:
			if doc.copy_selection():
				_set_hint("Copied. Ctrl+V pastes at the mouse.")
		Cmd.PASTE:
			_paste()
		Cmd.DUPLICATE:
			var res := doc.duplicate_selection()
			_set_hint("Duplicated." if bool(res["ok"]) else "Cannot duplicate: " + str(res["text"]))
		Cmd.DELETE:
			doc.delete_selection()
		Cmd.DESELECT:
			doc.clear_selection()
		Cmd.GRID:
			canvas.show_grid = not canvas.show_grid
			_view_menu.set_item_checked(_view_menu.get_item_index(Cmd.GRID), canvas.show_grid)
			canvas.queue_redraw()
		Cmd.BACKGROUND:
			canvas.show_background = not canvas.show_background
			_view_menu.set_item_checked(_view_menu.get_item_index(Cmd.BACKGROUND), canvas.show_background)
			canvas.queue_redraw()
		Cmd.DRAWER:
			palette.visible = not palette.visible
			_view_menu.set_item_checked(_view_menu.get_item_index(Cmd.DRAWER), palette.visible)
		Cmd.FIT:
			canvas.fit_view()
		Cmd.ZOOM_IN:
			canvas.zoom_by(EditorCanvas.ZOOM_STEP * 1.2, canvas.size / 2.0)
		Cmd.ZOOM_OUT:
			canvas.zoom_by(1.0 / (EditorCanvas.ZOOM_STEP * 1.2), canvas.size / 2.0)
		Cmd.ZOOM_100:
			canvas.zoom_actual()
		Cmd.HELP:
			EditorDialogs.help(self)
		Cmd.ABOUT:
			EditorDialogs.message(self, "About", "sabotage.ai level editor\nEdits *.sablevel.json files (tools/level_editor/FORMAT.md).\nEverything it can place comes from tools/level_editor/catalog.json.")
	_update_title()


func _refresh_file_menu() -> void:
	_builtin_menu.clear()
	var i := 0
	for id in LevelData.ids():
		_builtin_menu.add_item("%s  (%s)" % [LevelData.title(id), id], i)
		_builtin_menu.set_item_metadata(i, id)
		i += 1
	_recent_menu.clear()
	for j in _recent.size():
		_recent_menu.add_item(_recent[j], j)
	if _recent.is_empty():
		_recent_menu.add_item("(none)", 0)
		_recent_menu.set_item_disabled(0, true)
	_file_menu.set_item_disabled(_file_menu.get_item_index(Cmd.RECOVER), not FileAccess.file_exists(AUTOSAVE_PATH))


func _refresh_edit_menu() -> void:
	_edit_menu.set_item_disabled(_edit_menu.get_item_index(Cmd.UNDO), not doc.can_undo())
	_edit_menu.set_item_disabled(_edit_menu.get_item_index(Cmd.REDO), not doc.can_redo())
	var has_sel := doc.has_selection()
	for id in [Cmd.CUT, Cmd.COPY, Cmd.DUPLICATE, Cmd.DELETE, Cmd.DESELECT]:
		_edit_menu.set_item_disabled(_edit_menu.get_item_index(id), not has_sel)
	_edit_menu.set_item_disabled(_edit_menu.get_item_index(Cmd.PASTE), not doc.can_paste())


func _paste() -> void:
	if not doc.can_paste():
		_set_hint("The clipboard is empty.")
		return
	var at := canvas.screen_to_cell(canvas.get_local_mouse_position())
	if not doc.in_bounds(at.x, at.y) or not canvas.get_global_rect().has_point(get_global_mouse_position()):
		at = canvas.screen_to_cell(canvas.size / 2.0)
	var res := doc.paste_at(at)
	_set_hint("Pasted: drag it to place it, or press Delete." if bool(res["ok"]) else "Cannot paste: " + str(res["text"]))


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed:
		return
	if k.echo and not (k.keycode in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN]):
		return
	var ctrl := k.ctrl_pressed or k.meta_pressed
	var handled := true
	if ctrl:
		match k.keycode:
			KEY_N: _on_command(Cmd.NEW)
			KEY_O: _on_command(Cmd.OPEN)
			KEY_S: _on_command(Cmd.SAVE_AS if k.shift_pressed else Cmd.SAVE)
			KEY_Z: _on_command(Cmd.REDO if k.shift_pressed else Cmd.UNDO)
			KEY_Y: _on_command(Cmd.REDO)
			KEY_C: _on_command(Cmd.COPY)
			KEY_X: _on_command(Cmd.CUT)
			KEY_V: _on_command(Cmd.PASTE)
			KEY_D: _on_command(Cmd.DUPLICATE)
			KEY_B: _on_command(Cmd.DRAWER)
			KEY_Q: _on_command(Cmd.QUIT)
			KEY_F: palette.visible = true; palette.focus_search()
			_: handled = false
	else:
		match k.keycode:
			KEY_V: _select_tool(EditorCanvas.Tool.SELECT)
			KEY_B: _select_tool(EditorCanvas.Tool.PAINT)
			KEY_R: _select_tool(EditorCanvas.Tool.RECT)
			KEY_L: _select_tool(EditorCanvas.Tool.LINE)
			KEY_E: _select_tool(EditorCanvas.Tool.ERASER)
			KEY_I: _select_tool(EditorCanvas.Tool.EYEDROPPER)
			KEY_G: _on_command(Cmd.GRID)
			KEY_F: _on_command(Cmd.FIT)
			KEY_1: _on_command(Cmd.ZOOM_100)
			KEY_EQUAL, KEY_PLUS, KEY_KP_ADD: _on_command(Cmd.ZOOM_IN)
			KEY_MINUS, KEY_KP_SUBTRACT: _on_command(Cmd.ZOOM_OUT)
			KEY_F1: _on_command(Cmd.HELP)
			KEY_F5: _on_command(Cmd.PLAY)
			KEY_DELETE, KEY_BACKSPACE: _on_command(Cmd.DELETE)
			KEY_LEFT: _nudge(Vector2i(-1, 0))
			KEY_RIGHT: _nudge(Vector2i(1, 0))
			KEY_UP: _nudge(Vector2i(0, -1))
			KEY_DOWN: _nudge(Vector2i(0, 1))
			_: handled = false
	if handled:
		get_viewport().set_input_as_handled()


func _nudge(d: Vector2i) -> void:
	if not doc.has_selection():
		return
	var res := doc.nudge_selection(d)
	if not bool(res["ok"]):
		_set_hint("Cannot move: " + str(res["text"]))


# ---------------------------------------------------------------- files

func _guard_unsaved(then: Callable) -> void:
	if not doc.dirty:
		then.call()
		return
	EditorDialogs.confirm(self, "Unsaved changes", "The level has unsaved changes. Discard them?", "Discard", then,
		"Save first", func() -> void:
			_pending_after_save = then
			_save())


func _create_level(cols: int, rows: int) -> void:
	doc.new_level(cols, rows)
	canvas.fit_view()
	_set_hint("New %d x %d level." % [cols, rows])


func _show_open_dialog() -> void:
	_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_file_dialog.title = "Open a level file"
	if _last_dir != "":
		_file_dialog.current_dir = _last_dir
	_file_dialog.popup_centered()


func _show_save_dialog() -> void:
	_file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_file_dialog.title = "Save level as"
	if _last_dir != "":
		_file_dialog.current_dir = _last_dir
	_file_dialog.current_file = (doc.path.get_file() if doc.path != "" else str(doc.get_setting("meta", "id")) + ".sablevel.json")
	_file_dialog.popup_centered()


func _on_file_chosen(path: String) -> void:
	_last_dir = path.get_base_dir()
	if _file_dialog.file_mode == FileDialog.FILE_MODE_SAVE_FILE:
		if not path.ends_with(".sablevel.json"):
			path += ".sablevel.json"
		_write(path)
	else:
		_open_path(path)


## Open a level file (reports errors in a dialog and leaves the current level alone if the file is broken).
func _open_path(path: String) -> void:
	var res := doc.load_file(path)
	if not bool(res["ok"]):
		EditorDialogs.message(self, "Cannot open the level", "%s\n\n%s" % [path, "\n".join(PackedStringArray(res["errors"]))])
		return
	_add_recent(path)
	canvas.fit_view()
	var errs: Array = res["errors"]
	_set_hint("Opened %s%s" % [path.get_file(), (" (%d problem(s) listed below)" % errs.size()) if not errs.is_empty() else ""])


func _on_recent_chosen(i: int) -> void:
	if i < 0 or i >= _recent.size():
		return
	var path := _recent[i]
	_guard_unsaved(func() -> void: _open_path(path))


func _on_builtin_chosen(i: int) -> void:
	var id := str(_builtin_menu.get_item_metadata(i))
	_guard_unsaved(func() -> void: _open_builtin(id))


func _open_builtin(id: String) -> void:
	if LevelData.is_campaign(id):
		_open_path(LevelData.file_path(id))   # a level of the game: edited in place, Save overwrites its file
		return
	doc.adopt(EditorDocument.from_builtin(id))
	canvas.fit_view()
	_set_hint("Converted the level '%s' to the editor format. Use Save as to keep it." % id)


func _save() -> void:
	if doc.path == "":
		_show_save_dialog()
	else:
		_write(doc.path)


func _write(path: String) -> void:
	var err := doc.save(path)
	if err != OK:
		EditorDialogs.message(self, "Cannot save", "Saving %s failed (error %d)." % [path, err])
		_pending_after_save = Callable()
		return
	_add_recent(path)
	_delete_autosave()
	var n := problems.error_count()
	_set_hint("Saved %s%s" % [path, (" with %d error(s) in the validation list" % n) if n > 0 else ""])
	_update_title()
	if _pending_after_save.is_valid():
		var cb := _pending_after_save
		_pending_after_save = Callable()
		cb.call()


func _recover_autosave() -> void:
	var res := doc.load_file(AUTOSAVE_PATH)
	if bool(res["ok"]):
		doc.path = ""
		doc.dirty = true
		canvas.fit_view()
		_set_hint("Recovered the autosave. Use Save as to keep it.")
	else:
		EditorDialogs.message(self, "Cannot recover", "\n".join(PackedStringArray(res["errors"])))


func _do_autosave() -> void:
	if doc.dirty:
		LevelFile.save_file(AUTOSAVE_PATH, doc.data)


func _delete_autosave() -> void:
	if FileAccess.file_exists(AUTOSAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(AUTOSAVE_PATH))


func _request_quit() -> void:
	_guard_unsaved(func() -> void:
		_save_config()
		_delete_autosave()
		get_tree().quit())


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_request_quit()


func _load_config() -> void:
	var cf := ConfigFile.new()
	if cf.load(CONFIG_PATH) != OK:
		return
	for p in cf.get_value("files", "recent", []):
		_recent.append(str(p))
	_last_dir = str(cf.get_value("files", "last_dir", ""))


func _save_config() -> void:
	var cf := ConfigFile.new()
	cf.set_value("files", "recent", _recent)
	cf.set_value("files", "last_dir", _last_dir)
	cf.save(CONFIG_PATH)


func _add_recent(path: String) -> void:
	_recent.erase(path)
	_recent.push_front(path)
	while _recent.size() > MAX_RECENT:
		_recent.pop_back()
	_last_dir = path.get_base_dir()
	_save_config()


# ---------------------------------------------------------------- play-test

func _play() -> void:
	var reason := doc.unplayable_reason()
	if reason != "":
		EditorDialogs.message(self, "Cannot play-test", reason + "\nFix it (see the validation list) and try again.")
		return
	var err := LevelFile.save_file(PLAYTEST_PATH, doc.data)
	if err != OK:
		EditorDialogs.message(self, "Cannot play-test", "Could not write the temporary level file (error %d)." % err)
		return
	var file := ProjectSettings.globalize_path(PLAYTEST_PATH)
	var args := PackedStringArray(["--path", ProjectSettings.globalize_path("res://"), "--", "--level-file=" + file])
	_play_pid = OS.create_process(OS.get_executable_path(), args)
	if _play_pid <= 0:
		EditorDialogs.message(self, "Cannot play-test", "The game could not be started.")
	else:
		_set_hint("Started the game on %s (process %d)." % [file, _play_pid])


# ---------------------------------------------------------------- demo (for screenshots)

func _demo(mode: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	doc.adopt(EditorDocument.from_builtin(LevelData.DEFAULT_ID))
	doc.set_setting("player", "max_health", 150)
	var bro := Vector2i(-1, -1)
	var term := Vector2i(-1, -1)
	for r in doc.rows():
		for c in doc.cols():
			var ch := doc.get_cell(c, r)
			if ch == "B" and bro.x < 0:
				bro = Vector2i(c, r)
			elif ch == "L" and term.x < 0:
				term = Vector2i(c, r)
	if doc.minigames().is_empty():
		doc.add_minigame("wrong_only")
		doc.add_minigame("timing")
	match mode:
		"fit":
			canvas.fit_view()
		"mid":
			canvas.zoom = 0.3
			canvas.jump_to(term)
		"minigames":
			tabs.current_tab = 1
			minigames.refresh()
		"ghost":
			canvas.zoom = 0.7
			canvas.jump_to(bro if bro.x >= 0 else Vector2i(10, 10))
			doc.select_thing_at(term.x, term.y)
			var entry := catalog.entry_for_char("B")
			palette.show_armed(entry)
			_on_item_picked(entry)
			canvas.debug_hover(bro + Vector2i(4, 0))
		"move":
			canvas.zoom = 0.7
			canvas.jump_to(term)
			doc.set_object_name(bro.x, bro.y, "Lobby Bro")
			doc.select_thing_at(term.x, term.y)
			canvas.debug_move(Vector2i(3, 0))
		_:
			canvas.zoom = 0.7
			canvas.jump_to(bro if bro.x >= 0 else Vector2i(10, 10))
			doc.set_object_name(bro.x, bro.y, "Lobby Bro")
			doc.select_thing_at(bro.x, bro.y)
	problems.refresh()
