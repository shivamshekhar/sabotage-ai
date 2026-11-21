class_name HazardStrip
extends Control
## A thin strip of diagonal yellow and black warning stripes, like the frame of the warning signs: a header or footer for a panel. It fills the width it is
## given and is `thickness` tall.
##
##   panel_column.add_child(HazardStrip.make(10.0))

# STRIPE: the width in pixels of one yellow (or black) stripe, measured along the strip. SLANT: how far (px) the stripes lean over the strip's height.
const STRIPE := 14.0
const SLANT := 1.0

const YELLOW := Color(1.0, 0.78, 0.1)
const BLACK := Color(0.09, 0.1, 0.13)
const EDGE := Color(0.04, 0.05, 0.09)


static func make(thickness: float) -> HazardStrip:
	var s := HazardStrip.new()
	s.custom_minimum_size = Vector2(0.0, thickness)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return s


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), YELLOW)
	var x := -size.y * SLANT - STRIPE
	while x < size.x + size.y:
		var points := PackedVector2Array([Vector2(x, size.y), Vector2(x + STRIPE, size.y), Vector2(x + STRIPE + size.y * SLANT, 0.0), Vector2(x + size.y * SLANT, 0.0)])
		draw_colored_polygon(points, BLACK)
		x += STRIPE * 2.0
	draw_rect(Rect2(Vector2.ZERO, size), EDGE, false, 1.5)
