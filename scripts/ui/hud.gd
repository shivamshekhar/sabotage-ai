class_name Hud
extends CanvasLayer
## The heads-up display along the top of the screen: the score on the left and the level number on the right ("WORLD 1-1", numbered
## like Super Mario Bros, see LevelData.stage_label()). More can be added to the row later. It FLOATS over the game: no bar or panel
## behind it. To stay readable on any background every letter has a thick dark outline and a soft drop shadow. It has a canvas layer of
## its own, so the camera (and its zoom) cannot move or squash it. It sits above the vignette and below the touch controls, banners
## and puzzle windows.

# LAYER: the canvas layer it is drawn on (the vignette is 5, the touch controls 10, banners 19 and 20, puzzle windows 30).
const LAYER := 8

# CAPTION_SIZE / VALUE_SIZE: the font sizes of the small label ("SCORE") and of the number under it.
const CAPTION_SIZE := 18
const VALUE_SIZE := 18

# SIDE_MARGIN / TOP_MARGIN: the space in pixels between the screen's edges and the items.
const SIDE_MARGIN := 32
const TOP_MARGIN := 14

# OUTLINE_SIZE: the thickness in pixels of the dark outline around every letter. SHADOW_OFFSET: how far the soft shadow falls.
const OUTLINE_SIZE := 6
const SHADOW_OFFSET := Vector2(2, 3)

const TEXT := Color(1, 1, 1)
const CAPTION := Color(0.55, 1.0, 0.78)
const OUTLINE := Color(0.02, 0.03, 0.06, 0.95)
const SHADOW := Color(0, 0, 0, 0.7)

var _score_label: Label
var _stage_label: Label
var _shown_score := -1
var _pending_stage := ""


## Add a HUD under `parent` showing the level number `stage`.
static func add_to(parent: Node, stage: String) -> Hud:
	var hud := Hud.new()
	hud.name = "Hud"
	parent.add_child(hud)
	hud.set_stage(stage)
	return hud


func _init() -> void:
	layer = LAYER


func _ready() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_TOP_WIDE)
	margin.add_theme_constant_override("margin_left", SIDE_MARGIN)
	margin.add_theme_constant_override("margin_right", SIDE_MARGIN)
	margin.add_theme_constant_override("margin_top", TOP_MARGIN)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)
	_score_label = _item(row, "SCORE:", "000000", HORIZONTAL_ALIGNMENT_LEFT)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)
	_stage_label = _item(row, "WORLD:", "1-1", HORIZONTAL_ALIGNMENT_RIGHT)
	refresh()


## One item of the row: the caption and the value side by side on one line, in the same size. Returns the value's label.
func _item(row: HBoxContainer, caption: String, value: String, align: HorizontalAlignment) -> Label:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 12)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(line)
	line.add_child(_label(caption, CAPTION_SIZE, CAPTION, align))
	var big := _label(value, VALUE_SIZE, TEXT, align)
	line.add_child(big)
	return big


func _label(text: String, size: int, color: Color, align: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", OUTLINE)
	l.add_theme_constant_override("outline_size", OUTLINE_SIZE)
	l.add_theme_color_override("font_shadow_color", SHADOW)
	l.add_theme_constant_override("shadow_offset_x", int(SHADOW_OFFSET.x))
	l.add_theme_constant_override("shadow_offset_y", int(SHADOW_OFFSET.y))
	l.add_theme_constant_override("shadow_outline_size", OUTLINE_SIZE)
	return l


func set_stage(stage: String) -> void:
	if _stage_label != null:
		_stage_label.text = stage
	else:
		_pending_stage = stage


## Show the current score and level number.
func refresh() -> void:
	if _pending_stage != "":
		_stage_label.text = _pending_stage
	_shown_score = GameStats.score
	_score_label.text = "%06d" % _shown_score


func _process(_delta: float) -> void:
	if _shown_score != GameStats.score:
		refresh()
