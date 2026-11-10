class_name SimonSaysGame
extends Minigame
## Simon says: obey "Simon says tap X" but do NOT react to a plain "Tap X". Each round has a timer bar:
## on a "Simon says" round tap the right button before it runs out; on any other round wait it out.

# ROUNDS: how many rounds. Half are "Simon says". Higher: a longer puzzle.
const ROUNDS := 4

# ROUND_TIME: seconds per round (the timer bar). Higher: easier. Lower: tighter.
const ROUND_TIME := 2.5

const BUTTON_NAMES := ["CAT", "TOAST", "ROBOT"]
const BUTTON_COLORS := [Color(0.85, 0.5, 0.15), Color(0.7, 0.5, 0.25), Color(0.3, 0.45, 0.8)]

var _says: Array[bool] = []
var _round_no := 0
var _target := 0
var _buttons: Array[Button] = []


func _init() -> void:
	instructions = "Only do what Simon says."


func _ready() -> void:
	_build_frame()
	var row := _make_row()
	for i in BUTTON_NAMES.size():
		var b := _make_button(BUTTON_NAMES[i], BUTTON_COLORS[i])
		b.custom_minimum_size = Vector2(240, 120)
		b.pressed.connect(_on_tap.bind(i))
		row.add_child(b)
		_buttons.append(b)
	_add_timer_bar()
	begin()


func begin() -> void:
	_says = [true, true, false, false]
	_says.shuffle()
	_round_no = 0
	_next_round()


func _next_round() -> void:
	_target = randi() % BUTTON_NAMES.size()
	var says := _says[_round_no]
	_prompt.text = ("Simon says: tap %s" if says else "Tap %s") % BUTTON_NAMES[_target]
	_status.text = "%d / %d" % [_round_no, ROUNDS]
	_start_clock(ROUND_TIME)


func _round_done() -> void:
	_round_no += 1
	if _round_no >= ROUNDS:
		_win()
	else:
		_next_round()


func _on_tap(i: int) -> void:
	if _over:
		return
	if not _says[_round_no]:
		_lose("SIMON DIDN'T SAY!")
	elif i == _target:
		_round_done()
	else:
		_lose("SIMON SAID %s!" % BUTTON_NAMES[_target])


func _on_clock_done() -> void:
	if _over:
		return
	if _says[_round_no]:
		_lose("TOO SLOW!")
	else:
		_round_done()   # correctly did nothing


func auto_solve() -> void:
	for i in ROUNDS:
		if _says[_round_no]:
			_buttons[_target].pressed.emit()
		else:
			_clock_left = 0.01
		await _wait_frames(3)


func auto_fail() -> void:
	if _says[_round_no]:
		_buttons[(_target + 1) % BUTTON_NAMES.size()].pressed.emit()
	else:
		_buttons[0].pressed.emit()
