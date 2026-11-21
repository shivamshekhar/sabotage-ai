class_name HackStyle
extends RefCounted
## How the puzzle window (HackPopup and the Minigame puzzles in it) looks: the game's own look, navy steel with cyan edge lights, hazard yellow and orange
## accents, and thick dark outlines on the lettering. One place for the colours and the boxes, so the window and every puzzle share them.
##
##   panel.add_theme_stylebox_override("panel", HackStyle.panel())
##   HackStyle.style_button(button, Color(0.2, 0.55, 0.9))

# The colours. CYAN: the edge lights. NAVY / NAVY_DARK: the window and the inset screens. MINT: the green of the titles and the HUD. TEXT: the lettering.
const CYAN := Color(0.23, 0.82, 1.0)
const CYAN_DIM := Color(0.16, 0.42, 0.56)
const NAVY := Color(0.07, 0.1, 0.17)
const NAVY_DARK := Color(0.035, 0.055, 0.1)
const MINT := Color(0.4, 1.0, 0.6)
const ORANGE := Color(0.94, 0.54, 0.14)
const TEXT := Color(0.95, 0.98, 1.0)
const OUTLINE := Color(0.02, 0.03, 0.06, 0.95)

# CORNER: the corner radius of the boxes (the game's tiles are blocky, so it is small). EDGE_WIDTH: the width of a box's edge light. GLOW_SIZE: how far the
# window's cyan glow reaches outside it.
const CORNER := 8
const EDGE_WIDTH := 3
const GLOW_SIZE := 14

# BUTTON_LIP: how thick (px) the darker lower edge of a button is (it makes it look raised); a pressed button loses it.
const BUTTON_LIP := 5

# OUTLINE_SIZE: the thickness of the dark outline round the lettering.
const OUTLINE_SIZE := 6


## The window: a steel-navy box with a cyan edge light and a soft cyan glow outside.
static func panel() -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = NAVY
	b.border_color = CYAN
	b.set_border_width_all(EDGE_WIDTH)
	b.set_corner_radius_all(CORNER)
	b.set_content_margin_all(22)
	b.shadow_color = Color(CYAN, 0.32)
	b.shadow_size = GLOW_SIZE
	return b


## A darker box set into the window: the strip with the instructions, and the screen the puzzle is on.
static func inset(edge: Color = CYAN_DIM, margin := 12) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = NAVY_DARK
	b.border_color = edge
	b.set_border_width_all(2)
	b.set_corner_radius_all(CORNER - 2)
	b.set_content_margin_all(margin)
	return b


## A raised button of `color`: a dark edge with a thicker lip under it, lighter when hovered, pushed in when pressed. The lettering is white with a dark outline.
static func style_button(b: Button, color: Color) -> void:
	b.add_theme_stylebox_override("normal", _button_box(color, false))
	b.add_theme_stylebox_override("hover", _button_box(color.lightened(0.12), false))
	b.add_theme_stylebox_override("pressed", _button_box(color.lightened(0.4), true))
	b.add_theme_stylebox_override("hover_pressed", _button_box(color.lightened(0.4), true))
	b.add_theme_stylebox_override("disabled", _button_box(color.darkened(0.4), false))
	style_text(b)


static func _button_box(color: Color, pressed: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(CORNER + 2)
	box.border_color = color.darkened(0.45)
	box.set_border_width_all(2)
	box.border_width_bottom = 2 if pressed else BUTTON_LIP
	box.set_content_margin_all(6)
	if pressed:
		box.content_margin_top = 6 + BUTTON_LIP - 2         # (the lettering sinks with it)
	return box


## The timer bar: a dark channel with an orange fill.
static func style_bar(bar: ProgressBar) -> void:
	var back := inset(CYAN_DIM, 0)
	var fill := StyleBoxFlat.new()
	fill.bg_color = ORANGE
	fill.set_corner_radius_all(CORNER - 4)
	bar.add_theme_stylebox_override("background", back)
	bar.add_theme_stylebox_override("fill", fill)


## White lettering with the dark outline all the game's text has.
static func style_text(c: Control, color: Color = TEXT) -> void:
	c.add_theme_color_override("font_color", color)
	c.add_theme_color_override("font_outline_color", OUTLINE)
	c.add_theme_constant_override("outline_size", OUTLINE_SIZE)
