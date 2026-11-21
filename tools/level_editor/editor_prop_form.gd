class_name EditorPropForm
extends RefCounted
## Builds the editing widgets for a list of catalog property definitions (float / int as spin boxes with min, max and step,
## string as a text field, choice as a drop-down, bool as a check box), each with a "reset to default" button. Used by the
## inspector (objects, player, terrain, level) and by the minigame designer (parameters).

# LABEL_COLOR: colour of a field's label when its value is the default; changed values use the accent colour so the
# user sees at a glance what differs from the defaults.
const LABEL_COLOR := Color(0.6, 0.64, 0.72)


## Add one row per definition in `defs` to `parent`.
## getter(key) -> current value; setter(key, value) stores it; is_changed(key) -> bool (differs from the default);
## reset(key) restores the default. overrides maps a key to an Array of options, which turns a string or choice into a
## drop-down with exactly those options (used for the background list and the puzzle list). When the current value of such a
## drop-down is not in the options it is added, so nothing is lost.
static func build(parent: Container, defs: Array, getter: Callable, setter: Callable, is_changed: Callable, reset: Callable, overrides: Dictionary = {}) -> void:
	for d in defs:
		_add_row(parent, d as Dictionary, getter, setter, is_changed, reset, overrides)


static func _add_row(parent: Container, def: Dictionary, getter: Callable, setter: Callable, is_changed: Callable, reset: Callable, overrides: Dictionary) -> void:
	var key := str(def["key"])
	var type := str(def.get("type", "string"))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	parent.add_child(box)
	var label := Label.new()
	label.text = str(def.get("label", key))
	label.tooltip_text = "%s (key: %s)" % [label.text, key]
	label.add_theme_font_size_override("font_size", 12)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(label)
	var line := HBoxContainer.new()
	box.add_child(line)
	var reset_button := Button.new()
	reset_button.text = "Reset"
	reset_button.tooltip_text = "Back to the default (%s)" % str(def.get("default", ""))
	reset_button.focus_mode = Control.FOCUS_NONE

	# `apply` shows a value in the widget without triggering the setter.
	var widget: Control
	var apply: Callable
	if overrides.has(key) or type == "choice":
		var options: Array = overrides.get(key, def.get("options", []))
		var ob := OptionButton.new()
		ob.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ob.clip_text = true
		var texts: Array[String] = []
		for o in options:
			texts.append(str(o))
		apply = func(v: Variant) -> void:
			var s := str(v)
			if not texts.has(s):
				texts.append(s)
			ob.clear()
			for t in texts:
				ob.add_item(t)
			ob.select(texts.find(s))
		ob.item_selected.connect(func(i: int) -> void:
			setter.call(key, texts[i])
			_refresh_state(label, reset_button, is_changed, key))
		widget = ob
	elif type == "bool":
		var cb := CheckBox.new()
		cb.text = "enabled"
		apply = func(v: Variant) -> void: cb.set_pressed_no_signal(bool(v))
		cb.toggled.connect(func(on: bool) -> void:
			setter.call(key, on)
			_refresh_state(label, reset_button, is_changed, key))
		widget = cb
	elif type == "float" or type == "int":
		var sb := SpinBox.new()
		sb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sb.min_value = float(def.get("min", -1000000.0))
		sb.max_value = float(def.get("max", 1000000.0))
		sb.step = float(def.get("step", 1.0)) if type == "float" else 1.0
		sb.allow_greater = false
		sb.allow_lesser = false
		sb.select_all_on_focus = true
		apply = func(v: Variant) -> void: sb.set_value_no_signal(float(v))
		sb.value_changed.connect(func(v: float) -> void:
			if type == "int":
				setter.call(key, int(roundf(v)))
			else:
				setter.call(key, snappedf(v, 0.0001))
			_refresh_state(label, reset_button, is_changed, key))
		widget = sb
	else:
		var le := LineEdit.new()
		le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		apply = func(v: Variant) -> void: le.text = str(v)
		le.text_changed.connect(func(t: String) -> void:
			setter.call(key, t)
			_refresh_state(label, reset_button, is_changed, key))
		widget = le
	line.add_child(widget)
	line.add_child(reset_button)
	apply.call(getter.call(key))
	_refresh_state(label, reset_button, is_changed, key)
	reset_button.pressed.connect(func() -> void:
		reset.call(key)
		apply.call(getter.call(key))
		_refresh_state(label, reset_button, is_changed, key))


static func _refresh_state(label: Label, reset_button: Button, is_changed: Callable, key: String) -> void:
	var changed: bool = is_changed.call(key)
	reset_button.disabled = not changed
	label.add_theme_color_override("font_color", EditorTheme.ACCENT if changed else LABEL_COLOR)
