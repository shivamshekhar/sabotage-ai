class_name Player
extends CharacterBody2D
## Platformer controller: run, jump, climb ladders, take damage, respawn.
## Origin is at the feet. Visuals live in PlayerSprite, the bar in HealthBar.

signal health_changed(current: int, maximum: int)

# MOVEMENT TUNING. Units are pixels and seconds. Godot's Y axis points DOWN, so "up" is a
# NEGATIVE velocity. Every formula is multiplied by delta (the physics step), so the feel
# does not depend on frame rate.

# SPEED: top running speed, in pixels per second. It is the target of the horizontal
# movement in _physics_process():
#     velocity.x = move_toward(velocity.x, dir * run_speed, accel * delta)   (dir is -1, 0 or 1)
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
#     velocity.y = jump_speed
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
#     velocity.y += gravity_px * LevelData.gravity_scale * delta
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

# FLOOR_SNAP: how far down (px) the body follows the floor when it walks off a small edge (Godot's default is 1). A vehicle sets its own while it is in use.
const FLOOR_SNAP := 1.0

# HEALTH_BAR_OFFSET: where the health bar's centre sits relative to the player's feet, in
# pixels (negative y = above). It should clear the top of the sprite and hitbox (see
# BODY_SIZE); make y more negative if the bar overlaps the head.
const HEALTH_BAR_OFFSET := Vector2(0, -154)

# ENERGY_BAR_OFFSET / ENERGY_BAR_SIZE: where the blue energy bar sits (just under the health bar) and how big it is (slimmer than the health bar).
const ENERGY_BAR_OFFSET := Vector2(0, -140)
const ENERGY_BAR_SIZE := Vector2(76, 6)

# ENERGY_BAR_FILL / ENERGY_BAR_BACK: the energy bar's colours (blue on dark blue; the mech's bar is the same).
const ENERGY_BAR_FILL := Color("#3aa0ff")
const ENERGY_BAR_BACK := Color("#14223c")

# THROW_ENERGY_COST: the share of the energy bar one throw uses (0.1 = 10%); a throw needs this much energy left. ENERGY_RECOVERY: the share of the
# bar that comes back every second while the player is not throwing or firing the EMP gun (0.1 = 10% a second), a little every physics step. Bleeding halves it.
const THROW_ENERGY_COST := 0.1
const ENERGY_RECOVERY := 0.1

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
# The values below start as the constants above and may be changed per level by a level file (see apply_tuning()). Code
# reads these variables, never the constants, so a level can make the player faster, floatier and so on.
var run_speed := SPEED
var run_accel := ACCEL
var jump_speed := JUMP_VELOCITY
var gravity_px := GRAVITY
var climb_px := CLIMB_SPEED
var max_health := MAX_HEALTH
var invuln_seconds := INVULN_TIME
var hazard_fraction := HAZARD_DAMAGE_FRACTION
var throw_cooldown := THROW_COOLDOWN
var knock_x := KNOCKBACK_X
var knock_up := KNOCKBACK_UP
var stun_seconds := STUN_TIME
var fall_death_px := FALL_DEATH_HEIGHT
var pit_delay := PIT_DEATH_DELAY
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
var _emp := EmpGun.new()    # the EMP gun: it fires for as long as the heavy attack button is held (see EmpGun)
var _emp_firing := false      # the EMP gun fired in the last step
var _emp_pose_timer := 0.0     # while above zero, the EMP gun is in the hand and the arm is out (see EmpGun.POSE_TIME)
var _regrab_timer := 0.0  # while above zero, ladders cannot be grabbed (after jumping off one)
var _peak_y := 0.0     # highest point (smallest y) reached since last standing/climbing
var _ladder := Rect2()  # the ladder being climbed (valid while climbing)
var _facing := 1
var _hurt_timer := 0.0
var _invuln_timer := 0.0
var _stun_timer := 0.0
var _status: PlayerStatus     # the poison, burning, bleeding and radiation (made in _ready)
var _visuals: PlayerSprite
var _health_bar: HealthBar
var _energy_bar: HealthBar

## What throwing uses (see THROW_ENERGY_COST). The mech has its own (Mech.energy).
var energy := Energy.new()
var _body_shape: CollisionShape2D
var _body_rect: RectangleShape2D

## The vehicle the player is in (see Mech), or null on foot.
var mech: Mech

var _pickup_frozen := false     # held in place while a vehicle is assembled round them (see MechAssembly)

# SCRIPTED_WALK_ARRIVE: how close (px) to its spot a scripted walk (walk_to()) must get to be finished. SCRIPTED_WALK_SLOW: within this many pixels of the spot the
# walk slows down in proportion, so the player stops on it instead of overshooting.
const SCRIPTED_WALK_ARRIVE := 6.0
const SCRIPTED_WALK_SLOW := 80.0

## Emitted when a scripted walk (walk_to()) has brought the player to its spot.
signal walk_finished

var _walk_to := NAN             # the x the player is walking to by themselves (NAN: they are not)


func _ready() -> void:
	_status = PlayerStatus.new(self)
	z_index = 2
	add_to_group(Groups.PLAYER)
	_peak_y = global_position.y
	collision_mask = PhysicsLayers.PLAYER_MASK
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = BODY_SIZE
	shape.shape = rect
	shape.position = Vector2(0, -BODY_SIZE.y / 2.0)
	add_child(shape)
	_body_shape = shape
	_body_rect = rect

	add_child(PlayerShadow.new())  # added first so it draws behind the sprite

	_visuals = PlayerSprite.new()
	add_child(_visuals)

	_health_bar = HealthBar.new()
	_health_bar.position = HEALTH_BAR_OFFSET
	_health_bar.set_title(display_name)
	add_child(_health_bar)
	health_changed.connect(func(current: int, maximum: int) -> void:
		_health_bar.set_ratio(float(current) / maximum))
	health_changed.emit(health, max_health)
	_energy_bar = HealthBar.new()
	_energy_bar.position = ENERGY_BAR_OFFSET
	_energy_bar.bar_size = ENERGY_BAR_SIZE
	_energy_bar.fill_color = ENERGY_BAR_FILL
	_energy_bar.back_color = ENERGY_BAR_BACK
	_energy_bar.set_ratio(energy.level)
	add_child(_energy_bar)


## Returns true if the hit landed (not blocked by invulnerability). `from_enemy` is false for spikes and the like: only an enemy's hit is made worse by radiation sickness.
## `source_x` is the x of whatever hit us, if it has a position: the knockback pushes away from it.
func take_damage(amount: int, source_x: float = NAN, from_enemy := true) -> bool:
	if _invuln_timer > 0.0 or _pit_dying or _pickup_frozen or is_walking_to():     # (nothing stops a player on their way into a door)
		return false
	if mech != null:
		return _mech_takes_damage(amount, source_x)
	if from_enemy:
		amount = roundi(float(amount) * _status.damage_taken_scale())     # (radiation sickness makes enemies hit harder)
	health = maxi(0, health - amount)
	health_changed.emit(health, max_health)
	if health == 0:
		die("health")
	else:
		_invuln_timer = invuln_seconds
		_hurt_timer = HURT_TIME
		_stun_timer = stun_seconds
		_windup = -1.0            # a hit interrupts a throw
		_throw_pose_timer = 0.0
		_emp_pose_timer = 0.0
		_stop_climb()
		var push := -_facing
		if not is_nan(source_x) and not is_equal_approx(source_x, global_position.x):
			push = 1 if global_position.x > source_x else -1
		velocity = Vector2(push * knock_x, knock_up)
		_visuals.flinch(_facing)
		_visuals.blink(invuln_seconds)
	return true


## The player's body box in world pixels, as things that hurt it test it (it is wider in a vehicle: its chassis, and taller).
func body_box() -> Rect2:
	var half := half_width()
	var height := _body_rect.size.y
	return Rect2(global_position + Vector2(-half, -height), Vector2(half * 2.0, height))


## True if a ladder is within reach right now (see _find_ladder()).
func ladder_in_reach() -> bool:
	if mech != null:
		# the vehicle is wider than a ladder and may stand beside it (its body stopped by the wall the ladder leans on): any ladder under its body counts
		var body := Rect2(global_position.x - half_width(), global_position.y - BODY_SIZE.y * Mech.SIZE_IN_PLAYERS, half_width() * 2.0, BODY_SIZE.y * Mech.SIZE_IN_PLAYERS)
		for l in ladders:
			if body.intersects(l):
				return true
		return false
	return _find_ladder(-1.0).has_area() or _find_ladder(1.0).has_area()


## Half the width of the body as it is drawn and as enemies keep their distance from it: the player's, or the vehicle's chassis.
func half_width() -> float:
	return maxf(BODY_SIZE.x * 0.5, Mech.CHASSIS_SIZE.x * 0.5 if mech != null else 0.0)


## Which way the player faces: 1 right, -1 left.
func facing() -> int:
	return _facing


## Resize the hit box to `factor` times the player's size (the feet stay where they are). Used by a vehicle.
func set_body_scale(factor: float) -> void:
	_body_rect.size = BODY_SIZE * factor
	_body_shape.position = Vector2(0, -BODY_SIZE.y * factor / 2.0)


## Hold the player where they are while a vehicle is built round them (a power-up pickup): they cannot move, fall, be hurt or be pushed until
## end_pickup_freeze().
func freeze_for_pickup() -> void:
	_pickup_frozen = true
	velocity = Vector2.ZERO
	_stop_climb()
	_windup = -1.0
	_throw_pose_timer = 0.0
	_emp_pose_timer = 0.0


## The player's own picture and bars go (the pilot in the new vehicle takes their place).
func hide_for_pickup() -> void:
	_visuals.visible = false
	_health_bar.visible = false
	_energy_bar.visible = false


func end_pickup_freeze() -> void:
	_pickup_frozen = false


func is_frozen_for_pickup() -> bool:
	return _pickup_frozen


## Walk to the world position x by themselves: the controls are ignored until they get there (walk_finished). It is how the player walks into a door (ExitDoor).
func walk_to(x: float) -> void:
	_walk_to = x


## True while a scripted walk (walk_to()) is under way: the controls do nothing.
func is_walking_to() -> bool:
	return not is_nan(_walk_to)


## The direction (-1 to 1) of a scripted walk this step, slowing down near the spot; the walk ends when the spot is reached, or when a wall stops the player short of it
## (a vehicle, which is wider, cannot always get right to the middle of a doorway beside a wall).
func _scripted_dir() -> float:
	var gap := _walk_to - global_position.x
	var blocked := is_on_wall() and signf(get_wall_normal().x) == -signf(gap)
	if absf(gap) <= SCRIPTED_WALK_ARRIVE or blocked:
		_walk_to = NAN
		walk_finished.emit()
		return 0.0
	return clampf(gap / SCRIPTED_WALK_SLOW, -1.0, 1.0)


## Get into the mech (a power-up): the player's own picture and health bar are hidden, the hit box grows and the mech fights, moves and
## takes the damage until it is destroyed.
func board_mech(carried_in := false) -> void:
	if mech != null:
		return
	_stop_climb()
	_clear_status()
	_windup = -1.0
	_throw_pose_timer = 0.0
	_emp_pose_timer = 0.0
	global_position.y -= 2.0
	mech = Mech.new()
	add_child(mech)
	mech.setup(self)
	mech.destroyed.connect(_on_mech_destroyed)
	_visuals.visible = false
	_health_bar.visible = false
	_energy_bar.visible = false
	_invuln_timer = maxf(_invuln_timer, 0.8)
	if carried_in:
		_invuln_timer = 0.0      # (it came with the player from the last level: nothing to protect from)


func _on_mech_destroyed() -> void:
	_leave_mech(true)
	velocity = Vector2(-_facing * 160.0, -520.0)    # thrown out of the wreck
	_invuln_timer = 1.5
	_hurt_timer = HURT_TIME
	_visuals.blink(1.5)


## Out of the mech (it was destroyed, or the player died).
func _leave_mech(explode: bool) -> void:
	if mech == null:
		return
	var m := mech
	mech = null
	GameStats.lose_mech()
	m.release(explode)
	_visuals.visible = true
	_health_bar.visible = true
	_energy_bar.visible = true


## A hit while in the mech: the mech takes it (the player's own health is untouched). Knocked back a little, then invulnerable briefly.
func _mech_takes_damage(amount: int, source_x: float) -> bool:
	var push := -_facing
	if not is_nan(source_x) and not is_equal_approx(source_x, global_position.x):
		push = 1 if global_position.x > source_x else -1
	var broke := mech.take_damage(amount)
	if not broke:
		_invuln_timer = invuln_seconds
		velocity = Vector2(push * knock_x * 0.5, knock_up * 0.4)
	return true


## Poisoned (by the toxic puffer fish): for the next `ticks` times, DamageOverTime.TICK_TIME seconds apart, lose `fraction` of the maximum
## health, without being knocked back or made invulnerable. Poison never kills: it stops at 1 health point (the puffer's bite
## does the killing, a pit or a fall does the rest). Another poisoning restarts the count. The player is tinted green meanwhile.
func apply_poison(ticks: int, fraction: float) -> void:
	if not _immune_to_status():
		_status.apply(_status.poison, ticks, fraction)


## True while a poisoning is still hurting.
func is_poisoned() -> bool:
	return _status.is_poisoned()


## Set on fire (by a lava ball): for the next `ticks` times, DamageOverTime.TICK_TIME seconds apart, lose `fraction` of the maximum health,
## without being knocked back or made invulnerable, and for as long as it lasts thrown objects only go PlayerStatus.BURN_THROW_RANGE of their
## usual distance. Like poison it never kills, and a new burning restarts the count. A burning player is tinted orange and has
## flames. (A lava ball sets 1% per tick for 16 ticks: a quarter of the poison's rate for four times as long.)
func apply_burn(ticks: int, fraction: float) -> void:
	if not _immune_to_status():
		_status.apply(_status.burn, ticks, fraction)


## True while a burning is still hurting.
func is_burning() -> bool:
	return _status.is_burning()


## Bleeding (from a piranha bite): for the next `ticks` times, DamageOverTime.TICK_TIME seconds apart, lose `fraction` of the maximum health
## (like burning, never below 1 point), and the energy bar refills at half speed meanwhile. The player flashes red and drips blood.
func apply_bleed(ticks: int, fraction: float) -> void:
	if not _immune_to_status():
		_status.apply(_status.bleed, ticks, fraction)


## True while a bleeding is still hurting.
func is_bleeding() -> bool:
	return _status.is_bleeding()


## Radiation sickness (from an eel's touch): a slow loss of health (a third of a burn's rate, for twice as long) and, for as long as it lasts, every hit from
## an enemy does PlayerStatus.RADIATION_DAMAGE_TAKEN times its damage. The player has a radioactive glow.
func apply_radiation(ticks: int, fraction: float) -> void:
	if not _immune_to_status():
		_status.apply(_status.radiation, ticks, fraction)


## True while radiation sickness lasts.
func is_radiated() -> bool:
	return _status.is_radiated()


## How far thrown objects go right now, as a fraction of the normal range.
func throw_range_scale() -> float:
	return _status.throw_range_scale()


## The mech's hull keeps poison and fire out, and a player who is dying cannot be set on fire.
func _immune_to_status() -> bool:
	return mech != null or _pit_dying or health <= 0


## One physics step of the poison and the burning: what they take off now (never below 1 health point).
func _status_step(delta: float) -> void:
	var lost := _status.step(delta)
	if lost > 0 and health > 1:
		health = maxi(1, health - lost)
		health_changed.emit(health, max_health)


## The energy bar refills a little every step while the player is not throwing or firing the EMP gun (and more slowly while bleeding).
func _recover_energy(delta: float) -> void:
	if _throw_timer <= 0.0 and _windup < 0.0 and not _emp_firing:
		energy.recover(delta, ENERGY_RECOVERY * _status.energy_recovery_scale())
	_energy_bar.set_ratio(energy.level)


func _clear_status() -> void:
	_status.clear()


## The picture the player is shown with (PlayerStatus tints it).
func visuals() -> PlayerSprite:
	return _visuals


## Interact with whatever is in reach. The player only announces it (the interacted signal); the
## level decides whether there is a computer in reach.
func interact() -> void:
	interacted.emit()


## The player's weapon: throw an everyday object, picked at random (see SpriteLibrary.PROJECTILES), in the
## direction the player faces. It flies in an arc (see Projectile).
func attack_light() -> void:
	if mech != null:
		return    # in the mech the light attack is the laser: the Mech works it for as long as the button is held
	if _throw_timer > 0.0 or _emp_firing or climbing or _stun_timer > 0.0 or not energy.spend(THROW_ENERGY_COST):
		return
	_energy_bar.set_ratio(energy.level)
	_throw_timer = throw_cooldown
	_windup = THROW_WINDUP
	_throw_pose_timer = THROW_POSE_TIME


## The object leaves the hand (called when the wind-up ends).
func _release_throw() -> void:
	var names: Array = SpriteLibrary.PROJECTILES.keys()
	var from := global_position + Vector2(_facing * THROW_HAND.x, THROW_HAND.y)
	var obj := Projectile.launch(get_parent(), names[randi() % names.size()], from, _facing, velocity, throw_range_scale())
	threw.emit(obj)


## The heavy attack at the moment the button goes down: in the mech the missile turret. (On foot the heavy attack is the EMP gun, which fires for as long as the button is held:
## see EmpGun and _physics_process().)
func attack_heavy() -> void:
	if mech != null:
		mech.fire_missile()


## Apply a level's values (see the "player" and "terrain" sections of a level file; tools/level_editor/catalog.json lists them).
## Keys that are missing keep their defaults. Call it once, right after creating the player.
func apply_tuning(player_values: Dictionary, terrain_values: Dictionary = {}) -> void:
	display_name = str(player_values.get("name", display_name))
	run_speed = float(player_values.get("speed", run_speed))
	run_accel = float(player_values.get("accel", run_accel))
	jump_speed = float(player_values.get("jump_velocity", jump_speed))
	gravity_px = float(player_values.get("gravity", gravity_px))
	climb_px = float(player_values.get("climb_speed", climb_px))
	max_health = int(player_values.get("max_health", max_health))
	health = max_health
	invuln_seconds = float(player_values.get("invuln_time", invuln_seconds))
	hazard_fraction = float(player_values.get("hazard_damage_fraction", hazard_fraction))
	throw_cooldown = float(player_values.get("throw_cooldown", throw_cooldown))
	knock_x = float(player_values.get("knockback_x", knock_x))
	knock_up = float(player_values.get("knockback_up", knock_up))
	stun_seconds = float(player_values.get("stun_time", stun_seconds))
	fall_death_px = float(terrain_values.get("fall_death_height", fall_death_px))
	pit_delay = float(terrain_values.get("pit_death_delay", pit_delay))
	if is_inside_tree():
		health_changed.emit(health, max_health)


## Damage dealt to the player by one hazard hit (spikes): a share of MAX_HEALTH, see HAZARD_DAMAGE_FRACTION.
static func hazard_damage() -> int:
	return roundi(MAX_HEALTH * HAZARD_DAMAGE_FRACTION)


## Fell into a deadly pit (see PitHazard): all health is lost and the player dies.
## The player keeps falling to the bottom, can no longer be controlled, blinks for PIT_DEATH_DELAY seconds
## down there, then the death is declared and they respawn (see _pit_step()).
func fall_in_pit() -> void:
	if _pit_dying:
		return
	_leave_mech(false)
	_clear_status()
	_pit_dying = true
	_pit_timer = -1.0
	health = 0
	health_changed.emit(health, max_health)
	_stop_climb()
	_windup = -1.0
	_throw_pose_timer = 0.0
	_emp_pose_timer = 0.0
	_visuals.update_pose(&"hurt", _facing, 0.0)


func _pit_step(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, run_accel * delta)
	if not is_on_floor():
		velocity.y += gravity_px * LevelData.gravity_scale * delta
	move_and_slide()
	if is_on_floor() and _pit_timer < 0.0:
		_pit_timer = pit_delay
		_visuals.blink(pit_delay)
	if _pit_timer >= 0.0:
		_pit_timer -= delta
		if _pit_timer <= 0.0:
			die("pit")
	_visuals.update_pose(&"hurt", _facing, delta)


## Out of health or a deadly fall: back to the last checkpoint with a full bar.
func die(cause: String = "health") -> void:
	_leave_mech(false)
	_pit_dying = false
	_walk_to = NAN
	_clear_status()
	died.emit(cause)
	_peak_y = spawn.y
	energy.fill()
	health = max_health
	health_changed.emit(health, max_health)
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
	if _pickup_frozen:
		velocity = Vector2.ZERO
		_visuals.update_pose(&"idle", _facing, delta)
		return
	var dir := Input.get_axis(InputActions.MOVE_LEFT, InputActions.MOVE_RIGHT)
	var vdir := Input.get_axis(InputActions.MOVE_UP, InputActions.MOVE_DOWN)  # negative = up
	_hurt_timer = maxf(0.0, _hurt_timer - delta)
	_invuln_timer = maxf(0.0, _invuln_timer - delta)
	_stun_timer = maxf(0.0, _stun_timer - delta)
	_status_step(delta)
	_throw_timer = maxf(0.0, _throw_timer - delta)
	_emp_firing = _emp.work(self, mech == null and not climbing and _stun_timer <= 0.0 and not is_walking_to() and Input.is_action_pressed(InputActions.ATTACK_HEAVY), delta)
	if _emp_firing:
		_emp_pose_timer = EmpGun.POSE_TIME
	if mech == null:
		_recover_energy(delta)
	_throw_pose_timer = maxf(0.0, _throw_pose_timer - delta)
	_emp_pose_timer = maxf(0.0, _emp_pose_timer - delta)
	if _windup >= 0.0:
		_windup -= delta
		if _windup <= 0.0:
			_windup = -1.0
			if _stun_timer <= 0.0 and not climbing:   # knocked about or grabbed a ladder mid wind-up: no throw
				_release_throw()
	if _stun_timer > 0.0:
		dir = 0.0  # knocked back: no steering for a moment
	var scripted := is_walking_to()      # walking into a door: the controls do nothing
	if scripted:
		dir = _scripted_dir()
		vdir = 0.0

	if not scripted and Input.is_action_just_pressed(InputActions.INTERACT):
		interact()
	if not scripted and Input.is_action_just_pressed(InputActions.ATTACK_LIGHT):
		attack_light()
	if not scripted and Input.is_action_just_pressed(InputActions.ATTACK_HEAVY):
		attack_heavy()

	if hazard_count > 0 and mech == null:      # (the mech walks over spikes unharmed)
		take_damage(roundi(max_health * hazard_fraction), NAN, false)  # ignored while invulnerable (spikes are not an enemy: no extra for radiation)

	# Up/down grabs a ladder when one is in reach: standing at its bottom, standing on its
	# top deck (down only), or catching it mid-jump. Otherwise up falls through to a jump.
	_regrab_timer = maxf(0.0, _regrab_timer - delta)
	if not climbing and mech == null and vdir != 0.0 and _stun_timer <= 0.0 and _regrab_timer <= 0.0:
		var ladder := _find_ladder(vdir)
		if ladder.has_area():
			_start_climb(ladder)

	# Jump button while on a ladder: let go and leap off, steering with left/right.
	var ladder_jump := false
	if climbing and not scripted and Input.is_action_just_pressed(InputActions.JUMP):
		_stop_climb()
		_regrab_timer = LADDER_REGRAB_TIME
		ladder_jump = true

	if climbing:
		# Locked to the ladder: only up/down, no sideways movement. You leave at the top deck,
		# the bottom floor, or by pressing jump (handled above).
		velocity = Vector2(0.0, vdir * climb_px)
	else:
		# Weaker deceleration while stunned so the knockback actually carries.
		var accel := 500.0 if _stun_timer > 0.0 else run_accel
		if mech != null:
			accel = 500.0 if _stun_timer > 0.0 else Mech.ACCEL
		velocity.x = move_toward(velocity.x, dir * (Mech.SPEED if mech != null else SPEED), accel * delta)
		if ladder_jump:
			velocity.y = jump_speed
		elif not is_on_floor():
			velocity.y += gravity_px * LevelData.gravity_scale * delta
		elif not scripted and (Input.is_action_just_pressed(InputActions.JUMP) or (Input.is_action_just_pressed(InputActions.MOVE_UP) and not TouchControls.should_show() and not (mech != null and ladder_in_reach()))):
			# "jump" (Space / the JUMP button) always jumps. On a keyboard "move_up" (W / Up)
			# is both jump and climb: a ladder in reach was already grabbed above (so we'd be
			# climbing, not here); otherwise it jumps. On a phone the D-pad's up never jumps.
			velocity.y = mech.start_jump() if mech != null else jump_speed

	if mech != null:
		mech.before_move(dir, delta)   # climbs steps and works the booster
	move_and_slide()

	if climbing:
		_keep_on_ladder(vdir)

	_track_fall()

	if dir != 0.0 and not climbing:
		_facing = 1 if dir > 0.0 else -1
	_visuals.update_pose(_pose_state(vdir), _facing, delta)
	_visuals.set_gun(_emp_pose_timer > 0.0 and mech == null, _facing)


## Track the highest point of the current fall and die if we land too far below it.
func _track_fall() -> void:
	if climbing:
		_peak_y = global_position.y
	elif is_on_floor():
		if global_position.y - _peak_y > fall_death_px:
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
	collision_mask = PhysicsLayers.PLAYER_CLIMBING_MASK  # pass through the ladder's top deck both ways
	velocity = Vector2.ZERO
	global_position.x = ladder.get_center().x  # snap onto the ladder's centre line


func _stop_climb() -> void:
	climbing = false
	collision_mask = PhysicsLayers.PLAYER_MASK


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
	if _emp_pose_timer > 0.0 and not climbing:
		return &"shoot"
	if _throw_pose_timer > 0.0 and not climbing:
		return &"throw_windup" if _windup >= 0.0 else &"throw_release"
	if climbing:
		return &"climb" if vdir != 0.0 else &"climb_idle"
	if not is_on_floor():
		return &"jump" if velocity.y < 0.0 else &"fall"
	if absf(velocity.x) > 20.0:
		return &"walk"
	return &"idle"
