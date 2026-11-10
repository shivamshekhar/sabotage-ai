class_name DontPressGame
extends Minigame
## "Don't press the red button": the only way to win is to do nothing until the timer bar runs out.

# HOLD_TIME: seconds you must resist the button. Higher: a longer, more tempting wait.
const HOLD_TIME := 3.0

var _button: Button


func _init() -> void:
	instructions = "Read the sign. Obey the sign."


func _ready() -> void:
	_build_frame()
	_prompt.text = "Whatever you do, DON'T PRESS THE RED BUTTON"
	_button = _make_button("RED BUTTON", Color(0.85, 0.15, 0.2))
	_button.custom_minimum_size = Vector2(380, 130)
	_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_button.pressed.connect(_on_pressed)
	_box.add_child(_button)
	_add_timer_bar()
	begin()


func begin() -> void:
	_status.text = "...waiting..."
	_start_clock(HOLD_TIME)


func _on_pressed() -> void:
	_lose("YOU PRESSED IT. WHY.")


func _on_clock_done() -> void:
	_win()


func auto_solve() -> void:
	_clock_left = 0.01


func auto_fail() -> void:
	_button.pressed.emit()
