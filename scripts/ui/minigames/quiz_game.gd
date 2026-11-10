class_name QuizGame
extends Minigame
## Shared base of the multiple-choice puzzles (WrongOnlyGame, JokeGame). Each round shows a question and
## a few buttons. Subclasses fill `bank` with {"q": question, "right": the answer, "wrong": [other
## answers]} entries and say whether the goal is the right answer (want_right) or any wrong one.

# ROUNDS: how many questions in a row must be answered properly. Higher: a longer puzzle.
const ROUNDS := 2

# OPTIONS: how many answer buttons each question shows (the right answer plus OPTIONS - 1 wrong ones).
const OPTIONS := 3

var bank: Array = []
var want_right := true
var header := ""        # a line put above each question
var lose_message := "WRONG"
var win_round_message := "NICE"

var _row: HBoxContainer
var _round_no := 0
var _buttons: Array[Button] = []
var _is_right: Array[bool] = []
var _used: Array[int] = []   # bank entries already asked this run


func _ready() -> void:
	_build_frame()
	_row = _make_row()
	begin()


func begin() -> void:
	_round_no = 0
	_used.clear()
	_next_question()


func _next_question() -> void:
	_clear(_row)
	_buttons.clear()
	_is_right.clear()
	var pick := randi() % bank.size()
	while _used.has(pick) and _used.size() < bank.size():
		pick = randi() % bank.size()
	_used.append(pick)
	var entry: Dictionary = bank[pick]
	_prompt.text = "%s\n%s" % [header, entry["q"]] if header != "" else str(entry["q"])
	_status.text = "%d / %d" % [_round_no, ROUNDS]
	var answers: Array = [[entry["right"], true]]
	var wrongs: Array = (entry["wrong"] as Array).duplicate()
	wrongs.shuffle()
	for w in wrongs.slice(0, OPTIONS - 1):
		answers.append([w, false])
	answers.shuffle()
	for a in answers:
		var b := _make_button(a[0], Color(0.2, 0.32, 0.55))
		b.custom_minimum_size = Vector2(270, 120)
		b.add_theme_font_size_override("font_size", 28)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.pressed.connect(_on_pick.bind(a[1]))
		_row.add_child(b)
		_buttons.append(b)
		_is_right.append(a[1])


func _on_pick(right: bool) -> void:
	if _over:
		return
	if right == want_right:
		_round_no += 1
		if _round_no >= ROUNDS:
			_win()
		else:
			_next_question()
	else:
		_lose(lose_message)


func auto_solve() -> void:
	for i in ROUNDS:
		_buttons[_is_right.find(want_right)].pressed.emit()
		await _wait_frames(1)


func auto_fail() -> void:
	_buttons[_is_right.find(not want_right)].pressed.emit()
