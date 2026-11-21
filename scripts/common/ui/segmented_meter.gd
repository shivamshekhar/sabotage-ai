class_name SegmentedMeter
extends Control
## A volume-style meter made of blocks (like a retro level bar): tap or drag over it to set the level, or use Left/Right once it has the focus. The level goes in steps of one
## block. Good for a finger as well as a mouse. Its look is set by the colours below (the menus restyle them to the game's).
##
##   var meter := SegmentedMeter.new()
##   meter.value = 0.7
##   meter.changed.connect(func(v: float) -> void: Settings.set_music_volume(v))

## Emitted when the player changes the level (not when `value` is set from code): `new_value` is 0 to 1.
signal changed(new_value: float)

# SEGMENTS: how many blocks the meter has (so how many steps there are above zero). GAP: the space between two blocks, in pixels.
const SEGMENTS := 10
const GAP := 5.0

# CORNER: how rounded the blocks are, in pixels.
const CORNER := 3.0

var fill_color := Color(0.23, 0.82, 1.0)
var empty_color := Color(0.07, 0.1, 0.17)
var edge_color := Color(0.16, 0.42, 0.56)
var focus_color := Color(1.0, 1.0, 1.0, 0.9)

## The level now, 0 to 1 (a multiple of 1 / SEGMENTS).
var value := 0.0:
	set(v):
		value = snappedf(clampf(v, 0.0, 1.0), 1.0 / SEGMENTS)
		queue_redraw()

var _dragging := false
var _on_box: StyleBoxFlat       # the look of a lit block and of an unlit one (made on the first draw, from the colours above)
var _off_box: StyleBoxFlat


func _init() -> void:
	focus_mode = Control.FOCUS_ALL
	custom_minimum_size = Vector2(300.0, 44.0)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		if event.pressed:
			_set_from_x(event.position.x)
			grab_focus()
	elif event is InputEventMouseMotion and _dragging:
		_set_from_x(event.position.x)
	elif event is InputEventKey and event.pressed and has_focus():
		if event.keycode == KEY_LEFT:
			_change(value - 1.0 / SEGMENTS)
			accept_event()
		elif event.keycode == KEY_RIGHT:
			_change(value + 1.0 / SEGMENTS)
			accept_event()


## The level for a touch at x pixels from the meter's left edge: the block under it is the last one lit; a touch on the very first half block turns it right down.
func _set_from_x(x: float) -> void:
	var block := size.x / SEGMENTS
	var lit := int(ceil(x / block - 0.35))
	_change(float(clampi(lit, 0, SEGMENTS)) / SEGMENTS)


func _change(new_value: float) -> void:
	var before := value
	value = new_value
	if not is_equal_approx(before, value):
		changed.emit(value)


func _box(color: Color, edge: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = edge
	box.set_border_width_all(2)
	box.set_corner_radius_all(int(CORNER))
	return box


func _draw() -> void:
	var block_w := (size.x - GAP * (SEGMENTS - 1)) / SEGMENTS
	if _on_box == null:
		_on_box = _box(fill_color, fill_color.lightened(0.35))
		_off_box = _box(empty_color, edge_color)
	var lit := roundi(value * SEGMENTS)
	for i in SEGMENTS:
		draw_style_box(_on_box if i < lit else _off_box, Rect2(i * (block_w + GAP), 0.0, block_w, size.y))
	if has_focus():
		draw_rect(Rect2(Vector2.ZERO, size).grow(3.0), focus_color, false, 2.0)
