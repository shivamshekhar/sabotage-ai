class_name SequenceGame
extends Minigame
## "Memory" puzzle: four coloured pads light up in a random order; repeat the order to unlock.
## A wrong pad starts over with a new order.

# LENGTH: how many pads are in the sequence. Higher: harder to remember. Lower: easier.
const LENGTH := 4

# FLASH_TIME: seconds each pad stays lit while the sequence is shown; the gap between flashes is
# half of it. Higher: easier to follow. Lower: faster and harder.
const FLASH_TIME := 0.5

const PAD_COLORS := [Color(0.85, 0.2, 0.25), Color(0.2, 0.7, 0.35), Color(0.25, 0.45, 0.9), Color(0.9, 0.75, 0.2)]

var _pads: Array[Button] = []
var _sequence: Array[int] = []
var _input_index := 0
var _accepting := false
var _round := 0   # bumped on every restart so an old flashing sequence stops itself


func _init() -> void:
	instructions = "Watch the pads, then repeat the order."


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 16)
	add_child(box)
	_status = _make_label("", 36)
	box.add_child(_status)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 20)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(grid)
	for i in PAD_COLORS.size():
		var pad := _make_button("", PAD_COLORS[i].darkened(0.45))
		pad.custom_minimum_size = Vector2(150, 150)
		pad.pressed.connect(_on_pad.bind(i))
		grid.add_child(pad)
		_pads.append(pad)
	begin()


func begin() -> void:
	_round += 1
	_sequence.clear()
	for i in LENGTH:
		_sequence.append(randi() % PAD_COLORS.size())
	_input_index = 0
	_accepting = false
	_show_sequence(_round)


func _show_sequence(my_round: int) -> void:
	_status.text = "WATCH"
	await get_tree().create_timer(0.6, true, false, true).timeout
	for i in _sequence:
		if my_round != _round:
			return
		_light(i, true)
		await get_tree().create_timer(FLASH_TIME, true, false, true).timeout
		_light(i, false)
		await get_tree().create_timer(FLASH_TIME * 0.5, true, false, true).timeout
	if my_round == _round:
		_status.text = "YOUR TURN  (%d)" % _sequence.size()
		_accepting = true


func _light(i: int, lit: bool) -> void:
	var box := _pads[i].get_theme_stylebox("normal").duplicate() as StyleBoxFlat
	box.bg_color = PAD_COLORS[i] if lit else PAD_COLORS[i].darkened(0.45)
	_pads[i].add_theme_stylebox_override("normal", box)
	_pads[i].add_theme_stylebox_override("hover", box)


func _on_pad(i: int) -> void:
	if not _accepting:
		return
	_light(i, true)
	get_tree().create_timer(0.15, true, false, true).timeout.connect(func() -> void: _light(i, false))
	if i != _sequence[_input_index]:
		_accepting = false
		_status.text = "WRONG - NEW CODE"
		await get_tree().create_timer(0.9, true, false, true).timeout
		begin()
		return
	_input_index += 1
	_status.text = "YOUR TURN  (%d)" % (_sequence.size() - _input_index)
	if _input_index >= _sequence.size():
		_accepting = false
		_status.text = "ACCESS GRANTED"
		solved.emit()


## For tests: the order the pads will be/were shown in.
func sequence() -> Array[int]:
	return _sequence


## For tests: press a pad as if clicked.
func press(i: int) -> void:
	_on_pad(i)


## For tests: true once the sequence has been shown and input is accepted.
func accepting() -> bool:
	return _accepting


func auto_solve() -> void:
	while not _accepting:
		await _wait_frames(1)
	for i in _sequence.duplicate():
		_on_pad(i)


func auto_fail() -> void:
	while not _accepting:
		await _wait_frames(1)
	_on_pad((_sequence[0] + 1) % PAD_COLORS.size())
