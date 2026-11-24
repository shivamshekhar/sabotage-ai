class_name OutfitComposer
extends RefCounted
## Makes the hero's pictures for an outfit. A pose is its parts (<part>/<style>/player_<pose>_<part>.png, made by tools/art/generate_player.py) put one over the other, bottom to
## top (CharacterPoses.PARTS), each in the style the outfit has for its slot, and recoloured to the outfit's colour (WardrobeCatalog.recolor()). The pictures are made when a
## pose is first asked for and kept, so changing the outfit costs nothing until the new look is drawn, and drawing it costs a few milliseconds a pose.

static var _textures := {}    # "outfit signature|pose" -> the texture made for it
static var _images := {}      # path of a part's picture -> its Image (never changed: a recoloured part is a copy), or null if there is no such picture


## The picture of `pose` for `outfit` (made once, then kept).
static func texture(outfit: Outfit, pose: String) -> Texture2D:
	var key := "%s|%s" % [outfit.signature(), pose]
	if not _textures.has(key):
		_textures[key] = ImageTexture.create_from_image(compose(outfit, pose))
	return _textures[key]


## The picture of `pose` for `outfit`, newly drawn.
static func compose(outfit: Outfit, pose: String) -> Image:
	var image := Image.create(CharacterPoses.HERO_FRAME.x, CharacterPoses.HERO_FRAME.y, false, Image.FORMAT_RGBA8)
	for part in CharacterPoses.PARTS:
		var layer := part_image(outfit, pose, part)
		if layer != null:
			image.blend_rect(layer, Rect2i(Vector2i.ZERO, layer.get_size()), Vector2i.ZERO)
	return image


## The picture of one part of `pose` as `outfit` wears it, or null if the outfit has no such part (no goggles, bald) or the pose has none (the back of the head has no goggles).
## The image must not be changed: it may be the kept original.
static func part_image(outfit: Outfit, pose: String, part: StringName) -> Image:
	var changeable := WardrobeCatalog.SLOTS.has(part)
	var source_pose := CharacterPoses.part_pose(WardrobeCatalog.pose_for(outfit.style(&"torso"), pose), part)
	var style: StringName = &""
	if changeable:
		style = outfit.style(part)
		if style == WardrobeCatalog.NO_PART:
			return null
	var picture := _original(source_pose, part, style)
	if picture == null and changeable and style != WardrobeCatalog.default_style(part):
		picture = _original(source_pose, part, WardrobeCatalog.default_style(part))     # (a style that has no picture in this pose, say the short hair seen from behind: the original style)
	if picture == null:
		return null
	if changeable and outfit.color_id(part) != WardrobeCatalog.default_color(part):
		picture = picture.duplicate()
		WardrobeCatalog.recolor(picture, part, outfit.color(part))
	return picture


## The path of a part's picture: <part>/<style>/player_<pose>_<part>.png for a part with styles (`style` is the style's folder), <part>/player_<pose>_<part>.png for one
## without (`style` is &"").
static func path(pose: String, part: StringName, style: StringName = &"") -> String:
	if style == &"":
		return "%s%s/player_%s_%s.png" % [AssetPaths.HERO_LAYERS, part, pose, part]
	return "%s%s/%s/player_%s_%s.png" % [AssetPaths.HERO_LAYERS, part, style, pose, part]


static func _original(pose: String, part: StringName, style: StringName) -> Image:
	var file := path(pose, part, style)
	if not _images.has(file):
		var texture: Texture2D = AssetPaths.texture(file) if ResourceLoader.exists(file) else null
		var image: Image = texture.get_image() if texture != null else null
		if image != null and image.get_format() != Image.FORMAT_RGBA8:
			image.convert(Image.FORMAT_RGBA8)
		_images[file] = image
	return _images[file]
