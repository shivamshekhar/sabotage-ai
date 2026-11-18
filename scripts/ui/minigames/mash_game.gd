class_name MashGame
extends Minigame
## Button mashing against a timer bar: tap the big red arcade button before the bar runs out. The button is small and jumps to a new
## place after every tap, so you have to chase it.

# TAPS_NEEDED: how many taps you need. Higher: a harder sprint.
const TAPS_NEEDED := 4

# TIME_LIMIT: seconds to land TAPS_NEEDED taps (the timer bar shows it). Lower: harder.
const TIME_LIMIT := 3.0

# BUTTON_SIZE: the size in pixels of the red button (it is not smaller than the phone tap size, Minigame.BUTTON_MIN, in width).
# Smaller: harder to hit. Larger: easier.
const BUTTON_SIZE := Vector2(120, 112)

# FIELD_SIZE: the area in pixels the button hops around in.
const FIELD_SIZE := Vector2(780, 190)

# MIN_HOP: the least distance in pixels the button moves each tap, so it never stays where it was.
const MIN_HOP := 200.0

const RED := Color(0.86, 0.0, 0.0)
const DARK_RED := Color(0.35, 0.0, 0.02)
const METAL := Color(0.68, 0.68, 0.72)
const SHADOW := Color(0.12, 0.12, 0.13)

var _field: Control
var _button: Button
var _taps := 0
var _held := false


func _init() -> void:
	instructions = "Catch the button and tap it!"


func _ready() -> void:
	_build_frame()
	_field = Control.new()
	_field.custom_minimum_size = FIELD_SIZE
	_field.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_box.add_child(_field)
	_button = Button.new()
	_button.focus_mode = Control.FOCUS_NONE
	_button.size = BUTTON_SIZE
	_button.custom_minimum_size = BUTTON_SIZE
	for state in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		_button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	_button.draw.connect(_draw_button)
	_button.button_down.connect(func() -> void:
		_held = true
		_button.queue_redraw())
	_button.button_up.connect(func() -> void:
		_held = false
		_button.queue_redraw())
	_button.pressed.connect(_on_tap)
	_field.add_child(_button)
	_add_timer_bar()
	begin()


func begin() -> void:
	_taps = 0
	_prompt.text = "Tap it %d times before the bar runs out!" % int(_p("taps_needed", TAPS_NEEDED))
	_status.text = "0 / %d" % int(_p("taps_needed", TAPS_NEEDED))
	_hop(false)
	_start_clock(float(_p("time_limit", TIME_LIMIT)))


## Move the button to a random spot in the field (at least MIN_HOP away from where it is, when `away` is true).
func _hop(away: bool) -> void:
	var room := FIELD_SIZE - BUTTON_SIZE
	var spot := Vector2(randf() * room.x, randf() * room.y)
	var tries := 0
	while away and spot.distance_to(_button.position) < MIN_HOP and tries < 20:
		spot = Vector2(randf() * room.x, randf() * room.y)
		tries += 1
	_button.position = spot


func _on_tap() -> void:
	if _over:
		return
	_taps += 1
	_status.text = "%d / %d" % [_taps, int(_p("taps_needed", TAPS_NEEDED))]
	if _taps >= int(_p("taps_needed", TAPS_NEEDED)):
		_win()
	else:
		_hop(true)


func _on_clock_done() -> void:
	_lose("TOO SLOW. TYPICAL HUMAN.")


## The arcade button: a red dome on a grey base with a dark shadow underneath (it sinks a little while held).
func _draw_button() -> void:
	var w := BUTTON_SIZE.x
	var h := BUTTON_SIZE.y
	var sink := 8.0 if _held else 0.0
	_button.draw_colored_polygon(_ellipse(Vector2(w / 2.0, h - 34.0), w / 2.0, 28.0), SHADOW)
	_button.draw_colored_polygon(_ellipse(Vector2(w / 2.0, h - 46.0), w / 2.0, 28.0), METAL)
	_button.draw_colored_polygon(_ellipse(Vector2(w / 2.0, h - 54.0 + sink), w * 0.34, 24.0), DARK_RED)
	_button.draw_colored_polygon(_ellipse(Vector2(w / 2.0, h - 66.0 + sink), w * 0.34, 24.0), RED)


func _ellipse(center: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 40:
		var a := TAU * float(i) / 40.0
		points.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	return points


func auto_solve() -> void:
	for i in int(_p("taps_needed", TAPS_NEEDED)):
		_button.pressed.emit()


func auto_fail() -> void:
	_clock_left = 0.01
