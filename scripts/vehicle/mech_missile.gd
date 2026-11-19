class_name MechMissile
extends Node2D
## A missile from the mech's missile turret: it leaves slowly, speeds up, steers a little towards the nearest enemy ahead of it and blows up on a wall,
## the floor or an enemy, hurting every enemy within Mech.BLAST_RADIUS. It has an exhaust flame, a glow, sparks and a trail of smoke.

# START_SPEED / TOP_SPEED / ACCEL: how fast it flies (pixels per second) and how quickly it gets there.
const START_SPEED := 320.0
const TOP_SPEED := 760.0
const ACCEL := 900.0

# TURN_RATE: how fast it can steer towards a target, radians per second (0 = it flies straight). HOMING_RANGE: how near a target must be.
# HOMING_CONE: how far ahead of the missile (cosine of the angle) a target must be to be steered at.
const TURN_RATE := 2.2
const HOMING_RANGE := 520.0
const HOMING_CONE := 0.3

# LIFETIME: seconds before it burns out and blows up anyway. HIT_MARGIN: how far round an enemy's hit box a pass still hits, in pixels.
const LIFETIME := 2.6
const HIT_MARGIN := 8.0

# EXPLOSION_STRENGTH: the size of the explosion (see Explosion; 1 is a vehicle's own).
const EXPLOSION_STRENGTH := 0.55

# SPRITE_SCALE: the pictures are twice their size on screen. NOZZLE_X: where the nozzle is, in pixels from the missile's middle.
const SPRITE_SCALE := 0.5
const NOZZLE_X := -26.0

# The exhaust flame: FLAME_VARIANTS pictures cycled FLAME_FPS times a second, flickering; it grows to full length in FLAME_GROW seconds. Its picture is
# FLAME_PICTURE_SIZE px (height is half of it) and ends at the nozzle. The glow round the tail pulses.
const FLAME_VARIANTS := 3
const FLAME_FPS := 30.0
const FLAME_GROW := 1.0 / 6.0
const FLAME_FLICKER := Vector2(0.85, 0.25)           # (average, swing) of the flicker
const FLAME_FLICKER_SPEED := 70.0
const FLAME_PICTURE_SIZE := Vector2(170.0, 52.0)
const GLOW_SIZE := Vector2(1.2, 0.25)                 # (average scale, swing)
const GLOW_PULSE_SPEED := 55.0
const GLOW_OFFSET := 4.0

# The smoke trail and the sparks thrown out of the exhaust.
const SMOKE_VARIANTS := 3
const SMOKE_AMOUNT := 26
const SMOKE_LIFE := 0.8
const SMOKE_SIZE := Vector2(0.13, 0.22)
const SMOKE_GROWTH := Vector2(0.6, 1.9)
const SMOKE_BEHIND := 14.0
const SPARK_AMOUNT := 14
const SPARK_LIFE := 0.35
const SPARK_SPEED := Vector2(60.0, 190.0)
const SPARK_SIZE := Vector2(0.12, 0.26)

var velocity := Vector2.ZERO
var mech: Mech
var _age := 0.0
var _speed := START_SPEED
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
	add_child(Sprites.make(AssetPaths.mech("missile"), SPRITE_SCALE))
	# the glow round the tail and the exhaust flame (the flame's picture ends at the nozzle: its right edge is at NOZZLE_X)
	_glow = Sprites.glow(AssetPaths.effect("missile_glow"), GLOW_SIZE.x, -1)
	_glow.position = Vector2(NOZZLE_X - GLOW_OFFSET, 0.0)
	add_child(_glow)
	_flame = Sprites.glow(AssetPaths.mech("missile_flame_1"), SPRITE_SCALE, -1, false)
	_flame.offset = Vector2(-FLAME_PICTURE_SIZE.x, -FLAME_PICTURE_SIZE.y / 2.0)
	_flame.position = Vector2(NOZZLE_X, 0.0)
	add_child(_flame)
	_animate_flame()
	# the smoke trail (it stays where it was made, not on the missile): soft puffs that grow and fade
	var smoke := ParticlePreset.new()
	smoke.texture = AssetPaths.effect("smoke_%d" % (randi() % SMOKE_VARIANTS + 1))
	smoke.world_space = true
	smoke.one_shot = false
	smoke.explosiveness = 0.0
	smoke.amount = SMOKE_AMOUNT
	smoke.lifetime = SMOKE_LIFE
	smoke.direction = Vector2.ZERO
	smoke.speed_min = 4.0
	smoke.speed_max = 20.0
	smoke.gravity = Vector2(0.0, -16.0)
	smoke.random_angle = true
	smoke.scale_min = SMOKE_SIZE.x
	smoke.scale_max = SMOKE_SIZE.y
	smoke.grow = ParticlePreset.grow_curve(SMOKE_GROWTH.x, SMOKE_GROWTH.y)
	smoke.colors = ParticlePreset.fade_gradient([Color(1.0, 0.8, 0.5, 0.0), Color(0.78, 0.76, 0.78, 0.75), Color(0.35, 0.35, 0.4, 0.0)])
	var trail := smoke.build()
	trail.position = Vector2(NOZZLE_X - SMOKE_BEHIND, 0.0)
	add_child(trail)
	# sparks thrown out of the exhaust
	var sparks := ParticlePreset.new()
	sparks.texture = AssetPaths.effect("spark")
	sparks.additive = true
	sparks.one_shot = false
	sparks.explosiveness = 0.0
	sparks.amount = SPARK_AMOUNT
	sparks.lifetime = SPARK_LIFE
	sparks.direction = Vector2.LEFT
	sparks.spread = 28.0
	sparks.speed_min = SPARK_SPEED.x
	sparks.speed_max = SPARK_SPEED.y
	sparks.gravity = Vector2(0.0, 220.0)
	sparks.scale_min = SPARK_SIZE.x
	sparks.scale_max = SPARK_SIZE.y
	sparks.colors = ParticlePreset.fade_gradient([Color(1.0, 0.95, 0.7, 1.0), Color(1.0, 0.45, 0.1, 0.0)])
	var exhaust := sparks.build()
	exhaust.position = Vector2(NOZZLE_X - 6.0, 0.0)
	add_child(exhaust)


func _animate_flame() -> void:
	_flame.texture = AssetPaths.mech("missile_flame_%d" % (int(_age * FLAME_FPS) % FLAME_VARIANTS + 1))
	var k := FLAME_FLICKER.x + FLAME_FLICKER.y * sin(_age * FLAME_FLICKER_SPEED)
	_flame.scale = Vector2(SPRITE_SCALE * (0.35 + 0.65 * minf(1.0, _age / FLAME_GROW)) * k, SPRITE_SCALE)
	_glow.scale = Vector2.ONE * (GLOW_SIZE.x + GLOW_SIZE.y * sin(_age * GLOW_PULSE_SPEED))


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
	for e in get_tree().get_nodes_in_group(Groups.ENEMIES):
		if Geom.segment_hits_rect(from, to, (e.hurtbox() as Rect2).grow(HIT_MARGIN)):
			_explode()
			return
	# a wall or the floor?
	var query := PhysicsRayQueryParameters2D.create(from, to, PhysicsLayers.WORLD)
	if mech != null and is_instance_valid(mech):
		query.exclude.append(mech.player.get_rid())
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		global_position = hit["position"]
		_explode()
		return
	global_position = to


## The middle of the nearest enemy ahead of the missile within HOMING_RANGE, or null.
func _homing_target() -> Variant:
	var best: Variant = null
	var best_d := HOMING_RANGE
	for e in get_tree().get_nodes_in_group(Groups.ENEMIES):
		var c := (e.hurtbox() as Rect2).get_center()
		var d := global_position.distance_to(c)
		var ahead := (c - global_position).normalized().dot(velocity.normalized())
		if d < best_d and ahead > HOMING_CONE:
			best_d = d
			best = c
	return best


func _explode() -> void:
	_done = true
	if mech != null and is_instance_valid(mech):
		mech.blast(global_position)
	Explosion.spawn(get_parent(), global_position, EXPLOSION_STRENGTH)
	queue_free()
