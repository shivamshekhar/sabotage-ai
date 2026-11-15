class_name EditorMinigames
extends HBoxContainer
## The minigame designer: edits the level's `minigames` list. A list on the left (add, duplicate, delete), the details on the
## right: id, name, kind, the kind's parameters (from the catalog), the questions of the quiz kinds, and a Preview button that
## runs the real puzzle when the game offers HackPopup.open_definition().

## Emitted with a message to show in the status bar.
signal status(text: String)

var doc: EditorDocument
var catalog: EditorCatalog

var _list: ItemList
var _kind_pick: OptionButton
var _details: VBoxContainer
var _sel := -1
var _preview_button: Button


func _ready() -> void:
	catalog = EditorCatalog.get_instance()
	add_theme_constant_override("separation", 8)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(280, 0)
	add_child(left)
	var title := Label.new()
	title.text = "MINIGAMES OF THIS LEVEL"
	title.add_theme_color_override("font_color", EditorTheme.ACCENT)
	left.add_child(title)
	_list = ItemList.new()
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.item_selected.connect(func(i: int) -> void:
		_sel = i
		_build_details())
	left.add_child(_list)
	var add_row := HBoxContainer.new()
	left.add_child(add_row)
	_kind_pick = OptionButton.new()
	_kind_pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for k in catalog.minigame_kinds:
		_kind_pick.add_item("%s (%s)" % [str((k as Dictionary)["name"]), str((k as Dictionary)["kind"])])
	add_row.add_child(_kind_pick)
	_btn("Add", add_row, _on_add)
	var row2 := HBoxContainer.new()
	left.add_child(row2)
	_btn("Duplicate", row2, func() -> void:
		var n := doc.duplicate_minigame(_sel)
		if n >= 0:
			_sel = n
			refresh())
	_btn("Delete", row2, func() -> void:
		doc.delete_minigame(_sel)
		_sel = mini(_sel, doc.minigames().size() - 1)
		refresh())
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_details = VBoxContainer.new()
	_details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_details.add_theme_constant_override("separation", 6)
	scroll.add_child(_details)
	if doc != null:
		refresh()


func _btn(text: String, parent: Container, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(action)
	parent.add_child(b)
	return b


## Show the minigames of a document.
func set_document(d: EditorDocument) -> void:
	if doc != null:
		doc.changed.disconnect(_on_changed)
	doc = d
	doc.changed.connect(_on_changed)
	_sel = 0 if not d.minigames().is_empty() else -1
	if _list != null:
		refresh()


func _on_changed(kind: String) -> void:
	if kind == "all" or kind == "minigames_list":
		if _sel >= doc.minigames().size():
			_sel = doc.minigames().size() - 1
		if _sel < 0 and not doc.minigames().is_empty():
			_sel = 0
		refresh()


func _on_add() -> void:
	var kind := str((catalog.minigame_kinds[_kind_pick.selected] as Dictionary)["kind"])
	_sel = doc.add_minigame(kind)
	refresh()


## Rebuild the list and the details.
func refresh() -> void:
	if _list == null or doc == null:
		return
	_list.clear()
	for m in doc.minigames():
		_list.add_item("%s   [%s]" % [str((m as Dictionary).get("name", "")), str((m as Dictionary).get("id", ""))])
	if _sel >= 0 and _sel < _list.item_count:
		_list.select(_sel)
	_build_details()


func _build_details() -> void:
	for c in _details.get_children():
		c.queue_free()
		_details.remove_child(c)
	if _sel < 0 or _sel >= doc.minigames().size():
		var l := Label.new()
		l.text = "No minigame selected. Add one on the left, then give a lock terminal this puzzle's id\n(select the terminal, field \"Puzzle\")."
		l.add_theme_color_override("font_color", EditorTheme.DIM_TEXT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_details.add_child(l)
		return
	var i := _sel
	var m: Dictionary = doc.minigames()[i]
	var kind := str(m.get("kind", ""))
	var kind_entry := catalog.minigame_kind_entry(kind)
	var head := Label.new()
	head.text = "%s" % str(kind_entry.get("name", kind))
	head.add_theme_font_size_override("font_size", 16)
	head.add_theme_color_override("font_color", EditorTheme.ACCENT)
	_details.add_child(head)

	var msg := Label.new()
	msg.add_theme_color_override("font_color", EditorTheme.ERROR)
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_field_label("Id (unique; lock terminals refer to it; press Enter or leave the field to apply)")
	var id_edit := LineEdit.new()
	id_edit.text = str(m.get("id", ""))
	var apply_id := func(_t: Variant = "") -> void:
		var err := doc.set_minigame_field(i, "id", id_edit.text)
		msg.text = err
		if err == "":
			refresh_item_text(i)
		else:
			id_edit.text = str((doc.minigames()[i] as Dictionary).get("id", ""))
	id_edit.text_submitted.connect(apply_id)
	id_edit.focus_exited.connect(apply_id)
	_details.add_child(id_edit)
	_details.add_child(msg)

	_field_label("Name")
	var name_edit := LineEdit.new()
	name_edit.text = str(m.get("name", ""))
	name_edit.text_changed.connect(func(t: String) -> void:
		doc.set_minigame_field(i, "name", t)
		refresh_item_text(i))
	_details.add_child(name_edit)

	_field_label("Kind")
	var kind_option := OptionButton.new()
	var kinds := catalog.minigame_kind_names()
	for k in kinds:
		kind_option.add_item(k)
	kind_option.select(maxi(kinds.find(kind), 0))
	kind_option.item_selected.connect(func(idx: int) -> void:
		doc.set_minigame_field(i, "kind", kinds[idx]))
	_details.add_child(kind_option)

	var params: Array = kind_entry.get("params", [])
	if not params.is_empty():
		_field_label("Parameters (only values that differ from the defaults are saved)")
		EditorPropForm.build(_details, params,
			func(key: String) -> Variant: return doc.get_minigame_param(i, key),
			func(key: String, v: Variant) -> void: doc.set_minigame_param(i, key, v),
			func(key: String) -> bool: return str(doc.get_minigame_param(i, key)) != str(EditorCatalog.default_of(params, key)),
			func(key: String) -> void: doc.set_minigame_param(i, key, EditorCatalog.default_of(params, key)))
	if bool(kind_entry.get("questions", false)):
		_build_questions(i)

	_preview_button = Button.new()
	_preview_button.text = "Preview this puzzle"
	if _can_preview():
		_preview_button.pressed.connect(func() -> void: _preview(i))
	else:
		_preview_button.disabled = true
		_preview_button.tooltip_text = "The game does not provide HackPopup.open_definition() yet, so a preview is not possible."
	_details.add_child(_preview_button)


func refresh_item_text(i: int) -> void:
	if i < 0 or i >= _list.item_count:
		return
	var m: Dictionary = doc.minigames()[i]
	_list.set_item_text(i, "%s   [%s]" % [str(m.get("name", "")), str(m.get("id", ""))])


func _field_label(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", EditorPropForm.LABEL_COLOR)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_details.add_child(l)


func _build_questions(i: int) -> void:
	var sep := HSeparator.new()
	_details.add_child(sep)
	var head := Label.new()
	head.text = "Questions (the right answer is shown among the wrong ones in the game)"
	head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.add_theme_color_override("font_color", EditorTheme.ACCENT)
	_details.add_child(head)
	var qs := doc.questions(i)
	for q in qs.size():
		var qd: Dictionary = qs[q]
		var box := PanelContainer.new()
		_details.add_child(box)
		var col := VBoxContainer.new()
		box.add_child(col)
		var top := HBoxContainer.new()
		col.add_child(top)
		var num := Label.new()
		num.text = "Question %d" % (q + 1)
		num.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(num)
		_btn("Remove question", top, func() -> void: doc.remove_question(i, q))
		var q_edit := LineEdit.new()
		q_edit.placeholder_text = "Question text"
		q_edit.text = str(qd.get("q", ""))
		q_edit.text_changed.connect(func(t: String) -> void: doc.set_question_text(i, q, "q", t))
		col.add_child(q_edit)
		var right := LineEdit.new()
		right.placeholder_text = "Right answer"
		right.text = str(qd.get("right", ""))
		right.add_theme_color_override("font_color", EditorTheme.ACCENT)
		right.text_changed.connect(func(t: String) -> void: doc.set_question_text(i, q, "right", t))
		col.add_child(right)
		var wrong: Array = qd.get("wrong", [])
		for w in wrong.size():
			var wr := HBoxContainer.new()
			col.add_child(wr)
			var we := LineEdit.new()
			we.placeholder_text = "Wrong answer"
			we.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			we.text = str(wrong[w])
			we.text_changed.connect(func(t: String) -> void: doc.set_wrong_answer(i, q, w, t))
			wr.add_child(we)
			_btn("x", wr, func() -> void: doc.remove_wrong_answer(i, q, w))
		_btn("Add wrong answer", col, func() -> void: doc.add_wrong_answer(i, q))
	_btn("Add question", _details, func() -> void: doc.add_question(i))


## True if the game has HackPopup.open_definition(parent, laser_id, definition).
static func game_can_preview() -> bool:
	var script: Script = HackPopup
	for m in script.get_script_method_list():
		if str((m as Dictionary).get("name", "")) == "open_definition":
			return true
	return false


func _can_preview() -> bool:
	return game_can_preview()


func _preview(i: int) -> void:
	var m: Dictionary = (doc.minigames()[i] as Dictionary).duplicate(true)
	var def := {"kind": m.get("kind", ""), "params": m.get("params", {}), "questions": m.get("questions", [])}
	var script: Script = HackPopup
	script.call("open_definition", get_tree().root, "preview", def)
	status.emit("Previewing '%s'. Press Esc or X to leave it." % str(m.get("name", "")))
