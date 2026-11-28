class_name PerfOverlay
extends CanvasLayer
## A debugging aid: the frame rate and the length of the last frames in a corner of the screen, and a line in the console for every frame that took longer than SPIKE_MS (a stutter),
## with the time it happened, so a stutter can be matched to what the player was doing. It shows only when the game is started with SABOTAGE_PERF=1 (add_to() does nothing
## otherwise); F3 hides and shows it.
##
##   PerfOverlay.add_to(self)        # in Main: nothing unless SABOTAGE_PERF is set

# ENV_VARIABLE: the environment variable that turns the overlay on.
const ENV_VARIABLE := "SABOTAGE_PERF"

# SPIKE_MS: a frame longer than this (ms) is a spike: it is counted and printed. 33 ms is two frames missed at 60 per second.
const SPIKE_MS := 33.0

# WINDOW: how many seconds the average and the worst frame are taken over.
const WINDOW := 1.0

# LAYER: the canvas layer (above everything else). FONT_SIZE / MARGIN: the text's size and its distance from the corner (px). COLOR: the text colour.
const LAYER := 100
const FONT_SIZE := 10
const MARGIN := 6.0
const COLOR := Color(0.6, 1.0, 0.7)

var _label: Label
var _frames := 0
var _elapsed := 0.0
var _worst_ms := 0.0
var _spikes := 0
var _since_start := 0.0


## Add the overlay under `parent` if SABOTAGE_PERF is set. Returns it, or null.
static func add_to(parent: Node) -> PerfOverlay:
	if OS.get_environment(ENV_VARIABLE) == "":
		return null
	var overlay := PerfOverlay.new()
	parent.add_child(overlay)
	return overlay


func _init() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_label = Label.new()
	_label.position = Vector2(MARGIN, MARGIN)
	_label.add_theme_font_size_override("font_size", FONT_SIZE)
	_label.add_theme_color_override("font_color", COLOR)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 4)
	add_child(_label)


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F3:
		visible = not visible


func _process(delta: float) -> void:
	var frame_ms := delta * 1000.0
	_since_start += delta
	_frames += 1
	_elapsed += delta
	_worst_ms = maxf(_worst_ms, frame_ms)
	if frame_ms > SPIKE_MS:
		_spikes += 1
		print("PERF spike: %.0f ms at %.1f s" % [frame_ms, _since_start])
	if _elapsed >= WINDOW:
		_label.text = "%d fps   avg %.1f ms   worst %.0f ms   spikes %d   nodes %d" % [roundi(_frames / _elapsed), 1000.0 * _elapsed / _frames, _worst_ms, _spikes,
				int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))]
		_frames = 0
		_elapsed = 0.0
		_worst_ms = 0.0
