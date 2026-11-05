class_name PlayerShadow
extends Node2D
## Soft shadows that lift the player off the busy background:
##  - a dark halo behind the body, so the character reads against the racks
##  - a contact shadow on the floor under the feet
## Origin is at the player's feet.

const HALO_CENTER := Vector2(0, -66)
const HALO_SIZE := Vector2(150, 190)
const HALO_ALPHA := 0.4
const CONTACT_CENTER := Vector2(0, -3)
const CONTACT_SIZE := Vector2(100, 18)
const CONTACT_ALPHA := 0.6

static var _blob: GradientTexture2D


func _ready() -> void:
	z_index = -1  # behind the player's sprite, above the level
	_add_blob(HALO_CENTER, HALO_SIZE, HALO_ALPHA)
	_add_blob(CONTACT_CENTER, CONTACT_SIZE, CONTACT_ALPHA)


func _add_blob(center: Vector2, size: Vector2, alpha: float) -> void:
	var s := Sprite2D.new()
	s.texture = _blob_texture()
	s.position = center
	s.scale = size / float(_blob_texture().width)
	s.modulate = Color(0, 0, 0, alpha)
	add_child(s)


static func _blob_texture() -> GradientTexture2D:
	if _blob == null:
		var grad := Gradient.new()
		grad.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
		grad.colors = PackedColorArray([Color(1, 1, 1, 1.0), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0.0)])
		_blob = GradientTexture2D.new()
		_blob.gradient = grad
		_blob.fill = GradientTexture2D.FILL_RADIAL
		_blob.fill_from = Vector2(0.5, 0.5)
		_blob.fill_to = Vector2(1.0, 0.5)
		_blob.width = 128
		_blob.height = 128
	return _blob
