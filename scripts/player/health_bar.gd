class_name HealthBar
extends Node2D
## Small bar drawn above the player: red is the full bar (damage taken),
## green on top is the health remaining.

const SIZE := Vector2(76, 10)
const OUTLINE := Color("#0b0d14")
const GREEN := Color("#2ee66b")
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
