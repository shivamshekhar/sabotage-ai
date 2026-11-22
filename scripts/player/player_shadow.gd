class_name PlayerShadow
extends Node2D
## Soft shadows that lift the player off the busy background:
##  - a dark halo behind the body, so the character reads against the racks (it moves with the body)
##  - a contact shadow on the floor (a GroundShadow: it stays on the floor under the feet when the player jumps, and shrinks and fades with the height)
## Origin is at the player's feet.

# The halo is a radial gradient (opaque in the middle, fading to nothing at the edge) drawn as a black blob. Its position is relative to the player's feet
# (negative y = up). In _add_blob(): sprite scale = size / texture width, colour = black with the alpha.

# HALO_CENTER: where the dark halo behind the body is centred; roughly the middle of the body.
const HALO_CENTER := Vector2(0, -66)

# HALO_SIZE: width and height of the halo, in pixels. Larger: darkens more of the background
# around the player (easier to read, but a visible smudge). Smaller: tighter.
const HALO_SIZE := Vector2(150, 190)

# HALO_ALPHA: peak opacity of the halo at its centre. 0 = off. Higher: more contrast between
# the player and a busy background. Lower: subtler.
const HALO_ALPHA := 0.4

# CONTACT_SIZE: width and height of the contact shadow ellipse on the floor, in pixels. It is wide and
# flat. Larger: the player looks heavier or higher above the floor.
const CONTACT_SIZE := Vector2(100, 18)

# CONTACT_ALPHA: peak opacity of the contact shadow at its centre, when the player is on the floor. 0 = off.
const CONTACT_ALPHA := 0.6


func _ready() -> void:
	z_index = -1  # behind the player's sprite, above the level
	_add_blob(HALO_CENTER, HALO_SIZE, HALO_ALPHA)
	var contact := GroundShadow.new()
	contact.size = CONTACT_SIZE
	contact.alpha = CONTACT_ALPHA
	add_child(contact)


func _add_blob(center: Vector2, size: Vector2, alpha: float) -> void:
	var s := Sprite2D.new()
	s.texture = GroundShadow.blob_texture()
	s.position = center
	s.scale = size / float(GroundShadow.blob_texture().width)
	s.modulate = Color(0, 0, 0, alpha)
	add_child(s)
