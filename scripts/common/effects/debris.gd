class_name Debris
extends Node2D
## A piece that has come off something (a leg that snapped, the parts of an exploding vehicle): it tumbles through the air under gravity, bounces once
## on a floor it lands on, then fades away.

# GRAVITY: how fast it falls (pixels per second squared). LIFETIME: seconds before it has faded out completely (it starts fading after
# FADE_AFTER).
const GRAVITY := 1500.0
const LIFETIME := 2.2
const FADE_AFTER := 1.2

# BOUNCE_KEEP: how much of its fall speed it keeps (reversed) on the one bounce; SLIDE_KEEP: how much sideways speed and spin it keeps after it.
# REST_LIFT: how far above the floor it comes to rest, in pixels.
const BOUNCE_KEEP := 0.35
const SLIDE_KEEP := 0.6
const SPIN_KEEP := 0.5
const REST_LIFT := 4.0

# Drawn above the player and the world around.
const Z := 3

var velocity := Vector2.ZERO
var spin := 0.0
var _age := 0.0
var _bounced := false


## Throw a piece (a picture `texture` drawn with `piece_scale`) from `at` at the angle `rotation_start` with `throw_velocity` and a spin (radians
## per second) under `parent`.
static func spawn(parent: Node, texture: Texture2D, at: Vector2, rotation_start: float, piece_scale: Vector2, throw_velocity: Vector2, spin_speed: float) -> Debris:
	var d := Debris.new()
	var sp := Sprites.make(texture)
	sp.scale = piece_scale
	d.add_child(sp)
	d.global_position = at
	d.rotation = rotation_start
	d.velocity = throw_velocity
	d.spin = spin_speed
	d.z_index = Z
	parent.add_child(d)
	return d


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		queue_free()
		return
	velocity.y += GRAVITY * delta
	var from := global_position
	var to := from + velocity * delta
	if velocity.y > 0.0:
		var query := PhysicsRayQueryParameters2D.create(from, to + Vector2(0.0, 6.0), PhysicsLayers.WORLD)
		var hit := get_world_2d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			to = hit["position"] - Vector2(0.0, REST_LIFT)
			velocity.y = -velocity.y * BOUNCE_KEEP if not _bounced else 0.0
			velocity.x *= SLIDE_KEEP
			spin *= SPIN_KEEP
			_bounced = true
	global_position = to
	rotation += spin * delta
	if _age > FADE_AFTER:
		modulate.a = 1.0 - (_age - FADE_AFTER) / (LIFETIME - FADE_AFTER)
