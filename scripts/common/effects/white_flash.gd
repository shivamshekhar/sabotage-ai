class_name WhiteFlash
extends RefCounted
## A soft white glow that swells out of a spot in the world and fades: the moment a power-up comes together. It is one smooth glow (bright in the middle, falling
## off gently to nothing at the edge, with a wider, fainter halo round it), so it has no visible disc or ring in it and melts into what is behind it. Anything else
## that wants the same can use it.
##
##   WhiteFlash.burst(get_parent(), player.global_position + Vector2(0, -90), 384.0)

# PLAYER_SIZES: how big the glow of a power-up is, in player heights (3 = three times the player's size).
const PLAYER_SIZES := 3.0

# START_SHARE: the share of its full size the glow starts at. RISE_TIME: seconds it takes to swell to full size, at full brightness. FADE_TIME: seconds it then takes
# to fade away.
const START_SHARE := 0.25
const RISE_TIME := 0.16
const FADE_TIME := 0.55

# HALO_SIZE / HALO_ALPHA: the wider glow behind: its size as a multiple of the main glow's, and how bright it is (0 to 1).
const HALO_SIZE := 1.5
const HALO_ALPHA := 0.4

# FALLOFF: the glow's brightness (0 to 1) at evenly spaced distances from its middle to its edge: a smooth bell, with no step where the edge of a bright core would
# show.
const FALLOFF := [1.0, 0.92, 0.74, 0.5, 0.29, 0.14, 0.055, 0.015, 0.0]

# TEXTURE_SIZE: the size in pixels of the glow's picture (it is scaled to the size asked for).
const TEXTURE_SIZE := 256

# Z: drawn over everything in the world.
const Z := 40

static var _texture: GradientTexture2D


## Glow `size` pixels across at the world position `at`, in `world` (a node of the level): it swells to full size at once, then fades.
static func burst(world: Node, at: Vector2, size: float) -> void:
	_glow(world, at, size * HALO_SIZE, HALO_ALPHA)
	_glow(world, at, size, 1.0)


static func _glow(world: Node, at: Vector2, size: float, alpha: float) -> void:
	var glow := Sprite2D.new()
	glow.texture = _soft_texture()
	glow.material = Blend.additive()
	glow.position = at
	glow.z_index = Z
	glow.modulate.a = alpha
	var tex_width := float(TEXTURE_SIZE)
	glow.scale = Vector2.ONE * (size * START_SHARE / tex_width)
	world.add_child(glow)
	var tw := glow.create_tween()
	tw.tween_property(glow, "scale", Vector2.ONE * (size / tex_width), RISE_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(glow, "modulate:a", 0.0, FADE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(glow.queue_free)


## The glow's picture: white, round, bright in the middle, falling off smoothly (FALLOFF) to transparent at the edge.
static func _soft_texture() -> GradientTexture2D:
	if _texture == null:
		var gradient := Gradient.new()
		var offsets := PackedFloat32Array()
		var colors := PackedColorArray()
		for i in FALLOFF.size():
			offsets.append(float(i) / float(FALLOFF.size() - 1))
			colors.append(Color(1.0, 1.0, 1.0, float(FALLOFF[i])))
		gradient.offsets = offsets
		gradient.colors = colors
		_texture = GradientTexture2D.new()
		_texture.gradient = gradient
		_texture.fill = GradientTexture2D.FILL_RADIAL
		_texture.fill_from = Vector2(0.5, 0.5)
		_texture.fill_to = Vector2(1.0, 0.5)
		_texture.width = TEXTURE_SIZE
		_texture.height = TEXTURE_SIZE
	return _texture
