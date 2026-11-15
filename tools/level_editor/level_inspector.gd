class_name LevelInspector
extends PanelContainer
## The right-hand panel. With an object selected it shows its type, its name and its catalog values; with a block of tiles
## selected it offers copy / cut / delete; with nothing selected it shows the tabs Level (title, size), Player and Terrain.
## Everything is built from the catalog (EditorPropForm), so new catalog entries appear without code changes.

var doc: EditorDocument
var catalog: EditorCatalog

var _content: VBoxContainer
var _resize_spins: Dictionary = {}
var _tab := 0


func _ready() -> void:
	catalog = EditorCatalog.get_instance()
	custom_minimum_size = Vector2(300, 0)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 6)
	scroll.add_child(_content)
	if doc != null:
		rebuild()


## Show the inspector for a document.
func set_document(d: EditorDocument) -> void:
	if doc != null:
		doc.selection_changed.disconnect(rebuild)
		doc.changed.disconnect(_on_changed)
	doc = d
	doc.selection_changed.connect(rebuild)
	doc.changed.connect(_on_changed)
	if _content != null:
		rebuild()


func _on_changed(kind: String) -> void:
	if kind == "all" or kind == "grid" or kind == "minigames_list":
		rebuild()


## Rebuild the panel for the current selection.
func rebuild() -> void:
	if _content == null or doc == null:
		return
	for c in _content.get_children():
		c.queue_free()
		_content.remove_child(c)
	if doc.has_selection() and doc.sel_object:
		_build_object()
	elif doc.has_selection():
		_build_block()
	else:
		_build_level_tabs()


func _heading(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", EditorTheme.ACCENT)
	l.add_theme_font_size_override("font_size", 16)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(l)
	return l


func _note(text: String, parent: Container = null) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", EditorTheme.DIM_TEXT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	(parent if parent != null else _content).add_child(l)
	return l


func _button(text: String, parent: Container, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(action)
	parent.add_child(b)
	return b


# ---------------------------------------------------------------- object

func _build_object() -> void:
	var anchor := doc.sel_anchor
	var type := doc.object_type_at(anchor.x, anchor.y)
	var ch := doc.get_cell(anchor.x, anchor.y)
	var entry := catalog.entry_for_type(type)
	_heading("%s" % str(entry.get("name", type)))
	_note("type: %s    tile: (%d, %d)    map character: %s" % [type, anchor.x, anchor.y, ch])
	var name_label := Label.new()
	name_label.text = "Name"
	name_label.add_theme_font_size_override("font_size", 12)
	_content.add_child(name_label)
	var name_edit := LineEdit.new()
	name_edit.text = doc.object_name(anchor.x, anchor.y)
	name_edit.placeholder_text = "(unnamed)"
	name_edit.max_length = LevelFile.MAX_NAME_LENGTH
	name_edit.text_changed.connect(func(t: String) -> void: doc.set_object_name(anchor.x, anchor.y, t))
	_content.add_child(name_edit)
	var defs := catalog.props_for_type(type)
	if defs.is_empty():
		_note("This object has no values to tune.")
	else:
		var overrides := {}
		if type == "lock_terminal":
			overrides["minigame"] = doc.minigame_choices()
		EditorPropForm.build(_content, defs,
			func(key: String) -> Variant: return doc.get_prop(anchor.x, anchor.y, key),
			func(key: String, v: Variant) -> void: doc.set_prop(anchor.x, anchor.y, key, v),
			func(key: String) -> bool: return doc.is_prop_changed(anchor.x, anchor.y, key),
			func(key: String) -> void: doc.reset_prop(anchor.x, anchor.y, key),
			overrides)
	_actions()


func _build_block() -> void:
	var sel := doc.sel
	var thing := doc.thing_at(sel.position.x, sel.position.y)
	if sel.size == Vector2i.ONE and not thing.is_empty():
		var ch := str(thing["char"])
		_heading(_thing_name(ch))
		_note("tile (%d, %d), map character %s. Tiles have no values; drag it on the canvas to move it." % [sel.position.x, sel.position.y, ch])
		if _is_gate(ch):
			_gate_id_row(ch)
	elif not thing.is_empty() and Rect2i(thing["rect"]) == sel:
		var ch2 := str(thing["char"])
		_heading(_thing_name(ch2))
		_note("%d x %d tiles at (%d, %d)." % [sel.size.x, sel.size.y, sel.position.x, sel.position.y])
		if _is_gate(ch2):
			_gate_id_row(ch2)
	else:
		_heading("%d x %d tiles selected" % [sel.size.x, sel.size.y])
		_note("Drag inside the selection to move it (Ctrl = copy).")
	_actions()


func _is_gate(ch: String) -> bool:
	return ch.length() == 1 and ch >= "1" and ch <= "9"


func _thing_name(ch: String) -> String:
	if _is_gate(ch):
		return "Laser gate %s" % ch
	return str(catalog.entry_for_char(ch).get("name", ch))


## The id of a laser gate is the digit that pairs it with its lock terminal (a terminal opens the nearest gate unless its
## "laser" value names one). It can be changed here to any id no other gate uses.
func _gate_id_row(id: String) -> void:
	var label := Label.new()
	label.text = "Gate id"
	label.add_theme_font_size_override("font_size", 12)
	_content.add_child(label)
	var pick := OptionButton.new()
	for g in "123456789":
		pick.add_item(g)
	pick.select(int(id) - 1)
	pick.tooltip_text = "Ids already used by another gate are refused."
	pick.item_selected.connect(func(i: int) -> void:
		if not doc.set_gate_id(id, pick.get_item_text(i)):
			pick.select(int(id) - 1))
	_content.add_child(pick)
	_note("A lock terminal opens the nearest laser gate. To pair one with a farther gate, set the terminal's \"laser\" value to this id.")


func _actions() -> void:
	var row := HFlowContainer.new()
	_content.add_child(row)
	_button("Duplicate (Ctrl+D)", row, func() -> void: doc.duplicate_selection())
	_button("Copy", row, func() -> void: doc.copy_selection())
	_button("Cut", row, func() -> void: doc.cut_selection())
	_button("Delete (Del)", row, func() -> void: doc.delete_selection())
	_button("Deselect", row, func() -> void: doc.clear_selection())


# ---------------------------------------------------------------- level, player, terrain

func _build_level_tabs() -> void:
	var tabs := TabContainer.new()
	tabs.custom_minimum_size = Vector2(0, 480)
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_child(tabs)
	tabs.tab_changed.connect(func(i: int) -> void: _tab = i)
	tabs.add_child(_section_page("Level", catalog.meta_props, "meta", true))
	tabs.add_child(_section_page("Player", catalog.player_props, "player", false))
	tabs.add_child(_section_page("Terrain", catalog.terrain_props, "terrain", false))
	tabs.current_tab = _tab
	_note("Select something on the canvas (Select tool, V) to edit its name and values.")


func _section_page(page_name: String, defs: Array, section: String, with_grid: bool) -> Control:
	var page := VBoxContainer.new()
	page.name = page_name
	page.add_theme_constant_override("separation", 6)
	if section == "player":
		_note("Values of the player for this level. Only changed values are saved. The spawn point is the P tile.", page)
	if section == "terrain":
		_note("Level-wide physics and look.", page)
	var overrides := {}
	if section == "terrain":
		overrides["background"] = EditorCatalog.backgrounds()
	EditorPropForm.build(page, defs,
		func(key: String) -> Variant: return doc.get_setting(section, key),
		func(key: String, v: Variant) -> void: doc.set_setting(section, key, v),
		func(key: String) -> bool: return doc.is_setting_changed(section, key),
		func(key: String) -> void: doc.reset_setting(section, key),
		overrides)
	if with_grid:
		_grid_section(page)
	return page


func _grid_section(page: VBoxContainer) -> void:
	var sep := HSeparator.new()
	page.add_child(sep)
	var l := Label.new()
	l.text = "Grid size (tiles)"
	l.add_theme_color_override("font_color", EditorTheme.ACCENT)
	page.add_child(l)
	_note("Resize: the old level's top-left corner is placed at the offset in the new grid (negative offsets crop).", page)
	var grid := GridContainer.new()
	grid.columns = 4
	page.add_child(grid)
	_resize_spins.clear()
	var fields := [["cols", "Cols", doc.cols(), EditorDocument.MIN_GRID, EditorDocument.MAX_GRID],
		["rows", "Rows", doc.rows(), EditorDocument.MIN_GRID, EditorDocument.MAX_GRID],
		["ox", "Offset X", 0, -EditorDocument.MAX_GRID, EditorDocument.MAX_GRID],
		["oy", "Offset Y", 0, -EditorDocument.MAX_GRID, EditorDocument.MAX_GRID]]
	for f in fields:
		var lab := Label.new()
		lab.text = str(f[1])
		grid.add_child(lab)
		var sb := SpinBox.new()
		sb.min_value = float(f[3])
		sb.max_value = float(f[4])
		sb.value = float(f[2])
		sb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(sb)
		_resize_spins[str(f[0])] = sb
	_button("Resize level", page, func() -> void:
		doc.resize(int((_resize_spins["cols"] as SpinBox).value), int((_resize_spins["rows"] as SpinBox).value),
			Vector2i(int((_resize_spins["ox"] as SpinBox).value), int((_resize_spins["oy"] as SpinBox).value))))
