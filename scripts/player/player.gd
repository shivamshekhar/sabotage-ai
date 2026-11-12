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

# LAYER_ENEMY: enemies. The player does not collide with it (you can walk through an enemy; it
# hurts you by touching, see AIBro), but thrown objects look for it (see Projectile).
const LAYER_ENEMY := 4

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
const SPEED := 380.0

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
#     hits you can take = 1 / HAZARD_DAMAGE_FRACTION, rounded up
# Higher: a sturdier player. Lower: a more fragile one.
const MAX_HEALTH := 100

# HAZARD_DAMAGE_FRACTION: share of MAX_HEALTH lost per hit from a hazard such as spikes
# (see hazard_damage() and take_damage()). Standing in a hazard hurts you again every
# INVULN_TIME seconds.
#     damage per hit = round(MAX_HEALTH * HAZARD_DAMAGE_FRACTION)
# Higher: deadlier hazards. Lower: more forgiving ones.
const HAZARD_DAMAGE_FRACTION := 0.2

# MAX_NAME_LENGTH: the most characters of the player's name that are kept and shown above the health
# bar. Longer names are cut off, so a name can never be wider than the sprite (HealthBar.TITLE_FONT_SIZE
# sets the letter size; tools/tests/health_test.gd checks the widest name fits).
# Higher: room for longer names, but they may stick out past the sprite. Lower: shorter names only.
const MAX_NAME_LENGTH := 10

# DEFAULT_NAME: the name shown until players can choose their own (a menu is planned).
const DEFAULT_NAME := "SABOTEUR"

# PIT_DEATH_DELAY: seconds the player blinks at the bottom of a deadly pit (see PitHazard), after landing, before the
# game over is declared and they respawn (see fall_in_pit()). Higher: a longer look at what happened.
# Lower: back in the action sooner.
const PIT_DEATH_DELAY := 0.5

# THROW_COOLDOWN: seconds after a throw before the next one is allowed (see attack_light()).
# Higher: slower, more deliberate throwing. Lower: you can spam objects.
const THROW_COOLDOWN := 0.35

# THROW_WINDUP: seconds between pressing the throw button and the object leaving the hand: the
# wind-up pose (arm drawn back) is shown for this long, then the release pose. Higher: a slower, more
# visible wind-up and a laggier button. Lower: the throw feels instant.
const THROW_WINDUP := 0.08

# THROW_POSE_TIME: seconds from the button press until the throwing pose ends and normal movement
# poses return. It should be longer than THROW_WINDUP (the rest is the follow-through).
const THROW_POSE_TIME := 0.3

# THROW_HAND: where a thrown object leaves the player, relative to the feet and in the direction
# the player faces: x is how far in front, y is the height (negative = up). It should be around
# chest height (see BODY_SIZE).
const THROW_HAND := Vector2(34, -92)

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

# FALL_DEATH_HEIGHT: how far in pixels you can fall, measured from the highest point of the fall
# (the top of a jump counts) down to where you land, before the landing kills you. Landing
# from further than this is instant death and you respawn (see die()). Grabbing a ladder or
# landing safely restarts the measurement.
#     fall = landing y - highest y reached while airborne
# It must exceed the biggest drop a level expects you to survive: the longest legitimate drop plus
# your jump height (JUMP_VELOCITY^2 / (2 * GRAVITY)). Tiles are Level.T pixels tall.
# Higher: forgiving, tall drops are safe. Lower: even moderate drops are lethal.
const FALL_DEATH_HEIGHT := 700.0

## Emitted when the player dies. cause is "health" (ran out of health), "fall" or "pit".
signal died(cause: String)

## Emitted when the player presses the interact button.
signal interacted

## Emitted when the player throws an object (see attack_light()).
signal threw(projectile: Projectile)

# LADDER_REGRAB_TIME: seconds after jumping off a ladder during which ladders cannot be grabbed
# again, so holding up/down as you leap doesn't snap you straight back onto the same ladder.
# Higher: a longer committed leap. Lower: you can catch a ladder again sooner, even the one you left.
const LADDER_REGRAB_TIME := 0.3

## The player's name, shown above the health bar. Setting it trims spaces at the ends and cuts it to
## MAX_NAME_LENGTH characters; an empty name falls back to DEFAULT_NAME.
var display_name := DEFAULT_NAME:
	set(value):
		var cleaned := value.strip_edges().left(MAX_NAME_LENGTH)
		display_name = cleaned if cleaned != "" else DEFAULT_NAME
		if _health_bar != null:
			_health_bar.set_title(display_name)

var spawn := Vector2.ZERO
var health := MAX_HEALTH
var hazard_count := 0   # how many hazard areas (spikes) currently overlap the player
var climbing := false
## Ladder columns in world space (top-left of the top tile, down to the floor). Set by main from the Level.
var ladders: Array[Rect2] = []

var _pit_dying := false      # fell into a deadly pit: falling, then waiting out PIT_DEATH_DELAY
var _pit_timer := -1.0     # counts down once the player has landed at the bottom (negative = not landed yet)
var _throw_timer := 0.0   # while above zero, another throw is not allowed
var _windup := -1.0       # seconds until a started throw leaves the hand (negative = no throw pending)
var _throw_pose_timer := 0.0   # while above zero, the throwing pose is shown
var _regrab_timer := 0.0  # while above zero, ladders cannot be grabbed (after jumping off one)
var _peak_y := 0.0     # highest point (smallest y) reached since last standing/climbing
var _ladder := Rect2()  # the ladder being climbed (valid while climbing)
var _facing := 1
var _hurt_timer := 0.0
var _invuln_timer := 0.0
var _stun_timer := 0.0
var _visuals: PlayerSprite
var _health_bar: HealthBar


func _ready() -> void:
	z_index = 2
	add_to_group("player")
	_peak_y = global_position.y
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
	_health_bar.set_title(display_name)
	add_child(_health_bar)
	health_changed.connect(func(current: int, maximum: int) -> void:
		_health_bar.set_ratio(float(current) / maximum))
	health_changed.emit(health, MAX_HEALTH)


## Returns true if the hit landed (not blocked by invulnerability).
## `source_x` is the x of whatever hit us, if it has a position: the knockback pushes away from it.
func take_damage(amount: int, source_x: float = NAN) -> bool:
	if _invuln_timer > 0.0 or _pit_dying:
		return false
	health = maxi(0, health - amount)
	health_changed.emit(health, MAX_HEALTH)
	if health == 0:
		die("health")
	else:
		_invuln_timer = INVULN_TIME
		_hurt_timer = HURT_TIME
		_stun_timer = STUN_TIME
		_windup = -1.0            # a hit interrupts a throw
		_throw_pose_timer = 0.0
		_stop_climb()
		var push := -_facing
		if not is_nan(source_x) and not is_equal_approx(source_x, global_position.x):
			push = 1 if global_position.x > source_x else -1
		velocity = Vector2(push * KNOCKBACK_X, KNOCKBACK_UP)
		_visuals.flinch(_facing)
		_visuals.blink(INVULN_TIME)
	return true


## Interact with whatever is in reach. The player only announces it (the interacted signal); the
## level decides whether there is a computer in reach.
func interact() -> void:
	interacted.emit()


## The player's weapon: throw an everyday object, picked at random (see SpriteLibrary.PROJECTILES), in the
## direction the player faces. It flies in an arc (see Projectile).
func attack_light() -> void:
	if _throw_timer > 0.0 or climbing or _stun_timer > 0.0:
		return
	_throw_timer = THROW_COOLDOWN
	_windup = THROW_WINDUP
	_throw_pose_timer = THROW_POSE_TIME


## The object leaves the hand (called when the wind-up ends).
func _release_throw() -> void:
	var names: Array = SpriteLibrary.PROJECTILES.keys()
	var from := global_position + Vector2(_facing * THROW_HAND.x, THROW_HAND.y)
	var obj := Projectile.launch(get_parent(), names[randi() % names.size()], from, _facing, velocity)
	threw.emit(obj)


## Slow, strong attack. Not implemented yet.
func attack_heavy() -> void:
	pass


## Damage dealt to the player by one hazard hit (spikes): a share of MAX_HEALTH, see HAZARD_DAMAGE_FRACTION.
static func hazard_damage() -> int:
	return roundi(MAX_HEALTH * HAZARD_DAMAGE_FRACTION)


## Fell into a deadly pit (see PitHazard): all health is lost and the player dies.
## The player keeps falling to the bottom, can no longer be controlled, blinks for PIT_DEATH_DELAY seconds
## down there, then the death is declared and they respawn (see _pit_step()).
func fall_in_pit() -> void:
	if _pit_dying:
		return
	_pit_dying = true
	_pit_timer = -1.0
	health = 0
	health_changed.emit(health, MAX_HEALTH)
	_stop_climb()
	_windup = -1.0
	_throw_pose_timer = 0.0
	_visuals.update_pose(&"hurt", _facing, 0.0)


func _pit_step(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, ACCEL * delta)
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	move_and_slide()
	if is_on_floor() and _pit_timer < 0.0:
		_pit_timer = PIT_DEATH_DELAY
		_visuals.blink(PIT_DEATH_DELAY)
	if _pit_timer >= 0.0:
		_pit_timer -= delta
		if _pit_timer <= 0.0:
			die("pit")
	_visuals.update_pose(&"hurt", _facing, delta)


## Out of health or a deadly fall: back to the last checkpoint with a full bar.
func die(cause: String = "health") -> void:
	_pit_dying = false
	died.emit(cause)
	_peak_y = spawn.y
	health = MAX_HEALTH
	health_changed.emit(health, MAX_HEALTH)
	global_position = spawn
	reset_physics_interpolation()   # a teleport: don't smear the sprite across the level
	velocity = Vector2.ZERO
	_stop_climb()
	_hurt_timer = HURT_TIME
	_invuln_timer = 0.5
	_visuals.blink(0.5)


func _physics_process(delta: float) -> void:
	if _pit_dying:
		_pit_step(delta)
		return
	var dir := Input.get_axis("move_left", "move_right")
	var vdir := Input.get_axis("move_up", "move_down")  # negative = up
	_hurt_timer = maxf(0.0, _hurt_timer - delta)
	_invuln_timer = maxf(0.0, _invuln_timer - delta)
	_stun_timer = maxf(0.0, _stun_timer - delta)
	_throw_timer = maxf(0.0, _throw_timer - delta)
	_throw_pose_timer = maxf(0.0, _throw_pose_timer - delta)
	if _windup >= 0.0:
		_windup -= delta
		if _windup <= 0.0:
			_windup = -1.0
			if _stun_timer <= 0.0 and not climbing:   # knocked about or grabbed a ladder mid wind-up: no throw
				_release_throw()
	if _stun_timer > 0.0:
		dir = 0.0  # knocked back: no steering for a moment

	if Input.is_action_just_pressed("interact"):
		interact()
	if Input.is_action_just_pressed("attack_light"):
		attack_light()
	if Input.is_action_just_pressed("attack_heavy"):
		attack_heavy()

	if hazard_count > 0:
		take_damage(hazard_damage())  # ignored while invulnerable

	# Up/down grabs a ladder when one is in reach: standing at its bottom, standing on its
	# top deck (down only), or catching it mid-jump. Otherwise up falls through to a jump.
	_regrab_timer = maxf(0.0, _regrab_timer - delta)
	if not climbing and vdir != 0.0 and _stun_timer <= 0.0 and _regrab_timer <= 0.0:
		var ladder := _find_ladder(vdir)
		if ladder.has_area():
			_start_climb(ladder)

	# Jump button while on a ladder: let go and leap off, steering with left/right.
	var ladder_jump := false
	if climbing and Input.is_action_just_pressed("jump"):
		_stop_climb()
		_regrab_timer = LADDER_REGRAB_TIME
		ladder_jump = true

	if climbing:
		# Locked to the ladder: only up/down, no sideways movement. You leave at the top deck,
		# the bottom floor, or by pressing jump (handled above).
		velocity = Vector2(0.0, vdir * CLIMB_SPEED)
	else:
		# Weaker deceleration while stunned so the knockback actually carries.
		var accel := 500.0 if _stun_timer > 0.0 else ACCEL
		velocity.x = move_toward(velocity.x, dir * SPEED, accel * delta)
		if ladder_jump:
			velocity.y = JUMP_VELOCITY
		elif not is_on_floor():
			velocity.y += GRAVITY * delta
		elif Input.is_action_just_pressed("jump") or (Input.is_action_just_pressed("move_up") and not TouchControls.should_show()):
			# "jump" (Space / the JUMP button) always jumps. On a keyboard "move_up" (W / Up)
			# is both jump and climb: a ladder in reach was already grabbed above (so we'd be
			# climbing, not here); otherwise it jumps. On a phone the D-pad's up never jumps.
			velocity.y = JUMP_VELOCITY

	move_and_slide()

	if climbing:
		_keep_on_ladder(vdir)

	_track_fall()

	if dir != 0.0 and not climbing:
		_facing = 1 if dir > 0.0 else -1
	_visuals.update_pose(_pose_state(vdir), _facing, delta)


## Track the highest point of the current fall and die if we land too far below it.
func _track_fall() -> void:
	if climbing:
		_peak_y = global_position.y
	elif is_on_floor():
		if global_position.y - _peak_y > FALL_DEATH_HEIGHT:
			die("fall")
		else:
			_peak_y = global_position.y
	else:
		_peak_y = minf(_peak_y, global_position.y)


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
	if _throw_pose_timer > 0.0 and not climbing:
		return &"throw_windup" if _windup >= 0.0 else &"throw_release"
	if climbing:
		return &"climb" if vdir != 0.0 else &"climb_idle"
	if not is_on_floor():
		return &"jump" if velocity.y < 0.0 else &"fall"
	if absf(velocity.x) > 20.0:
		return &"walk"
	return &"idle"
