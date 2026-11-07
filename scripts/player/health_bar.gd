class_name HealthBar
extends Node2D
## Small bar drawn above the player: red is the full bar (damage taken),
## green on top is the health remaining.

# SIZE: width and height of the bar in pixels. The green fill is SIZE.x * ratio wide, where
# ratio is health / maximum health; the outline is the bar grown by a small fixed margin.
# Larger: easier to read, but more clutter above the player.
const SIZE := Vector2(76, 10)

# OUTLINE: colour of the border around the bar. A dark colour keeps it readable on any
# background.
const OUTLINE := Color("#0b0d14")

# GREEN: colour of the remaining health (the filled part).
const GREEN := Color("#2ee66b")

# RED: colour of the full bar behind the fill. Whatever the green doesn't cover shows as red,
# which is the damage taken.
const RED := Color("#e0334a")

var ratio := 1.0


func set_ratio(value: float) -> void:
	ratio = clampf(value, 0.0, 1.0)
	queue_redraw()


func _draw() -> void:
	var bar := Rect2(-SIZE.x / 2.0, -SIZE.y / 2.0, SIZE.x, SIZE.y)
	draw_rect(bar.grow(2.0), OUTLINE)
	draw_rect(bar, RED)
	var fill := Rect2(bar.position, Vector2(bar.size.x * ratio, bar.size.y))
	draw_rect(fill, GREEN)
	draw_rect(Rect2(fill.position, Vector2(fill.size.x, 3.0)), Color(1, 1, 1, 0.25))
