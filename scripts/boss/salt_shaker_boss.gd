class_name SaltShakerBoss
extends Node2D
## The first boss, RAM SALTMAN: a glass salt shaker full of stolen data-center hardware. He hovers around the arena glaring, where the
## player can hit him with thrown objects. Every so often he charges over the player, turns upside down and SHAKES himself like a real
## salt shaker (rocking side to side and bouncing up and down, the hardware inside rattling about), spraying RAM sticks, CPUs and chipsets
## down through the holes of his cap; then he flips back and returns to hover. He can only be hurt while he hovers (and while he
## returns), never while he is attacking.
##
## His look is a SaltmanVisual (layers and expressions, see there). His position is the middle of his body. He is in the "enemies"
## group, so thrown objects find him (see Projectile: hurtbox(), take_hit()). Set him up with setup() after adding him to the tree.

signal defeated

enum State { HOVER, WINDUP, FLIP_DOWN, SPRAY, FLIP_UP, RETURN, DEAD }

# SIZE_IN_PLAYERS: how tall the boss is, in player heights (Player.BODY_SIZE.y). 2.16 = a bit over twice the player.
const SIZE_IN_PLAYERS := 2.16

# MAX_HEALTH: his hit points (a thrown object does Projectile.DAMAGE = 10 of them, a laser hit 20, a missile 80). Higher: a longer fight.
const MAX_HEALTH := 500

# HOVER_HEIGHT: how far above the floor the middle of the boss floats while hovering, in pixels. It must be low enough for thrown
# objects (which leave the hand about 92 px up) to reach the boss's body, and high enough that the player walks safely beneath it.
const HOVER_HEIGHT := 245.0

# SWAY: how far left and right of the arena's middle the hover drifts, in pixels, and how fast (SWAY_SPEED in radians per second;
# the drift takes TAU / SWAY_SPEED seconds to go back and forth). BOB: the small up and down float, in pixels.
const SWAY := 480.0
const SWAY_SPEED := 0.55
const BOB := 14.0

# FIRST_HOVER_TIME: seconds of hovering before the very first attack, so the fight starts calmly and the player can see where everything is.
const FIRST_HOVER_TIME := 7.0

# HOVER_TIME: seconds of hovering between attacks (a random time between the two). Shorter: a more aggressive boss.
const HOVER_TIME_MIN := 4.0
const HOVER_TIME_MAX := 6.0

# ATTACK_HEIGHT: how far above the floor the middle of the boss is while he sprays (upside down).
const ATTACK_HEIGHT := 425.0

# SWOOP_SPEED: how fast he charges to a spot above the player, and flies home, in pixels per second.
const SWOOP_SPEED := 560.0

# FOLLOW_SPEED: how fast he follows the player's x while spraying, in pixels per second. The player runs at 380, so they can get out
# from under him, but only by running.
const FOLLOW_SPEED := 210.0

# FLIP_TIME: seconds the boss takes to turn over (and back).
const FLIP_TIME := 0.55

# SHAKING: how he shakes while spraying (like shaking a salt shaker). ROCK_ANGLE is how far he tips to either side in radians and
# ROCK_SPEED how fast, in radians per second; SHAKE_BOUNCE is how far he jerks up and down in pixels and SHAKE_SPEED how fast; SHAKE_SWAY
# is the sideways slide that goes with the rocking, in pixels. SHAKE_RAMP is the seconds he takes to get going and to settle down.
const ROCK_ANGLE := 0.24
const ROCK_SPEED := 17.0
const SHAKE_BOUNCE := 20.0
const SHAKE_SPEED := 34.0
const SHAKE_SWAY := 12.0
const SHAKE_RAMP := 0.3

# SPRAY_TIME: seconds of spraying, and the pause between two pieces (a random time between the two), for the first half of his
# health and once he is below half (ENRAGED_*).
const SPRAY_TIME := 3.6
const SPRAY_INTERVAL := Vector2(0.08, 0.12)
const ENRAGED_SPRAY_TIME := 4.6
const ENRAGED_SPRAY_INTERVAL := Vector2(0.05, 0.08)

# SPRAY_SPEED: launch speed range of a piece in pixels per second, and SPRAY_SPREAD the half angle in degrees of the cone it flies in
# (0 = straight down).
const SPRAY_SPEED := Vector2(240.0, 430.0)
const SPRAY_SPREAD := 34.0

# CONTACT_DAMAGE_FRACTION: share of the player's maximum health lost by touching the boss's body.
const CONTACT_DAMAGE_FRACTION := 0.1

# BODY_FRACTION: how much of the picture's width and height counts as the boss's body (for being hit and for touching it).
const BODY_FRACTION := Vector2(0.78, 0.9)

# HURT_FACE_TIME: seconds the pained face shows after a hit.
const HURT_FACE_TIME := 0.4

# LEAN: how far he tips into a charge, in radians per pixel per second of his sideways speed, and the most he tips (radians).
const LEAN_PER_SPEED := 0.0006
const LEAN_MAX := 0.3

# NAME: shown above the health bar.
const BOSS_NAME := "RAM SALTMAN"

var state := State.HOVER
var health := MAX_HEALTH
var arena := Rect2()        # the open space of the arena in world pixels (the boss stays inside it)
var floor_y := 0.0          # the floor's height
var visual: SaltmanVisual   # what he looks like (layers, expressions)

var _bar: HealthBar
var _scale := 1.0
var _t := 0.0                       # the hover clock
var _state_time := 0.0              # seconds in the current state
var _hover_left := 0.0              # seconds of hovering still to do
var _spray_left := 0.0
var _spray_timer := 0.0
var _velocity := Vector2.ZERO       # how the boss moved this step (bullets inherit part of it)
var _flip := 0.0                    # 0 = upright, 1 = upside down
var _shake := 0.0                   # 0 = still, 1 = shaking fully (eases in and out)
var _lean := 0.0                    # tilt into the direction of travel
var _wobble := 0.0                  # a kick of rocking after being hit, fading away
var _hurt_flash := 0.0
var _hurt_face := 0.0
var _contact_timer := 0.0
var _player: Player


## Put the boss in an arena: `open_area` is the free space (world pixels) and `floor_level` the y of the floor.
func setup(open_area: Rect2, floor_level: float) -> void:
	arena = open_area
	floor_y = floor_level
	global_position = _home()
	reset_physics_interpolation()


func _ready() -> void:
	name = "SaltShakerBoss"
	z_index = 1
	add_to_group(Groups.ENEMIES)
	visual = SaltmanVisual.new()
	add_child(visual)       # (its layers are built in its _ready, so its size is known from here on)
	_scale = SIZE_IN_PLAYERS * Player.BODY_SIZE.y / visual.size.y
	visual.scale = Vector2(_scale, _scale)
	_bar = HealthBar.new()
	_bar.position = Vector2(0, -visual.size.y * _scale / 2.0 - 24.0)
	_bar.scale = Vector2(1.8, 1.8)
	_bar.set_title(BOSS_NAME)
	add_child(_bar)
	_bar.set_ratio(1.0)
	_enter(State.HOVER)
	_hover_left = FIRST_HOVER_TIME


## The boss's body in world coordinates: what touching it means.
func body_rect() -> Rect2:
	var size := visual.size * _scale * BODY_FRACTION
	return Rect2(global_position - size / 2.0, size)


## What thrown objects are tested against (see Projectile). The boss can only be hurt while he hovers or returns: otherwise the
## box is parked far away and everything flies straight through.
func hurtbox() -> Rect2:
	if state == State.HOVER or state == State.RETURN:
		return body_rect()
	return Rect2(Vector2(-1.0e7, -1.0e7), Vector2.ZERO)


## Thrown objects never burn up on him.
func burns_projectiles() -> bool:
	return false


## Enemies are woken and put to sleep by the level; the boss is always awake.
func set_active(_value: bool) -> void:
	pass


## A hit (a thrown object, a laser hit or a missile blast: see Projectile, Mech) takes `damage` hit points off, while he is hovering or returning.
func take_hit(damage: int, from_x: float = NAN) -> void:
	if state == State.DEAD or not (state == State.HOVER or state == State.RETURN):
		return
	health = maxi(0, health - damage)
	_bar.set_ratio(float(health) / MAX_HEALTH)
	_hurt_flash = 0.25
	_hurt_face = HURT_FACE_TIME
	GameStats.add_score(GameStats.BOSS_HIT_SCORE, _score_spot())
	var push := 1.0 if is_nan(from_x) or global_position.x > from_x else -1.0
	_wobble = 0.28 * push                  # knocked, he rocks away from where it hit
	if health == 0:
		_die()


## Where the points text of a hit appears: just above his top.
func _score_spot() -> Vector2:
	var r := body_rect()
	return Vector2(r.get_center().x, r.position.y - 8.0)


## Below half health he sprays for longer and faster.
func enraged() -> bool:
	return health * 2 <= MAX_HEALTH


func _home() -> Vector2:
	return Vector2(arena.get_center().x, floor_y - HOVER_HEIGHT)


func _enter(next: State) -> void:
	state = next
	_state_time = 0.0
	match next:
		State.HOVER:
			_hover_left = randf_range(HOVER_TIME_MIN, HOVER_TIME_MAX)
		State.SPRAY:
			_spray_left = ENRAGED_SPRAY_TIME if enraged() else SPRAY_TIME
			_spray_timer = 0.25


func _find_player() -> Player:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(Groups.PLAYER) as Player
	return _player


func _physics_process(delta: float) -> void:
	_t += delta
	_state_time += delta
	var before := global_position
	match state:
		State.HOVER:
			_hover(delta)
		State.WINDUP:
			_windup(delta)
		State.FLIP_DOWN:
			_flip = minf(_state_time / FLIP_TIME, 1.0)
			if _state_time >= FLIP_TIME:
				_enter(State.SPRAY)
		State.SPRAY:
			_spray(delta)
		State.FLIP_UP:
			_flip = 1.0 - minf(_state_time / FLIP_TIME, 1.0)
			_fly_to(_home(), SWOOP_SPEED * 0.6, delta)
			if _state_time >= FLIP_TIME:
				_enter(State.RETURN)
		State.RETURN:
			if _fly_to(_home(), SWOOP_SPEED, delta):
				_enter(State.HOVER)
		State.DEAD:
			_dead_step(delta)
	_velocity = (global_position - before) / maxf(delta, 0.0001)
	_hurt_flash = maxf(0.0, _hurt_flash - delta)
	_hurt_face = maxf(0.0, _hurt_face - delta)
	_animate(delta)
	_touch_player(delta)
	queue_redraw()


## Drifting left and right above the arena with a gentle bob.
func _hover(delta: float) -> void:
	var goal := _home() + Vector2(sin(_t * SWAY_SPEED) * SWAY, sin(_t * 1.7) * BOB)
	_fly_to(goal, 330.0, delta)
	_hover_left -= delta
	if _hover_left <= 0.0 and _find_player() != null:
		_enter(State.WINDUP)


## Charge over the player (the face goes hot and narrow to warn them) and, once there, turn over.
func _windup(delta: float) -> void:
	var player := _find_player()
	if player == null:
		_enter(State.HOVER)
		return
	var goal := Vector2(clampf(player.global_position.x, arena.position.x + 160.0, arena.end.x - 160.0), floor_y - ATTACK_HEIGHT)
	var arrived := _fly_to(goal, SWOOP_SPEED, delta)
	if arrived or _state_time > 2.2:
		_enter(State.FLIP_DOWN)


## Hang upside down above the player, following them, shaking, and rain hardware out of the cap.
func _spray(delta: float) -> void:
	var player := _find_player()
	if player != null:
		var goal_x := clampf(player.global_position.x, arena.position.x + 160.0, arena.end.x - 160.0)
		global_position.x = move_toward(global_position.x, goal_x, FOLLOW_SPEED * delta)
	global_position.y = move_toward(global_position.y, floor_y - ATTACK_HEIGHT, 120.0 * delta)
	_spray_left -= delta
	_spray_timer -= delta
	if _spray_timer <= 0.0 and _spray_left > 0.0:
		_fire_piece()
		var gap := ENRAGED_SPRAY_INTERVAL if enraged() else SPRAY_INTERVAL
		_spray_timer = randf_range(gap.x, gap.y)
	if _spray_left <= 0.0:
		_enter(State.FLIP_UP)


## One piece out of a random cap hole, flying down in a cone and carrying a little of the boss's own sideways speed.
func _fire_piece() -> void:
	var hole: Vector2 = visual.cap_holes[randi() % visual.cap_holes.size()]
	var from := visual.to_global(hole)
	var down := Vector2.DOWN.rotated(deg_to_rad(randf_range(-SPRAY_SPREAD, SPRAY_SPREAD)))
	var kinds := ["ram_stick", "ram_stick", "cpu", "chipset"]
	BossBullet.spray(get_parent(), kinds[randi() % kinds.size()], from, down * randf_range(SPRAY_SPEED.x, SPRAY_SPEED.y) + Vector2(_velocity.x * 0.4, 0.0))


## Move towards `goal` at most `speed` pixels per second; true once there.
func _fly_to(goal: Vector2, speed: float, delta: float) -> bool:
	global_position = global_position.move_toward(goal, speed * delta)
	global_position.x = clampf(global_position.x, arena.position.x + 150.0, arena.end.x - 150.0)
	return global_position.distance_to(goal) < 8.0


# ---------- looks and motion ----------

## Everything that makes him look alive, every physics step: the expression, the turn over, the shaking (rocking and bouncing like a
## real salt shaker, with the hardware rattling inside), leaning into a charge, and the kick of being hit. Each of these eases in and
## out, so poses blend into each other instead of snapping.
func _animate(delta: float) -> void:
	# which face
	var face := "idle"
	match state:
		State.WINDUP:
			face = "charge"
		State.FLIP_DOWN, State.SPRAY:
			face = "attack"
		State.DEAD:
			face = "dead"
	if _hurt_face > 0.0 and state != State.DEAD:
		face = "hurt"
	visual.set_expression(face)
	visual.set_hot(1.0 if state == State.SPRAY else 0.0)

	# how hard he is shaking: fully while spraying, a little while charging or just hit, easing in and out
	var want := 0.0
	match state:
		State.SPRAY:
			want = 1.0
		State.FLIP_DOWN:
			want = 0.5
		State.WINDUP:
			want = 0.3
		State.DEAD:
			want = 0.8
	if _hurt_face > 0.0:
		want = maxf(want, 0.6)
	_shake = move_toward(_shake, want, delta / SHAKE_RAMP)
	visual.set_shake(_shake)
	visual.set_slump(smoothstep(0.0, 1.0, _flip))

	# tipping into the direction of travel while charging or returning
	var lean_goal := 0.0
	if state == State.WINDUP or state == State.RETURN or state == State.FLIP_UP:
		lean_goal = clampf(_velocity.x * LEAN_PER_SPEED, -LEAN_MAX, LEAN_MAX)
	elif state == State.HOVER:
		lean_goal = cos(_t * SWAY_SPEED) * 0.07        # a lazy tilt in time with the drift
	_lean = lerpf(_lean, lean_goal, 1.0 - exp(-9.0 * delta))
	_wobble = move_toward(_wobble, 0.0, 0.5 * delta)

	# the turn over (eased, with a little overshoot wobble), then the rocking of the shake on top of it
	var eased := smoothstep(0.0, 1.0, _flip)
	var rock := sin(_t * ROCK_SPEED) * ROCK_ANGLE * _shake
	var wobble := _wobble * sin(_t * 22.0) if _wobble != 0.0 else 0.0
	visual.rotation = PI * eased + sin(_flip * PI) * 0.12 + _lean + rock + wobble
	# the jerking up and down and the slide that goes with the rocking (the sprite moves, not the boss, so the cap holes move with it)
	var bounce := sin(_t * SHAKE_SPEED) * SHAKE_BOUNCE * _shake
	var slide := sin(_t * ROCK_SPEED + 1.1) * SHAKE_SWAY * _shake
	visual.position = Vector2(slide, bounce)
	visual.modulate = _tint()
	visual.step(delta)


func _tint() -> Color:
	if _hurt_flash > 0.0:
		return Color(2.2, 2.2, 2.2)
	if state == State.WINDUP or state == State.FLIP_DOWN or state == State.SPRAY:
		return Color(1.0, 0.82, 0.82)      # flushed while he attacks (and then he cannot be hurt)
	return Color.WHITE


## Touching the boss's body hurts (the player is then knocked away).
func _touch_player(delta: float) -> void:
	if state == State.DEAD:
		return
	_contact_timer = maxf(0.0, _contact_timer - delta)
	var player := _find_player()
	if player == null or _contact_timer > 0.0:
		return
	var box := Rect2(player.global_position + Vector2(-Player.BODY_SIZE.x / 2.0, -Player.BODY_SIZE.y), Player.BODY_SIZE)
	if box.intersects(body_rect().grow_individual(0.0, 0.0, 0.0, -14.0)):      # (a little less at the bottom, so standing under him is safe)
		_contact_timer = 0.8
		player.take_damage(roundi(player.max_health * CONTACT_DAMAGE_FRACTION), global_position.x)


# ---------- defeat ----------

func _die() -> void:
	GameStats.add_score(GameStats.BOSS_SCORE, _score_spot())
	_enter(State.DEAD)
	remove_from_group(Groups.ENEMIES)
	for b in get_tree().get_nodes_in_group(Groups.BOSS_BULLETS):
		b.queue_free()
	defeated.emit()


## Shake, spill his hardware, then fade out.
func _dead_step(delta: float) -> void:
	_flip = move_toward(_flip, 0.0, delta / FLIP_TIME)
	if _state_time < 1.2 and int(_state_time * 20.0) != int((_state_time - delta) * 20.0):
		var kinds := ["ram_stick", "cpu", "chipset"]
		BossBullet.spray(get_parent(), kinds[randi() % kinds.size()], global_position + Vector2(randf_range(-120, 120), randf_range(-100, 60)),
				Vector2(randf_range(-260, 260), randf_range(-420, -120)), false)
	if _state_time > 1.0:
		global_position.y = move_toward(global_position.y, floor_y - visual.size.y * _scale * 0.3, 160.0 * delta)
		modulate.a = clampf(1.0 - (_state_time - 1.4) / 0.9, 0.0, 1.0)
		if _state_time > 2.4:
			queue_free()


## The boss's shadow on the floor: smaller and fainter the higher he floats.
func _draw() -> void:
	if floor_y <= 0.0:
		return
	var height := clampf((floor_y - global_position.y) / 520.0, 0.0, 1.0)
	var width := (visual.size.x * _scale * 0.5) * (1.0 - 0.35 * height)
	var at := Vector2(0.0, floor_y - global_position.y)
	draw_set_transform(at, 0.0, Vector2(1.0, 0.16))
	draw_circle(Vector2.ZERO, width, Color(0, 0, 0, 0.34 * (1.0 - 0.5 * height) * modulate.a))
