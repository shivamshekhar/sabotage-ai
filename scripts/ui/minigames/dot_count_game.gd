class_name DotCountGame
extends Minigame
## A counting game: a scatter of red and blue dots; pick how many are RED.

# ROUNDS: how many correct counts in a row it takes. Higher: a longer puzzle.
const ROUNDS := 2

# SLOTS: the dots sit on a COLUMNS x 2 grid of slots with a little jitter; each slot may hold a dot.
const COLUMNS := 10
const DOT_RADIUS := 16.0
const FIELD_SIZE := Vector2(700, 120)

var _field: Control
var _row: HBoxContainer
var _dots: Array[Dictionary] = []   # {"pos": Vector2, "red": bool}
var _buttons: Array[Button] = []
var _answers: Array[int] = []
var _correct := 0
var _round_no := 0


func _init() -> void:
	instructions = "Count carefully."


func _ready() -> void:
	_build_frame()
	_field = Control.new()
	_field.custom_minimum_size = FIELD_SIZE
	_field.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_field.draw.connect(_draw_field)
	_box.add_child(_field)
	_row = _make_row()
	begin()


func begin() -> void:
	_round_no = 0
	_next_round()


func _next_round() -> void:
	_dots.clear()
	var slots: Array[Vector2i] = []
	for c in COLUMNS:
		for r in 2:
			slots.append(Vector2i(c, r))
	slots.shuffle()
	_correct = 0
	var count := 9 + randi() % 5
	for i in count:
		var red := i < 3 + randi() % 4 or i == 0
		var s := slots[i]
		var cell := Vector2(FIELD_SIZE.x / COLUMNS, FIELD_SIZE.y / 2.0)
		var pos := Vector2((s.x + 0.5) * cell.x, (s.y + 0.5) * cell.y) + Vector2(randf_range(-8, 8), randf_range(-8, 8))
		_dots.append({"pos": pos, "red": red})
	for d in _dots:
		if d["red"]:
			_correct += 1
	_field.queue_redraw()
	_prompt.text = "How many RED dots?"
	_status.text = "%d / %d" % [_round_no, ROUNDS]
	_clear(_row)
	_buttons.clear()
	_answers.clear()
	var options: Array[int] = [_correct]
	while options.size() < 4:
		var n := clampi(_correct + randi_range(-3, 3), 1, 12)
		if not options.has(n):
			options.append(n)
	options.shuffle()
	for n in options:
		var b := _make_button(str(n), Color(0.2, 0.32, 0.55))
		b.custom_minimum_size = Vector2(150, 100)
		b.pressed.connect(_on_pick.bind(n))
		_row.add_child(b)
		_buttons.append(b)
		_answers.append(n)


func _draw_field() -> void:
	_field.draw_rect(Rect2(Vector2.ZERO, FIELD_SIZE), Color(0.05, 0.08, 0.14))
	for d in _dots:
		_field.draw_circle(d["pos"], DOT_RADIUS, Color(0.9, 0.2, 0.25) if d["red"] else Color(0.25, 0.45, 0.95))


func _on_pick(n: int) -> void:
	if _over:
		return
	if n == _correct:
		_round_no += 1
		if _round_no >= ROUNDS:
			_win()
		else:
			_next_round()
	else:
		_lose("THAT IS NOT HOW MANY. RECOUNT.")


func auto_solve() -> void:
	for i in ROUNDS:
		_buttons[_answers.find(_correct)].pressed.emit()
		await _wait_frames(1)


func auto_fail() -> void:
	_buttons[(_answers.find(_correct) + 1) % _buttons.size()].pressed.emit()
