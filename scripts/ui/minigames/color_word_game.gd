class_name ColorWordGame
extends Minigame
## "Press the button that says GREEN": two buttons, one coloured like the word but saying something
## else, the other coloured differently but actually saying the word. Read, don't look.

# ROUNDS: how many correct picks in a row it takes. Higher: more chances to be fooled.
const ROUNDS := 3

const NAMES := ["GREEN", "RED", "BLUE", "YELLOW"]
const COLORS := {
	"GREEN": Color(0.15, 0.62, 0.28), "RED": Color(0.8, 0.18, 0.2),
	"BLUE": Color(0.2, 0.38, 0.85), "YELLOW": Color(0.78, 0.62, 0.1),
}

var _row: HBoxContainer
var _round_no := 0
var _right: Button
var _wrong: Button


func _init() -> void:
	instructions = "Read carefully. Colours lie."


func _ready() -> void:
	_build_frame()
	_row = _make_row()
	begin()


func begin() -> void:
	_round_no = 0
	_next_round()


func _next_round() -> void:
	_clear(_row)
	var target: String = NAMES[randi() % NAMES.size()]
	var other: String = target
	while other == target:
		other = NAMES[randi() % NAMES.size()]
	_prompt.text = "Press the button that SAYS \"%s\"" % target
	_status.text = "%d / %d" % [_round_no, ROUNDS]
	# the decoy is coloured like the target word but says something else; the real one is the other way round
	_wrong = _word_button(other, COLORS[target])
	_right = _word_button(target, COLORS[other])
	_wrong.pressed.connect(_on_pick.bind(false))
	_right.pressed.connect(_on_pick.bind(true))
	var pair := [_wrong, _right]
	pair.shuffle()
	for b in pair:
		_row.add_child(b)


func _word_button(text: String, color: Color) -> Button:
	var b := _make_button(text, color)
	b.custom_minimum_size = Vector2(320, 130)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_outline_color", Color.BLACK)
	b.add_theme_constant_override("outline_size", 8)
	return b


func _on_pick(right: bool) -> void:
	if _over:
		return
	if right:
		_round_no += 1
		if _round_no >= ROUNDS:
			_win()
		else:
			_next_round()
	else:
		_lose("READ THE WORD, NOT THE COLOUR!")


func auto_solve() -> void:
	for i in ROUNDS:
		_right.pressed.emit()
		await _wait_frames(1)


func auto_fail() -> void:
	_wrong.pressed.emit()
