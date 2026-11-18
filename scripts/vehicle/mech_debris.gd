class_name MechDebris
extends Node2D
## A piece that has come off the mech (a leg that snapped, or the parts of it when it explodes): it tumbles through the air under gravity,
## bounces once on a floor it lands on, then fades away.

# GRAVITY: how fast it falls (pixels per second squared). LIFETIME: seconds before it has faded out completely (it starts fading after
# FADE_AFTER).
const GRAVITY := 1500.0
const LIFETIME := 2.2
const FADE_AFTER := 1.2

var velocity := Vector2.ZERO
var spin := 0.0
var _age := 0.0
var _bounced := false


## Throw a piece (a picture `texture` drawn with `scale`) from `at` with `velocity` and a spin (radians per second) under `parent`.
static func spawn(parent: Node, texture: Texture2D, at: Vector2, rotation_start: float, piece_scale: Vector2, throw_velocity: Vector2, spin_speed: float) -> MechDebris:
	var d := MechDebris.new()
	var sp := Sprite2D.new()
	sp.texture = texture
	sp.scale = piece_scale
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	d.add_child(sp)
	d.global_position = at
	d.rotation = rotation_start
	d.velocity = throw_velocity
	d.spin = spin_speed
	d.z_index = 3
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
		var query := PhysicsRayQueryParameters2D.create(from, to + Vector2(0.0, 6.0), Player.LAYER_WORLD)
		var hit := get_world_2d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			to = hit["position"] - Vector2(0.0, 4.0)
			velocity.y = -velocity.y * 0.35 if not _bounced else 0.0
			velocity.x *= 0.6
			spin *= 0.5
			_bounced = true
	global_position = to
	rotation += spin * delta
	if _age > FADE_AFTER:
		modulate.a = 1.0 - (_age - FADE_AFTER) / (LIFETIME - FADE_AFTER)
