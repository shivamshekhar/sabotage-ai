class_name ScorePopups
extends Node2D
## The small "+100" that floats up from where points were earned and fades away. Points that come in quick succession are pooled so the screen
## is not spammed: every new award restarts a short timer (POOL_TIME), and when it runs out the whole sum shows ONCE, where the last award
## happened. (A long chain of awards still shows at the latest MAX_WAIT seconds after the first.) The score itself (GameStats.score) is
## raised at once; only the text is pooled.
##
## Use GameStats.add_score(points, at) with a position in the world; this node is made on demand and lives under the scene's root.

# POOL_TIME: seconds after the last award before the pooled total is shown. MAX_WAIT: the longest the first award of a chain waits.
const POOL_TIME := 1.0
const MAX_WAIT := 2.5

# FLOAT_HEIGHT: how far in pixels the text drifts up while it fades. LIFE: seconds it is visible. FONT_SIZE: kept small on purpose.
const FLOAT_HEIGHT := 46.0
const LIFE := 1.1
const FONT_SIZE := 18

const COLOR := Color(1.0, 0.86, 0.35)
const OUTLINE := Color(0.05, 0.04, 0.02, 0.95)

static var _instance: ScorePopups

var _pending := 0
var _at := Vector2.ZERO
var _since_last := 0.0
var _since_first := 0.0


## Award a text of `points` at the world position `at` (it is pooled with others that come within POOL_TIME).
static func add(points: int, at: Vector2) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or points == 0:
		return
	if _instance == null or not is_instance_valid(_instance):
		_instance = ScorePopups.new()
		_instance.name = "ScorePopups"
		_instance.z_index = 50
		tree.root.add_child(_instance)
	_instance._award(points, at)


func _award(points: int, at: Vector2) -> void:
	if _pending == 0:
		_since_first = 0.0
	_pending += points
	_at = at
	_since_last = 0.0


func _process(delta: float) -> void:
	if _pending == 0:
		return
	_since_last += delta
	_since_first += delta
	if _since_last >= POOL_TIME or _since_first >= MAX_WAIT:
		_show(_pending, _at)
		_pending = 0


func _show(points: int, at: Vector2) -> void:
	var p := ScorePopup.new()
	p.text = "+%d" % points
	p.position = at
	add_child(p)
	var tw := p.create_tween().set_parallel(true)
	tw.tween_property(p, "position:y", at.y - FLOAT_HEIGHT, LIFE).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(p, "modulate:a", 0.0, LIFE * 0.6).set_delay(LIFE * 0.4)
	tw.chain().tween_callback(p.queue_free)


## One floating text.
class ScorePopup:
	extends Node2D

	var text := ""

	func _draw() -> void:
		var font := ThemeDB.fallback_font
		var size := ScorePopups.FONT_SIZE
		var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var at := Vector2(-width / 2.0, 0.0)
		draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 6, ScorePopups.OUTLINE)
		draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, ScorePopups.COLOR)
