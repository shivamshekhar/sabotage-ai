class_name WardrobePanel
extends CanvasLayer
## The wardrobe window, in the game's own look (see HackStyle): the hero as they are dressed now, in a box on the left (standing, walking, jumping or firing the EMP gun, as the
## buttons under it say), and on the right a row for every slot of the WardrobeCatalog: arrows that go through its styles and a swatch for each of its colours. Every change is
## worn and kept at once (see Wardrobe). RANDOM makes up an outfit, ORIGINAL puts the first one back.
##
##   var panel := WardrobePanel.open(self)
##   panel.closed.connect(on_closed)

signal closed

# LAYER: the canvas layer of the window: above the menus under it.
const LAYER := 40

# PANEL_WIDTH: the window's width in pixels, in the game's 1280x720 reference screen. Its height follows its content.
const PANEL_WIDTH := 1160.0

# STRIP_HEIGHT: the hazard stripe along the top. HEADER_ICON: the size of the icon in the title row. TITLE_SIZE / ROW_SIZE / HINT_SIZE: font sizes.
const STRIP_HEIGHT := 12.0
const HEADER_ICON := Vector2(56.0, 56.0)
const TITLE_SIZE := 25
const ROW_SIZE := 14
const HINT_SIZE := 11

# PREVIEW_SIZE: the size of the box the hero is shown in (px); PREVIEW_SCALE: how many times bigger than in the game they are drawn; PREVIEW_FEET: where their feet are in the
# box (from the top left); PREVIEW_COLOR: the box's colour.
const PREVIEW_SIZE := Vector2(300.0, 400.0)
const PREVIEW_SCALE := 2.8
const PREVIEW_FEET := Vector2(150.0, 372.0)
const PREVIEW_COLOR := Color(0.05, 0.07, 0.12, 0.9)

# PREVIEW_STATES: the buttons under the hero: what they say and the state of the sprite they show (see PlayerSprite.update_pose()).
const PREVIEW_STATES := [
	{"label": "STAND", "state": &"idle"},
	{"label": "WALK", "state": &"walk"},
	{"label": "JUMP", "state": &"jump"},
	{"label": "SHOOT", "state": &"shoot"},
]

# LABEL_WIDTH: the width of the slot's name; STYLE_WIDTH: of its style's name between the arrows; ARROW_SIZE: of an arrow button; SWATCH_SIZE: of a colour's swatch.
const LABEL_WIDTH := 110.0
const STYLE_WIDTH := 190.0
const ARROW_SIZE := Vector2(46.0, 46.0)
const SWATCH_SIZE := Vector2(30.0, 30.0)

# SWATCH_BORDER: the width of a swatch's border; SWATCH_SELECTED_COLOR / SWATCH_COLOR: the border of the colour worn now / of the others.
const SWATCH_BORDER := 4
const SWATCH_SELECTED_COLOR := Color(1.0, 1.0, 1.0)
const SWATCH_COLOR := Color(0.07, 0.09, 0.14)

# BOTTOM_BUTTON_SIZE: the size of the buttons along the bottom; ARROW_COLOR / STATE_COLOR / STATE_SELECTED_COLOR / BACK_COLOR / RESET_COLOR: their colours.
const BOTTOM_BUTTON_SIZE := Vector2(220.0, 54.0)
const STATE_BUTTON_SIZE := Vector2(70.0, 40.0)
const ARROW_COLOR := Color(0.17, 0.32, 0.52)
const STATE_COLOR := Color(0.17, 0.32, 0.52)
const STATE_SELECTED_COLOR := Color(0.85, 0.5, 0.12)
const BACK_COLOR := Color(0.2, 0.55, 0.9)
const RESET_COLOR := Color(0.55, 0.3, 0.2)

const HINT := "PICK A STYLE WITH THE ARROWS AND A COLOUR WITH THE SWATCHES. WHAT YOU WEAR IS KEPT."

var _sprite: PlayerSprite
var _state: StringName = &"idle"
var _style_labels := {}       # slot -> the label between its arrows
var _swatches := {}           # slot -> {colour id -> its button}
var _state_buttons := {}      # state -> its button
var _back: Button


## Show the window under `parent`.
static func open(parent: Node) -> WardrobePanel:
	var panel := WardrobePanel.new()
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
	var middle := HBoxContainer.new()
	middle.add_theme_constant_override("separation", 28)
	middle.add_child(_preview_column())
	middle.add_child(_slot_column())
	column.add_child(middle)
	column.add_child(_hint(HINT))
	column.add_child(_bottom_row())
	_refresh()
	_back.grab_focus()


func _process(delta: float) -> void:
	_sprite.update_pose(_state, 1, delta)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and int(event.physical_keycode) == KeyBindings.CANCEL_KEY:
		get_viewport().set_input_as_handled()
		_close()


# ---------------------------------------------------------------------------------------------------------------------------
# building the window
# ---------------------------------------------------------------------------------------------------------------------------
func _header() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var icon := TextureRect.new()
	icon.texture = AssetPaths.ui("icon_wardrobe")
	icon.custom_minimum_size = HEADER_ICON
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)
	row.add_child(_label("WARDROBE", TITLE_SIZE, HackStyle.MINT))
	return row


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


## The hero in a box, and the buttons that say how they stand.
func _preview_column() -> Control:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	var box := Panel.new()
	box.custom_minimum_size = PREVIEW_SIZE
	box.clip_contents = true
	var style := StyleBoxFlat.new()
	style.bg_color = PREVIEW_COLOR
	style.set_corner_radius_all(8)
	box.add_theme_stylebox_override("panel", style)
	var figure := Node2D.new()
	figure.position = PREVIEW_FEET
	figure.scale = Vector2(PREVIEW_SCALE, PREVIEW_SCALE)
	_sprite = PlayerSprite.new()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST      # (the flat blocky art stays crisp when it is drawn big)
	figure.add_child(_sprite)
	box.add_child(figure)
	column.add_child(box)
	var states := HBoxContainer.new()
	states.add_theme_constant_override("separation", 6)
	for entry: Dictionary in PREVIEW_STATES:
		var button := Button.new()
		button.text = entry["label"]
		button.custom_minimum_size = STATE_BUTTON_SIZE
		button.add_theme_font_size_override("font_size", HINT_SIZE)
		button.pressed.connect(_show_state.bind(entry["state"]))
		states.add_child(button)
		_state_buttons[entry["state"]] = button
	column.add_child(states)
	return column


## A row for every slot: its name, the arrows round its style's name, and the swatches of its colours.
func _slot_column() -> Control:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	for slot in WardrobeCatalog.SLOTS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var name_label := _label(String(WardrobeCatalog.LABELS[slot]), ROW_SIZE, HackStyle.CYAN)
		name_label.custom_minimum_size = Vector2(LABEL_WIDTH, 0.0)
		row.add_child(name_label)
		row.add_child(_arrow("<", slot, -1))
		var style_label := _label("", ROW_SIZE)
		style_label.custom_minimum_size = Vector2(STYLE_WIDTH, 0.0)
		style_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(style_label)
		_style_labels[slot] = style_label
		row.add_child(_arrow(">", slot, 1))
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(14.0, 0.0)
		row.add_child(gap)
		_swatches[slot] = {}
		for entry: Dictionary in WardrobeCatalog.palette(slot):
			var swatch := Button.new()
			swatch.custom_minimum_size = SWATCH_SIZE
			swatch.tooltip_text = entry["label"]
			swatch.pressed.connect(_pick_color.bind(slot, entry["id"]))
			row.add_child(swatch)
			_swatches[slot][entry["id"]] = swatch
		column.add_child(row)
	return column


func _arrow(text: String, slot: StringName, step: int) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = ARROW_SIZE
	button.add_theme_font_size_override("font_size", ROW_SIZE + 4)
	HackStyle.style_button(button, ARROW_COLOR)
	button.pressed.connect(_step.bind(slot, step))
	return button


func _bottom_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	row.alignment = BoxContainer.ALIGNMENT_END
	var random := _button("RANDOM", ARROW_COLOR)
	random.pressed.connect(func() -> void:
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		Wardrobe.shuffle(rng)
		_refresh())
	row.add_child(random)
	var original := _button("ORIGINAL", RESET_COLOR)
	original.pressed.connect(func() -> void:
		Wardrobe.reset()
		_refresh())
	row.add_child(original)
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
# what the player does
# ---------------------------------------------------------------------------------------------------------------------------
func _step(slot: StringName, step: int) -> void:
	Sfx.play(get_tree(), Sfx.CLICK)
	Wardrobe.step_style(slot, step)
	_refresh()


func _pick_color(slot: StringName, id: StringName) -> void:
	Sfx.play(get_tree(), Sfx.CLICK)
	Wardrobe.change(slot, &"", id)
	_refresh()


func _show_state(state: StringName) -> void:
	Sfx.play(get_tree(), Sfx.CLICK)
	_state = state
	_refresh()


## Show what is worn now: every slot's style, which swatch is the one worn, which way the hero is shown.
func _refresh() -> void:
	var outfit := Wardrobe.outfit()
	for slot in WardrobeCatalog.SLOTS:
		(_style_labels[slot] as Label).text = String(WardrobeCatalog.style_entry(slot, outfit.style(slot))["label"])
		var fixed := WardrobeCatalog.fixed_color(slot, outfit.style(slot)) != &""      # (a style with a colour of its own has no swatches)
		for id in _swatches[slot]:
			(_swatches[slot][id] as Button).visible = not fixed
			_style_swatch(_swatches[slot][id], WardrobeCatalog.color_entry(slot, id)["color"], id == outfit.color_id(slot))
	for state in _state_buttons:
		HackStyle.style_button(_state_buttons[state], STATE_SELECTED_COLOR if state == _state else STATE_COLOR)


## A swatch: a flat square of its colour, with a bright border when it is the one worn.
func _style_swatch(button: Button, color: Color, worn: bool) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = SWATCH_SELECTED_COLOR if worn else SWATCH_COLOR
	box.set_border_width_all(SWATCH_BORDER)
	box.set_corner_radius_all(6)
	for state in ["normal", "hover", "pressed", "focus"]:
		button.add_theme_stylebox_override(state, box)


func _close() -> void:
	closed.emit()
	queue_free()
