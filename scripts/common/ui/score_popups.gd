class_name ScorePopups
extends RefCounted
## The small "+100" that floats up from where points were earned and fades away. There is no waiting and no adding together: every award shows its own text
## the moment it is earned (an enemy dies, a text floats away from it). The score itself (GameStats.score) is raised at once, independent of the text.
##
## Use GameStats.add_score(points, at) with a position in the world. The text lives in the level being played, so it goes with the level.

# FLOAT_HEIGHT: how far in pixels the text drifts up while it fades. LIFE: seconds it is visible. FONT_SIZE: kept small on purpose.
const FLOAT_HEIGHT := 46.0
const LIFE := 1.1
const FONT_SIZE := 12

# FADE_START: the share of LIFE after which the text starts to fade (the first part it is fully visible).
const FADE_START := 0.4

# Z: drawn over everything in the world.
const Z := 50

const COLOR := Color(1.0, 0.86, 0.35)
const OUTLINE := Color(0.05, 0.04, 0.02, 0.95)


## Float a text of `points` up from the world position `at`, now. Does nothing when there is no scene yet (or no points).
static func add(points: int, at: Vector2) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or points == 0:
		return
	var parent: Node = tree.current_scene if tree.current_scene != null else tree.root
	var p := ScorePopup.new()
	p.text = "+%d" % points if points > 0 else str(points)
	p.position = at
	p.z_index = Z
	p.add_to_group(Groups.SCORE_POPUPS)
	parent.add_child(p)
	var tw := p.create_tween().set_parallel(true)
	tw.tween_property(p, "position:y", at.y - FLOAT_HEIGHT, LIFE).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(p, "modulate:a", 0.0, LIFE * (1.0 - FADE_START)).set_delay(LIFE * FADE_START)
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
