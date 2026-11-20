class_name PitCreature
extends Node2D
## A creature that lives in a deadly pit (see PitHazard): the robot piranha of the piranha tank, the poisonous puffer fish of the
## toxic waste, the lava balls of the lava and the glowing eels of the nuclear waste. They are all the same kind of enemy: they hide
## under the liquid, then pop up at their own spot and either peek out or leap to one side - towards the player when they are near -
## and hurt the player if they hit them (a share of the player's health; the puffer's poison keeps hurting for a few seconds). One
## thrown object destroys one. They have no health bar. A destroyed creature comes back at the same spot after RESPAWN_TIME seconds,
## and only then: a living one never "respawns". While its pit is off screen it is hidden and does no work at all (PitHazard
## switches that).
##
## What makes each kind different is its entry in SPECIES: its pictures, size, damage, how it is animated (the piranha snaps its jaws,
## the puffer inflates, the lava ball flickers, the eel swims), its glow and the particles it leaves. To add a creature, draw its
## frames (tools/art/generate_pit_creatures.py), add an entry here, and give its pit kind a creature in PitHazard.CREATURES.
##
## Its position is the middle of its body. It is in the "enemies" group so thrown objects find it (see Projectile), but it is only
## hittable while it is above the surface.

signal defeated

# BITE_FRACTION: share of the player's maximum health taken by one bite (the piranha's; the other kinds have their own `damage`).
#     damage = round(Player.MAX_HEALTH * BITE_FRACTION)
# Higher: a more dangerous fish.
const BITE_FRACTION := 0.1

# RESPAWN_TIME: seconds a destroyed creature stays gone; when they are up it is back at its spot and pops up at once. Fixed.
const RESPAWN_TIME := 5.0

# SENSE_RANGE: how far in pixels (sideways) from its spot the player is noticed, and SENSE_HEIGHT how far above the
# surface they may be. A noticed player is leapt at; otherwise the creature leaps or peeks at random.
const SENSE_RANGE := 420.0
const SENSE_HEIGHT := 360.0

# AIMED_CHANCE: when it notices the player, the chance (0 to 1) that the next appearance is a leap at them.
const AIMED_CHANCE := 0.85

# FISH_SCALE: size of a piranha relative to its 184 px sprite (each species has its own `scale`). HIDE_DEPTH: how far in pixels
# below the surface a hidden creature waits (deep enough to be fully behind the liquid; a species may need more).
const FISH_SCALE := 0.56
const HIDE_DEPTH := 52.0

# LEAP_HEIGHT_MIN / LEAP_HEIGHT_MAX: how high above the surface a leap peaks, in pixels. LEAP_REACH_MIN / MAX: how far
# sideways a leap goes. LEAP_TIME_MIN / MAX: how long a leap lasts, in seconds. PEEK_HEIGHT: how far a peeking
# creature's head sticks out of the surface. (A species can change the first three with `leap_height`, `leap_reach` and `leap_time`.)
const LEAP_HEIGHT_MIN := 110.0
const LEAP_HEIGHT_MAX := 190.0
const LEAP_REACH_MIN := 70.0
const LEAP_REACH_MAX := 190.0
const LEAP_TIME_MIN := 0.85
const LEAP_TIME_MAX := 1.3
const PEEK_HEIGHT := 34.0

# LURK_TIME: how long in seconds a creature stays hidden between one appearance and the next. Fixed. (The first appearance after the
# level starts is staggered along the pit, see first_delay.)
const LURK_TIME := 2.0

# BITE_STEPS: one bite, as a list of [mouth pose, seconds it is shown]. The poses are the four drawn frames of the fish
# (see SpriteLibrary.PIT_FISH_PARTS): 0 closed, 1 slightly open, 2 open, 3 wide open. The mouth rests shut, opens
# in steps, hangs wide, then snaps shut again; the bite repeats for as long as the fish is awake. Longer times: a slower,
# more menacing chomp; the last (closed) entry is the pause between bites.
const BITE_STEPS := [[1, 0.06], [2, 0.06], [3, 0.16], [2, 0.05], [1, 0.04], [0, 0.4]]

# LEAP_BITE_STEPS: the same, for a fish that is leaping out of the water: it comes out with its jaws wide open, and snaps them
# shut and open again while it flies, so the open mouth is what you see most of the time. The mouth only moves while the fish
# is out of the water (peeking or leaping); a hidden one keeps it closed.
const LEAP_BITE_STEPS := [[3, 0.3], [2, 0.05], [1, 0.04], [0, 0.07], [1, 0.04], [2, 0.05]]

# EYE_POSITION: where the piranha's glowing eye sits, in the fish frame's pixels from its top-left corner (at 1x).
const EYE_POSITION := Vector2(136, 44)

# EYE_GLOW_MIN / EYE_GLOW_MAX: how strongly the eye's red glow shines at the dim and bright points of its pulse (0 to 1).
# Keep MAX modest: the glow is additive, so a high value blows out the head.
const EYE_GLOW_MIN := 0.25
const EYE_GLOW_MAX := 0.6

# HURT_BOX: the size in pixels of the part of the piranha that counts as touching (the player, or a thrown object); the other
# species have their own `hurt`.
const HURT_BOX := Vector2(84, 58)

# SPECIES: the kinds of creature. `liquid` is the pit kind whose art folder holds its `parts` (the frames; SpriteLibrary.pit()),
# `scale` its size, `hurt` its touching box, `damage` the share of the player's health one hit takes, `anim` how the frames are
# used ("mouth" snap, "inflate", "flicker", "swim"), `frame_time` the seconds per frame of the flickering and swimming ones,
# `hide` how deep it waits (HIDE_DEPTH if missing), `splash` the colour of the spray it makes at the surface. Optional: `eye`
# (the piranha's glowing eye), `glow` (a colour: an additive copy of the picture that pulses), `trail` (particles it leaves while
# it is out of the water: colour, how many per second, how long they live, whether they glow), `poison` ([ticks, share of health
# per tick] a hit makes the player suffer, see Player.apply_poison()), `burn` (the same for Player.apply_burn(): a lava ball's 16 ticks of 1%), `bleed` (Player.apply_bleed(): the piranha's bite, the same rate and time as a burn), `radiation` (Player.apply_radiation(): the eel, 0.75 of a burn's rate and 1.25 times as long: 20 ticks of 0.75%), `leap_height`,
# `leap_reach`, `leap_time` ([min, max]), `lurk` (seconds hidden between appearances, instead of LURK_TIME), `vertical` (it only ever jumps straight up and down from its spot, never peeks or leaps
# sideways), `fire` (it is made of fire: a thrown object that hits it burns up and does not hurt it) and `anchor` (the pixel of the
# picture that is the creature's position, if not the middle: the fireball's head, so its flame trails behind it).
const SPECIES := {
	"piranha": {"liquid": "piranha_tank", "parts": ["fish_closed", "fish_slight", "fish_open", "fish_wide"], "scale": 0.56,
		"hurt": Vector2(84, 58), "damage": 0.1, "anim": "mouth", "eye": true, "splash": Color(0.85, 0.95, 1.0, 0.9), "bleed": [16, 0.01]},
	"puffer": {"liquid": "toxic_waste", "parts": ["puffer_small", "puffer_mid", "puffer_big"], "scale": 0.5210,
		"hurt": Vector2(64, 58), "damage": 0.08, "anim": "inflate", "hide": 53.0, "splash": Color(0.6, 1.0, 0.3, 0.9),
		"poison": [4, 0.04], "trail": {"color": Color(0.55, 1.0, 0.25, 0.85), "rate": 14.0, "life": 0.9, "glow": false}},
	"lava_ball": {"liquid": "lava", "parts": ["ball_a", "ball_b", "ball_c"], "scale": 0.8,
		"hurt": Vector2(68, 68), "damage": 0.15, "anim": "flicker", "frame_time": 0.08, "hide": 66.0, "glow": Color(1.0, 0.5, 0.1),
		"splash": Color(1.0, 0.6, 0.15, 0.95), "leap_height": [221.0, 351.0], "leap_time": [1.95, 2.05], "lurk": 3.5,
		"vertical": true, "fire": true, "burn": [16, 0.01], "anchor": Vector2(188, 62),
		"trail": {"color": Color(1.0, 0.65, 0.2, 0.95), "rate": 30.0, "life": 0.7, "glow": true}},
	"eel": {"liquid": "nuclear_waste", "parts": ["eel_a", "eel_b", "eel_c", "eel_d"], "scale": 0.4144,
		"hurt": Vector2(83, 26), "damage": 0.12, "anim": "swim", "frame_time": 0.11, "hide": 29.0, "glow": Color(0.5, 1.0, 0.3),
		"splash": Color(0.7, 1.0, 0.4, 0.95), "radiation": [20, 0.0075], "leap_reach": [110.0, 250.0], "leap_height": [90.0, 170.0], "leap_time": [1.0, 1.4],
		"trail": {"color": Color(0.7, 1.0, 0.4, 0.9), "rate": 12.0, "life": 0.8, "glow": true}},
}

# AILMENTS: the SPECIES keys that make the player suffer something, each one [ticks, share of health per tick] for Player.apply_<name>().
const AILMENTS := ["poison", "burn", "bleed", "radiation"]

enum State { LURK, PEEK, LEAP, DEAD }

var state := State.LURK
var surface_y := 0.0
var home_x := 0.0          # where it pops up
var x_min := 0.0           # the sideways limits of its leaps (the inside of the pit)
var x_max := 0.0

## The kind of creature (a key of SPECIES) and its entry.
var species_name := "piranha"
var species: Dictionary = SPECIES["piranha"]

## The share of the player's health a hit takes, and seconds until a destroyed creature returns (start as the species' / the constants above).
var bite_fraction := BITE_FRACTION
var respawn_time := RESPAWN_TIME

## Seconds until the first appearance after the level starts (PitHazard staggers the creatures of one pit, so they do not all jump at
## once); negative = LURK_TIME.
var first_delay := -1.0

var _timer := 0.0
var _flip: Node2D
var _body: Sprite2D
var _aura: Sprite2D        # an additive copy of the picture that makes glowing species shine
var _trail: CPUParticles2D
var _frames: Array[Texture2D] = []
var _eye: Sprite2D
var _t := 0.0              # time inside the current peek or leap
var _bite_t := 0.0         # time since it came out of the water, for the mouth / the inflating
var _clock := 0.0          # always running, for the flickering and swimming
var _leap_from := 0.0
var _leap_to := 0.0
var _leap_height := 0.0
var _leap_time := 1.0
var _rng := RandomNumberGenerator.new()
var _player: Node2D
var _active := true
var _body_visible := true


## A creature that pops up at `spot_x`, in a pit whose surface is at `surface` and whose inside spans `left` to `right`.
func _init(surface: float = 0.0, spot_x: float = 0.0, left: float = 0.0, right: float = 0.0, kind: String = "piranha") -> void:
	surface_y = surface
	home_x = spot_x
	x_min = left
	x_max = right
	species_name = kind
	species = SPECIES[kind]
	bite_fraction = float(species["damage"])


## Bite damage in health points (see BITE_FRACTION).
static func bite_damage() -> int:
	return roundi(Player.MAX_HEALTH * BITE_FRACTION)


func _ready() -> void:
	_rng.seed = int(home_x) * 7 + int(surface_y)
	add_to_group(Groups.ENEMIES)
	z_index = PitHazard.FISH_Z   # behind the liquid, in front of the player
	_flip = Node2D.new()          # mirrors the creature when it swims left, so it is never upside down
	for part in species["parts"]:
		_frames.append(SpriteLibrary.pit(str(species["liquid"]), str(part)))
	_body = Sprite2D.new()
	_body.texture = _frames[0]
	_body.centered = false
	var half := _frames[0].get_size() / 2.0
	var origin: Vector2 = species.get("anchor", half)   # the point of the picture that sits on the creature's position (its middle, or the fireball's head)
	_body.offset = -origin
	_flip.add_child(_body)
	if species.has("glow"):
		_aura = Sprite2D.new()
		_aura.texture = _frames[0]
		_aura.centered = false
		_aura.offset = -origin
		_aura.material = _additive()
		_aura.modulate = Color(species["glow"], 0.55)
		_flip.add_child(_aura)
		var shine := create_tween().set_loops()
		shine.tween_property(_aura, "modulate:a", 0.25, 0.45).set_trans(Tween.TRANS_SINE)
		shine.tween_property(_aura, "modulate:a", 0.7, 0.45).set_trans(Tween.TRANS_SINE)
	if bool(species.get("eye", false)):
		_eye = Sprite2D.new()
		_eye.texture = SpriteLibrary.pit(str(species["liquid"]), "fish_eye")
		_eye.material = _additive()
		_eye.position = EYE_POSITION - half
		_flip.add_child(_eye)
		var pulse := create_tween().set_loops()
		pulse.tween_property(_eye, "modulate:a", EYE_GLOW_MIN, 0.5).set_trans(Tween.TRANS_SINE)
		pulse.tween_property(_eye, "modulate:a", EYE_GLOW_MAX, 0.5).set_trans(Tween.TRANS_SINE)
	add_child(_flip)
	scale = Vector2.ONE * float(species["scale"])
	if species.has("trail"):
		_build_trail(species["trail"])
	_hide_and_lurk(first_delay)


func _additive() -> CanvasItemMaterial:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return m


## The particles a creature leaves behind while it is out of the water (embers, poison drops, glowing spray). They live in the
## world, not on the creature, so they stay where they were dropped.
func _build_trail(trail: Dictionary) -> void:
	_trail = CPUParticles2D.new()
	_trail.top_level = true
	_trail.z_index = 5
	_trail.texture = PitHazard.glow_texture()
	_trail.amount = maxi(4, int(float(trail["rate"]) * float(trail["life"])))
	_trail.lifetime = float(trail["life"])
	_trail.local_coords = false
	_trail.direction = Vector2(0, 1)
	_trail.spread = 70.0
	_trail.gravity = Vector2(0, 160)
	_trail.initial_velocity_min = 10.0
	_trail.initial_velocity_max = 50.0
	_trail.scale_amount_min = 0.05
	_trail.scale_amount_max = 0.13
	_trail.color = trail["color"]
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
	fade.colors = PackedColorArray([Color(1, 1, 1, 0.0), Color(1, 1, 1, 1.0), Color(1, 1, 1, 0.0)])
	_trail.color_ramp = fade
	if bool(trail["glow"]):
		_trail.material = _additive()
	_trail.emitting = false
	add_child(_trail)


## Wake or put to sleep (Level does this for enemies far from the player, PitHazard when the pit is off screen).
func set_active(value: bool) -> void:
	if value == _active:
		return
	_active = value
	set_physics_process(value)
	visible = value and _body_visible
	if _trail != null and not value:
		_trail.emitting = false


func _show_frame(index: int) -> void:
	_body.texture = _frames[index]
	if _aura != null:
		_aura.texture = _frames[index]


## The mouth pose (0 closed ... 3 wide open) at `t` seconds into a repeating list of [pose, seconds] steps.
static func mouth_pose(steps: Array, t: float) -> int:
	var total := 0.0
	for step in steps:
		total += float(step[1])
	t = fmod(t, total)
	for step in steps:
		t -= float(step[1])
		if t < 0.0:
			return int(step[0])
	return 0


func _hide_depth() -> float:
	return float(species.get("hide", HIDE_DEPTH))


## Seconds this kind waits under the liquid between appearances (LURK_TIME unless its species says otherwise).
func lurk_time() -> float:
	return float(species.get("lurk", LURK_TIME))


## Go (back) under the liquid at its spot and wait `wait` seconds (lurk_time() if not given) before the next appearance.
func _hide_and_lurk(wait: float = -1.0) -> void:
	state = State.LURK
	position = Vector2(home_x, surface_y + _hide_depth())
	rotation = 0.0
	_flip.scale = Vector2.ONE
	modulate = Color.WHITE
	_body_visible = true
	visible = _active
	_bite_t = 0.0
	_show_frame(0)
	if _trail != null:
		_trail.emitting = false
	_timer = wait if wait >= 0.0 else lurk_time()


func _physics_process(delta: float) -> void:
	_clock += delta
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
				_hide_and_lurk(0.0)   # respawned: it pops up again at once
	if state == State.PEEK or state == State.LEAP:
		_bite_t += delta
		_animate()
		_bite_check()
		if _trail != null:
			_trail.global_position = global_position
			_trail.emitting = true
	elif _trail != null:
		_trail.emitting = false


## Pick the picture for this moment (the creature is out of the water).
func _animate() -> void:
	var count := _frames.size()
	match str(species["anim"]):
		"mouth":
			_show_frame(mouth_pose(LEAP_BITE_STEPS if state == State.LEAP else BITE_STEPS, _bite_t))
		"inflate":   # puffs up as it breaks the surface, and lets some air out as it comes down
			var frame := 0 if _bite_t < 0.08 else (1 if _bite_t < 0.22 else count - 1)
			if state == State.LEAP and _t / _leap_time > 0.85:
				frame = 1
			_show_frame(frame)
		"flicker", "swim":
			_show_frame(int(_clock / float(species["frame_time"])) % count)


## The creature's own reach: it notices the player near its spot and above the surface.
func _noticed_player() -> Node2D:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(Groups.PLAYER) as Node2D
	if _player == null:
		return null
	var dx := _player.global_position.x - home_x
	var dy := surface_y - _player.global_position.y
	if absf(dx) <= SENSE_RANGE and dy <= SENSE_HEIGHT and dy >= -200.0:
		return _player
	return null


func _appear() -> void:
	if bool(species.get("vertical", false)):   # a lava ball only jumps straight up and down
		_start_leap(null)
		return
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
	var low := surface_y + _hide_depth()
	var high := surface_y - PEEK_HEIGHT + 16.0
	if _t < 0.3:
		position.y = lerpf(low, high, ease(_t / 0.3, 0.35))
	elif _t < 1.0:
		position.y = high
	elif _t < 1.3:
		position.y = lerpf(high, low, (_t - 1.0) / 0.3)
	else:
		_hide_and_lurk()


## A range [min, max] of the species (or the default one) as a random number.
func _range(key: String, default_min: float, default_max: float) -> float:
	var r: Array = species.get(key, [default_min, default_max])
	return _rng.randf_range(float(r[0]), float(r[1]))


## A leap to one side: at the player when there is one to aim at, otherwise left or right at random.
func _start_leap(target: Node2D) -> void:
	state = State.LEAP
	_t = 0.0
	if bool(species.get("vertical", false)):
		_leap_height = _range("leap_height", LEAP_HEIGHT_MIN, LEAP_HEIGHT_MAX)
		_leap_from = home_x
		_leap_to = home_x
		_leap_time = _range("leap_time", LEAP_TIME_MIN, LEAP_TIME_MAX)
		_flip.scale = Vector2.ONE
		_splash(Vector2(home_x, surface_y))
		return
	var dir := 1.0 if _rng.randf() < 0.5 else -1.0
	var reach := _range("leap_reach", LEAP_REACH_MIN, LEAP_REACH_MAX)
	_leap_height = _range("leap_height", LEAP_HEIGHT_MIN, LEAP_HEIGHT_MAX)
	var reach_limits: Array = species.get("leap_reach", [LEAP_REACH_MIN, LEAP_REACH_MAX])
	var height_limits: Array = species.get("leap_height", [LEAP_HEIGHT_MIN, LEAP_HEIGHT_MAX])
	if target != null:
		dir = signf(target.global_position.x - home_x)
		if dir == 0.0:
			dir = 1.0
		reach = clampf(absf(target.global_position.x - home_x), float(reach_limits[0]), float(reach_limits[1]))
		# peak about as high as the player's chest
		_leap_height = clampf(surface_y - (target.global_position.y - 64.0) + 30.0, float(height_limits[0]), float(height_limits[1]))
	_leap_from = home_x
	_leap_to = clampf(home_x + dir * reach, x_min, x_max)
	if absf(_leap_to - _leap_from) < 40.0:
		_leap_to = clampf(home_x - dir * reach, x_min, x_max)
	_leap_time = _range("leap_time", LEAP_TIME_MIN, LEAP_TIME_MAX)
	_flip.scale = Vector2(1.0, -1.0 if _leap_to < _leap_from else 1.0)
	_splash(Vector2(home_x, surface_y))


func _leap_step() -> void:
	var u := _t / _leap_time
	if u >= 1.0:
		_splash(Vector2(_leap_to, surface_y))
		_hide_and_lurk()   # it swims back to its spot out of sight
		return
	# a parabola: starts and ends hidden below the surface and peaks _leap_height above it
	var rise := _leap_height + _hide_depth()
	position = Vector2(lerpf(_leap_from, _leap_to, u), surface_y + _hide_depth() - rise * 4.0 * u * (1.0 - u))
	rotation = atan2(-rise * 4.0 * (1.0 - 2.0 * u), _leap_to - _leap_from)   # nose along the direction of travel
	if bool(species.get("vertical", false)):
		# its flame trails above it as it comes down: it flares up out of the liquid and gutters out as it falls back in
		modulate.a = clampf(u / 0.06, 0.0, 1.0) * clampf((1.0 - u) / 0.14, 0.0, 1.0)


func _bite_check() -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(Groups.PLAYER) as Node2D
	if _player == null or not (_player is Player):
		return
	var feet := _player.global_position
	var box := Rect2(feet.x - Player.BODY_SIZE.x / 2.0, feet.y - Player.BODY_SIZE.y, Player.BODY_SIZE.x, Player.BODY_SIZE.y)
	if hurtbox().intersects(box):
		# invulnerable for a moment after a hit: no repeats
		var landed: bool = (_player as Player).take_damage(roundi(Player.MAX_HEALTH * bite_fraction), global_position.x)
		if landed:
			for ailment in AILMENTS:
				if species.has(ailment):
					var values: Array = species[ailment]
					(_player as Player).call("apply_" + ailment, int(values[0]), float(values[1]))


# ---------- being hurt ----------

## The part of the creature that can be hit, in world pixels: only while it is out of the liquid; otherwise an empty
## rectangle far away (so a thrown object passing over the liquid does not hit it).
func hurtbox() -> Rect2:
	if (state == State.PEEK or state == State.LEAP) and global_position.y < surface_y + 10.0:
		var size: Vector2 = species["hurt"]
		return Rect2(global_position - size / 2.0, size)
	return Rect2(Vector2(-1.0e7, -1.0e7), Vector2.ZERO)


## True for a creature made of fire: a thrown object that hits it burns up (see Projectile).
func burns_projectiles() -> bool:
	return bool(species.get("fire", false))


## A thrown object hit: one hit destroys it (whatever `fraction` is: a creature has no health). It is back after RESPAWN_TIME (5 s).
## A creature of fire cannot be hurt at all.
func take_hit(_fraction: float, _from_x: float = NAN) -> void:
	if state == State.DEAD or burns_projectiles():
		return
	state = State.DEAD
	_timer = respawn_time
	defeated.emit()
	_splash(Vector2(global_position.x, surface_y))
	if _trail != null:
		_trail.emitting = false
	var tw := create_tween()
	tw.tween_property(self, "rotation", rotation + 2.5, 0.25)
	tw.parallel().tween_property(self, "modulate:a", 0.0, 0.25)
	tw.tween_callback(func() -> void: _body_visible = false; visible = false)


## A little burst of droplets at the surface where the creature breaks through or lands (in the colour of its liquid).
func _splash(at: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.texture = PitHazard.glow_texture()
	p.global_position = at
	p.top_level = true            # in world space, not scaled and moved with the creature
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
	p.color = species["splash"]
	add_child(p)
	p.emitting = true
	get_tree().create_timer(0.8).timeout.connect(p.queue_free)
