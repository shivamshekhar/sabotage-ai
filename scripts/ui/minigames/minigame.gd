class_name Minigame
extends Control
## Base class for the little puzzles shown when the player uses a computer (see HackPopup).
## A puzzle fills its parent, reports solved() when beaten and never "fails for good": a mistake
## just starts it over. Everything is clicked or tapped, so it works with a mouse and on a phone.
##
## Puzzles built on _build_frame() get a shared layout: a status line, a prompt, their own content, and
## an optional timer bar (see _start_clock()). Every puzzle also has two test hooks, auto_solve() and
## auto_fail(), that play it correctly or wrongly, so tools/tests/minigame_test.gd can check each one.

signal solved

## One-line instructions the popup shows above the puzzle.
var instructions := ""

# BUTTON_MIN: the smallest side in pixels of any clickable button in a puzzle. Phone fingers
# are big; keep it comfortably above the smallest tap target the controls use.
# Higher: easier to hit. Lower: more room for the puzzle but fiddly on a phone.
const BUTTON_MIN := 120.0

# RETRY_DELAY: seconds a "wrong" message stays up before the puzzle starts over.
# Higher: more time to read the joke. Lower: back to the puzzle faster.
const RETRY_DELAY := 0.9

var _box: VBoxContainer
var _status: Label
var _prompt: Label
var _bar: ProgressBar
var _over := false          # true once won, or while a lost round's message is showing
var _clock_left := -1.0     # seconds left on the timer bar (negative = no timer running)
var _clock_total := 1.0


## Start (or restart) the puzzle from scratch.
func begin() -> void:
	pass


## Test hook: play the puzzle correctly until it is solved. May take a few frames (await it).
func auto_solve() -> void:
	pass


## Test hook: make one mistake. The puzzle must not be solved by it, and must start over after RETRY_DELAY.
func auto_fail() -> void:
	pass


## Called when the timer bar runs out. Puzzles with a timer override this.
func _on_clock_done() -> void:
	pass


## The shared layout: status line on top, then the prompt, then whatever the puzzle adds to _box, then
## the timer bar (hidden until a clock is started).
func _build_frame() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_box = VBoxContainer.new()
	_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_box.add_theme_constant_override("separation", 12)
	add_child(_box)
	_status = _make_label("", 32)
	_status.add_theme_color_override("font_color", Color(0.4, 1.0, 0.6))
	_box.add_child(_status)
	_prompt = _make_label("", 30)
	_prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_prompt.custom_minimum_size = Vector2(840, 0)
	_prompt.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_box.add_child(_prompt)


## Add the timer bar at the bottom of the frame; call after the puzzle's own content has been added.
func _add_timer_bar() -> void:
	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(700, 20)
	_bar.show_percentage = false
	_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_bar.visible = false
	_box.add_child(_bar)


## Start the timer bar running down from `seconds`; when it hits zero _on_clock_done() is called.
func _start_clock(seconds: float) -> void:
	_clock_total = seconds
	_clock_left = seconds
	if _bar != null:
		_bar.visible = true
		_bar.max_value = seconds
		_bar.value = seconds


func _stop_clock() -> void:
	_clock_left = -1.0
	if _bar != null:
		_bar.visible = false


func _process(delta: float) -> void:
	if _clock_left < 0.0:
		return
	_clock_left -= delta
	if _bar != null:
		_bar.value = maxf(_clock_left, 0.0)
	if _clock_left <= 0.0:
		_clock_left = -1.0
		_on_clock_done()


func _win() -> void:
	if _over:
		return
	_over = true
	_stop_clock()
	_status.text = "ACCESS GRANTED"
	solved.emit()


## A mistake: show `message` for RETRY_DELAY seconds, then start over.
func _lose(message: String) -> void:
	if _over:
		return
	_over = true
	_stop_clock()
	_status.text = message
	await get_tree().create_timer(RETRY_DELAY, true, false, true).timeout
	if not is_inside_tree():
		return
	_over = false
	begin()


func _wait_frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _make_button(text: String, color: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(BUTTON_MIN, BUTTON_MIN)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 40)
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(14)
	b.add_theme_stylebox_override("normal", box)
	var pressed := box.duplicate() as StyleBoxFlat
	pressed.bg_color = color.lightened(0.45)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("hover", box)
	return b


func _make_label(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	return l


## A horizontal row of buttons, added to the frame.
func _make_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	_box.add_child(row)
	return row


## Remove and free every child of a container.
func _clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()
