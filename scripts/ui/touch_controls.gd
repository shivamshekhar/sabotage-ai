class_name TouchControls
extends CanvasLayer
## On-screen buttons. TouchScreenButton supports multi-touch, so you can hold a
## direction and jump at the same time. Each button drives an input action.

const BTN_SIZE := 130.0


func _ready() -> void:
	layer = 10
	_add_button("<", "move_left", Vector2(40, 540))
	_add_button(">", "move_right", Vector2(200, 540))
	_add_button("JUMP", "jump", Vector2(1110, 540))
	_add_button("UP", "move_up", Vector2(1110, 390))
	_add_button("DOWN", "move_down", Vector2(950, 540))


func _add_button(label: String, action: String, pos: Vector2) -> void:
	var tex := GradientTexture2D.new()
	tex.width = int(BTN_SIZE)
	tex.height = int(BTN_SIZE)
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 0.30))
	grad.set_color(1, Color(1, 1, 1, 0.12))
	tex.gradient = grad

	var shape := RectangleShape2D.new()
	shape.size = Vector2(BTN_SIZE, BTN_SIZE)

	var btn := TouchScreenButton.new()
	btn.position = pos
	btn.texture_normal = tex
	btn.shape = shape
	btn.shape_centered = false
	btn.action = action
	add_child(btn)

	var text := Label.new()
	text.text = label
	text.size = Vector2(BTN_SIZE, BTN_SIZE)
	text.position = pos
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text.add_theme_font_size_override("font_size", 30)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(text)
