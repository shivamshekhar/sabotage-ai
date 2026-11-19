class_name Blend
extends RefCounted
## Ready-made blend materials, one shared instance of each.

static var _additive: CanvasItemMaterial


## Adds the picture's colour to what is behind it: for glows, flames, sparks and beams.
static func additive() -> CanvasItemMaterial:
	if _additive == null:
		_additive = CanvasItemMaterial.new()
		_additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return _additive
