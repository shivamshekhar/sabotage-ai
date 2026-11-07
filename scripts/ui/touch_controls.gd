class_name TouchControls
extends CanvasLayer
## Phone controls. Left: an 8-way D-pad. Right: four buttons (jump, interact, light attack,
## heavy attack). Each control drives an input action, so gameplay code never knows about touch.
##
## Shown on phones only (see should_show()). To try it on a PC, run the game with the
## environment variable SABOTAGE_TOUCH=1: the overlay appears and the left mouse button acts
## as a finger.
##
## Raw touch events are handled here (instead of TouchScreenButton) so that:
##  - several fingers work at once (steer with the D-pad while tapping JUMP)
##  - the D-pad is a real 8-way pad: slide the thumb around it, hold up+right for a diagonal
##  - sliding a thumb between the face buttons switches without lifting it
##  - controls stick to the real screen corners, even on wide phones where the game viewport
##    is wider than the 1280x720 design size
##  - touch areas are a bit bigger than what is drawn, so near-misses still count

# LAYOUT. Units are pixels in game coordinates (the design space, which can be wider on long
# phone screens). layout() turns these into screen positions.

# MARGIN: gap between the controls and the screen edges: x for the left and right edges,
# y for the bottom edge.
#     D-pad centre = (MARGIN.x + DPAD_RADIUS, view.y - MARGIN.y - DPAD_RADIUS)
#     button cluster: placed so its outer edge is MARGIN.x from the right edge and MARGIN.y
#     from the bottom edge
# Higher: moves the controls inwards, away from curved corners and the system gesture bar,
# but closer to the action. Lower: tucked into the corners, where edge swipes may trigger
# Android gestures.
const MARGIN := Vector2(70, 36)

# D-PAD (left). One finger steers it; where that finger is relative to the pad's centre
# picks the directions (see _touch_down and _update_dpad).

# DPAD_RADIUS: radius of the pad in pixels. Used for drawing, for the "is this touch on the
# pad?" test, and (times DPAD_DEADZONE) for the dead zone.
# Higher: a bigger, easier thumb target that covers more of the screen (also raise
# Main.TOUCH_SIDE_PADDING so the player stays clear of it). Lower: smaller and fiddlier.
const DPAD_RADIUS := 120.0

# DPAD_DEADZONE: fraction of the radius, around the centre, where the thumb counts as "not
# pressing":
#     dead zone = DPAD_RADIUS * DPAD_DEADZONE
# Higher: you must push further before the character reacts (fewer accidental moves, less
# sensitive). Lower: twitchy, reacts to tiny thumb movements.
const DPAD_DEADZONE := 0.22

# DPAD_DIAGONAL: how a thumb position becomes up to two directions. With v = thumb - centre
# and len = |v|, a direction is ON when its share of the offset is large enough:
#     right is on if v.x > 0 and |v.x| >= len * DPAD_DIAGONAL      (same for left, up, down)
# Two directions on at once make a diagonal (for example right + up). A direction turns on
# once the thumb is more than asin(DPAD_DIAGONAL) away from the other axis.
# Higher: diagonals shrink to a narrow band; at 1 / sqrt(2) there are none (4-way).
# Lower: diagonals get wider and pure directions narrower, so pressing slightly up while
# running triggers a jump more easily.
const DPAD_DIAGONAL := 0.38

# DPAD_GRAB_PADDING: a touch lands on the pad if it is within DPAD_RADIUS + this many pixels
# of its centre.
# Higher: forgiving first touches. Lower: you must hit the drawn circle. (Keep it small
# enough not to steal touches meant for the buttons.)
const DPAD_GRAB_PADDING := 40.0

# DPAD_ACTIONS: which input action each direction presses (names registered in InputSetup).
# Change a value to rebind a direction; gameplay code only ever sees the actions.
const DPAD_ACTIONS := {
	"left": "move_left", "right": "move_right", "up": "move_up", "down": "move_down",
}

# DPAD_VECTORS: the unit vector of each direction, used only to place and point the arrows
# when drawing. Not used for input.
const DPAD_VECTORS := {
	"left": Vector2.LEFT, "right": Vector2.RIGHT, "up": Vector2.UP, "down": Vector2.DOWN,
}

# FACE BUTTONS (right): a diamond of circles around the cluster centre from layout().

# FACE_RADIUS: radius of each button in pixels (drawing and touch).
# Higher: bigger targets, but neighbouring buttons start to touch. Lower: smaller, harder
# to hit.
const FACE_RADIUS := 62.0

# FACE_SPREAD: distance from the cluster's centre to each button's centre, in pixels.
# Neighbouring buttons are FACE_SPREAD * sqrt(2) apart, so:
#     gap between two circles = FACE_SPREAD * sqrt(2) - 2 * FACE_RADIUS
# If that goes negative the buttons overlap (touches then go to the nearest centre, but they
# are easy to mis-hit). The cluster's outer reach is FACE_SPREAD + FACE_RADIUS.
const FACE_SPREAD := 98.0

# FACE_HIT_PADDING: a touch counts as on a button if it is within FACE_RADIUS + this many
# pixels of its centre; where two buttons qualify, the nearer centre wins.
# Higher: forgiving, but more mix-ups between neighbours. Lower: exact.
const FACE_HIT_PADDING := 12.0

# FACE_BUTTONS: the buttons, in order (tests refer to them by index). Each entry has:
#     action  the input action pressed while it is held (see InputSetup)
#     label   the text drawn on it
#     offset  where it sits around the cluster centre, as a direction that is multiplied by
#             FACE_SPREAD: (0, 1) is the bottom, (-1, 0) left, (1, 0) right, (0, -1) top
# To add a button add an entry with a free offset. To swap positions, swap offsets.
const FACE_BUTTONS := [
	{"action": "jump", "label": "JUMP", "offset": Vector2(0, 1)},
	{"action": "interact", "label": "USE", "offset": Vector2(-1, 0)},
	{"action": "attack_light", "label": "LIGHT", "offset": Vector2(1, 0)},
	{"action": "attack_heavy", "label": "HEAVY", "offset": Vector2(0, -1)},
]

# LOOK.

# ACCENT: the cyan used for the rings and the pressed glow (it matches the cyan edge-lights
# in the level). Each use sets its own alpha. Change the colour to restyle the controls.
const ACCENT := Color(0.23, 0.82, 1.0)

# IDLE_ALPHA: overall opacity multiplier while a control is NOT being touched. Every part
# (dark fill, ring, label, arrows) has its own base opacity and this multiplies all of them:
#     drawn alpha = base alpha * IDLE_ALPHA
# 0 = invisible (the controls still work), 1 = fully drawn. Kept low so they don't distract
# from the game; raise it if they are hard to see on a bright screen.
const IDLE_ALPHA := 0.3

# ACTIVE_ALPHA: the same multiplier while the control is pressed, so it lights up as
# feedback. Keep it clearly above IDLE_ALPHA, or you can't tell a press registered.
const ACTIVE_ALPHA := 0.85

# MOUSE_FINGER: the made-up finger id used for the mouse in the SABOTAGE_TOUCH=1 desktop
# debug mode (real fingers are numbered from zero upwards). It only needs to differ from
# those.
const MOUSE_FINGER := 99

var _dpad_center := Vector2.ZERO
var _face_centers: Array[Vector2] = []
var _dpad_finger := -1
var _dpad_on := {"left": false, "right": false, "up": false, "down": false}
var _face_held: Array[int] = []           # fingers currently on each face button
var _face_touches := {}                   # finger id -> face button index (-1 = none)
var _emulate_mouse := false
var _canvas: Control


## Phones show the overlay; PCs don't. SABOTAGE_TOUCH=1 forces it on for debugging.
static func should_show() -> bool:
	return OS.has_feature("mobile") or OS.get_environment("SABOTAGE_TOUCH") != ""


func _ready() -> void:
	layer = 10
	_emulate_mouse = not OS.has_feature("mobile") and OS.get_environment("SABOTAGE_TOUCH") != ""
	for i in FACE_BUTTONS.size():
		_face_centers.append(Vector2.ZERO)
		_face_held.append(0)
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_controls)
	add_child(_canvas)
	get_viewport().size_changed.connect(func() -> void: layout(get_viewport().get_visible_rect().size))
	layout(get_viewport().get_visible_rect().size)


func _exit_tree() -> void:
	_release_all()


func _notification(what: int) -> void:
	# Don't leave inputs "stuck" if the app loses focus mid-touch.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_release_all()


## Place the controls for a viewport of the given size (D-pad bottom-left, buttons bottom-right).
func layout(view: Vector2) -> void:
	_dpad_center = Vector2(MARGIN.x + DPAD_RADIUS, view.y - MARGIN.y - DPAD_RADIUS)
	var reach := FACE_SPREAD + FACE_RADIUS
	var cluster := Vector2(view.x - MARGIN.x - reach, view.y - MARGIN.y - reach)
	for i in FACE_BUTTONS.size():
		_face_centers[i] = cluster + (FACE_BUTTONS[i]["offset"] as Vector2) * FACE_SPREAD
	if _canvas:
		_canvas.queue_redraw()


## Centre of the D-pad (for tests and tooling).
func dpad_center() -> Vector2:
	return _dpad_center


## Centre of a face button, by index into FACE_BUTTONS (for tests and tooling).
func face_center(index: int) -> Vector2:
	return _face_centers[index]


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_down(event.index, event.position)
		else:
			_touch_up(event.index)
	elif event is InputEventScreenDrag:
		_touch_move(event.index, event.position)
	elif _emulate_mouse:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_touch_down(MOUSE_FINGER, event.position)
			else:
				_touch_up(MOUSE_FINGER)
		elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			_touch_move(MOUSE_FINGER, event.position)


func _touch_down(finger: int, pos: Vector2) -> void:
	# The D-pad takes one finger at a time and keeps it while it slides around.
	if _dpad_finger == -1 and pos.distance_to(_dpad_center) <= DPAD_RADIUS + DPAD_GRAB_PADDING:
		_dpad_finger = finger
		_update_dpad(pos)
		return
	var b := _face_at(pos)
	_face_touches[finger] = b
	_hold_face(b)


func _touch_move(finger: int, pos: Vector2) -> void:
	if finger == _dpad_finger:
		_update_dpad(pos)
		return
	var old: int = _face_touches.get(finger, -1)
	var b := _face_at(pos)
	if b == old:
		return
	_unhold_face(old)
	_face_touches[finger] = b
	_hold_face(b)


func _touch_up(finger: int) -> void:
	if finger == _dpad_finger:
		_dpad_finger = -1
		_set_dpad({"left": false, "right": false, "up": false, "down": false})
		return
	_unhold_face(_face_touches.get(finger, -1))
	_face_touches.erase(finger)


# ---------- D-pad ----------

## 8-way: the thumb's offset from the pad centre picks up to two directions (a diagonal is two).
func _update_dpad(pos: Vector2) -> void:
	var v := pos - _dpad_center
	var len := v.length()
	var on := {"left": false, "right": false, "up": false, "down": false}
	if len >= DPAD_RADIUS * DPAD_DEADZONE:
		on["left"] = v.x < 0.0 and absf(v.x) >= len * DPAD_DIAGONAL
		on["right"] = v.x > 0.0 and absf(v.x) >= len * DPAD_DIAGONAL
		on["up"] = v.y < 0.0 and absf(v.y) >= len * DPAD_DIAGONAL
		on["down"] = v.y > 0.0 and absf(v.y) >= len * DPAD_DIAGONAL
	_set_dpad(on)


func _set_dpad(on: Dictionary) -> void:
	for dir in on:
		if on[dir] != _dpad_on[dir]:
			_dpad_on[dir] = on[dir]
			if on[dir]:
				Input.action_press(DPAD_ACTIONS[dir])
			else:
				Input.action_release(DPAD_ACTIONS[dir])
	if _canvas:
		_canvas.queue_redraw()


# ---------- face buttons ----------

## Face button under a point, with forgiving edges. Where padded areas overlap, the nearest wins.
func _face_at(pos: Vector2) -> int:
	var best := -1
	var best_dist := INF
	for i in _face_centers.size():
		var d := pos.distance_to(_face_centers[i])
		if d <= FACE_RADIUS + FACE_HIT_PADDING and d < best_dist:
			best = i
			best_dist = d
	return best


func _hold_face(b: int) -> void:
	if b < 0:
		return
	_face_held[b] += 1
	if _face_held[b] == 1:
		Input.action_press(FACE_BUTTONS[b]["action"])
		_canvas.queue_redraw()


func _unhold_face(b: int) -> void:
	if b < 0:
		return
	_face_held[b] = maxi(0, _face_held[b] - 1)
	if _face_held[b] == 0:
		Input.action_release(FACE_BUTTONS[b]["action"])
		_canvas.queue_redraw()


func _release_all() -> void:
	_face_touches.clear()
	_dpad_finger = -1
	for dir in _dpad_on:
		if _dpad_on[dir]:
			_dpad_on[dir] = false
			Input.action_release(DPAD_ACTIONS[dir])
	for b in _face_held.size():
		if _face_held[b] > 0:
			_face_held[b] = 0
			Input.action_release(FACE_BUTTONS[b]["action"])


# ---------- drawing ----------

func _draw_controls() -> void:
	_draw_dpad()
	for i in FACE_BUTTONS.size():
		_draw_face_button(i)


func _draw_dpad() -> void:
	var c := _dpad_center
	var r := DPAD_RADIUS
	var k := ACTIVE_ALPHA if _dpad_finger != -1 else IDLE_ALPHA
	_canvas.draw_circle(c, r, Color(0.04, 0.07, 0.13, 0.5 * k))
	_canvas.draw_arc(c, r - 2.0, 0.0, TAU, 64, Color(ACCENT, 0.9 * k), 3.0, true)
	_canvas.draw_circle(c, r * 0.2, Color(1, 1, 1, 0.25 * k))
	for dir in DPAD_VECTORS:
		var dv: Vector2 = DPAD_VECTORS[dir]
		var perp := Vector2(-dv.y, dv.x)
		var tip := c + dv * (r * 0.8)
		var base := c + dv * (r * 0.42)
		var half := r * 0.2
		var active: bool = _dpad_on[dir]
		_canvas.draw_colored_polygon(
			PackedVector2Array([tip, base + perp * half, base - perp * half]),
			Color(1, 1, 1, 0.95 * ACTIVE_ALPHA if active else 0.9 * k))
		if active:
			_canvas.draw_circle(c + dv * (r * 0.58), r * 0.34, Color(ACCENT, 0.28 * ACTIVE_ALPHA))


func _draw_face_button(i: int) -> void:
	var c := _face_centers[i]
	var k := ACTIVE_ALPHA if _face_held[i] > 0 else IDLE_ALPHA
	_canvas.draw_circle(c, FACE_RADIUS, Color(0.04, 0.07, 0.13, 0.5 * k))
	_canvas.draw_circle(c, FACE_RADIUS - 8.0, Color(1, 1, 1, 0.2 * k))
	_canvas.draw_arc(c, FACE_RADIUS - 2.0, 0.0, TAU, 48, Color(ACCENT, 0.9 * k), 3.0, true)
	var font := ThemeDB.fallback_font
	var size := 24
	_canvas.draw_string(font, Vector2(c.x - FACE_RADIUS, c.y + size * 0.35), FACE_BUTTONS[i]["label"],
		HORIZONTAL_ALIGNMENT_CENTER, FACE_RADIUS * 2.0, size, Color(1, 1, 1, 0.9 * k))
