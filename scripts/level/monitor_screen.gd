class_name MonitorScreen
extends Control
## One live screen on a machine, drawn every frame so it is always "doing something". The
## monitoring station has three, placed over its blank monitors by Level:
##   GRAPH     a caption and a scrolling line that wanders at random
##   TERMINAL  an "AI job": a funny status message above a progress bar that runs 0 to 100. When it
##             finishes, the same slot shows "Generated AI slop poster!" and then its costs, one at
##             a time, and the job starts over.
##   SCOPE     a made-up tokens-per-second number and an orange wave that drifts and changes shape
##   BARS      a row of bars (an equaliser) that rise and fall at random, on the supercomputer's status display
##   LOCK      the screen of a gate computer: a red padlock and "ACCESS RESTRICTED" while its laser gate
##             is on, a green open padlock and "ACCESS GRANTED" once it is off (see set_locked)
## Nothing here is a real measurement: it is all random, on purpose. The screens are tiny, so they are
## kept minimal and large: everything sits inside a margin, nothing overlaps, and any text that would
## not fit is shrunk until it does (see fitted_font_size).

enum Kind { GRAPH, TERMINAL, SCOPE, LOCK, BARS }
enum Job { LOADING, STALLED, DONE }

# ---------------------------------------------------------------------------------------------
# LOOK
# ---------------------------------------------------------------------------------------------

# BG: the screen background. It matches the blank screen painted into the machine image.
const BG := Color(0.03, 0.06, 0.12)

# CYAN: the graph line and the progress bar. ORANGE: the oscilloscope. GREEN: the finished state.
# These match the lights elsewhere in the level.
const CYAN := Color(0.23, 0.82, 1.0)
const ORANGE := Color(0.94, 0.54, 0.14)
const GREEN := Color(0.18, 0.9, 0.42)

# RED: the locked state of a gate computer's screen (GREEN is its unlocked state).
const RED := Color(1.0, 0.25, 0.25)

# LOCK_PULSE_SPEED: radians per second of the slow throb of the locked screen's red glow.
# Higher: a nervous flicker. Lower: a calm one.
const LOCK_PULSE_SPEED := 3.0

# LOCKED_TEXT / UNLOCKED_TEXT: the two lines under the padlock. Keep them short; they are shrunk to fit.
const LOCKED_TEXT := "ACCESS\nRESTRICTED"
const UNLOCKED_TEXT := "ACCESS\nGRANTED"

# TEXT: main text colour. DIM: captions (low contrast on purpose, so they stay in the background).
const TEXT := Color(0.85, 0.92, 1.0)
const DIM := Color(0.4, 0.5, 0.65)

# FONT_BODY: height in pixels of the main text (the terminal's message). FONT_SMALL: height of the
# captions and the percentage. Bigger is easier to read from across the room, but the strings must be
# short enough to fit (the tests check this). Text that still does not fit its area at these sizes is
# made smaller automatically, but not below MIN_FONT_SIZE.
const FONT_BODY := 8
const FONT_SMALL := 8

# MIN_FONT_SIZE: the smallest text height the fitting is allowed to shrink to. Below this it would be
# unreadable, so instead shorten the string.
const MIN_FONT_SIZE := 8

# PADDING: empty margin in pixels between the edge of every screen and its content, so nothing
# touches the bezel. Higher: more breathing room, less space for content.
const PADDING := 3.0

# LINE_GAP: extra pixels between two lines of text (the pixel font is drawn on its own 8 px grid, so lines need air to stay apart). Higher: looser lines.
const LINE_GAP := 2.0

# BLOCK_GAP: vertical space in pixels left between stacked pieces (caption and plot).
const BLOCK_GAP := 2.0

# ---------------------------------------------------------------------------------------------
# GRAPH SCREEN
# ---------------------------------------------------------------------------------------------

# GRAPH_STEP_TIME: seconds between new graph samples. Each sample is one pixel, so the line scrolls
# left at 1 / GRAPH_STEP_TIME pixels per second. Smaller: faster scrolling.
const GRAPH_STEP_TIME := 0.07

# GRAPH_DRIFT: the most a new sample can differ from the previous one, as a fraction of the graph
# height (a random walk). Higher: jagged and busy. Lower: smooth and lazy.
const GRAPH_DRIFT := 0.16

# GRAPH_SPIKE_CHANCE: probability, per sample, that the line jumps to a completely random height
# instead of drifting. Higher: more dramatic spikes. 0: no spikes.
const GRAPH_SPIKE_CHANCE := 0.06

# GRAPH_CAPTIONS: the little captions shown above the graph, one at a time. Each must fit on one
# line of the screen (a short caption is fine; a long one is shrunk).
const GRAPH_CAPTIONS: Array[String] = [
	"GPU 100%", "TEMP 9001", "VRAM yes", "FANS ok", "LOAD ALL", "NaN NaN",
]

# CAPTION_TIME: seconds each graph caption stays before the next one.
const CAPTION_TIME := 2.6

# ---------------------------------------------------------------------------------------------
# BARS SCREEN
# ---------------------------------------------------------------------------------------------

# BAR_PITCH / BAR_WIDTH: the distance (px) from one bar to the next and the width of a bar. BAR_MARGIN: free space (px) at the left of the first bar and above the tallest.
# BAR_FLOOR: the space (px) between the bars' base and the screen's bottom edge. More bars fit when the pitch is smaller.
const BAR_PITCH := 6.8
const BAR_WIDTH := 4.6
const BAR_MARGIN := 3.5
const BAR_FLOOR := 2.5

# BAR_MIN_LEVEL: the lowest a bar falls (0 to 1 of the full height); no bar disappears. BAR_PEAK: above this level a bar gets an orange cap of BAR_CAP px.
const BAR_MIN_LEVEL := 0.15
const BAR_PEAK := 0.82
const BAR_CAP := 2.4

# BAR_SMOOTHING: how fast a bar moves to its new level (per second; higher: snappier). BAR_RETARGET_MIN / BAR_RETARGET_MAX: the seconds a bar keeps its target before picking
# another at random (each bar has its own timing, so the row never moves in step).
const BAR_SMOOTHING := 9.0
const BAR_RETARGET_MIN := 0.12
const BAR_RETARGET_MAX := 0.6

# BAR_LOW / BAR_HIGH: the colours of a short and of a tall bar (a bar's colour is between them by its height).
const BAR_LOW := Color(0.094, 0.43, 0.59)
const BAR_HIGH := Color(0.23, 0.82, 1.0)

# ---------------------------------------------------------------------------------------------
# OSCILLOSCOPE SCREEN
# ---------------------------------------------------------------------------------------------

# SCOPE_PHASE_SPEED: how fast the wave slides sideways, in radians per second. Higher: a faster
# scrolling wave.
const SCOPE_PHASE_SPEED := 6.0

# SCOPE_RETARGET_TIME: seconds between picking a new random frequency and height for the wave. The
# wave glides to them (see SCOPE_SMOOTHING), so this sets how often its shape changes.
const SCOPE_RETARGET_TIME := 1.3

# SCOPE_SMOOTHING: how quickly the wave glides to its new frequency and height, per second.
# Higher: abrupt changes. Lower: slow, flowing changes.
const SCOPE_SMOOTHING := 2.5

# TOK_TIME: seconds between changes of the made-up tokens-per-second number. Lower: a blurrier,
# faster-flickering number.
const TOK_TIME := 0.18

# ---------------------------------------------------------------------------------------------
# TERMINAL SCREEN: THE AI JOB
# ---------------------------------------------------------------------------------------------

# JOB_SPEED_MIN, JOB_SPEED_MAX: the progress bar's speed in percent per second. It picks a new
# random speed in this range every JOB_SPEED_RETARGET seconds, so the bar lurches, crawls and
# bursts like a real (bad) loading bar. Average run time is about 100 / the mean speed.
const JOB_SPEED_MIN := 5.0
const JOB_SPEED_MAX := 24.0

# JOB_SPEED_RETARGET: seconds between picking a new speed for the bar. Lower: more erratic.
const JOB_SPEED_RETARGET := 0.55

# JOB_STALL_AT: the percentage where the bar always stalls (the classic "stuck at 99%"), and
# JOB_STALL_TIME: how many seconds it stays stuck there before jumping to the end.
const JOB_STALL_AT := 99.0
const JOB_STALL_TIME := 1.6

# QUIP_TIME: seconds each funny status message is shown while loading.
const QUIP_TIME := 1.5

# RESULT_PAGE_TIME: seconds each message is shown once the job is finished (first the headline, then
# each of STATS). When the last has been shown, the job starts over.
const RESULT_PAGE_TIME := 1.9

# STATUS_LINES: how many lines of text the terminal's message slot holds. The progress bar sits below it,
# so a larger value takes room from the free space between them. Each message must fit in this many lines.
const STATUS_LINES := 3

# BAR_H: height of the progress bar in pixels. The percentage is drawn right aligned just above it.
const BAR_H := 14.0

# DONE_TEXT: the headline shown first when the job is finished. A newline starts a new line; each line must
# be short enough for the screen width, and there can be at most STATUS_LINES lines.
const DONE_TEXT := "Generated\nAI slop\nposter!"

# STALL_TEXT: the message while the bar is stuck at JOB_STALL_AT.
const STALL_TEXT := "Still\n99%..."

# QUIPS: funny status messages shown while loading, one at a time and at random. The first is always
# shown first. Keep them short: each must fit the message slot (at most STATUS_LINES lines, each short
# enough for the screen width; use a newline to choose where it breaks).
const QUIPS: Array[String] = [
	"Loading...",
	"Reading\nthe web...",
	"Stealing\nart...",
	"Heating\nGPUs...",
	"Drinking\na lake...",
	"Adding\nfingers...",
	"Making\nstuff up...",
	"Firing a\nhuman...",
	"Thinking\nhard...",
	"Boiling\nan ocean...",
	"Blaming\nthe\nintern...",
	"Generating\nvibes...",
]

# STATS: the results shown one at a time, after DONE_TEXT, once the job is finished. Same format as
# the quips: short lines, at most STATUS_LINES of them.
const STATS: Array[String] = [
	"Water:\n69,000\ngallons",
	"Power:\n420 MWh",
	"Artists\nfired: 12",
	"Fingers:\n11/hand",
	"Quality:\njust slop",
]

var kind := Kind.GRAPH
## LOCK screens only: true while the gate is on (red), false once it has been switched off (green).
var locked := true

var _rng := RandomNumberGenerator.new()
var _font: Font
var _t := 0.0

# graph
var _samples := PackedFloat32Array()
var _graph_value := 0.5
var _graph_timer := 0.0
var _caption := 0
var _caption_timer := 0.0

# oscilloscope
var _phase := 0.0
var _freq := 0.25
var _freq_target := 0.25
var _amp := 0.6
var _amp_target := 0.6
var _scope_timer := 0.0
var _tok := 12000
var _tok_timer := 0.0
var _bar_levels := PackedFloat32Array()
var _bar_targets := PackedFloat32Array()
var _bar_timers := PackedFloat32Array()

# terminal
var _job := Job.LOADING
var _progress := 0.0
var _speed := 10.0
var _speed_timer := 0.0
var _stall_timer := 0.0
var _quip := 0
var _quip_timer := 0.0
var _page := 0
var _page_timer := 0.0


## Prepare a screen of the given kind and size. `seed_value` makes each screen behave differently.
func setup(screen_kind: Kind, screen_size: Vector2, seed_value: int) -> void:
	kind = screen_kind
	size = screen_size
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font
	_rng.seed = seed_value
	match kind:
		Kind.GRAPH:
			_samples.resize(maxi(2, int(size.x - 2.0 * PADDING)))
			_samples.fill(0.5)
		Kind.TERMINAL:
			_restart_job()
		Kind.BARS:
			_setup_bars()


## Show a gate computer's screen as locked (red) or unlocked (green).
func set_locked(value: bool) -> void:
	locked = value


# ---------- state that tests (and the drawing code) read ----------

## The text under the padlock on a LOCK screen.
func lock_text() -> String:
	return LOCKED_TEXT if locked else UNLOCKED_TEXT


## Which part of the job the terminal is in (LOADING, STALLED or DONE).
func job_state() -> Job:
	return _job


## Terminal progress, 0 to 100.
func progress() -> float:
	return _progress


## The terminal's message: a quip while loading, the stall message, then the finished headline and
## each result in turn.
func status_text() -> String:
	match _job:
		Job.DONE:
			return DONE_TEXT if _page == 0 else STATS[_page - 1]
		Job.STALLED:
			return STALL_TEXT
	return QUIPS[_quip]


## The caption shown above the graph or the oscilloscope (empty for the terminal).
func caption_text() -> String:
	match kind:
		Kind.GRAPH:
			return GRAPH_CAPTIONS[_caption]
		Kind.SCOPE:
			return "%dt/s" % _tok
	return ""


## The graph's current samples (0 to 1), oldest first.
func graph_samples() -> PackedFloat32Array:
	return _samples


## The oscilloscope's current phase, in radians; it keeps growing while the wave scrolls.
func scope_phase() -> float:
	return _phase


## The rectangles content is drawn in, in this screen's own coordinates. Every one is inside the
## padding, and none overlap. Graph and oscilloscope: "caption" and "plot". Terminal: "status" (the
## message slot, STATUS_LINES lines) and "bar".
func layout_rects() -> Dictionary:
	var inner := Rect2(PADDING, PADDING, size.x - 2.0 * PADDING, size.y - 2.0 * PADDING)
	if kind == Kind.LOCK:
		var label_h := _line_height(FONT_BODY) * 2.0
		return {
			"icon": Rect2(inner.position, Vector2(inner.size.x, inner.size.y - label_h - BLOCK_GAP)),
			"label": Rect2(inner.position.x, inner.end.y - label_h, inner.size.x, label_h),
		}
	if kind == Kind.TERMINAL:
		var status_h := _line_height(FONT_BODY) * STATUS_LINES
		return {
			"status": Rect2(inner.position, Vector2(inner.size.x, status_h)),
			"bar": Rect2(inner.position.x, inner.end.y - BAR_H, inner.size.x, BAR_H),
		}
	var caption := Rect2(inner.position, Vector2(inner.size.x, _font.get_height(FONT_SMALL)))
	var plot_top := caption.end.y + BLOCK_GAP
	return {
		"caption": caption,
		"plot": Rect2(inner.position.x, plot_top, inner.size.x, inner.end.y - plot_top),
	}


## The largest text height, no bigger than `wanted`, at which `text` fits inside width x max_height
## (wrapping onto as many lines as it needs). Never goes below MIN_FONT_SIZE. This is what keeps
## text from spilling out of a screen.
func fitted_font_size(text: String, wanted: int, width: float, max_height: float) -> int:
	var s := wanted
	while s > MIN_FONT_SIZE and not _fits(text, s, width, max_height):
		s -= 1
	return s


## The height of one line of text at size `s`, with the gap between lines.
func _line_height(s: int) -> float:
	return _font.get_height(s) + LINE_GAP


## True if every line of `text` (lines are only broken where the text has a newline) is at most `width` wide and all of them are at most `max_height` tall.
func _fits(text: String, s: int, width: float, max_height: float) -> bool:
	var lines := text.split("\n")
	for line in lines:
		if _font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, s).x > width + 0.01:
			return false
	return _line_height(s) * lines.size() - LINE_GAP <= max_height + 0.01


## Draw `text` line by line in `area` (top first), each line left aligned or centred, with LINE_GAP between lines.
func _draw_lines(area: Rect2, text: String, s: int, color: Color, align: HorizontalAlignment) -> void:
	var y := area.position.y + _font.get_ascent(s)
	for line in text.split("\n"):
		draw_string(_font, Vector2(area.position.x, y), line, align, area.size.x, s, color)
		y += _line_height(s)


# ---------- animation ----------

func _process(delta: float) -> void:
	_t += delta
	match kind:
		Kind.GRAPH:
			_update_graph(delta)
		Kind.SCOPE:
			_update_scope(delta)
		Kind.BARS:
			_update_bars(delta)
		Kind.TERMINAL:
			_update_terminal(delta)
	queue_redraw()


## How many bars fit across the screen.
func bar_count() -> int:
	return maxi(1, int((size.x - 2.0 * BAR_MARGIN + (BAR_PITCH - BAR_WIDTH)) / BAR_PITCH))


## The current height of every bar, 0 to 1 of the full height (the row's left to right).
func bar_levels() -> PackedFloat32Array:
	return _bar_levels


func _setup_bars() -> void:
	var n := bar_count()
	_bar_levels.resize(n)
	_bar_targets.resize(n)
	_bar_timers.resize(n)
	for i in n:
		_bar_levels[i] = _rng.randf_range(BAR_MIN_LEVEL, 1.0)
		_bar_targets[i] = _bar_levels[i]
		_bar_timers[i] = _rng.randf_range(0.0, BAR_RETARGET_MAX)


## Each bar glides to its own random target and picks a new one after its own random time.
func _update_bars(delta: float) -> void:
	var glide := 1.0 - exp(-BAR_SMOOTHING * delta)
	for i in _bar_levels.size():
		_bar_timers[i] -= delta
		if _bar_timers[i] <= 0.0:
			_bar_timers[i] = _rng.randf_range(BAR_RETARGET_MIN, BAR_RETARGET_MAX)
			_bar_targets[i] = _rng.randf_range(BAR_MIN_LEVEL, 1.0)
		_bar_levels[i] = lerpf(_bar_levels[i], _bar_targets[i], glide)


func _update_graph(delta: float) -> void:
	_graph_timer += delta
	while _graph_timer >= GRAPH_STEP_TIME:
		_graph_timer -= GRAPH_STEP_TIME
		if _rng.randf() < GRAPH_SPIKE_CHANCE:
			_graph_value = _rng.randf_range(0.1, 0.95)
		else:
			_graph_value = clampf(_graph_value + _rng.randf_range(-GRAPH_DRIFT, GRAPH_DRIFT), 0.05, 0.95)
		_samples.remove_at(0)
		_samples.append(_graph_value)
	_caption_timer += delta
	if _caption_timer >= CAPTION_TIME:
		_caption_timer = 0.0
		_caption = (_caption + 1 + _rng.randi() % (GRAPH_CAPTIONS.size() - 1)) % GRAPH_CAPTIONS.size()


func _update_scope(delta: float) -> void:
	_phase += SCOPE_PHASE_SPEED * delta
	_scope_timer -= delta
	if _scope_timer <= 0.0:
		_scope_timer = SCOPE_RETARGET_TIME
		_freq_target = _rng.randf_range(0.12, 0.45)
		_amp_target = _rng.randf_range(0.25, 1.0)
	var glide := 1.0 - exp(-SCOPE_SMOOTHING * delta)
	_freq = lerpf(_freq, _freq_target, glide)
	_amp = lerpf(_amp, _amp_target, glide)
	_tok_timer -= delta
	if _tok_timer <= 0.0:
		_tok_timer = TOK_TIME
		_tok = _rng.randi_range(8000, 16999)


func _update_terminal(delta: float) -> void:
	match _job:
		Job.LOADING:
			_speed_timer -= delta
			if _speed_timer <= 0.0:
				_speed_timer = JOB_SPEED_RETARGET
				_speed = _rng.randf_range(JOB_SPEED_MIN, JOB_SPEED_MAX)
			_progress = minf(_progress + _speed * delta, JOB_STALL_AT)
			_quip_timer += delta
			if _quip_timer >= QUIP_TIME:
				_quip_timer = 0.0
				_next_quip()
			if _progress >= JOB_STALL_AT:
				_job = Job.STALLED
				_stall_timer = JOB_STALL_TIME
		Job.STALLED:
			_stall_timer -= delta
			if _stall_timer <= 0.0:
				_progress = 100.0
				_job = Job.DONE
				_page = 0
				_page_timer = 0.0
		Job.DONE:
			_page_timer += delta
			if _page_timer >= RESULT_PAGE_TIME:
				_page_timer = 0.0
				_page += 1
				if _page > STATS.size():
					_restart_job()


func _restart_job() -> void:
	_job = Job.LOADING
	_progress = 0.0
	_speed_timer = 0.0
	_quip = 0
	_quip_timer = 0.0


## A different quip from the current one (never the first, which is only for the start).
func _next_quip() -> void:
	var next := 1 + _rng.randi() % (QUIPS.size() - 1)
	if next == _quip:
		next = 1 + (next % (QUIPS.size() - 1))
	_quip = next


# ---------- drawing ----------

func _draw() -> void:
	if kind != Kind.BARS:      # (the bars are drawn straight onto the machine's own dark display and grid lines)
		draw_rect(Rect2(Vector2.ZERO, size), BG)
	var rects := layout_rects()
	match kind:
		Kind.GRAPH:
			_draw_graph(rects)
		Kind.SCOPE:
			_draw_scope(rects)
		Kind.TERMINAL:
			_draw_terminal(rects)
		Kind.LOCK:
			_draw_lock(rects)
		Kind.BARS:
			_draw_bars()


## Draw text inside `area`, top-left aligned, shrunk if needed so it never leaves the area.
func _text_in(area: Rect2, text: String, wanted: int, color: Color) -> void:
	_draw_lines(area, text, fitted_font_size(text, wanted, area.size.x, area.size.y), color, HORIZONTAL_ALIGNMENT_LEFT)


func _draw_graph(rects: Dictionary) -> void:
	_text_in(rects["caption"], caption_text(), FONT_SMALL, DIM)
	var plot: Rect2 = rects["plot"]
	var points := PackedVector2Array()
	var last := float(_samples.size() - 1)
	for i in _samples.size():
		points.append(Vector2(plot.position.x + plot.size.x * i / last, plot.end.y - _samples[i] * plot.size.y))
	draw_polyline(points, CYAN, 1.5)


func _draw_scope(rects: Dictionary) -> void:
	_text_in(rects["caption"], caption_text(), FONT_SMALL, ORANGE)
	var plot: Rect2 = rects["plot"]
	var mid := plot.position.y + plot.size.y / 2.0
	var half := plot.size.y / 2.0 - 1.0   # leave room for the line's own thickness
	var points := PackedVector2Array()
	for x in range(0, int(plot.size.x) + 1):
		var envelope := 0.65 + 0.35 * sin(x * 0.09 + _t * 1.7)
		var wobble := 0.05 * sin(x * 7.3 + _t * 40.0)   # a little jitter so it looks "live"
		var v := clampf(sin(x * _freq + _phase) * _amp * envelope + wobble, -0.95, 0.95)
		points.append(Vector2(plot.position.x + x, mid - v * half))
	draw_polyline(points, ORANGE, 1.5)


func _draw_terminal(rects: Dictionary) -> void:
	var done := _job == Job.DONE
	_text_in(rects["status"], status_text(), FONT_BODY, GREEN if done else TEXT)
	var bar: Rect2 = rects["bar"]
	draw_rect(bar, Color(0.08, 0.13, 0.22))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * _progress / 100.0, bar.size.y)), GREEN if done else CYAN)
	draw_rect(bar, Color(DIM, 0.8), false, 1.0)
	# the percentage, right aligned just above the bar (on the dark background it stays readable at every fill level)
	var label := "%d%%" % int(_progress)
	var baseline := bar.position.y - BLOCK_GAP
	draw_string(_font, Vector2(bar.position.x, baseline), label, HORIZONTAL_ALIGNMENT_RIGHT, bar.size.x, FONT_SMALL, GREEN if done else CYAN)


func _draw_bars() -> void:
	var base := size.y - BAR_FLOOR
	var full := base - BAR_MARGIN
	for i in _bar_levels.size():
		var level := _bar_levels[i]
		var x := BAR_MARGIN + i * BAR_PITCH
		var top := base - full * level
		draw_rect(Rect2(x, top, BAR_WIDTH, base - top), BAR_LOW.lerp(BAR_HIGH, level))
		if level > BAR_PEAK:
			draw_rect(Rect2(x, top, BAR_WIDTH, BAR_CAP), Color(ORANGE))


func _draw_lock(rects: Dictionary) -> void:
	var color := RED if locked else GREEN
	# A background wash: throbbing red while locked, steady dim green when open.
	var wash := 0.12 + 0.08 * sin(_t * LOCK_PULSE_SPEED) if locked else 0.1
	draw_rect(Rect2(Vector2.ZERO, size), Color(color, wash))
	# The padlock, scaled to fit the icon area: a body with a keyhole and a shackle on top
	# (closed while locked, swung open to one side when unlocked).
	var icon: Rect2 = rects["icon"]
	var u := minf(icon.size.x / 3.0, icon.size.y / 3.4)   # one unit; the lock is 3 wide and 3.4 tall
	var cx := icon.position.x + icon.size.x / 2.0
	var top := icon.position.y + (icon.size.y - 3.4 * u) / 2.0
	var body := Rect2(cx - 1.5 * u, top + 1.4 * u, 3.0 * u, 2.0 * u)
	var shackle_c := Vector2(cx, top + 1.4 * u)
	var width := maxf(2.0, 0.34 * u)
	if locked:
		draw_arc(shackle_c, 0.85 * u, PI, TAU, 24, color, width)
		draw_line(shackle_c + Vector2(-0.85 * u, 0), shackle_c + Vector2(-0.85 * u, 0.25 * u), color, width)
		draw_line(shackle_c + Vector2(0.85 * u, 0), shackle_c + Vector2(0.85 * u, 0.25 * u), color, width)
	else:
		var open_c := shackle_c + Vector2(1.0 * u, -0.45 * u)
		draw_arc(open_c, 0.85 * u, PI, TAU, 24, color, width)
		draw_line(open_c + Vector2(-0.85 * u, 0), open_c + Vector2(-0.85 * u, 0.6 * u), color, width)
	draw_rect(body, color)
	draw_circle(body.get_center() - Vector2(0, 0.15 * u), 0.3 * u, BG)
	draw_rect(Rect2(body.get_center().x - 0.1 * u, body.get_center().y - 0.1 * u, 0.2 * u, 0.7 * u), BG)
	_text_in_centered(rects["label"], lock_text(), FONT_BODY, color)


## Like _text_in but each line is centred horizontally.
func _text_in_centered(area: Rect2, text: String, wanted: int, color: Color) -> void:
	_draw_lines(area, text, fitted_font_size(text, wanted, area.size.x, area.size.y), color, HORIZONTAL_ALIGNMENT_CENTER)
