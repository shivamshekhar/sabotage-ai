class_name Player
extends CharacterBody2D
## Platformer controller: run, jump, climb ladders, take damage, respawn.
## Origin is at the feet. Visuals live in PlayerSprite, the bar in HealthBar.

signal health_changed(current: int, maximum: int)

# Physics layers. Ladder top decks are one-way and live on their own layer so the
# player can ignore them while climbing (needed to climb back down through the deck).
const LAYER_WORLD := 1
const LAYER_LADDER_DECK := 2

const SPEED := 320.0
const ACCEL := 2600.0
const JUMP_VELOCITY := -660.0
const GRAVITY := 1600.0
const CLIMB_SPEED := 190.0
const LADDER_OVERLAP := 0.75   # fraction of the hitbox that must overlap a ladder to grab it
const LADDER_SLACK := 6.0      # vertical tolerance (px) when grabbing at the top/bottom
const HURT_TIME := 0.4
# Hitbox is a bit narrower than the ~96px-wide art so tight jumps stay fair.
const BODY_SIZE := Vector2(60, 128)

const MAX_HEALTH := 100
const HAZARD_DAMAGE := 25
const INVULN_TIME := 1.0       # seconds of blinking invulnerability after a hit
const KNOCKBACK_UP := -420.0
const KNOCKBACK_X := 260.0     # pushed backwards (away from facing) on a hit
const STUN_TIME := 0.25        # input is ignored briefly after a hit
const HEALTH_BAR_OFFSET := Vector2(0, -142)

var spawn := Vector2.ZERO
var health := MAX_HEALTH
var hazard_count := 0   # how many hazard areas (spikes) currently overlap the player
var climbing := false
## Ladder columns in world space (top-left of the top tile, down to the floor). Set by main from the Level.
var ladders: Array[Rect2] = []

var _ladder := Rect2()  # the ladder being climbed (valid while climbing)
var _facing := 1
var _hurt_timer := 0.0
var _invuln_timer := 0.0
var _stun_timer := 0.0
var _visuals: PlayerSprite
var _health_bar: HealthBar


func _ready() -> void:
	z_index = 2
	collision_mask = LAYER_WORLD | LAYER_LADDER_DECK
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = BODY_SIZE
	shape.shape = rect
	shape.position = Vector2(0, -BODY_SIZE.y / 2.0)
	add_child(shape)

	add_child(PlayerShadow.new())  # added first so it draws behind the sprite

	_visuals = PlayerSprite.new()
	add_child(_visuals)

	_health_bar = HealthBar.new()
	_health_bar.position = HEALTH_BAR_OFFSET
	add_child(_health_bar)
	health_changed.connect(func(current: int, maximum: int) -> void:
		_health_bar.set_ratio(float(current) / maximum))
	health_changed.emit(health, MAX_HEALTH)


## Returns true if the hit landed (not blocked by invulnerability).
func take_damage(amount: int) -> bool:
	if _invuln_timer > 0.0:
		return false
	health = maxi(0, health - amount)
	health_changed.emit(health, MAX_HEALTH)
	if health == 0:
		die()
	else:
		_invuln_timer = INVULN_TIME
		_hurt_timer = HURT_TIME
		_stun_timer = STUN_TIME
		_stop_climb()
		velocity = Vector2(-_facing * KNOCKBACK_X, KNOCKBACK_UP)
		_visuals.flinch(_facing)
		_visuals.blink(INVULN_TIME)
	return true


## Out of health: back to the start with a full bar.
func die() -> void:
	health = MAX_HEALTH
	health_changed.emit(health, MAX_HEALTH)
	global_position = spawn
	velocity = Vector2.ZERO
	_stop_climb()
	_hurt_timer = HURT_TIME
	_invuln_timer = 0.5
	_visuals.blink(0.5)


func _physics_process(delta: float) -> void:
	var dir := Input.get_axis("move_left", "move_right")
	var vdir := Input.get_axis("move_up", "move_down")  # negative = up
	_hurt_timer = maxf(0.0, _hurt_timer - delta)
	_invuln_timer = maxf(0.0, _invuln_timer - delta)
	_stun_timer = maxf(0.0, _stun_timer - delta)
	if _stun_timer > 0.0:
		dir = 0.0  # knocked back: no steering for a moment

	if hazard_count > 0:
		take_damage(HAZARD_DAMAGE)  # ignored while invulnerable

	# Up/down grabs a ladder when one is in reach: standing at its bottom, standing on its
	# top deck (down only), or catching it mid-jump. Otherwise up falls through to a jump.
	if not climbing and vdir != 0.0 and _stun_timer <= 0.0:
		var ladder := _find_ladder(vdir)
		if ladder.has_area():
			_start_climb(ladder)

	if climbing:
		# Locked to the ladder: only up/down. No jumping and no sideways movement;
		# you leave at the top deck or the bottom floor.
		velocity = Vector2(0.0, vdir * CLIMB_SPEED)
	else:
		# Weaker deceleration while stunned so the knockback actually carries.
		var accel := 500.0 if _stun_timer > 0.0 else ACCEL
		velocity.x = move_toward(velocity.x, dir * SPEED, accel * delta)
		if not is_on_floor():
			velocity.y += GRAVITY * delta
		elif Input.is_action_just_pressed("move_up"):
			# Up is both jump and climb. A ladder in reach was already grabbed above
			# (so we'd be climbing, not here); otherwise up jumps.
			velocity.y = JUMP_VELOCITY

	move_and_slide()

	if climbing:
		_keep_on_ladder(vdir)

	if dir != 0.0 and not climbing:
		_facing = 1 if dir > 0.0 else -1
	_visuals.update_pose(_pose_state(vdir), _facing, delta)


# ---------- ladders ----------

## A ladder can be grabbed when at least LADDER_OVERLAP of the hitbox overlaps it
## horizontally and the feet are within its height. From the top deck you can only
## go down, from the bottom only up.
func _find_ladder(vdir: float) -> Rect2:
	var half := BODY_SIZE.x / 2.0
	var feet := global_position.y
	for l in ladders:
		var overlap := minf(global_position.x + half, l.end.x) - maxf(global_position.x - half, l.position.x)
		if overlap / BODY_SIZE.x < LADDER_OVERLAP:
			continue
		if feet < l.position.y - LADDER_SLACK or feet > l.end.y + LADDER_SLACK:
			continue
		if vdir < 0.0 and feet <= l.position.y + 1.0:
			continue  # already at the top
		if vdir > 0.0 and feet >= l.end.y - 1.0:
			continue  # already at the bottom
		return l
	return Rect2()


func _start_climb(ladder: Rect2) -> void:
	_ladder = ladder
	climbing = true
	collision_mask = LAYER_WORLD  # pass through the ladder's top deck both ways
	velocity = Vector2.ZERO
	global_position.x = ladder.get_center().x  # snap onto the ladder's centre line


func _stop_climb() -> void:
	climbing = false
	collision_mask = LAYER_WORLD | LAYER_LADDER_DECK


## Keep the player on the ladder's centre line and step off at either end.
func _keep_on_ladder(vdir: float) -> void:
	global_position.x = _ladder.get_center().x
	# Small tolerance: the floor collision stops us a fraction of a pixel short of the end.
	if vdir < 0.0 and global_position.y <= _ladder.position.y + 1.0:
		global_position.y = _ladder.position.y  # stand on the top deck
		_stop_climb()
		velocity = Vector2.ZERO
	elif vdir > 0.0 and global_position.y >= _ladder.end.y - 1.0:
		global_position.y = _ladder.end.y  # step off onto the floor
		_stop_climb()
		velocity = Vector2.ZERO


func _pose_state(vdir: float) -> StringName:
	if _hurt_timer > 0.0:
		return &"hurt"
	if climbing:
		return &"climb" if vdir != 0.0 else &"climb_idle"
	if not is_on_floor():
		return &"jump" if velocity.y < 0.0 else &"fall"
	if absf(velocity.x) > 20.0:
		return &"walk"
	return &"idle"
