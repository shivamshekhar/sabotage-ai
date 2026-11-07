class_name Vignette
extends CanvasLayer
## Darkens the screen edges so the eye stays on the action in the middle.

# EDGE_ALPHA: how dark the screen corners get, from 0 (no vignette) to 1 (black). The
# darkness ramps up from nothing, starting at CLEAR_UNTIL, to this value at the corners.
# Higher: a heavier, more cinematic frame. Lower: subtler.
const EDGE_ALPHA := 0.55

# CLEAR_UNTIL: fraction of the distance from the screen centre to the corners that stays
# completely untouched (it is the middle stop of the gradient: transparent from the centre
# out to here).
# Higher: the clear area is larger and the darkening hugs the corners. Lower: darkening
# starts closer to the middle.
const CLEAR_UNTIL := 0.5


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
