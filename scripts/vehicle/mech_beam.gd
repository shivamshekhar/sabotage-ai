class_name MechBeam
extends Node2D
## The short-lived effects of the mech's weapons:
##   - the laser: a blue beam with a glow (drawn additively, so it brightens whatever is behind it), energy rings travelling along it, a burst
##     where it ends, and glowing rings and a starburst at the muzzle that expand and fade (assets/powerups/mech/laser_halo.png, laser_burst.png)
##   - an explosion: a fireball, a shock ring, sparks and rising smoke (used for missiles and, bigger, for the mech itself blowing up)

# BEAM_TIME: seconds the beam stays visible while it fades.
const BEAM_TIME := 0.2

# The beam's colours (blue, with a white-blue core).
const BLUE := Color(0.27, 0.58, 1.0)
const BLUE_LIGHT := Color(0.75, 0.88, 1.0)

# HALO_TIME: seconds the rings at the muzzle take to expand and fade.
const HALO_TIME := 0.32

# EXPLOSION_TIME: seconds an explosion's fireball and ring last.
const EXPLOSION_TIME := 0.55

var _from := Vector2.ZERO
var _to := Vector2.ZERO
var _hit := false
var _age := 0.0
var _kind := "beam"
var _radius := 60.0
var _halos: Array[Sprite2D] = []
var _burst: Sprite2D


static func _additive() -> CanvasItemMaterial:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return m


## Show a laser beam from `from` to `to` (world positions) under `parent`; `hit` makes a bigger burst at the end.
static func show_beam(parent: Node, from: Vector2, to: Vector2, hit: bool) -> void:
	var b := MechBeam.new()
	b._from = from
	b._to = to
	b._hit = hit
	b.z_index = 4
	b.material = _additive()
	parent.add_child(b)
	# the rings and the starburst at the muzzle
	var halo_tex := load("res://assets/powerups/mech/laser_halo.png") as Texture2D
	for i in 2:
		var h := Sprite2D.new()
		h.texture = halo_tex
		h.global_position = from
		h.scale = Vector2(0.2, 0.2)
		h.material = _additive()
		h.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		h.modulate.a = 0.0
		b.add_child(h)
		b._halos.append(h)
	b._burst = Sprite2D.new()
	b._burst.texture = load("res://assets/powerups/mech/laser_burst.png")
	b._burst.global_position = from
	b._burst.material = _additive()
	b._burst.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	b.add_child(b._burst)
	# a burst where it ends
	var end := Sprite2D.new()
	end.texture = load("res://assets/powerups/mech/laser_burst.png")
	end.global_position = to
	end.scale = Vector2(0.5, 0.5) if hit else Vector2(0.3, 0.3)
	end.material = _additive()
	end.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	b.add_child(end)


## An explosion at `at`; `scale_factor` 1 is the mech's own (large), smaller for a missile.
static func explosion(parent: Node, at: Vector2, scale_factor: float = 1.0) -> void:
	var b := MechBeam.new()
	b._kind = "explosion"
	b._radius = 90.0 * scale_factor
	b.global_position = at
	b.z_index = 4
	parent.add_child(b)
	# sparks (little bright stars)
	var sparks := CPUParticles2D.new()
	sparks.texture = load("res://assets/powerups/mech/spark.png")
	sparks.material = _additive()
	sparks.emitting = true
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	sparks.amount = int(22 * maxf(scale_factor, 0.5))
	sparks.lifetime = 0.6
	sparks.direction = Vector2(0, -1)
	sparks.spread = 180.0
	sparks.initial_velocity_min = 140.0 * scale_factor
	sparks.initial_velocity_max = 420.0 * scale_factor
	sparks.gravity = Vector2(0, 900)
	sparks.scale_amount_min = 0.25
	sparks.scale_amount_max = 0.6
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
	ramp.colors = PackedColorArray([Color(1.0, 0.95, 0.75, 1.0), Color(1.0, 0.6, 0.2, 0.9), Color(0.6, 0.2, 0.08, 0.0)])
	sparks.color_ramp = ramp
	b.add_child(sparks)
	# smoke that rises and spreads
	var smoke := CPUParticles2D.new()
	smoke.texture = load("res://assets/powerups/mech/smoke_%d.png" % (randi() % 3 + 1))
	smoke.emitting = true
	smoke.one_shot = true
	smoke.explosiveness = 0.85
	smoke.amount = int(8 * maxf(scale_factor, 0.6))
	smoke.lifetime = 1.3
	smoke.direction = Vector2(0, -1)
	smoke.spread = 70.0
	smoke.initial_velocity_min = 20.0
	smoke.initial_velocity_max = 90.0 * scale_factor
	smoke.gravity = Vector2(0, -30)
	smoke.scale_amount_min = 0.35 * scale_factor + 0.1
	smoke.scale_amount_max = 0.7 * scale_factor + 0.15
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.5))
	curve.add_point(Vector2(1.0, 1.7))
	smoke.scale_amount_curve = curve
	var sramp := Gradient.new()
	sramp.offsets = PackedFloat32Array([0.0, 0.2, 1.0])
	sramp.colors = PackedColorArray([Color(0.9, 0.8, 0.6, 0.0), Color(0.5, 0.48, 0.5, 0.7), Color(0.2, 0.2, 0.22, 0.0)])
	smoke.color_ramp = sramp
	b.add_child(smoke)


func _process(delta: float) -> void:
	_age += delta
	var life := BEAM_TIME if _kind == "beam" else EXPLOSION_TIME + 1.0
	if _kind == "beam":
		life = maxf(BEAM_TIME, HALO_TIME)
	if _age >= life:
		queue_free()
		return
	if _kind == "beam":
		var t := _age / HALO_TIME
		for i in _halos.size():
			var u := clampf(t - i * 0.22, 0.0, 1.0)
			_halos[i].scale = Vector2.ONE * lerpf(0.2, 0.85, 1.0 - pow(1.0 - u, 2.0))
			_halos[i].modulate.a = sin(u * PI) * 0.95 if u > 0.0 else 0.0
		if _burst != null:
			_burst.scale = Vector2.ONE * lerpf(0.9, 0.35, clampf(t, 0.0, 1.0))
			_burst.rotation = t * 1.2
			_burst.modulate.a = 1.0 - clampf(t * 1.6, 0.0, 1.0)
	queue_redraw()


func _draw() -> void:
	if _kind == "beam":
		var t := clampf(1.0 - _age / BEAM_TIME, 0.0, 1.0)
		var a := to_local(_from)
		var b := to_local(_to)
		# the glow: wide soft layers, then the beam, then the white core
		draw_line(a, b, Color(BLUE, 0.10 * t), 34.0 * (0.5 + 0.5 * t))
		draw_line(a, b, Color(BLUE, 0.18 * t), 22.0 * (0.5 + 0.5 * t))
		draw_line(a, b, Color(BLUE, 0.45 * t), 11.0 * t + 3.0)
		draw_line(a, b, Color(BLUE_LIGHT, 0.9 * t), 5.0 * t + 1.5)
		draw_line(a, b, Color(1, 1, 1, t), 2.2)
		# energy rings travelling along the beam
		var dir := (b - a).normalized()
		var length := a.distance_to(b)
		var spacing := 52.0
		var shift := fposmod(_age * 900.0, spacing)
		var k := 0
		while shift + k * spacing < length:
			var p := a + dir * (shift + k * spacing)
			var fade := 1.0 - (shift + k * spacing) / maxf(length, 1.0)
			draw_set_transform(p, dir.angle(), Vector2(0.28, 1.0))
			draw_arc(Vector2.ZERO, 9.0, 0.0, TAU, 20, Color(BLUE_LIGHT, 0.55 * t * (0.4 + 0.6 * fade)), 2.2)
			k += 1
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_circle(b, (11.0 if _hit else 6.0) * (0.6 + t), Color(BLUE_LIGHT, 0.85 * t))
		draw_circle(b, (22.0 if _hit else 12.0) * (0.6 + t), Color(BLUE, 0.3 * t))
	else:
		var t := clampf(_age / EXPLOSION_TIME, 0.0, 1.0)
		if t < 1.0:
			draw_circle(Vector2.ZERO, _radius * (0.35 + 0.65 * t), Color(1.0, 0.5, 0.15, 0.5 * (1.0 - t)))
			draw_circle(Vector2.ZERO, _radius * 0.7 * (0.5 + 0.5 * t), Color(1.0, 0.75, 0.3, 0.7 * (1.0 - t)))
			draw_circle(Vector2.ZERO, _radius * 0.4 * (1.0 - t * 0.6), Color(1.0, 0.96, 0.8, 0.95 * (1.0 - t)))
			draw_arc(Vector2.ZERO, _radius * (0.4 + 1.2 * t), 0.0, TAU, 44, Color(1.0, 0.85, 0.5, 0.75 * (1.0 - t)), 4.0 * (1.0 - t) + 1.0)
