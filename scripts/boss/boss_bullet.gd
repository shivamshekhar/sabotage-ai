class_name BossBullet
extends Node2D
## A piece of stolen hardware (a RAM stick, a CPU or a chipset) sprayed by the salt shaker boss (see SaltShakerBoss). It tumbles through
## the air under gravity, hurts the player if it touches them, and shatters in a burst of sparks when it hits the floor or a wall. A
## bullet made with harmful = false is just debris (it is what the boss spills when it is defeated).

# KINDS: the pictures a bullet can have (assets/bosses/<name>.png) and how big each hit box is, in pixels.
const KINDS := {
	"ram_stick": {"radius": 26.0},
	"cpu": {"radius": 24.0},
	"chipset": {"radius": 22.0},
}

# SPRITE_SCALE: drawn size as a fraction of the picture (they are small, 0.3 of the pictures' size). The hit boxes shrink with it.
const SPRITE_SCALE := 0.3

# GRAVITY: downward acceleration in pixels per second squared. Higher: the pieces drop faster and steeper.
const GRAVITY := 900.0

# SPIN_SPEED: the most a piece tumbles, in radians per second (each one gets its own random spin up to this).
const SPIN_SPEED := 9.0

# LIFETIME: seconds before a piece that hit nothing disappears.
const LIFETIME := 6.0

# DAMAGE_FRACTION: share of the player's maximum health one hit takes.
const DAMAGE_FRACTION := 0.12

var kind := "ram_stick"
var velocity := Vector2.ZERO
var harmful := true

var _age := 0.0
var _spin := 0.0
var _done := false
var _sprite: Sprite2D


## Create a bullet of `kind` at `from` moving at `velocity` and add it under `parent`.
static func spray(parent: Node, kind_name: String, from: Vector2, speed: Vector2, hurts: bool = true) -> BossBullet:
	var b := BossBullet.new()
	b.kind = kind_name
	b.position = from
	b.velocity = speed
	b.harmful = hurts
	parent.add_child(b)
	return b


func _ready() -> void:
	z_index = 3
	_spin = randf_range(-SPIN_SPEED, SPIN_SPEED)
	rotation = randf() * TAU
	_sprite = Sprite2D.new()
	_sprite.texture = AssetPaths.boss(kind)
	_sprite.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
	add_child(_sprite)
	if harmful:
		add_to_group(Groups.BOSS_BULLETS)


func _physics_process(delta: float) -> void:
	if _done:
		return
	_age += delta
	if _age > LIFETIME:
		queue_free()
		return
	var from := global_position
	var to := from + velocity * delta
	# a floor or a wall: a ray from here to there, so a fast piece cannot skip through
	var query := PhysicsRayQueryParameters2D.create(from, to, PhysicsLayers.WORLD)
	for p in get_tree().get_nodes_in_group(Groups.PLAYER):
		query.exclude.append((p as CollisionObject2D).get_rid())
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		_shatter(hit["position"], hit["normal"])
		return
	global_position = to
	velocity.y += GRAVITY * LevelData.gravity_scale * delta
	rotation += _spin * delta
	if harmful:
		_hit_player()


func _hit_player() -> void:
	var radius: float = float(KINDS[kind]["radius"]) * SPRITE_SCALE
	for p in get_tree().get_nodes_in_group(Groups.PLAYER):
		var player := p as Player
		var body := Rect2(player.global_position + Vector2(-Player.BODY_SIZE.x / 2.0, -Player.BODY_SIZE.y), Player.BODY_SIZE)
		if body.grow(radius).has_point(global_position):
			if player.take_damage(roundi(player.max_health * DAMAGE_FRACTION), global_position.x):
				_shatter(global_position, -velocity.normalized())
			return


## Burst into sparks and vanish.
func _shatter(at: Vector2, normal: Vector2) -> void:
	_done = true
	remove_from_group(Groups.BOSS_BULLETS)
	var sparks := CPUParticles2D.new()
	sparks.top_level = true
	sparks.global_position = at
	sparks.z_index = 3
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	sparks.amount = 12
	sparks.lifetime = 0.45
	sparks.direction = normal
	sparks.spread = 70.0
	sparks.gravity = Vector2(0, 700)
	sparks.initial_velocity_min = 90.0
	sparks.initial_velocity_max = 260.0
	sparks.scale_amount_min = 2.0
	sparks.scale_amount_max = 4.0
	sparks.color = Color(1.0, 0.85, 0.4)
	get_parent().add_child(sparks)
	sparks.emitting = true
	get_tree().create_timer(0.6).timeout.connect(sparks.queue_free)
	queue_free()
