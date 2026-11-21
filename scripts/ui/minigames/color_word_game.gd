class_name ColorWordGame
extends Minigame
## "Press the button that says GREEN": two buttons, one coloured like the word but saying something
## else, the other coloured differently but actually saying the word. Read, don't look.

# ROUNDS: how many correct picks in a row it takes. Higher: more chances to be fooled.
const ROUNDS := 3

# OPTIONS: how many buttons each round shows (2 or 3): one says the word, the rest are decoys. Higher: harder to spot the right one.
const OPTIONS := 3

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
	var names := NAMES.duplicate()
	names.shuffle()
	var target: String = names[0]
	var other: String = names[1]
	var third: String = names[2]
	_prompt.text = "Press the button that SAYS \"%s\"" % target
	_status.text = "%d / %d" % [_round_no, int(_p("rounds", ROUNDS))]
	# One button says the target in some other colour. One decoy is coloured like the target word but says something else; the
	# other says a third word in the fourth colour (so neither the colours nor the words give the right one away).
	_right = _word_button(target, COLORS[other])
	_wrong = _word_button(other, COLORS[target])
	var decoy := _word_button(third, COLORS[names[3]])
	_right.pressed.connect(_on_pick.bind(true))
	_wrong.pressed.connect(_on_pick.bind(false))
	decoy.pressed.connect(_on_pick.bind(false))
	var buttons := [_wrong, _right, decoy].slice(0, OPTIONS)
	if not buttons.has(_right):
		buttons[0] = _right
	buttons.shuffle()
	for b in buttons:
		_row.add_child(b)


func _word_button(text: String, color: Color) -> Button:
	var b := _make_button(text, color)
	b.custom_minimum_size = Vector2(250, 130)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_outline_color", Color.BLACK)
	b.add_theme_constant_override("outline_size", 8)
	return b


func _on_pick(right: bool) -> void:
	if _over:
		return
	if right:
		_round_no += 1
		if _round_no >= int(_p("rounds", ROUNDS)):
			_win()
		else:
			_next_round()
	else:
		_lose("READ THE WORD, NOT THE COLOUR!")


func auto_solve() -> void:
	for i in int(_p("rounds", ROUNDS)):
		_right.pressed.emit()
		await _wait_frames(1)


func auto_fail() -> void:
	_wrong.pressed.emit()
