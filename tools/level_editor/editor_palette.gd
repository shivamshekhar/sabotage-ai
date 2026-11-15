class_name EditorPalette
extends PanelContainer
## The side drawer: every placeable item of the catalog grouped by category, each with its icon and name, with a search box.
## Clicking an item arms it (see EditorCanvas). Groups can be folded.

## Emitted when the user clicks an item.
signal item_picked(entry: Dictionary)

# ICON_SIZE: width and height in pixels of the item icons in the list. Raise for bigger, easier-to-recognise icons.
const ICON_SIZE := 34

# FOLD_ABOVE: a group with more items than this starts folded, and its icons are only loaded when it is opened (or when a search
# shows them), so a palette of thousands of tiles opens at once. Raise it to start with bigger groups open.
const FOLD_ABOVE := 24

# MAX_ICONS_PER_SEARCH: the most icons a search loads at once (the rest show their name only until you narrow the search).
const MAX_ICONS_PER_SEARCH := 60

var catalog: EditorCatalog
var _search: LineEdit
var _list: VBoxContainer
var _buttons: Array[Button] = []   # all item buttons (meta "entry" holds the catalog entry)
var _groups: Dictionary = {}       # group name -> {"header": Button, "box": VBoxContainer}
var _button_group := ButtonGroup.new()


func _ready() -> void:
	catalog = EditorCatalog.get_instance()
	custom_minimum_size = Vector2(240, 0)
	var col := VBoxContainer.new()
	add_child(col)
	var title := Label.new()
	title.text = "PALETTE"
	title.add_theme_color_override("font_color", EditorTheme.ACCENT)
	col.add_child(title)
	_search = LineEdit.new()
	_search.placeholder_text = "Search items..."
	_search.clear_button_enabled = true
	_search.text_changed.connect(_apply_filter)
	col.add_child(_search)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	_build()


func _build() -> void:
	for group in catalog.groups():
		var header := Button.new()
		header.text = "v  " + group
		header.alignment = HORIZONTAL_ALIGNMENT_LEFT
		header.flat = true
		header.add_theme_color_override("font_color", EditorTheme.ACCENT)
		_list.add_child(header)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 2)
		_list.add_child(box)
		_groups[group] = {"header": header, "box": box}
		header.pressed.connect(func() -> void:
			box.visible = not box.visible
			header.text = ("v  " if box.visible else ">  ") + group
			if box.visible:
				_load_icons(box))
		for entry in catalog.palette_items():
			if str(entry.get("group", "")) != group:
				continue
			var b := Button.new()
			b.toggle_mode = true
			b.button_group = _button_group
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.text = " " + str(entry["name"])
			b.clip_text = true
			b.expand_icon = true
			b.add_theme_constant_override("icon_max_width", ICON_SIZE)
			b.custom_minimum_size = Vector2(0, ICON_SIZE + 6)
			b.tooltip_text = _tooltip(entry)
			b.set_meta("entry", entry)
			b.pressed.connect(func() -> void: item_picked.emit(entry))
			box.add_child(b)
			_buttons.append(b)
		if box.get_child_count() > FOLD_ABOVE:
			box.visible = false
			header.text = ">  " + group
		else:
			_load_icons(box)


## Give the buttons of a group their icons (done when the group is opened, not when the palette is built).
func _load_icons(box: Container) -> void:
	for b in box.get_children():
		var button := b as Button
		if button != null and button.icon == null and button.has_meta("entry"):
			var tex := catalog.texture(button.get_meta("entry") as Dictionary)
			if tex != null:
				button.icon = tex


func _tooltip(entry: Dictionary) -> String:
	var t := str(entry["name"])
	var ch := str(entry.get("char", ""))
	if ch != "":
		t += "\nmap character: " + ch
	if entry.has("footprint"):
		var f: Array = entry["footprint"]
		t += "\nfootprint: %d x %d tiles (placed by its bottom-left tile)" % [int(f[0]), int(f[1])]
	if bool(entry.get("unique", false)):
		t += "\nonly one per level (placing it again moves it)"
	return t


## Highlight the button of an entry (used when the eyedropper or code arms something) without emitting item_picked.
func show_armed(entry: Dictionary) -> void:
	for b in _buttons:
		var e: Dictionary = b.get_meta("entry")
		b.set_pressed_no_signal(not entry.is_empty() and str(e.get("char", "")) == str(entry.get("char", "")) and str(e.get("name", "")) == str(entry.get("name", "")))


## Clear the highlighted item.
func clear_armed() -> void:
	for b in _buttons:
		b.set_pressed_no_signal(false)


## Focus the search box.
func focus_search() -> void:
	_search.grab_focus()


func _apply_filter(text: String) -> void:
	var q := text.strip_edges().to_lower()
	var visible_in_group := {}
	var shown_icons := 0
	for b in _buttons:
		var e: Dictionary = b.get_meta("entry")
		var hay := (str(e["name"]) + " " + str(e.get("group", "")) + " " + str(e.get("char", ""))).to_lower()
		var matches := q == "" or hay.contains(q)
		b.visible = matches
		if matches:
			visible_in_group[str(e.get("group", ""))] = true
			if q != "" and shown_icons < MAX_ICONS_PER_SEARCH and b.icon == null:
				var tex := catalog.texture(e)
				if tex != null:
					b.icon = tex
				shown_icons += 1
	for g in _groups:
		var info: Dictionary = _groups[g]
		var any: bool = visible_in_group.has(g)
		(info["header"] as Button).visible = any
		(info["box"] as VBoxContainer).visible = any and (q != "" or (info["header"] as Button).text.begins_with("v"))
