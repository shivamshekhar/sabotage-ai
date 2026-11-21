class_name SettingsPanel
extends CanvasLayer
## The settings window, in the game's own look (see HackStyle): how loud the music and the sound effects are (a block meter each: tap or drag), and the controls. On a PC
## the controls are a list of every action with its two keys: click a key, press the new one (Esc cancels, Delete empties a key, a key another action uses is refused).
## On a phone there is nothing to change, so it lists what the touch buttons A to D do. Changes are kept at once (see Settings and KeyBindings).
##
##   var panel := SettingsPanel.open(self, TouchControls.should_show())
##   panel.closed.connect(on_closed)

signal closed

# LAYER: the canvas layer of the window: above the menus under it.
const LAYER := 40

# PANEL_WIDTH: the window's width in pixels, in the game's 1280x720 reference screen. Its height follows its content.
const PANEL_WIDTH := 980.0

# STRIP_HEIGHT: the hazard stripe along the top. HEADER_ICON: the size of the cog in the title row. TITLE_SIZE / SECTION_SIZE / ROW_SIZE / HINT_SIZE: font sizes.
const STRIP_HEIGHT := 12.0
const HEADER_ICON := Vector2(56.0, 56.0)
const TITLE_SIZE := 38
const SECTION_SIZE := 22
const ROW_SIZE := 22
const HINT_SIZE := 16

# LABEL_WIDTH: the width of the name column in a row of the window; METER_SIZE: the size of a volume meter; PERCENT_WIDTH: the width of the "70%" beside it.
const LABEL_WIDTH := 190.0
const METER_SIZE := Vector2(420.0, 38.0)
const PERCENT_WIDTH := 80.0

# KEY_BUTTON_SIZE: the size of a key button; BOTTOM_BUTTON_SIZE: of the buttons along the bottom. KEY_COLOR / LISTENING_COLOR: a key button at rest / waiting for a key.
const KEY_BUTTON_SIZE := Vector2(150.0, 40.0)
const BOTTOM_BUTTON_SIZE := Vector2(220.0, 54.0)
const KEY_COLOR := Color(0.17, 0.32, 0.52)
const LISTENING_COLOR := Color(0.85, 0.5, 0.12)
const BACK_COLOR := Color(0.2, 0.55, 0.9)
const RESET_COLOR := Color(0.55, 0.3, 0.2)

const LISTENING_TEXT := "PRESS A KEY"
const HINT_KEYS := "CLICK A KEY, THEN PRESS THE NEW ONE.   ESC CANCELS.   DEL EMPTIES A KEY."
const HINT_ROLES := "LIGHT ATTACK: THROW AN OBJECT, OR HOLD IT FOR THE MECH'S LASER.   HEAVY ATTACK: THE MECH'S MISSILE."
const USED_TEXT := "THAT KEY IS ALREADY USED BY  %s"
const RESERVED_TEXT := "THAT KEY CANNOT BE USED"
const LAST_KEY_TEXT := "AN ACTION KEEPS AT LEAST ONE KEY"

# TOUCH_ROLES: what the touch buttons do, as the window lists them for a phone (the letters come from TouchControls.FACE_BUTTONS).
const TOUCH_ROLES := {
	InputActions.JUMP: "JUMP",
	InputActions.INTERACT: "USE  (A COMPUTER)",
	InputActions.ATTACK_LIGHT: "LIGHT ATTACK  (THROW; THE MECH'S LASER)",
	InputActions.ATTACK_HEAVY: "HEAVY ATTACK  (THE MECH'S MISSILE)",
}
const TOUCH_PAD_TEXT := "D-PAD    MOVE, CLIMB"

var _touch := false
var _key_buttons := {}                  # "action:slot" -> the button
var _listening := ""                    # the "action:slot" of the key button waiting for a key
var _message: Label
var _music_percent: Label
var _sfx_percent: Label
var _back: Button


## Show the window under `parent`. `touch`: list the touch buttons instead of the keys.
static func open(parent: Node, touch: bool) -> SettingsPanel:
	var panel := SettingsPanel.new()
	panel._touch = touch
	parent.add_child(panel)
	return panel


func _init() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0.0)
	panel.add_theme_stylebox_override("panel", HackStyle.panel())
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	column.add_child(HazardStrip.make(STRIP_HEIGHT))
	column.add_child(_header())
	column.add_child(_section("AUDIO"))
	_music_percent = _percent_label()
	_sfx_percent = _percent_label()
	column.add_child(_volume_row("MUSIC", Settings.music_volume, _music_percent, func(v: float) -> void: Settings.set_music_volume(v)))
	column.add_child(_volume_row("SOUND FX", Settings.sfx_volume, _sfx_percent, func(v: float) -> void:
		Settings.set_sfx_volume(v)
		Sfx.play(get_tree(), Sfx.CLICK)))
	column.add_child(_section("TOUCH BUTTONS" if _touch else "CONTROLS"))
	column.add_child(_touch_list() if _touch else _key_grid())
	column.add_child(_hint(HINT_ROLES))
	_message = _hint("")
	_message.add_theme_color_override("font_color", HackStyle.ORANGE)
	if not _touch:
		column.add_child(_hint(HINT_KEYS))
	column.add_child(_message)
	column.add_child(_bottom_row())
	_refresh_keys()
	_back.grab_focus()


func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key := int(event.physical_keycode)
	if _listening == "":
		if key == KEY_ESCAPE:       # (any other key is left to the buttons: Enter presses the one that has the focus)
			get_viewport().set_input_as_handled()
			_close()
		return
	get_viewport().set_input_as_handled()
	var parts := _listening.split(":")
	var action := StringName(parts[0])
	var slot := int(parts[1])
	_message.text = ""
	if key == KEY_ESCAPE:
		pass
	elif key == KEY_DELETE or key == KEY_BACKSPACE:
		if not KeyBindings.clear(action, slot):
			_message.text = LAST_KEY_TEXT if KeyBindings.keys(action)[slot] != KeyBindings.NONE else ""
	else:
		var refused := KeyBindings.set_key(action, slot, key)
		if refused == "RESERVED":
			_message.text = RESERVED_TEXT
		elif refused != "":
			_message.text = USED_TEXT % refused
	_listening = ""
	_refresh_keys()


# ---------------------------------------------------------------------------------------------------------------------------
# building the window
# ---------------------------------------------------------------------------------------------------------------------------
func _header() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var icon := TextureRect.new()
	icon.texture = AssetPaths.ui("icon_settings")
	icon.custom_minimum_size = HEADER_ICON
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)
	row.add_child(_label("SETTINGS", TITLE_SIZE, HackStyle.MINT))
	return row


func _section(text: String) -> Control:
	return _label(text, SECTION_SIZE, HackStyle.CYAN)


func _label(text: String, size: int, color: Color = HackStyle.TEXT) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	HackStyle.style_text(label, color)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


func _hint(text: String) -> Label:
	var label := _label(text, HINT_SIZE, Color(HackStyle.TEXT, 0.6))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(PANEL_WIDTH - 60.0, 0.0)
	return label


func _percent_label() -> Label:
	var label := _label("", ROW_SIZE)
	label.custom_minimum_size = Vector2(PERCENT_WIDTH, 0.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return label


func _volume_row(title: String, value: float, percent: Label, on_change: Callable) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var name_label := _label(title, ROW_SIZE)
	name_label.custom_minimum_size = Vector2(LABEL_WIDTH, 0.0)
	row.add_child(name_label)
	var meter := SegmentedMeter.new()
	meter.custom_minimum_size = METER_SIZE
	meter.fill_color = HackStyle.CYAN
	meter.empty_color = HackStyle.NAVY_DARK
	meter.edge_color = HackStyle.CYAN_DIM
	meter.value = value
	percent.text = "%d%%" % roundi(meter.value * 100.0)
	meter.changed.connect(func(v: float) -> void:
		percent.text = "%d%%" % roundi(v * 100.0)
		on_change.call(v))
	row.add_child(meter)
	row.add_child(percent)
	return row


## The keys: every action with its two key buttons, in two columns.
func _key_grid() -> Control:
	var grid := GridContainer.new()
	grid.columns = 2 * (1 + KeyBindings.SLOTS)
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 6)
	var actions := InputActions.ALL
	var half := (actions.size() + 1) / 2
	for i in half:
		for index in [i, i + half]:
			if index >= actions.size():
				for pad in 1 + KeyBindings.SLOTS:
					grid.add_child(Control.new())
				continue
			var action: StringName = actions[index]
			var name_label := _label(String(KeyBindings.LABELS[action]), ROW_SIZE)
			name_label.custom_minimum_size = Vector2(LABEL_WIDTH - 40.0, 0.0)
			grid.add_child(name_label)
			for slot in KeyBindings.SLOTS:
				var button := Button.new()
				button.custom_minimum_size = KEY_BUTTON_SIZE
				button.add_theme_font_size_override("font_size", ROW_SIZE - 2)
				button.pressed.connect(_listen.bind(action, slot))
				grid.add_child(button)
				_key_buttons["%s:%d" % [action, slot]] = button
	return grid


## The touch buttons: a line for the D-pad and one for each lettered button.
func _touch_list() -> Control:
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	list.add_child(_label(TOUCH_PAD_TEXT, ROW_SIZE))
	for button in TouchControls.FACE_BUTTONS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		var letter := _label(String(button["label"]), ROW_SIZE + 6, HackStyle.ORANGE)
		letter.custom_minimum_size = Vector2(44.0, 0.0)
		row.add_child(letter)
		row.add_child(_label(String(TOUCH_ROLES[button["action"]]), ROW_SIZE))
		list.add_child(row)
	return list


func _bottom_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	row.alignment = BoxContainer.ALIGNMENT_END
	if not _touch:
		var reset := _button("RESET KEYS", RESET_COLOR)
		reset.pressed.connect(func() -> void:
			KeyBindings.reset()
			_message.text = ""
			_listening = ""
			_refresh_keys())
		row.add_child(reset)
	_back = _button("BACK", BACK_COLOR)
	_back.pressed.connect(_close)
	row.add_child(_back)
	return row


func _button(text: String, color: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = BOTTOM_BUTTON_SIZE
	button.add_theme_font_size_override("font_size", ROW_SIZE + 2)
	HackStyle.style_button(button, color)
	button.pressed.connect(func() -> void: Sfx.play(get_tree(), Sfx.CLICK))
	return button


# ---------------------------------------------------------------------------------------------------------------------------
# changing keys
# ---------------------------------------------------------------------------------------------------------------------------
func _listen(action: StringName, slot: int) -> void:
	_listening = "%s:%d" % [action, slot]
	_message.text = ""
	Sfx.play(get_tree(), Sfx.CLICK)
	_refresh_keys()


## Show every key button's key (the one waiting for a key says so).
func _refresh_keys() -> void:
	for id in _key_buttons:
		var button: Button = _key_buttons[id]
		var parts := String(id).split(":")
		var waiting: bool = id == _listening
		button.text = LISTENING_TEXT if waiting else KeyBindings.label(KeyBindings.keys(StringName(parts[0]))[int(parts[1])])
		HackStyle.style_button(button, LISTENING_COLOR if waiting else KEY_COLOR)


func _close() -> void:
	closed.emit()
	queue_free()
