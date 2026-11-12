class_name Piranha
extends Node2D
## A robot piranha living in a piranha tank (see PitHazard). It hides under the liquid, then pops up at its own spot and
## either peeks out snapping its jaws or leaps out to one side - towards the player when they are near - and
## bites if it hits them (10% of the player's health). One thrown object destroys it. It has no health bar. A
## destroyed piranha comes back at the same spot after RESPAWN_TIME seconds, and only then: a living one never
## "respawns". While its pit is off screen it is hidden and does no work at all (PitHazard switches that).
##
## Its position is the middle of its body. It is in the "enemies" group so thrown objects find it (see
## Projectile), but it is only hittable while it is above the surface.

signal defeated

# BITE_FRACTION: share of the player's maximum health taken by one bite.
#     damage = round(Player.MAX_HEALTH * BITE_FRACTION)
# Higher: a more dangerous fish.
const BITE_FRACTION := 0.1

# RESPAWN_TIME: seconds a destroyed piranha stays gone before it is back at its spot.
const RESPAWN_TIME := 6.0

# SENSE_RANGE: how far in pixels (sideways) from its spot the player is noticed, and SENSE_HEIGHT how far above the
# surface they may be. A noticed player is leapt at; otherwise the fish leaps or peeks at random.
const SENSE_RANGE := 420.0
const SENSE_HEIGHT := 360.0

# AIMED_CHANCE: when it notices the player, the chance (0 to 1) that the next appearance is a leap at them.
const AIMED_CHANCE := 0.85

# FISH_SCALE: size of a piranha relative to its 152 px sprite. HIDE_DEPTH: how far in pixels below the surface a
# hidden fish waits (deep enough to be fully behind the liquid).
const FISH_SCALE := 0.62
const HIDE_DEPTH := 52.0

# LEAP_HEIGHT_MIN / LEAP_HEIGHT_MAX: how high above the surface a leap peaks, in pixels. LEAP_REACH_MIN / MAX: how far
# sideways a leap goes. LEAP_TIME_MIN / MAX: how long a leap lasts, in seconds. PEEK_HEIGHT: how far a peeking
# piranha's head sticks out of the surface.
const LEAP_HEIGHT_MIN := 110.0
const LEAP_HEIGHT_MAX := 190.0
const LEAP_REACH_MIN := 70.0
const LEAP_REACH_MAX := 190.0
const LEAP_TIME_MIN := 0.85
const LEAP_TIME_MAX := 1.3
const PEEK_HEIGHT := 34.0

# LURK_MIN / LURK_MAX: how long in seconds a fish stays hidden between appearances.
const LURK_MIN := 0.3
const LURK_MAX := 2.0

# CHOMP_TIME: seconds one bite takes (jaw opens wide, hangs, then snaps shut, then a short rest); CHOMP_ANGLE: how wide the
# jaw opens, in radians (positive swings it down). Higher angle: a bigger gape.
const CHOMP_TIME := 0.55
const CHOMP_ANGLE := 0.95

# JAW_HINGE / EYE_POSITION: where the lower jaw is hinged and where the glowing eye sits, in the body sprite's pixels
# from its top-left corner (at 1x).
const JAW_HINGE := Vector2(122, 60)
const EYE_POSITION := Vector2(125, 43)

# EYE_GLOW_MIN / EYE_GLOW_MAX: how strongly the eye's red glow shines at the dim and bright points of its pulse (0 to 1).
# Keep MAX modest: the glow is additive, so a high value blows out the head.
const EYE_GLOW_MIN := 0.25
const EYE_GLOW_MAX := 0.6

# HURT_BOX: the size in pixels of the part of the fish that counts as touching (the player, or a thrown object).
const HURT_BOX := Vector2(76, 46)

enum State { LURK, PEEK, LEAP, DEAD }

var state := State.LURK
var surface_y := 0.0
var home_x := 0.0          # where it pops up
var x_min := 0.0           # the sideways limits of its leaps (the inside of the pit)
var x_max := 0.0

var _timer := 0.0
var _flip: Node2D
var _jaw: Sprite2D
var _eye: Sprite2D
var _t := 0.0              # time inside the current peek or leap
var _leap_from := 0.0
var _leap_to := 0.0
var _leap_height := 0.0
var _leap_time := 1.0
var _rng := RandomNumberGenerator.new()
var _player: Node2D
var _active := true
var _body_visible := true


## A piranha that pops up at `spot_x`, in a tank whose surface is at `surface` and whose inside spans `left` to `right`.
func _init(surface: float = 0.0, spot_x: float = 0.0, left: float = 0.0, right: float = 0.0) -> void:
	surface_y = surface
	home_x = spot_x
	x_min = left
	x_max = right


## Bite damage in health points (see BITE_FRACTION).
static func bite_damage() -> int:
	return roundi(Player.MAX_HEALTH * BITE_FRACTION)


func _ready() -> void:
	_rng.seed = int(home_x) * 7 + int(surface_y)
	add_to_group("enemies")
	z_index = PitHazard.FISH_Z   # behind the liquid, in front of the player
	_flip = Node2D.new()          # mirrors the fish when it swims left, so it is never upside down
	var body := Sprite2D.new()
	body.texture = SpriteLibrary.pit("piranha_tank", "fish_body")
	body.centered = false
	var half := body.texture.get_size() / 2.0
	body.offset = -half
	_jaw = Sprite2D.new()
	_jaw.texture = SpriteLibrary.pit("piranha_tank", "fish_jaw")
	_jaw.centered = false
	_jaw.offset = Vector2(0, -9)                    # the hinge is at the jaw image's left edge, 9 px down
	_jaw.position = JAW_HINGE - half
	_jaw.z_index = -1                               # behind the body, so the upper jaw covers it when shut
	_eye = Sprite2D.new()
	_eye.texture = SpriteLibrary.pit("piranha_tank", "fish_eye")
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_eye.material = add
	_eye.position = EYE_POSITION - half
	_flip.add_child(_jaw)
	_flip.add_child(body)
	_flip.add_child(_eye)
	add_child(_flip)
	scale = Vector2.ONE * FISH_SCALE
	# the jaw snaps open and shut all the time, and the eye pulses
	var chomp := create_tween().set_loops()
	chomp.tween_property(_jaw, "rotation", CHOMP_ANGLE, CHOMP_TIME * 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)   # open wide
	chomp.tween_interval(CHOMP_TIME * 0.15)                                                                                     # hang
	chomp.tween_property(_jaw, "rotation", 0.0, CHOMP_TIME * 0.12).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)           # snap shut
	chomp.tween_interval(CHOMP_TIME * 0.45)                                                                                     # rest
	var pulse := create_tween().set_loops()
	pulse.tween_property(_eye, "modulate:a", EYE_GLOW_MIN, 0.5).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(_eye, "modulate:a", EYE_GLOW_MAX, 0.5).set_trans(Tween.TRANS_SINE)
	_hide_and_lurk()


## Wake or put to sleep (Level does this for enemies far from the player, PitHazard when the tank is off screen).
func set_active(value: bool) -> void:
	if value == _active:
		return
	_active = value
	set_physics_process(value)
	visible = value and _body_visible


func _hide_and_lurk() -> void:
	state = State.LURK
	position = Vector2(home_x, surface_y + HIDE_DEPTH)
	rotation = 0.0
	_flip.scale = Vector2.ONE
	modulate = Color.WHITE
	_body_visible = true
	visible = _active
	_timer = _rng.randf_range(LURK_MIN, LURK_MAX)


func _physics_process(delta: float) -> void:
	match state:
		State.LURK:
			_timer -= delta
			if _timer <= 0.0:
				_appear()
		State.PEEK:
			_t += delta
			_peek_step()
		State.LEAP:
			_t += delta
			_leap_step()
		State.DEAD:
			_timer -= delta
			if _timer <= 0.0:
				_hide_and_lurk()
	if state == State.PEEK or state == State.LEAP:
		_bite_check()


## The fish's own reach: it notices the player near its spot and above the surface.
func _noticed_player() -> Node2D:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
	if _player == null:
		return null
	var dx := _player.global_position.x - home_x
	var dy := surface_y - _player.global_position.y
	if absf(dx) <= SENSE_RANGE and dy <= SENSE_HEIGHT and dy >= -200.0:
		return _player
	return null


func _appear() -> void:
	var target := _noticed_player()
	if target != null and _rng.randf() < AIMED_CHANCE:
		_start_leap(target)
	elif _rng.randf() < 0.45:
		_start_peek()
	else:
		_start_leap(null)


func _start_peek() -> void:
	state = State.PEEK
	_t = 0.0
	rotation = -0.5
	_flip.scale = Vector2.ONE
	_splash(Vector2(home_x, surface_y))


func _peek_step() -> void:
	# up in 0.3 s, hold for 0.7 s, down in 0.3 s
	var low := surface_y + HIDE_DEPTH
	var high := surface_y - PEEK_HEIGHT + 16.0
	if _t < 0.3:
		position.y = lerpf(low, high, ease(_t / 0.3, 0.35))
	elif _t < 1.0:
		position.y = high
	elif _t < 1.3:
		position.y = lerpf(high, low, (_t - 1.0) / 0.3)
	else:
		_hide_and_lurk()


## A leap to one side: at the player when there is one to aim at, otherwise left or right at random.
func _start_leap(target: Node2D) -> void:
	state = State.LEAP
	_t = 0.0
	var dir := 1.0 if _rng.randf() < 0.5 else -1.0
	var reach := _rng.randf_range(LEAP_REACH_MIN, LEAP_REACH_MAX)
	_leap_height = _rng.randf_range(LEAP_HEIGHT_MIN, LEAP_HEIGHT_MAX)
	if target != null:
		dir = signf(target.global_position.x - home_x)
		if dir == 0.0:
			dir = 1.0
		reach = clampf(absf(target.global_position.x - home_x), LEAP_REACH_MIN, LEAP_REACH_MAX)
		# peak about as high as the player's chest
		_leap_height = clampf(surface_y - (target.global_position.y - 64.0) + 30.0, LEAP_HEIGHT_MIN, LEAP_HEIGHT_MAX)
	_leap_from = home_x
	_leap_to = clampf(home_x + dir * reach, x_min, x_max)
	if absf(_leap_to - _leap_from) < 40.0:
		_leap_to = clampf(home_x - dir * reach, x_min, x_max)
	_leap_time = _rng.randf_range(LEAP_TIME_MIN, LEAP_TIME_MAX)
	_flip.scale = Vector2(1.0, -1.0 if _leap_to < _leap_from else 1.0)
	_splash(Vector2(home_x, surface_y))


func _leap_step() -> void:
	var u := _t / _leap_time
	if u >= 1.0:
		_splash(Vector2(_leap_to, surface_y))
		_hide_and_lurk()   # it swims back to its spot out of sight
		return
	# a parabola: starts and ends hidden below the surface and peaks _leap_height above it
	var rise := _leap_height + HIDE_DEPTH
	position = Vector2(lerpf(_leap_from, _leap_to, u), surface_y + HIDE_DEPTH - rise * 4.0 * u * (1.0 - u))
	rotation = atan2(-rise * 4.0 * (1.0 - 2.0 * u), _leap_to - _leap_from)   # nose along the direction of travel


func _bite_check() -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
	if _player == null or not (_player is Player):
		return
	var feet := _player.global_position
	var box := Rect2(feet.x - Player.BODY_SIZE.x / 2.0, feet.y - Player.BODY_SIZE.y, Player.BODY_SIZE.x, Player.BODY_SIZE.y)
	if hurtbox().intersects(box):
		(_player as Player).take_damage(bite_damage(), global_position.x)   # invulnerable for a moment after: no repeats


# ---------- being hurt ----------

## The part of the fish that can be hit, in world pixels: only while it is out of the liquid; otherwise an empty
## rectangle far away (so a thrown object passing over the water does not hit it).
func hurtbox() -> Rect2:
	if (state == State.PEEK or state == State.LEAP) and global_position.y < surface_y + 10.0:
		return Rect2(global_position - HURT_BOX / 2.0, HURT_BOX)
	return Rect2(Vector2(-1.0e7, -1.0e7), Vector2.ZERO)


## A thrown object hit: one hit destroys it (whatever `fraction` is: a piranha has no health). It returns after RESPAWN_TIME.
func take_hit(_fraction: float, _from_x: float = NAN) -> void:
	if state == State.DEAD:
		return
	state = State.DEAD
	_timer = RESPAWN_TIME
	defeated.emit()
	_splash(Vector2(global_position.x, surface_y))
	var tw := create_tween()
	tw.tween_property(self, "rotation", rotation + 2.5, 0.25)
	tw.parallel().tween_property(self, "modulate:a", 0.0, 0.25)
	tw.tween_callback(func() -> void: _body_visible = false; visible = false)


## A little burst of droplets at the surface where the fish breaks through or lands.
func _splash(at: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.texture = PitHazard.glow_texture()
	p.global_position = at
	p.top_level = true            # in world space, not scaled and moved with the fish
	p.z_index = 5
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 8
	p.lifetime = 0.55
	p.direction = Vector2(0, -1)
	p.spread = 55.0
	p.gravity = Vector2(0, 700)
	p.initial_velocity_min = 140.0
	p.initial_velocity_max = 260.0
	p.scale_amount_min = 0.05
	p.scale_amount_max = 0.12
	p.color = Color(0.85, 0.95, 1.0, 0.9)
	add_child(p)
	p.emitting = true
	get_tree().create_timer(0.8).timeout.connect(p.queue_free)
