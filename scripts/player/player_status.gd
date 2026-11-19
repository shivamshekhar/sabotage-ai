class_name PlayerStatus
extends RefCounted
## The player's poison and burning: two DamageOverTime effects, the tint they give the player (green, orange) and the flames of a burning player.
## Player owns one and forwards apply_poison() / apply_burn() / is_poisoned() / is_burning() / throw_range_scale() to it; nothing else needs to know
## how they work.

# POISON_TINT / BURN_TINT: the colours the player is tinted (burning wins over poison).
const POISON_TINT := Color(0.62, 1.0, 0.45)
const BURN_TINT := Color(1.0, 0.66, 0.5)

# BURN_THROW_RANGE: how far a thrown object goes while burning, as a fraction of the normal range (0.5 = half).
const BURN_THROW_RANGE := 0.5

# The flames of a burning player: a stream of glowing particles over the body. FLAME_BODY_SHARE: how much of the body they cover (of its width and
# height); FLAME_HEIGHT: where their middle is (a share of the body height above the feet).
const FLAME_Z := 3
const FLAME_AMOUNT := 34
const FLAME_LIFE := 0.55
const FLAME_BODY_SHARE := 0.4
const FLAME_HEIGHT := 0.45
const FLAME_SPREAD := 25.0
const FLAME_GRAVITY := Vector2(0.0, -60.0)
const FLAME_SPEED := Vector2(30.0, 80.0)
const FLAME_SIZE := Vector2(0.12, 0.3)
const FLAME_COLOR := Color(1.0, 0.55, 0.15, 0.9)
const FLAME_FADE := [Color(1.0, 1.0, 0.6, 0.0), Color(1.0, 0.9, 0.5, 1.0), Color(1.0, 0.2, 0.05, 0.0)]
const FLAME_FADE_OFFSETS := [0.0, 0.2, 1.0]

var poison := DamageOverTime.new()
var burn := DamageOverTime.new()
var flames: CPUParticles2D        # made the first time the player burns

var _player: Player


func _init(owner_player: Player) -> void:
	_player = owner_player


func is_poisoned() -> bool:
	return poison.active()


func is_burning() -> bool:
	return burn.active()


## How far thrown objects go right now, as a fraction of the normal range (1, or BURN_THROW_RANGE while burning).
func throw_range_scale() -> float:
	return BURN_THROW_RANGE if burn.active() else 1.0


## Start poisoning or burning the player for `ticks` ticks of `fraction` of their maximum health.
func apply(effect: DamageOverTime, ticks: int, fraction: float) -> void:
	effect.apply(ticks, roundi(_player.max_health * fraction))
	update_look()


## One physics step of both effects: the health `step()` returns is taken off (never below 1 point) and the look is updated when one ends. Returns
## the total taken off.
func step(delta: float) -> int:
	var lost := 0
	for effect in [poison, burn]:
		var tick: int = (effect as DamageOverTime).step(delta)
		lost += tick
		if tick > 0 and not (effect as DamageOverTime).active():
			update_look()
	return lost


func clear() -> void:
	poison.clear()
	burn.clear()
	update_look()


## The tint (orange while burning, green while poisoned, burning wins) and the flames.
func update_look() -> void:
	var visuals := _player.visuals()
	if visuals != null:
		var tint := Color.WHITE
		if burn.active():
			tint = BURN_TINT
		elif poison.active():
			tint = POISON_TINT
		visuals.modulate = Color(tint.r, tint.g, tint.b, visuals.modulate.a)
	if burn.active() and flames == null:
		flames = _make_flames()
		_player.add_child(flames)
	if flames != null:
		flames.emitting = burn.active()


func _make_flames() -> CPUParticles2D:
	var body := Player.BODY_SIZE
	var preset := ParticlePreset.new()
	preset.texture = PitHazard.glow_texture()
	preset.additive = true
	preset.one_shot = false
	preset.explosiveness = 0.0
	preset.amount = FLAME_AMOUNT
	preset.lifetime = FLAME_LIFE
	preset.direction = Vector2.UP
	preset.spread = FLAME_SPREAD
	preset.gravity = FLAME_GRAVITY
	preset.speed_min = FLAME_SPEED.x
	preset.speed_max = FLAME_SPEED.y
	preset.scale_min = FLAME_SIZE.x
	preset.scale_max = FLAME_SIZE.y
	preset.world_space = false
	preset.colors = ParticlePreset.fade_gradient(FLAME_FADE, FLAME_FADE_OFFSETS)
	var p := preset.build()
	p.color = FLAME_COLOR
	p.z_index = FLAME_Z
	p.position = Vector2(0.0, -body.y * FLAME_HEIGHT)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(body.x * FLAME_BODY_SHARE, body.y * FLAME_BODY_SHARE)
	return p
