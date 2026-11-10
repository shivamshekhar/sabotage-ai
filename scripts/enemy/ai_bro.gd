class_name AIBro
extends CharacterBody2D
## The first enemy: an "AI Bro" (a zombie sprite). It paces back and forth around its home spot, never
## stepping off its ledge. When the player comes close and the Bro is facing them, it chases. Close
## up it hits the player (damage and a flinch). It can be hurt by thrown objects (Projectile).
## Spikes on the floor don't hurt it, but falling into a spike pit too deep to climb out of kills it.
## Origin is at the feet, like the player.

signal defeated

# HEALTH_FRACTION: the Bro's maximum health as a share of the player's (Player.MAX_HEALTH).
#     max health = round(Player.MAX_HEALTH * HEALTH_FRACTION)
# Higher: tougher Bros (more thrown objects to beat one). Lower: they fold quickly.
const HEALTH_FRACTION := 0.2

# CONTACT_DAMAGE_FRACTION: share of the player's maximum health taken by one hit from a Bro.
#     damage = round(Player.MAX_HEALTH * CONTACT_DAMAGE_FRACTION)
# Higher: Bros hurt more. The player is also invulnerable for Player.INVULN_TIME after any hit.
const CONTACT_DAMAGE_FRACTION := 0.1

# PATROL_SPEED / CHASE_SPEED: walking speed while pacing and while chasing, in pixels per second.
# Keep CHASE_SPEED below the player's Player.SPEED so the player can outrun a Bro.
const PATROL_SPEED := 90.0
const CHASE_SPEED := 170.0

# PATROL_RADIUS: how far in pixels the Bro paces either side of its home spot (it also turns at any
# ledge edge or wall sooner). Higher: a longer beat. Lower: it shuffles on the spot.
const PATROL_RADIUS := 160.0

# SIGHT_RANGE: how far in pixels (horizontally) the Bro can notice the player, and only when it is
# facing them. SIGHT_HEIGHT: how far above or below its feet the player may be and still be noticed.
# Higher SIGHT_RANGE: it spots you from further away. Higher SIGHT_HEIGHT: it also sees you on nearby
# platforms.
const SIGHT_RANGE := 520.0
const SIGHT_HEIGHT := 150.0

# LOSE_RANGE: once chasing, the Bro gives up when the player is further than this many pixels away
# (or more than SIGHT_HEIGHT * 2 above or below), then walks back home. Higher: a more persistent chaser.
const LOSE_RANGE := 900.0

# HIT_RANGE: how close in pixels (horizontally, and within SIGHT_HEIGHT / 2 vertically) the player
# must be for the Bro to strike.
const HIT_RANGE := 75.0

# HIT_COOLDOWN: seconds between a Bro's strikes. Higher: slower attacker.
const HIT_COOLDOWN := 0.9

# EDGE_PROBE: while patrolling, how far ahead in pixels the Bro looks for floor; no floor there
# means turn around. While chasing, it only stops at a drop deeper than DROP_LIMIT: so a Bro will run
# into a spike pit after you (and die), but not off a cliff into the void.
const EDGE_PROBE := 50.0
const DROP_LIMIT := 280.0

# GRAVITY: downward acceleration, in pixels per second squared (same feel as the player's).
const GRAVITY := 2000.0

# BODY_SIZE: the Bro's hitbox in pixels (feet at the node's origin).
const BODY_SIZE := Vector2(56, 120)

# DISPLAY_NAME: the name shown above the Bro's health bar.
const DISPLAY_NAME := "AI Bro"

# BAR_OFFSET: where the health bar sits relative to the feet (negative y = above).
const BAR_OFFSET := Vector2(0, -140)

# HURT_KNOCKBACK: sideways speed in pixels per second when a thrown object lands, away from it.
const HURT_KNOCKBACK := 220.0

enum State { PATROL, CHASE, RETURN }

var max_health := 0
var health := 0
var state := State.PATROL

var _home_x := 0.0
var _dir := 1
var _hit_timer := 0.0
var _hurt_timer := 0.0
var _visuals: PlayerSprite
var _bar: HealthBar
var _dead := false
var _ignoring_player := false


## Contact damage in health points (see CONTACT_DAMAGE_FRACTION).
static func contact_damage() -> int:
	return roundi(Player.MAX_HEALTH * CONTACT_DAMAGE_FRACTION)


## Maximum health in health points (see HEALTH_FRACTION).
static func starting_health() -> int:
	return roundi(Player.MAX_HEALTH * HEALTH_FRACTION)


func _ready() -> void:
	max_health = starting_health()
	health = max_health
	_home_x = global_position.x
	_dir = 1 if randf() < 0.5 else -1
	name = "AIBro"
	z_index = 1
	add_to_group("enemies")
	collision_layer = Player.LAYER_ENEMY
	collision_mask = Player.LAYER_WORLD | Player.LAYER_LADDER_DECK
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = BODY_SIZE
	shape.shape = rect
	shape.position = Vector2(0, -BODY_SIZE.y / 2.0)
	add_child(shape)
	_visuals = PlayerSprite.new()
	_visuals.character = "zombie"
	add_child(_visuals)
	_bar = HealthBar.new()
	_bar.position = BAR_OFFSET
	_bar.set_title(DISPLAY_NAME)
	add_child(_bar)
	_bar.set_ratio(1.0)


func _physics_process(delta: float) -> void:
	if _dead:
		return
	_hit_timer = maxf(0.0, _hit_timer - delta)
	_hurt_timer = maxf(0.0, _hurt_timer - delta)
	var player := get_tree().get_first_node_in_group("player") as Player
	if player != null and not _ignoring_player:
		_ignoring_player = true
		add_collision_exception_with(player)   # the player and the Bro walk through each other; the Bro hurts by touch

	match state:
		State.PATROL:
			_patrol(player)
		State.CHASE:
			_chase(player)
		State.RETURN:
			_return_home(player)

	if not is_on_floor():
		velocity.y += GRAVITY * delta
	move_and_slide()

	if player != null and _in_reach(player) and _hit_timer <= 0.0:
		_strike(player)
	if global_position.y > 20000.0:
		_die()

	var pose := &"idle"
	if _hurt_timer > 0.0:
		pose = &"hurt"
	elif not is_on_floor():
		pose = &"fall"
	elif absf(velocity.x) > 20.0:
		pose = &"walk"
	_visuals.update_pose(pose, _dir, delta)


# ---------- behaviour ----------

func _patrol(player: Player) -> void:
	if _sees(player):
		state = State.CHASE
		return
	if absf(global_position.x - _home_x) >= PATROL_RADIUS:
		_dir = -1 if global_position.x > _home_x else 1   # past the edge of the beat: head back
	if is_on_wall() or not _floor_ahead(_dir, EDGE_PROBE, 30.0):
		_dir = -_dir
	_walk(_dir * PATROL_SPEED)


func _chase(player: Player) -> void:
	if player == null or _lost(player):
		state = State.RETURN
		return
	_dir = 1 if player.global_position.x > global_position.x else -1
	# keep close but don't stand inside the player; stop at a real cliff but not at a spike pit
	var gap := absf(player.global_position.x - global_position.x)
	if gap < HIT_RANGE * 0.5 or not _floor_ahead(_dir, EDGE_PROBE, DROP_LIMIT):
		_walk(0.0)
	else:
		_walk(_dir * CHASE_SPEED)


func _return_home(player: Player) -> void:
	if _sees(player):
		state = State.CHASE
		return
	if absf(global_position.x - _home_x) < PATROL_RADIUS * 0.5:
		state = State.PATROL
		return
	_dir = -1 if global_position.x > _home_x else 1
	if not _floor_ahead(_dir, EDGE_PROBE, 30.0):
		state = State.PATROL
		_home_x = global_position.x   # can't get back: make this the new home
		return
	_walk(_dir * PATROL_SPEED)


func _walk(speed: float) -> void:
	velocity.x = move_toward(velocity.x, speed, 1800.0 * get_physics_process_delta_time())


## The player is close enough, roughly level, and in the direction the Bro is facing.
func _sees(player: Player) -> bool:
	if player == null:
		return false
	var dx := player.global_position.x - global_position.x
	var dy := player.global_position.y - global_position.y
	return absf(dx) <= SIGHT_RANGE and absf(dy) <= SIGHT_HEIGHT and signf(dx) == float(_dir)


func _lost(player: Player) -> bool:
	var dx := player.global_position.x - global_position.x
	var dy := player.global_position.y - global_position.y
	return absf(dx) > LOSE_RANGE or absf(dy) > SIGHT_HEIGHT * 2.0


func _in_reach(player: Player) -> bool:
	var dx := absf(player.global_position.x - global_position.x)
	var dy := absf(player.global_position.y - global_position.y)
	return dx <= HIT_RANGE and dy <= SIGHT_HEIGHT / 2.0


## True if there is floor within `depth` pixels below the spot `ahead` pixels in front of the feet.
func _floor_ahead(dir: int, ahead: float, depth: float) -> bool:
	var from := global_position + Vector2(dir * ahead, -10.0)
	var to := from + Vector2(0.0, depth + 10.0)
	var query := PhysicsRayQueryParameters2D.create(from, to, Player.LAYER_WORLD | Player.LAYER_LADDER_DECK)
	return not get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func _strike(player: Player) -> void:
	_hit_timer = HIT_COOLDOWN
	_dir = 1 if player.global_position.x > global_position.x else -1
	player.take_damage(contact_damage(), global_position.x)   # the player may be invulnerable: then nothing happens


# ---------- being hurt ----------

## A thrown object landed. `fraction` is the share of maximum health it takes; `from_x` is where it hit.
func take_hit(fraction: float, from_x: float = NAN) -> void:
	if _dead:
		return
	health = maxi(0, health - roundi(max_health * fraction))
	_bar.set_ratio(float(health) / max_health)
	if state != State.CHASE:
		state = State.CHASE   # being hit gets its attention, even from behind
	if not is_nan(from_x):
		velocity.x = HURT_KNOCKBACK * (1.0 if global_position.x > from_x else -1.0)
	_hurt_timer = 0.25
	_visuals.flinch(_dir)
	_visuals.blink(0.3)
	if health == 0:
		_die()


## Fell into a spike pit too deep to climb out of: all health is lost.
func fall_in_pit() -> void:
	health = 0
	_bar.set_ratio(0.0)
	_die()


func _die() -> void:
	if _dead:
		return
	_dead = true
	defeated.emit()
	remove_from_group("enemies")
	collision_layer = 0   # no longer hit by thrown objects while it fades out
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.35)
	tw.tween_callback(queue_free)
