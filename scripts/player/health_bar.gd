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

# TITLE_FONT_SIZE: height in pixels of the name written above the bar. Small on purpose, so it
# labels without distracting. Names too wide for TITLE_MAX_WIDTH are shrunk to fit.
const TITLE_FONT_SIZE := 14

# TITLE_MAX_WIDTH: the widest the name may be drawn, in pixels; about the width of the character sprite.
# A name wider than this at TITLE_FONT_SIZE (a row of wide letters) is drawn smaller until it fits, but
# never below TITLE_MIN_FONT_SIZE. Higher: wide names may stick out past the sprite.
const TITLE_MAX_WIDTH := 92.0

# TITLE_MIN_FONT_SIZE: the smallest the name is shrunk to when fitting TITLE_MAX_WIDTH.
const TITLE_MIN_FONT_SIZE := 8

# TITLE_GAP: space in pixels between the top of the bar and the bottom of the name.
const TITLE_GAP := 5.0

# TITLE_COLOR: colour of the name. A soft white, a little dimmer than the bar so it stays secondary.
const TITLE_COLOR := Color(1, 1, 1, 0.85)

var ratio := 1.0
var title := ""


## The name drawn above the bar (empty for none).
func set_title(text: String) -> void:
	title = text
	queue_redraw()


## The font size the name is drawn at: TITLE_FONT_SIZE, shrunk if needed to fit TITLE_MAX_WIDTH.
func title_font_size(text: String = title) -> int:
	var size := TITLE_FONT_SIZE
	while size > TITLE_MIN_FONT_SIZE and ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > TITLE_MAX_WIDTH:
		size -= 1
	return size


## Width in pixels the name takes up when drawn.
func title_width(text: String = title) -> float:
	return ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, title_font_size(text)).x


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
	if title != "":
		var font := ThemeDB.fallback_font
		var at := Vector2(-title_width() / 2.0, bar.position.y - 2.0 - TITLE_GAP)   # baseline just above the bar's outline
		var size := title_font_size()
		draw_string_outline(font, at, title, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, OUTLINE)
		draw_string(font, at, title, HORIZONTAL_ALIGNMENT_LEFT, -1, size, TITLE_COLOR)
