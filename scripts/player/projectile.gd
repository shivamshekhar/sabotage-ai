class_name Projectile
extends Node2D
## An everyday object (a painting, a cat photo, a paintbrush...) thrown by the player. It follows a
## true ballistic arc: constant horizontal speed, vertical speed changed by gravity every step,
##     position += velocity * dt;   velocity.y += GRAVITY * dt
## which is a parabola, like a thrown stone. It spins while it flies and disappears when it hits
## a wall or floor, or an enemy (which takes HIT_FRACTION of its health).

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

# HIT_FRACTION: share of an enemy's maximum health taken by one hit.
#     damage = round(enemy max health * HIT_FRACTION)
# Higher: enemies die in fewer hits.
const HIT_FRACTION := 0.5

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
## `facing` (1 right, -1 left) by someone moving at `thrower_velocity`, and add it under `parent`.
static func launch(parent: Node, name: String, from: Vector2, facing: int, thrower_velocity: Vector2) -> Projectile:
	var p := Projectile.new()
	p.object_name = name
	p.position = from
	var angle := deg_to_rad(THROW_ANGLE_DEGREES)
	p.velocity = Vector2(facing * THROW_SPEED * cos(angle) + thrower_velocity.x * INHERIT_VELOCITY, -THROW_SPEED * sin(angle))
	p._spin_dir = float(facing)
	parent.add_child(p)
	return p


func _ready() -> void:
	z_index = 3
	add_to_group("projectiles")
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
	var next := position + velocity * delta
	# Did the step run into a wall, a floor or an enemy? (A ray from here to there: fast objects can't skip through.)
	var query := PhysicsRayQueryParameters2D.create(global_position, global_position + velocity * delta,
		Player.LAYER_WORLD | Player.LAYER_ENEMY)
	for p in get_tree().get_nodes_in_group("player"):
		query.exclude.append((p as CollisionObject2D).get_rid())   # the thrower is on the world layer too
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var target: Object = hit["collider"]
		if target.has_method("take_hit"):
			target.take_hit(HIT_FRACTION, global_position.x)
			_finish()
			return
		var normal: Vector2 = hit["normal"]
		if normal.y < -0.5:
			_land(hit["position"])          # came down on a floor, a crate or a ledge
		else:
			# a wall or ceiling: lose most of the sideways speed and drop
			global_position = hit["position"] + normal * 2.0
			velocity.x = -velocity.x * BOUNCE_KEEP
			velocity.y = maxf(velocity.y, 0.0) * 0.5
		return
	position = next
	velocity.y += GRAVITY * delta
	_sprite.rotation += SPIN_SPEED * _spin_dir * delta


## Come to rest on the surface point `at`, stay visible for REST_TIME, then blink for BLINK_TIME and disappear.
func _land(at: Vector2) -> void:
	_landed = true
	velocity = Vector2.ZERO
	var half := _sprite.texture.get_height() * SPRITE_SCALE / 2.0
	global_position = at + Vector2(0.0, -half + REST_SINK)
	_sprite.rotation = randf_range(-0.25, 0.25)   # settle, slightly askew
	remove_from_group("projectiles")   # no longer in flight
	add_to_group("landed_projectiles")
	await get_tree().create_timer(REST_TIME).timeout
	var cycles := maxi(1, roundi(BLINK_TIME / BLINK_PERIOD))
	var tw := create_tween().set_loops(cycles)
	tw.tween_property(_sprite, "modulate:a", 0.15, BLINK_PERIOD / 2.0)
	tw.tween_property(_sprite, "modulate:a", 1.0, BLINK_PERIOD / 2.0)
	await tw.finished
	queue_free()


func _finish() -> void:
	_done = true
	queue_free()
