class_name MechMissile
extends Node2D
## A missile from the mech's missile turret: it leaves slowly, speeds up, steers a little towards the nearest enemy ahead of it and
## blows up on a wall, the floor or an enemy, hurting every enemy within Mech.BLAST_RADIUS. It leaves a trail of smoke.

# START_SPEED / TOP_SPEED / ACCEL: how fast it flies (pixels per second) and how quickly it gets there.
const START_SPEED := 320.0
const TOP_SPEED := 760.0
const ACCEL := 900.0

# TURN_RATE: how fast it can steer towards a target, radians per second (0 = it flies straight). HOMING_RANGE: how near a target must be.
const TURN_RATE := 2.2
const HOMING_RANGE := 520.0

# LIFETIME: seconds before it burns out and blows up anyway.
const LIFETIME := 2.6

# SPRITE_SCALE: the pictures are twice their size on screen. NOZZLE_X: where the nozzle is, in pixels from the missile's middle.
const SPRITE_SCALE := 0.5
const NOZZLE_X := -26.0

var velocity := Vector2.ZERO
var mech: Mech
var _age := 0.0
var _speed := START_SPEED
var _sprite: Sprite2D
var _trail: CPUParticles2D
var _sparks: CPUParticles2D
var _flame: Sprite2D
var _glow: Sprite2D
var _done := false


static func launch(parent: Node, from: Vector2, dir: Vector2, owner_mech: Mech) -> MechMissile:
	var m := MechMissile.new()
	m.mech = owner_mech
	m.position = from
	m.rotation = dir.angle()
	m.velocity = dir.normalized() * START_SPEED
	parent.add_child(m)
	return m


func _ready() -> void:
	z_index = 3
	_sprite = Sprite2D.new()
	_sprite.texture = load("res://assets/powerups/mech/missile.png")
	_sprite.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(_sprite)
	# the glow round the tail and the exhaust flame (the flame's picture ends at the nozzle: its right edge is at NOZZLE_X)
	_glow = Sprite2D.new()
	_glow.texture = load("res://assets/powerups/mech/missile_glow.png")
	_glow.position = Vector2(NOZZLE_X - 4.0, 0.0)
	_glow.material = _additive()
	_glow.z_index = -1
	_glow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(_glow)
	_flame = Sprite2D.new()
	_flame.centered = false
	_flame.offset = Vector2(-170.0, -26.0)
	_flame.position = Vector2(NOZZLE_X, 0.0)
	_flame.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
	_flame.material = _additive()
	_flame.z_index = -1
	_flame.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(_flame)
	_animate_flame()
	# the smoke trail (it stays where it was made, not on the missile): soft puffs that grow and fade
	_trail = CPUParticles2D.new()
	_trail.texture = load("res://assets/powerups/mech/smoke_%d.png" % (randi() % 3 + 1))
	_trail.local_coords = false
	_trail.amount = 26
	_trail.lifetime = 0.8
	_trail.direction = Vector2.ZERO
	_trail.spread = 180.0
	_trail.initial_velocity_min = 4.0
	_trail.initial_velocity_max = 20.0
	_trail.gravity = Vector2(0.0, -16.0)
	_trail.angle_min = -180.0
	_trail.angle_max = 180.0
	_trail.scale_amount_min = 0.13
	_trail.scale_amount_max = 0.22
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.6))
	grow.add_point(Vector2(1.0, 1.9))
	_trail.scale_amount_curve = grow
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.15, 1.0])
	ramp.colors = PackedColorArray([Color(1.0, 0.8, 0.5, 0.0), Color(0.78, 0.76, 0.78, 0.75), Color(0.35, 0.35, 0.4, 0.0)])
	_trail.color_ramp = ramp
	_trail.position = Vector2(NOZZLE_X - 14.0, 0.0)
	add_child(_trail)
	# sparks thrown out of the exhaust
	_sparks = CPUParticles2D.new()
	_sparks.texture = load("res://assets/powerups/mech/spark.png")
	_sparks.material = _additive()
	_sparks.local_coords = false
	_sparks.amount = 14
	_sparks.lifetime = 0.35
	_sparks.direction = Vector2(-1.0, 0.0)
	_sparks.spread = 28.0
	_sparks.initial_velocity_min = 60.0
	_sparks.initial_velocity_max = 190.0
	_sparks.gravity = Vector2(0.0, 220.0)
	_sparks.scale_amount_min = 0.12
	_sparks.scale_amount_max = 0.26
	var sramp := Gradient.new()
	sramp.offsets = PackedFloat32Array([0.0, 1.0])
	sramp.colors = PackedColorArray([Color(1.0, 0.95, 0.7, 1.0), Color(1.0, 0.45, 0.1, 0.0)])
	_sparks.color_ramp = sramp
	_sparks.position = Vector2(NOZZLE_X - 6.0, 0.0)
	add_child(_sparks)


static func _additive() -> CanvasItemMaterial:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return m


func _animate_flame() -> void:
	_flame.texture = load("res://assets/powerups/mech/missile_flame_%d.png" % (int(_age * 30.0) % 3 + 1))
	var k := 0.85 + 0.25 * sin(_age * 70.0)
	_flame.scale = Vector2(SPRITE_SCALE * (0.35 + 0.65 * minf(1.0, _age * 6.0)) * k, SPRITE_SCALE)
	_glow.scale = Vector2.ONE * (1.2 + 0.25 * sin(_age * 55.0))
	_glow.modulate.a = 0.9


func _physics_process(delta: float) -> void:
	if _done:
		return
	_age += delta
	if _age > LIFETIME:
		_explode()
		return
	_speed = minf(TOP_SPEED, _speed + ACCEL * delta)
	_animate_flame()
	var target = _homing_target()
	var heading := velocity.angle()
	if target != null:
		var want: float = (target - global_position).angle()
		heading += clampf(angle_difference(heading, want), -TURN_RATE * delta, TURN_RATE * delta)
	velocity = Vector2.from_angle(heading) * _speed
	rotation = heading
	var from := global_position
	var to := from + velocity * delta
	# an enemy on the way?
	for e in get_tree().get_nodes_in_group("enemies"):
		if _segment_hits(from, to, (e.hurtbox() as Rect2).grow(8.0)):
			_explode()
			return
	# a wall or the floor?
	var query := PhysicsRayQueryParameters2D.create(from, to, Player.LAYER_WORLD)
	if mech != null and is_instance_valid(mech):
		query.exclude.append(mech.player.get_rid())
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		global_position = hit["position"]
		_explode()
		return
	global_position = to


func _homing_target() -> Variant:
	var best: Variant = null
	var best_d := HOMING_RANGE
	for e in get_tree().get_nodes_in_group("enemies"):
		var c := (e.hurtbox() as Rect2).get_center()
		var d := global_position.distance_to(c)
		var ahead := (c - global_position).normalized().dot(velocity.normalized())
		if d < best_d and ahead > 0.3:
			best_d = d
			best = c
	return best


func _segment_hits(a: Vector2, b: Vector2, r: Rect2) -> bool:
	var t0 := 0.0
	var t1 := 1.0
	var d := b - a
	for axis in 2:
		if absf(d[axis]) < 0.00001:
			if a[axis] < r.position[axis] or a[axis] > r.end[axis]:
				return false
		else:
			var ta: float = (r.position[axis] - a[axis]) / d[axis]
			var tb: float = (r.end[axis] - a[axis]) / d[axis]
			t0 = maxf(t0, minf(ta, tb))
			t1 = minf(t1, maxf(ta, tb))
			if t0 > t1:
				return false
	return true


func _explode() -> void:
	_done = true
	if mech != null and is_instance_valid(mech):
		mech.blast(global_position)
	MechBeam.explosion(get_parent(), global_position, 0.55)
	queue_free()
