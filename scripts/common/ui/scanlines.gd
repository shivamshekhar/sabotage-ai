class_name Scanlines
extends Control
## A faint pattern of horizontal lines over a screen-like panel (a monitor look). It fills its parent, draws over it and lets clicks through.
##
##   screen_panel.add_child(Scanlines.make())

# SPACING: pixels between two lines. ALPHA: how dark each line is (0 to 1). Lower: fainter.
const SPACING := 4.0
const ALPHA := 0.16


static func make() -> Scanlines:
	var s := Scanlines.new()
	s.set_anchors_preset(Control.PRESET_FULL_RECT)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return s


func _draw() -> void:
	var y := 0.0
	while y < size.y:
		draw_line(Vector2(0.0, y), Vector2(size.x, y), Color(0.0, 0.0, 0.0, ALPHA), 1.0)
		y += SPACING
