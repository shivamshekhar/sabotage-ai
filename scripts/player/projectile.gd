class_name Projectile
extends Node2D
## An everyday object (a painting, a cat photo, a paintbrush...) thrown by the player. It follows a
## true ballistic arc: constant horizontal speed, vertical speed changed by gravity every step,
##     position += velocity * dt;   velocity.y += GRAVITY * dt
## which is a parabola, like a thrown stone. It spins while it flies and disappears when it hits
## a wall or floor, or an enemy (which takes DAMAGE hit points). A thing made of fire (a lava ball, see
## PitCreature.burns_projectiles()) is not hurt: the object burns up instead. An object that falls into a deadly pit sinks out of
## sight for good (it never lies at the bottom, where its edge would show past the liquid). A burning thrower throws shorter (see launch()).

# THROW_SPEED: launch speed in pixels per second, along the throw angle.
#     horizontal speed = THROW_SPEED * cos(THROW_ANGLE),   vertical = -THROW_SPEED * sin(THROW_ANGLE)
#     range on flat ground = THROW_SPEED^2 * sin(2 * THROW_ANGLE) / GRAVITY
# Higher: a longer, flatter throw. Lower: a short lob.
const THROW_SPEED := 550.0

# THROW_ANGLE_DEGREES: angle above the horizontal the object is thrown at. Around 45 gives the
# longest range for a given speed; lower is a flatter shot, higher a lob.
const THROW_ANGLE_DEGREES := 30.0

# GRAVITY: downward acceleration of a thrown object, in pixels per second squared. Higher: a
# steeper, shorter arc and a quicker fall. Lower: a floaty, longer arc. It is separate from the
# player's GRAVITY so objects can be tuned to look right without changing jumps.
const GRAVITY := 1500.0

# INHERIT_VELOCITY: how much of the player's own horizontal speed is added to the throw, as a
# fraction (0 = none, 1 = all of it). Running while throwing then carries the object a bit further,
# as it would in real life.
const INHERIT_VELOCITY := 0.5

# SPIN_SPEED: how fast the object tumbles, in radians per second (in the throwing direction).
# 0 = it keeps its orientation. Purely visual.
const SPIN_SPEED := 7.0

# SPRITE_SCALE: drawn size = the 32px art * SPRITE_SCALE. Kept small so a throw is readable but
# not a screen-filling slab; pixel art stays crisp (nearest-neighbour filtering).
const SPRITE_SCALE := 1.25

# DAMAGE: the hit points one thrown object takes off an enemy (a Bro has Player.MAX_HEALTH * AIBro.HEALTH_FRACTION = 20, so two throws beat one).
# Higher: enemies die in fewer hits.
const DAMAGE := 10

# REST_TIME: seconds a thrown object lies on the ground, fully visible, before it starts to blink.
# Higher: players get longer to see what they threw. Lower: the floor clears quickly.
const REST_TIME := 0.5

# BLINK_TIME: seconds the resting object blinks before it disappears (BLINK_PERIOD is one on/off cycle).
const BLINK_TIME := 0.8
const BLINK_PERIOD := 0.16

# BOUNCE_KEEP: when an object hits a wall or ceiling it loses most of its sideways speed and drops
# to the floor; this is the share of that sideways speed it keeps, reversed (0 = it slides straight down
# the wall, 1 = a perfect bounce).
const BOUNCE_KEEP := 0.2

# REST_SINK: how many pixels the resting sprite sinks into the floor, so it looks like it lies on it
# rather than hovering. Purely visual.
const REST_SINK := 4.0

# HIT_RADIUS: how far in pixels around the object's centre counts as touching an enemy. Enemies are tested
# directly against the object's path each step (not through the physics engine), so a fast object
# can't slip through and one that starts inside an enemy still hits it. Higher: more forgiving hits.
const HIT_RADIUS := 16.0

# LIFETIME: seconds before a thrown object that hit nothing disappears.
const LIFETIME := 4.0

var velocity := Vector2.ZERO
var object_name := ""

var _age := 0.0
var _spin_dir := 1.0
var _sprite: Sprite2D
var _done := false
var _landed := false


## Create a projectile of the named object (see SpriteLibrary.PROJECTILES) at `from`, thrown towards
## `facing` (1 right, -1 left) by someone moving at `thrower_velocity`, and add it under `parent`. `range_scale` is how far it should
## go compared with a normal throw (0.5 = half): the range of a ballistic throw grows with the square of its speed, so the whole
## launch velocity is multiplied by the square root of it.
static func launch(parent: Node, name: String, from: Vector2, facing: int, thrower_velocity: Vector2, range_scale: float = 1.0) -> Projectile:
	var p := Projectile.new()
	p.object_name = name
	p.position = from
	var angle := deg_to_rad(THROW_ANGLE_DEGREES)
	p.velocity = Vector2(facing * THROW_SPEED * cos(angle) + thrower_velocity.x * INHERIT_VELOCITY, -THROW_SPEED * sin(angle)) * sqrt(range_scale)
	p._spin_dir = float(facing)
	parent.add_child(p)
	return p


func _ready() -> void:
	z_index = 3
	add_to_group(Groups.PROJECTILES)
	_sprite = Sprite2D.new()
	_sprite.texture = SpriteLibrary.projectile(object_name)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
	add_child(_sprite)


func _physics_process(delta: float) -> void:
	if _done or _landed:
		return
	_age += delta
	if _age > LIFETIME:
		_finish()
		return
	var from := global_position
	var to := from + velocity * delta
	if _in_a_pit(to):
		_sink()
		return
	# 1. Did this step pass through an enemy? Every enemy's hit box is tested against the step's line.
	for e in get_tree().get_nodes_in_group(Groups.ENEMIES):
		if Geom.segment_hits_rect(from, to, e.hurtbox().grow(HIT_RADIUS)):
			if e.has_method("burns_projectiles") and e.burns_projectiles():
				_burn_up()
				return
			e.take_hit(DAMAGE, from.x)
			_finish()
			return
	# 2. Did it run into a wall, a floor, a crate or a ledge? (A ray from here to there: it can't skip through.)
	var query := PhysicsRayQueryParameters2D.create(from, to, PhysicsLayers.WORLD)
	for p in get_tree().get_nodes_in_group(Groups.PLAYER):
		query.exclude = [(p as CollisionObject2D).get_rid()]   # the thrower is on the world layer too
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var normal: Vector2 = hit["normal"]
		if normal.y < -0.5:
			_land(hit["position"])          # came down on a floor, a crate or a ledge
		else:
			# a wall or ceiling: lose most of the sideways speed and drop
			global_position = hit["position"] + normal * 2.0
			velocity.x = -velocity.x * BOUNCE_KEEP
			velocity.y = maxf(velocity.y, 0.0) * 0.5
		return
	global_position = to
	velocity.y += GRAVITY * LevelData.gravity_scale * delta
	_sprite.rotation += SPIN_SPEED * _spin_dir * delta


## Come to rest on the surface point `at`, stay visible for REST_TIME, then blink for BLINK_TIME and disappear.
func _land(at: Vector2) -> void:
	_landed = true
	velocity = Vector2.ZERO
	var half := _sprite.texture.get_height() * SPRITE_SCALE / 2.0
	global_position = at + Vector2(0.0, -half + REST_SINK)
	reset_physics_interpolation()
	_sprite.rotation = randf_range(-0.25, 0.25)   # settle, slightly askew
	remove_from_group(Groups.PROJECTILES)   # no longer in flight
	add_to_group(Groups.LANDED_PROJECTILES)
	await get_tree().create_timer(REST_TIME).timeout
	var cycles := maxi(1, roundi(BLINK_TIME / BLINK_PERIOD))
	var tw := create_tween().set_loops(cycles)
	tw.tween_property(_sprite, "modulate:a", 0.15, BLINK_PERIOD / 2.0)
	tw.tween_property(_sprite, "modulate:a", 1.0, BLINK_PERIOD / 2.0)
	await tw.finished
	queue_free()


## True if the point is inside the liquid of a deadly pit.
func _in_a_pit(point: Vector2) -> bool:
	for pit in get_tree().get_nodes_in_group(Groups.PITS):
		if (pit as PitHazard).liquid_rect().has_point(point):
			return true
	return false


# SINK_TIME: seconds a thrown object takes to sink out of sight in a pit.
const SINK_TIME := 0.18


## Fell into a pit: it slips under the liquid and is gone.
func _sink() -> void:
	_done = true
	velocity = Vector2.ZERO
	remove_from_group(Groups.PROJECTILES)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_sprite, "modulate:a", 0.0, SINK_TIME)
	tw.tween_property(_sprite, "scale", Vector2(0.6, 0.6) * SPRITE_SCALE, SINK_TIME)
	await tw.finished
	queue_free()


# BURN_TIME: seconds a thrown object takes to burn up when it flies into fire.
const BURN_TIME := 0.5


## Flew into fire: the object blackens, shrivels and burns away in a burst of embers (the fire is not hurt).
func _burn_up() -> void:
	_done = true
	velocity = Vector2.ZERO
	remove_from_group(Groups.PROJECTILES)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_sprite, "modulate", Color(0.25, 0.1, 0.05, 0.0), BURN_TIME).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(_sprite, "scale", Vector2(0.25, 0.25) * SPRITE_SCALE, BURN_TIME)
	_sprite.self_modulate = Color(1.6, 0.7, 0.3)   # glows hot first
	var p := CPUParticles2D.new()
	p.texture = PitHazard.glow_texture()
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = add
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = 16
	p.lifetime = 0.6
	p.direction = Vector2(0, -1)
	p.spread = 80.0
	p.gravity = Vector2(0, -40)
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 130.0
	p.scale_amount_min = 0.04
	p.scale_amount_max = 0.12
	p.color = Color(1.0, 0.55, 0.15, 1.0)
	add_child(p)
	p.emitting = true
	await get_tree().create_timer(BURN_TIME + 0.1).timeout
	queue_free()


func _finish() -> void:
	_done = true
	queue_free()
