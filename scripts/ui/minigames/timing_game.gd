class_name TimingGame
extends Minigame
## "Calibrate" puzzle: a marker sweeps back and forth across a bar; press LOCK while it is inside
## the green zone. Each hit makes the zone narrower. A miss starts over.

# HITS_NEEDED: how many hits in a row unlock the terminal. Higher: longer. Lower: quicker.
const HITS_NEEDED := 3

# SWEEP_SPEED: how fast the marker crosses the bar, in bar-widths per second.
# Higher: harder timing. Lower: easier.
const SWEEP_SPEED := 0.9

# ZONE_START: the width of the green zone on the first hit, as a fraction of the bar.
# Higher: easier. Lower: needs sharper timing.
const ZONE_START := 0.28

# ZONE_SHRINK: the zone's width is multiplied by this after each hit (below 1).
# Lower: the last hits get much harder.
const ZONE_SHRINK := 0.7

const BAR_SIZE := Vector2(720, 70)

var _track: Control
var _marker := 0.0       # 0..1 position along the bar
var _dir := 1.0
var _zone_start := 0.0   # left edge of the green zone, 0..1
var _zone_width := ZONE_START
var _hits := 0
var _running := false


func _init() -> void:
	instructions = "Press LOCK when the marker is in the green zone."


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 24)
	add_child(box)
	_status = _make_label("", 36)
	box.add_child(_status)
	_track = Control.new()
	_track.custom_minimum_size = BAR_SIZE
	_track.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_track.draw.connect(_draw_bar)
	box.add_child(_track)
	var lock := _make_button("LOCK", Color(0.2, 0.55, 0.9))
	lock.custom_minimum_size = Vector2(260, 130)
	lock.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	lock.pressed.connect(press)
	box.add_child(lock)
	begin()


func begin() -> void:
	_hits = 0
	_zone_width = ZONE_START
	_marker = 0.0
	_dir = 1.0
	_new_zone()
	_running = true
	_update_status()


func _new_zone() -> void:
	_zone_start = randf_range(0.1, 0.9 - _zone_width)


func _update_status() -> void:
	_status.text = "ALIGN  %d / %d" % [_hits, HITS_NEEDED]


func _process(delta: float) -> void:
	if not _running:
		return
	_marker += _dir * SWEEP_SPEED * delta
	if _marker >= 1.0:
		_marker = 1.0
		_dir = -1.0
	elif _marker <= 0.0:
		_marker = 0.0
		_dir = 1.0
	_track.queue_redraw()


func _draw_bar() -> void:
	var s := BAR_SIZE
	_track.draw_rect(Rect2(Vector2.ZERO, s), Color(0.12, 0.14, 0.2))
	_track.draw_rect(Rect2(_zone_start * s.x, 0, _zone_width * s.x, s.y), Color(0.2, 0.75, 0.35))
	_track.draw_rect(Rect2(_marker * s.x - 6, -8, 12, s.y + 16), Color(1, 1, 1))


## The LOCK button (also callable from tests).
func press() -> void:
	if not _running:
		return
	if _marker >= _zone_start and _marker <= _zone_start + _zone_width:
		_hits += 1
		if _hits >= HITS_NEEDED:
			_running = false
			_status.text = "ACCESS GRANTED"
			solved.emit()
			return
		_zone_width *= ZONE_SHRINK
		_new_zone()
		_update_status()
	else:
		_running = false
		_status.text = "MISSED - RETRY"
		await get_tree().create_timer(0.8, true, false, true).timeout
		begin()


## For tests: put the marker in the middle of the green zone.
func aim() -> void:
	_marker = _zone_start + _zone_width / 2.0


func auto_solve() -> void:
	for i in HITS_NEEDED:
		while not _running:
			await _wait_frames(1)
		aim()
		press()
		await _wait_frames(1)


func auto_fail() -> void:
	while not _running:
		await _wait_frames(1)
	_marker = 0.0 if _zone_start > 0.3 else 1.0
	press()
