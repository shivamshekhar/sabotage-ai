class_name PauseButton
extends Button
## The small menu button in the corner of the game screen: a raised square (the game's own button look, see HackStyle) with the pause sign, two bars, on it. Pressing it is up to
## whoever made it (the HUD opens the PauseMenu). It never takes the keyboard focus, or Space (jump) and Enter would press it.
##
##   var button := PauseButton.new()
##   button.pressed.connect(open_the_menu)

# BUTTON_SIZE: the button's size in pixels (big enough for a finger). COLOR: its colour.
const BUTTON_SIZE := Vector2(56.0, 56.0)
const COLOR := Color(0.16, 0.3, 0.5)

# BAR_SIZE / BAR_GAP: the size of each of the two bars of the pause sign, and the space between them, in pixels. SIGN_COLOR: their colour.
const BAR_SIZE := Vector2(8.0, 24.0)
const BAR_GAP := 8.0
const SIGN_COLOR := Color(0.95, 0.98, 1.0)


func _init() -> void:
	custom_minimum_size = BUTTON_SIZE
	focus_mode = Control.FOCUS_NONE
	HackStyle.style_button(self, COLOR)


func _draw() -> void:
	var sink := Vector2(0.0, float(HackStyle.BUTTON_LIP) / 2.0) if is_pressed() else Vector2.ZERO
	var total := BAR_SIZE.x * 2.0 + BAR_GAP
	var origin := (size - Vector2(total, BAR_SIZE.y)) / 2.0 - Vector2(0.0, float(HackStyle.BUTTON_LIP) / 2.0) + sink
	for i in 2:
		draw_rect(Rect2(origin + Vector2(i * (BAR_SIZE.x + BAR_GAP), 0.0), BAR_SIZE), SIGN_COLOR)
