class_name Vignette
extends CanvasLayer
## Darkens the screen edges so the eye stays on the action in the middle.

const EDGE_ALPHA := 0.55   # darkness at the corners
const CLEAR_UNTIL := 0.5   # fraction of the radius that stays untouched


func _ready() -> void:
	layer = 5  # above the world, below the touch controls (10) and the win banner (20)
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, CLEAR_UNTIL, 1.0])
	grad.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0.02, 0.03, 0.07, EDGE_ALPHA)])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 1.0)
	tex.width = 256
	tex.height = 256

	var rect := TextureRect.new()
	rect.texture = tex
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
