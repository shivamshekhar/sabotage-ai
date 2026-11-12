class_name AIBro
extends CharacterBody2D
## The first enemy: an "AI Bro" (a zombie sprite). It paces back and forth around its home spot and never
## steps off a ledge. When the player comes close and the Bro is facing them, it chases: it climbs steps
## and ledges by jumping and hops over small gaps, but stops at any real drop (so it never walks into a
## spike pit). Close up it hits the player (damage and a flinch). Thrown objects (Projectile) hurt it.
## Origin is at the feet, like the player.
##
## Cost per Bro is kept small so a level can hold many: the sensing (a couple of ray casts) runs only
## THINK_INTERVAL seconds apart, not every frame; Level puts Bros that are far from the player to sleep
## (see set_active()); and a dead Bro is removed from the tree and freed, leaving nothing behind.

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

# JUMP_VELOCITY: upward speed of a Bro's jump (negative = up, like Player.JUMP_VELOCITY).
#     jump height = JUMP_VELOCITY^2 / (2 * GRAVITY)
# A Bro only jumps at obstacles lower than that height. Higher: it climbs taller steps.
const JUMP_VELOCITY := -720.0

# JUMP_COOLDOWN: seconds after a jump before the next one is allowed, so a Bro can't bounce up a wall.
const JUMP_COOLDOWN := 0.45

# PATROL_RADIUS: how far in pixels the Bro paces either side of its home spot (it also turns at any
# ledge edge or wall sooner). Higher: a longer beat. Lower: it shuffles on the spot.
const PATROL_RADIUS := 160.0

# SIGHT_RANGE: how far in pixels (horizontally) the Bro can notice the player, and only when it is
# facing them. SIGHT_HEIGHT: how far above or below its feet the player may be and still be noticed.
# Higher SIGHT_RANGE: it spots you from further away. Higher SIGHT_HEIGHT: it also sees you on nearby
# platforms.
const SIGHT_RANGE := 280.0
const SIGHT_HEIGHT := 150.0

# LOSE_RANGE: once chasing, the Bro gives up when the player is further than this many pixels away
# (or more than SIGHT_HEIGHT * 2 above or below), then walks back home. It should be larger than
# SIGHT_RANGE so a chase doesn't flicker on and off at the edge of sight.
const LOSE_RANGE := 420.0

# HIT_RANGE: how close in pixels (horizontally, and within SIGHT_HEIGHT / 2 vertically) the player
# must be for the Bro to strike.
const HIT_RANGE := 75.0

# HIT_COOLDOWN: seconds between a Bro's strikes. Higher: slower attacker.
const HIT_COOLDOWN := 0.9

# EDGE_PROBE: how far ahead in pixels the Bro looks for floor. DROP_LIMIT: how far below its feet that floor
# may be for it to count as ground (a step down is fine, a deeper drop is a ledge). No ground ahead
# means a patrolling Bro turns round and a chasing one stops (or jumps, see GAP_JUMP_REACH).
const EDGE_PROBE := 50.0
const DROP_LIMIT := 90.0

# GAP_JUMP_REACH: while chasing, if the ground ahead ends, the Bro jumps only when there is floor this far
# ahead (in pixels) to land on. It must be less than a jump can carry at CHASE_SPEED:
#     jump carry = CHASE_SPEED * 2 * |JUMP_VELOCITY| / GRAVITY
# so only narrow gaps are hopped; a spike pit is far too wide, and the Bro stops at its edge instead.
const GAP_JUMP_REACH := 115.0

# WALL_PROBE: how far ahead in pixels the Bro looks for a wall or step blocking its way.
const WALL_PROBE := 30.0

# THINK_INTERVAL: seconds between the Bro's sensing steps (ground ahead, wall ahead, where the player is).
# Movement still updates every frame from the latest result. Higher: cheaper, but slower to react.
# Lower: sharper reactions, more ray casts per second.
const THINK_INTERVAL := 0.1

# GRAVITY: downward acceleration, in pixels per second squared (same feel as the player's).
const GRAVITY := 2000.0

# BODY_SIZE: the Bro's hitbox in pixels (feet at the node's origin).
const BODY_SIZE := Vector2(56, 120)

# DISPLAY_NAME: the name shown above the Bro's health bar.
const DISPLAY_NAME := "AI Bro"

# BAR_OFFSET: where the health bar sits relative to the feet (negative y = above).
const BAR_OFFSET := Vector2(0, -140)

# HURT_KNOCKBACK: sideways speed in pixels per second when a thrown object lands, away from it (only
# if there is ground to be pushed onto: a Bro is never knocked off a ledge).
const HURT_KNOCKBACK := 220.0

enum State { PATROL, CHASE, RETURN }

var max_health := 0
var health := 0
var state := State.PATROL

var _home_x := 0.0
var _dir := 1
var _hit_timer := 0.0
var _hurt_timer := 0.0
var _jump_timer := 0.0
var _think_timer := 0.0
var _visuals: PlayerSprite
var _bar: HealthBar
var _dead := false
var _active := true
var _player: Player
var _ground_ahead := true     # sensing results, refreshed every THINK_INTERVAL
var _wall_ahead := false
var _can_climb := false
var _can_hop_gap := false
var _sees_player := false
var _lost_player := false
var _player_above := false


## Contact damage in health points (see CONTACT_DAMAGE_FRACTION).
static func contact_damage() -> int:
	return roundi(Player.MAX_HEALTH * CONTACT_DAMAGE_FRACTION)


## Maximum health in health points (see HEALTH_FRACTION).
static func starting_health() -> int:
	return roundi(Player.MAX_HEALTH * HEALTH_FRACTION)


## How high a jump gets, in pixels (see JUMP_VELOCITY).
static func jump_height() -> float:
	return JUMP_VELOCITY * JUMP_VELOCITY / (2.0 * GRAVITY)


func _ready() -> void:
	max_health = starting_health()
	health = max_health
	_home_x = global_position.x
	_dir = 1 if randf() < 0.5 else -1
	_think_timer = randf() * THINK_INTERVAL   # spread the sensing of many Bros over different frames
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


## The Bro's hit box in world coordinates (what thrown objects are tested against).
func hurtbox() -> Rect2:
	return Rect2(global_position + Vector2(-BODY_SIZE.x / 2.0, -BODY_SIZE.y), BODY_SIZE)


## Wake or put to sleep. A sleeping Bro does no thinking and no physics at all (Level does this for Bros
## far from the player, so only nearby ones cost anything).
func set_active(value: bool) -> void:
	if value == _active or _dead:
		return
	_active = value
	set_physics_process(value)
	if not value:
		velocity = Vector2.ZERO


func _physics_process(delta: float) -> void:
	if _dead:
		return
	_hit_timer = maxf(0.0, _hit_timer - delta)
	_hurt_timer = maxf(0.0, _hurt_timer - delta)
	_jump_timer = maxf(0.0, _jump_timer - delta)
	_think_timer -= delta
	if _think_timer <= 0.0:
		_think_timer = THINK_INTERVAL
		_sense()

	match state:
		State.PATROL:
			_patrol()
		State.CHASE:
			_chase()
		State.RETURN:
			_return_home()

	if not is_on_floor():
		velocity.y += GRAVITY * delta
	move_and_slide()

	if _player != null and _hit_timer <= 0.0 and _in_reach(_player):
		_strike(_player)
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


# ---------- sensing (every THINK_INTERVAL) ----------

func _sense() -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Player
		if _player != null:
			add_collision_exception_with(_player)   # the player and the Bro walk through each other; it hurts by touch
	_sees_player = false
	_lost_player = true
	_player_above = false
	if _player != null:
		var dx := _player.global_position.x - global_position.x
		var dy := _player.global_position.y - global_position.y
		_sees_player = absf(dx) <= SIGHT_RANGE and absf(dy) <= SIGHT_HEIGHT and signf(dx) == float(_dir)
		_lost_player = absf(dx) > LOSE_RANGE or absf(dy) > SIGHT_HEIGHT * 2.0
		_player_above = dy < -60.0 and absf(dx) < HIT_RANGE * 2.0
	if state == State.PATROL and _sees_player:
		state = State.CHASE
	elif state == State.CHASE and _lost_player:
		state = State.RETURN
	elif state == State.RETURN and _sees_player:
		state = State.CHASE
	# Sensing ahead is only needed while walking on the floor.
	if is_on_floor():
		var heading := _dir
		if state == State.CHASE and _player != null:
			heading = 1 if _player.global_position.x > global_position.x else -1
		_wall_ahead = _blocked_at(heading, 20.0)
		_ground_ahead = _wall_ahead or _floor_ahead(heading, EDGE_PROBE, DROP_LIMIT)   # a wall ahead is not a ledge
		_can_climb = _wall_ahead and not _blocked_at(heading, jump_height() - 10.0)
		_can_hop_gap = not _ground_ahead and _floor_ahead(heading, GAP_JUMP_REACH, DROP_LIMIT)


# ---------- behaviour (every frame, from the latest sensing) ----------

func _patrol() -> void:
	if absf(global_position.x - _home_x) >= PATROL_RADIUS:
		_dir = -1 if global_position.x > _home_x else 1   # past the edge of the beat: head back
	elif is_on_wall() or _wall_ahead or not _ground_ahead:
		_dir = -_dir                                     # a ledge or a wall: turn round
		_wall_ahead = false
		_ground_ahead = true
	_walk(_dir * PATROL_SPEED)


func _chase() -> void:
	if _player == null:
		state = State.RETURN
		return
	_dir = 1 if _player.global_position.x > global_position.x else -1
	var gap := absf(_player.global_position.x - global_position.x)
	if gap < HIT_RANGE * 0.5:
		_walk(0.0)
		if _player_above and is_on_floor():
			_jump()   # the player is on a ledge above: try to hop up to them
		return
	if is_on_floor():
		if not _ground_ahead:
			if _can_hop_gap:
				_jump()
				_walk(_dir * CHASE_SPEED)
			else:
				_walk(0.0)   # a real drop (or a spike pit): stop at the edge
			return
		if _wall_ahead:
			if _can_climb:
				_jump()
			else:
				_walk(0.0)   # too tall to climb
				return
	_walk(_dir * CHASE_SPEED)


func _return_home() -> void:
	if absf(global_position.x - _home_x) < PATROL_RADIUS * 0.5:
		state = State.PATROL
		return
	_dir = -1 if global_position.x > _home_x else 1
	if not _ground_ahead or _wall_ahead:
		state = State.PATROL
		_home_x = global_position.x   # can't get back: make this the new home
		return
	_walk(_dir * PATROL_SPEED)


func _jump() -> void:
	if is_on_floor() and _jump_timer <= 0.0:
		velocity.y = JUMP_VELOCITY
		_jump_timer = JUMP_COOLDOWN


func _walk(speed: float) -> void:
	velocity.x = move_toward(velocity.x, speed, 1800.0 * get_physics_process_delta_time())


func _in_reach(player: Player) -> bool:
	var dx := absf(player.global_position.x - global_position.x)
	var dy := absf(player.global_position.y - global_position.y)
	return dx <= HIT_RANGE and dy <= SIGHT_HEIGHT / 2.0


## True if there is floor within `depth` pixels below the spot `ahead` pixels in front of the feet.
func _floor_ahead(dir: int, ahead: float, depth: float) -> bool:
	var from := global_position + Vector2(dir * ahead, -10.0)
	var to := from + Vector2(0.0, depth + 10.0)
	var query := PhysicsRayQueryParameters2D.create(from, to, Player.LAYER_WORLD | Player.LAYER_LADDER_DECK)
	_ignore_player(query)
	return not get_world_2d().direct_space_state.intersect_ray(query).is_empty()


## True if solid ground (not a one-way ledge) blocks the way `height` pixels above the feet, WALL_PROBE ahead.
func _blocked_at(dir: int, height: float) -> bool:
	var from := global_position + Vector2(0.0, -height)
	var query := PhysicsRayQueryParameters2D.create(from, from + Vector2(dir * (BODY_SIZE.x / 2.0 + WALL_PROBE), 0.0), Player.LAYER_WORLD)
	_ignore_player(query)
	return not get_world_2d().direct_space_state.intersect_ray(query).is_empty()


## The player shares the world layer, so sensing rays must not mistake them for a wall or floor.
func _ignore_player(query: PhysicsRayQueryParameters2D) -> void:
	if _player != null and is_instance_valid(_player):
		query.exclude = [_player.get_rid()]


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
		var push := 1 if global_position.x > from_x else -1
		if _floor_ahead(push, EDGE_PROBE, DROP_LIMIT):   # never knocked off a ledge
			velocity.x = HURT_KNOCKBACK * push
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


## Remove the Bro: out of the "enemies" group and the physics world at once, then fade and free. Nothing
## else holds a reference to it, so it is garbage collected as soon as the node is freed.
func _die() -> void:
	if _dead:
		return
	_dead = true
	defeated.emit()
	remove_from_group("enemies")
	collision_layer = 0
	collision_mask = 0
	set_physics_process(false)
	_player = null
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.35)
	tw.tween_callback(queue_free)
