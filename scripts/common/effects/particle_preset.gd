class_name ParticlePreset
extends RefCounted
## A description of a burst or a stream of particles (CPUParticles2D), so the many effects (sparks, smoke, embers, trails) are written as a list of
## settings instead of a screenful of property assignments each. Fill in what differs from the defaults and call build().
##
##   var preset := ParticlePreset.new()
##   preset.texture = AssetPaths.effect("spark")
##   preset.amount = 20
##   preset.colors = ParticlePreset.fade_gradient([Color.WHITE, Color.ORANGE, Color(1, 0.3, 0, 0)])
##   parent.add_child(preset.build())

var texture: Texture2D
var amount := 10
var lifetime := 0.5
var one_shot := true            # a burst that plays once (false = a stream that keeps going)
var explosiveness := 1.0        # 1 = all at once, 0 = spread over the lifetime
var direction := Vector2.UP
var spread := 180.0             # degrees either side of `direction`
var speed_min := 50.0           # pixels per second
var speed_max := 150.0
var gravity := Vector2.ZERO
var scale_min := 0.2            # of the picture
var scale_max := 0.4
var grow: Curve                 # multiplies the size over a particle's life (optional)
var colors: Gradient            # tints and fades a particle over its life (optional)
var additive := false           # brighten what is behind (glowing things)
var world_space := true         # particles stay where they were born instead of following the emitter
var random_angle := false       # each particle at a random rotation (smoke)
var emission_points := PackedVector2Array()   # start from these points (in the emitter's space) instead of one spot


func build() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = texture
	p.amount = maxi(1, amount)
	p.lifetime = lifetime
	p.one_shot = one_shot
	p.emitting = true
	p.explosiveness = explosiveness
	p.direction = direction
	p.spread = spread
	p.initial_velocity_min = speed_min
	p.initial_velocity_max = speed_max
	p.gravity = gravity
	p.scale_amount_min = scale_min
	p.scale_amount_max = scale_max
	p.scale_amount_curve = grow
	p.color_ramp = colors
	p.local_coords = not world_space
	if additive:
		p.material = Blend.additive()
	if random_angle:
		p.angle_min = -180.0
		p.angle_max = 180.0
	if not emission_points.is_empty():
		p.emission_shape = CPUParticles2D.EMISSION_SHAPE_POINTS
		p.emission_points = emission_points
	return p


## A gradient through `colors`, evenly spaced from the start of a particle's life to its end.
static func fade_gradient(colors_list: Array) -> Gradient:
	var g := Gradient.new()
	var offsets := PackedFloat32Array()
	var cols := PackedColorArray()
	for i in colors_list.size():
		offsets.append(float(i) / float(maxi(1, colors_list.size() - 1)))
		cols.append(colors_list[i])
	g.offsets = offsets
	g.colors = cols
	return g


## A growth curve from `from_scale` at birth to `to_scale` at the end of life.
static func grow_curve(from_scale: float, to_scale: float) -> Curve:
	var c := Curve.new()
	c.add_point(Vector2(0.0, from_scale))
	c.add_point(Vector2(1.0, to_scale))
	return c
