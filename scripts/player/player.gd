class_name Player
extends CharacterBody2D
## Platformer controller: run, jump, climb ladders, take damage, respawn.
## Origin is at the feet. Visuals live in PlayerSprite, the bar in HealthBar.

signal health_changed(current: int, maximum: int)

# PHYSICS LAYERS. Godot collision layers are bit flags, so each layer needs its own bit.

# LAYER_WORLD: ground, walls, crates and ledges. Level colliders use it as their
# collision_layer, and the player always includes it in its collision_mask.
const LAYER_WORLD := 1

# LAYER_LADDER_DECK: the one-way deck on top of each ladder. It has its own layer so
# climbing can switch it off: the player's collision_mask is WORLD | DECK normally and just
# WORLD while climbing (see _start_climb / _stop_climb), which lets you climb down through
# the deck you are standing on. A new layer must use a different bit, and the player's
# mask must include it for the player to collide with it.
const LAYER_LADDER_DECK := 2

# MOVEMENT TUNING. Units are pixels and seconds. Godot's Y axis points DOWN, so "up" is a
# NEGATIVE velocity. Every formula is multiplied by delta (the physics step), so the feel
# does not depend on frame rate.

# SPEED: top running speed, in pixels per second. It is the target of the horizontal
# movement in _physics_process():
#     velocity.x = move_toward(velocity.x, dir * SPEED, accel * delta)   (dir is -1, 0 or 1)
# It also sets how far a jump carries:
#     jump distance = SPEED * air time          (air time: see JUMP_VELOCITY and GRAVITY)
# Higher: a faster runner whose jumps cover more ground, so gaps that were hard get easy.
# Lower: slower and more deliberate; wide gaps can become impossible to cross.
const SPEED := 360.0

# ACCEL: how fast velocity.x chases its target, in pixels per second per second. It is the
# step size of the move_toward() call above, so it governs speeding up, braking and turning
# around, on the ground and in the air alike:
#     time to full speed = SPEED / ACCEL
#     distance covered while getting there = 0.5 * ACCEL * time^2
# Higher: snappy, near-instant starts and stops.
# Lower: slidey, ice-like, and harder to land on small ledges.
# (While stunned after a hit a separate, weaker braking value is used so knockback carries.)
const ACCEL := 1600.0

# JUMP_VELOCITY: upward speed given at the moment of a jump, in pixels per second. It is
# negative because the Y axis points down. Set once, when jumping on the floor:
#     velocity.y = JUMP_VELOCITY
# and gravity then slows it, which gives:
#     jump height = JUMP_VELOCITY^2 / (2 * GRAVITY)
#     time to the top = |JUMP_VELOCITY| / GRAVITY
#     air time (landing at the same height) = 2 * |JUMP_VELOCITY| / GRAVITY
# Height grows with the SQUARE of the speed, so small changes are very noticeable.
# Higher: reaches higher platforms and hangs in the air longer. Lower: lower hops.
# After changing it, re-check the level's step heights (README.md, "Designing levels").
const JUMP_VELOCITY := -760.0

# GRAVITY: downward acceleration, in pixels per second per second, added every physics step
# while airborne:
#     velocity.y += GRAVITY * delta
# There is no maximum fall speed, so long drops keep speeding up. It also shapes the arc of
# knockback hops.
# Higher: heavy, snappy jumps (lower and shorter for the same JUMP_VELOCITY).
# Lower: floaty, moon-like jumps.
# Jump height and air time are both proportional to 1 / GRAVITY.
const GRAVITY := 2000.0

# CLIMB_SPEED: vertical speed on a ladder, in pixels per second, up or down:
#     velocity = Vector2(0, vdir * CLIMB_SPEED)        (vdir: -1 up, 0 still, +1 down)
# Time to climb a ladder = ladder height / CLIMB_SPEED.
# Higher: quicker climbing. Lower: slower, more laborious ladders.
# (The tests compare against this constant rather than a fixed number.)
const CLIMB_SPEED := 250.0

# LADDER_OVERLAP: how much of the player's hitbox must overlap a ladder, sideways, before
# Up/Down grabs it. A fraction from 0 to 1 of the hitbox width (BODY_SIZE.x), checked in
# _find_ladder():
#     overlap / BODY_SIZE.x >= LADDER_OVERLAP
# where overlap is how many pixels of the hitbox's width lie inside the ladder's width.
# Higher (towards 1): you must line up almost exactly. Lower: forgiving, grabs from further
# to the side. Because a ladder is wider than the hitbox, even 1 leaves a small window.
const LADDER_OVERLAP := 0.75

# LADDER_SLACK: vertical forgiveness, in pixels, when grabbing near a ladder's ends. Your
# feet must be between (ladder top - LADDER_SLACK) and (ladder bottom + LADDER_SLACK),
# checked in _find_ladder(). It also decides how far above the top deck you can still catch
# the ladder mid-jump.
# Higher: easier catches, but you can grab from slightly too far away.
# Lower: you must be at exactly the ladder's height.
const LADDER_SLACK := 6.0

# HURT_TIME: how long, in seconds, the hurt pose is shown after a hit. Visual only: it does
# not stop you moving (STUN_TIME does) and does not change invulnerability (INVULN_TIME).
const HURT_TIME := 0.4

# BODY_SIZE: the collision rectangle in pixels (width, height). Its origin is at the feet,
# so the shape is centred half its height above the player's position. It is used for:
#   - the CollisionShape2D (what you bump into),
#   - the ladder grab test (the width, see LADDER_OVERLAP),
#   - the health bar's position (see HEALTH_BAR_OFFSET).
# It is deliberately narrower than the drawn sprite, so tight jumps and spikes feel fair
# instead of pixel-exact.
# Wider: harder to fit through gaps and onto narrow ledges. Taller: needs more headroom.
# If you change it, update PlayerSprite.SCALE, the PlayerShadow sizes and HEALTH_BAR_OFFSET.
const BODY_SIZE := Vector2(60, 128)

# MAX_HEALTH: health at spawn and after dying, and the "full" mark of the health bar
# (bar fill = health / MAX_HEALTH).
#     hits you can take = MAX_HEALTH / HAZARD_DAMAGE, rounded up
# Higher: a sturdier player. Lower: a more fragile one.
const MAX_HEALTH := 100

# HAZARD_DAMAGE: health lost per hit from a hazard such as spikes (see take_damage()).
# Standing in a hazard hurts you again every INVULN_TIME seconds.
# Higher: deadlier hazards. Lower: more forgiving ones.
const HAZARD_DAMAGE := 25

# INVULN_TIME: seconds after a hit during which further damage is ignored. The sprite
# blinks for this long. While standing in spikes it is also the gap between hits:
#     time to die in a hazard = hits you can take * INVULN_TIME
# Higher: more time to escape, but hazards hurt less often.
# Lower: rapid repeated damage.
const INVULN_TIME := 1.0

# KNOCKBACK_UP: upward speed given by a hit, in pixels per second (negative = up, as with
# JUMP_VELOCITY). On a hit, in take_damage():
#     velocity = Vector2(-facing * KNOCKBACK_X, KNOCKBACK_UP)
# The hop height follows the jump formula: KNOCKBACK_UP^2 / (2 * GRAVITY).
# Higher: a bigger hop out of danger. Lower: a small bump.
const KNOCKBACK_UP := -420.0

# KNOCKBACK_X: sideways push from a hit, in pixels per second, opposite to the direction you
# face. It fades quickly during the stun (braking is reduced, not removed), so it carries
# you a short way before control returns.
# Higher: thrown further back. Lower: barely pushed.
const KNOCKBACK_X := 260.0

# STUN_TIME: seconds after a hit during which steering input is ignored and ladders cannot
# be grabbed, so the knockback plays out.
# Higher: more "ouch", less control. Lower: you can steer almost immediately and the
# knockback feels weaker.
const STUN_TIME := 0.25

# HEALTH_BAR_OFFSET: where the health bar's centre sits relative to the player's feet, in
# pixels (negative y = above). It should clear the top of the sprite and hitbox (see
# BODY_SIZE); make y more negative if the bar overlaps the head.
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


## Interact with whatever is in reach (terminals, doors, levers...). Not implemented yet.
func interact() -> void:
	pass


## Quick, weak attack. Not implemented yet.
func attack_light() -> void:
	pass


## Slow, strong attack. Not implemented yet.
func attack_heavy() -> void:
	pass


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

	if Input.is_action_just_pressed("interact"):
		interact()
	if Input.is_action_just_pressed("attack_light"):
		attack_light()
	if Input.is_action_just_pressed("attack_heavy"):
		attack_heavy()

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
		elif Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("move_up"):
			# "jump" (Space / the JUMP button) always jumps. "move_up" (W / Up / D-pad up) is
			# both jump and climb: a ladder in reach was already grabbed above (so we'd be
			# climbing, not here); otherwise it jumps.
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
