class_name Sprites
extends RefCounted
## Makes the Sprite2D nodes the game's pictures are shown in, so the same few settings are not written out in every script.

# SMOOTH: the filter for pictures made at twice (or more) the size they are shown at: shrinking them with mipmaps keeps them clean.
const SMOOTH := CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


## A sprite showing `texture`, scaled by `scale_value`, drawn at `z` (relative to its parent).
static func make(texture: Texture2D, scale_value := 1.0, z := 0, centered := true) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = texture
	s.centered = centered
	s.scale = Vector2(scale_value, scale_value)
	s.z_index = z
	s.texture_filter = SMOOTH
	return s


## The same, drawn additively: it brightens what is behind it (glows, flames, beams).
static func glow(texture: Texture2D, scale_value := 1.0, z := 0, centered := true) -> Sprite2D:
	var s := make(texture, scale_value, z, centered)
	s.material = Blend.additive()
	return s
