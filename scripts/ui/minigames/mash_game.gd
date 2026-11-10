class_name MashGame
extends Minigame
## Button mashing against a timer bar: tap fast enough and the gate gives in.

# TAPS_NEEDED: how many taps you need. Higher: a harder sprint.
const TAPS_NEEDED := 12

# TIME_LIMIT: seconds to land TAPS_NEEDED taps (the timer bar shows it). Lower: harder.
const TIME_LIMIT := 3.0

var _button: Button
var _taps := 0


func _init() -> void:
	instructions = "Tap! Tap! TAP!"


func _ready() -> void:
	_build_frame()
	_button = _make_button("MASH ME!", Color(0.85, 0.5, 0.1))
	_button.custom_minimum_size = Vector2(380, 140)
	_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_button.pressed.connect(_on_tap)
	_box.add_child(_button)
	_add_timer_bar()
	begin()


func begin() -> void:
	_taps = 0
	_prompt.text = "Tap %d times before the bar runs out!" % TAPS_NEEDED
	_status.text = "0 / %d" % TAPS_NEEDED
	_start_clock(TIME_LIMIT)


func _on_tap() -> void:
	if _over:
		return
	_taps += 1
	_status.text = "%d / %d" % [_taps, TAPS_NEEDED]
	if _taps >= TAPS_NEEDED:
		_win()


func _on_clock_done() -> void:
	_lose("TOO SLOW. TYPICAL HUMAN.")


func auto_solve() -> void:
	for i in TAPS_NEEDED:
		_button.pressed.emit()


func auto_fail() -> void:
	_clock_left = 0.01
