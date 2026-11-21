class_name RingLockGame
extends Minigame
## "Rotating lock": a ring turns with a green arc on it, and a white marker waits still at the top, outside the ring. Press LOCK
## when the arc is under the marker. Each hit makes the arc smaller and the ring faster, and turns it the other way. A miss starts over.
## SafeCrackerGame is the same idea with several rings inside each other that are locked one after another.

# HITS_NEEDED: how many hits in a row open the lock. Higher: longer.
const HITS_NEEDED := 3

# TURN_TIME: seconds one full turn of the ring takes at first. Higher: slower and easier. Lower: harder.
const TURN_TIME := 3.0

# ARC_START: the width in degrees of the green arc at first. Higher: easier. Lower: needs sharper timing.
const ARC_START := 80.0

# ARC_SHRINK / SPEED_UP: after each hit the arc's width is multiplied by ARC_SHRINK (below 1) and the ring's speed by SPEED_UP (above 1).
const ARC_SHRINK := 0.75
const SPEED_UP := 1.2

# CANVAS_SIZE: the size in pixels of the square the ring is drawn in. RING_RADIUS / RING_WIDTH: the ring's size (one ring).
const CANVAS_SIZE := Vector2(300, 300)
const RING_RADIUS := 100.0
const RING_WIDTH := 34.0

# MARKER_ANGLE: where the still marker waits, in radians (straight up).
const MARKER_ANGLE := -PI / 2.0

const TRACK := Color(0.12, 0.14, 0.2)
const ARC := Color(0.2, 0.75, 0.35)
const ARC_LOCKED := Color(0.15, 0.5, 0.3)

var _canvas: Control
var _rings: Array[Dictionary] = []     # {"radius", "angle", "width" (radians), "speed" (radians/s, signed), "locked"}
var _stage := 0                        # the ring being aimed at (safe cracker), or the number of hits (one ring)
var _concentric := false               # false: one ring, new arcs after each hit. true: several rings locked one by one.


func _init() -> void:
	instructions = "Press LOCK when the green arc is under the marker."


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 40)
	add_child(row)
	_canvas = Control.new()
	_canvas.custom_minimum_size = CANVAS_SIZE
	_canvas.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_canvas.draw.connect(_draw_canvas)
	row.add_child(_canvas)
	var side := VBoxContainer.new()
	side.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	side.add_theme_constant_override("separation", 24)
	row.add_child(side)
	_status = _make_label("", 36)
	_status.custom_minimum_size = Vector2(300, 0)
	side.add_child(_status)
	var lock := _make_button("LOCK", Color(0.2, 0.55, 0.9))
	lock.custom_minimum_size = Vector2(300, 130)
	lock.pressed.connect(press)
	side.add_child(lock)
	begin()


func begin() -> void:
	_stage = 0
	_rings.clear()
	_make_rings()
	_update_status()


## The rings at the start (one ring here; SafeCrackerGame makes several).
func _make_rings() -> void:
	_rings.append(_new_ring(RING_RADIUS, 1.0, deg_to_rad(float(_p("arc_start", ARC_START))), TAU / float(_p("turn_time", TURN_TIME))))


func _new_ring(radius: float, direction: float, width: float, speed: float) -> Dictionary:
	# start with the arc well away from the marker so the player has to wait for it
	var start := MARKER_ANGLE + randf_range(1.2, TAU - 1.2)
	return {"radius": radius, "angle": start, "width": width, "speed": speed * direction, "locked": false}


func _needed() -> int:
	return int(_p("hits_needed", HITS_NEEDED))


func _update_status() -> void:
	_status.text = "ALIGN  %d / %d" % [_stage, _needed()]


func _process(delta: float) -> void:
	if _over:
		return
	for ring in _rings:
		if not ring["locked"]:
			ring["angle"] = wrapf(float(ring["angle"]) + float(ring["speed"]) * delta, -PI, PI)
	_canvas.queue_redraw()


func _draw_canvas() -> void:
	var c := CANVAS_SIZE / 2.0
	var outer := 0.0
	for ring in _rings:
		var r: float = ring["radius"]
		outer = maxf(outer, r)
		_canvas.draw_arc(c, r, 0.0, TAU, 72, TRACK, _ring_width())
		var half: float = float(ring["width"]) / 2.0
		var a: float = ring["angle"]
		_canvas.draw_arc(c, r, a - half, a + half, 32, ARC_LOCKED if ring["locked"] else ARC, _ring_width())
	# the still marker: a white arrow just outside the outermost ring, pointing at it
	var tip := c + Vector2.from_angle(MARKER_ANGLE) * (outer + _ring_width() / 2.0 + 2.0)
	_canvas.draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-14, -22), tip + Vector2(14, -22)]), Color.WHITE)


func _ring_width() -> float:
	return RING_WIDTH if not _concentric else 26.0


## True if the arc of `ring` is under the marker.
func _under_marker(ring: Dictionary) -> bool:
	return absf(angle_difference(float(ring["angle"]), MARKER_ANGLE)) <= float(ring["width"]) / 2.0


## The LOCK button (also callable from tests).
func press() -> void:
	if _over:
		return
	var ring: Dictionary = _rings[_stage if _concentric else 0]
	if not _under_marker(ring):
		_lose("MISSED - RETRY")
		return
	_stage += 1
	if _concentric:
		ring["locked"] = true
	if _stage >= _needed():
		_update_status()
		_win()
		return
	if not _concentric:
		var next_speed: float = absf(float(ring["speed"])) * float(_p("speed_up", SPEED_UP))
		var direction: float = -signf(float(ring["speed"]))
		_rings[0] = _new_ring(RING_RADIUS, direction, float(ring["width"]) * float(_p("arc_shrink", ARC_SHRINK)), next_speed)
	_update_status()


## For tests: put the arc being aimed at under the marker.
func aim() -> void:
	_rings[_stage if _concentric else 0]["angle"] = MARKER_ANGLE


func auto_solve() -> void:
	for i in _needed():
		while _over:
			await _wait_frames(1)
		aim()
		press()
		await _wait_frames(1)


func auto_fail() -> void:
	while _over:
		await _wait_frames(1)
	_rings[_stage if _concentric else 0]["angle"] = MARKER_ANGLE + PI
	press()
