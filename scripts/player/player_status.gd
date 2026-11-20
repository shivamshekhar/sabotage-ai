class_name PlayerStatus
extends RefCounted
## The player's ailments: four DamageOverTime effects and how they show on the player.
##   poison     (puffer fish)  green tint
##   burn       (lava ball)    orange tint and flames; thrown objects only go half as far
##   bleed      (piranha bite) the player flashes red and drips blood; the energy bar refills at half speed
##   radiation  (eel touch)    a green-yellow radioactive glow; left and right, up and down are swapped (see Player.controls_swapped())
## Player owns one and forwards apply_poison() / apply_burn() / apply_bleed() / apply_radiation() and the questions to it; nothing else needs to
## know how they work.

# The tints (a player with several is tinted by the first in this order: burning, bleeding, radiation, poison).
const POISON_TINT := Color(0.62, 1.0, 0.45)
const BURN_TINT := Color(1.0, 0.66, 0.5)
const RADIATION_TINT := Color(0.8, 1.0, 0.5)

# BLEED_TINT: the red the bleeding player flashes to. BLEED_FLASH_SPEED: how fast the flashing goes, in radians per second (6 is about one flash a
# second). BLEED_FLASH_MAX: how far (0 to 1) the colour goes to red at the brightest flash.
const BLEED_TINT := Color(1.0, 0.18, 0.18)
const BLEED_FLASH_SPEED := 9.0
const BLEED_FLASH_MAX := 0.85

# BURN_THROW_RANGE: how far a thrown object goes while burning, as a fraction of the normal range (0.5 = half).
const BURN_THROW_RANGE := 0.5

# BLEED_ENERGY_RECOVERY: the share of the normal energy recovery while bleeding (0.5 = half speed).
const BLEED_ENERGY_RECOVERY := 0.5

# RADIATION_GLOW_*: the halo of a radiated player: its colour, its size (a multiple of the body's height), and how it pulses (size and strength
# swing, and speed in radians per second).
const RADIATION_GLOW_COLOR := Color(0.55, 1.0, 0.2, 0.5)
const RADIATION_GLOW_SIZE := 1.9
const RADIATION_GLOW_PULSE := 0.18
const RADIATION_GLOW_SPEED := 4.0

# The particle streams over the body. A stream's `share` is how much of the body (of its width and height) it covers, `height` where its middle is
# (a share of the body height above the feet); the others are the usual particle settings.
const Z_ABOVE := 3
const FLAMES := {"amount": 34, "life": 0.55, "share": 0.4, "height": 0.45, "spread": 25.0, "gravity": Vector2(0.0, -60.0),
		"speed": Vector2(30.0, 80.0), "size": Vector2(0.12, 0.3), "color": Color(1.0, 0.55, 0.15, 0.9), "additive": true,
		"fade": [Color(1.0, 1.0, 0.6, 0.0), Color(1.0, 0.9, 0.5, 1.0), Color(1.0, 0.2, 0.05, 0.0)], "fade_at": [0.0, 0.2, 1.0]}
const BLOOD := {"amount": 16, "life": 0.7, "share": 0.35, "height": 0.6, "spread": 30.0, "gravity": Vector2(0.0, 520.0),
		"speed": Vector2(4.0, 30.0), "size": Vector2(0.06, 0.12), "color": Color(0.85, 0.05, 0.08, 1.0), "additive": false, "direction": Vector2.DOWN,
		"fade": [Color(1.0, 0.3, 0.3, 1.0), Color(0.75, 0.02, 0.05, 0.9), Color(0.5, 0.0, 0.03, 0.0)], "fade_at": []}
const RADIATION_MOTES := {"amount": 22, "life": 0.9, "share": 0.45, "height": 0.5, "spread": 180.0, "gravity": Vector2(0.0, -30.0),
		"speed": Vector2(10.0, 40.0), "size": Vector2(0.05, 0.12), "color": Color(0.7, 1.0, 0.3, 1.0), "additive": true,
		"fade": [Color(0.8, 1.0, 0.4, 0.0), Color(0.75, 1.0, 0.3, 1.0), Color(0.4, 1.0, 0.1, 0.0)], "fade_at": []}

var poison := DamageOverTime.new()
var burn := DamageOverTime.new()
var bleed := DamageOverTime.new()
var radiation := DamageOverTime.new()
var flames: CPUParticles2D        # each of these is made the first time it is needed
var drips: CPUParticles2D
var motes: CPUParticles2D
var halo: Sprite2D

var _player: Player
var _clock := 0.0


func _init(owner_player: Player) -> void:
	_player = owner_player


func is_poisoned() -> bool:
	return poison.active()


func is_burning() -> bool:
	return burn.active()


func is_bleeding() -> bool:
	return bleed.active()


func is_radiated() -> bool:
	return radiation.active()


## How far thrown objects go right now, as a fraction of the normal range (1, or BURN_THROW_RANGE while burning).
func throw_range_scale() -> float:
	return BURN_THROW_RANGE if burn.active() else 1.0


## How fast the energy bar refills right now, as a fraction of the normal speed (1, or BLEED_ENERGY_RECOVERY while bleeding).
func energy_recovery_scale() -> float:
	return BLEED_ENERGY_RECOVERY if bleed.active() else 1.0


## Start poisoning, burning, bleeding or irradiating the player (`effect` is one of this class's DamageOverTime) for `ticks` ticks of `fraction`
## of their maximum health.
func apply(effect: DamageOverTime, ticks: int, fraction: float) -> void:
	effect.apply(ticks, float(_player.max_health) * fraction)
	update_look()


## One physics step of all the effects: the health they take off is returned (the player never goes below 1 point from them) and the look is
## updated when one ends or flashes. Returns the total taken off.
func step(delta: float) -> int:
	_clock += delta
	var lost := 0
	for effect: DamageOverTime in [poison, burn, bleed, radiation]:
		var was_active := effect.active()
		lost += effect.step(delta)
		if was_active and not effect.active():
			update_look()
	if bleed.active() or radiation.active():
		_update_tint()
		_update_halo()
	return lost


func clear() -> void:
	for effect: DamageOverTime in [poison, burn, bleed, radiation]:
		effect.clear()
	update_look()


## The tint and the particles and halo of the effects that are on.
func update_look() -> void:
	_update_tint()
	if burn.active() and flames == null:
		flames = _make_stream(FLAMES)
	if bleed.active() and drips == null:
		drips = _make_stream(BLOOD)
	if radiation.active() and motes == null:
		motes = _make_stream(RADIATION_MOTES)
	for pair: Array in [[flames, burn], [drips, bleed], [motes, radiation]]:
		if pair[0] != null:
			(pair[0] as CPUParticles2D).emitting = (pair[1] as DamageOverTime).active()
	if radiation.active() and halo == null:
		_make_halo()
	_update_halo()


func _update_tint() -> void:
	var visuals := _player.visuals()
	if visuals == null:
		return
	var tint := Color.WHITE
	if burn.active():
		tint = BURN_TINT
	elif bleed.active():
		var flash := 0.5 + 0.5 * sin(_clock * BLEED_FLASH_SPEED)
		tint = Color.WHITE.lerp(BLEED_TINT, flash * BLEED_FLASH_MAX)
	elif radiation.active():
		tint = RADIATION_TINT
	elif poison.active():
		tint = POISON_TINT
	visuals.modulate = Color(tint.r, tint.g, tint.b, visuals.modulate.a)


## The halo of radiation: on while irradiated, breathing in size and strength.
func _update_halo() -> void:
	if halo == null:
		return
	halo.visible = radiation.active()
	if halo.visible:
		var pulse := 0.5 + 0.5 * sin(_clock * RADIATION_GLOW_SPEED)
		halo.scale = Vector2.ONE * (RADIATION_GLOW_SIZE * Player.BODY_SIZE.y / float(halo.texture.get_height())) * (1.0 + RADIATION_GLOW_PULSE * pulse)
		halo.modulate = Color(RADIATION_GLOW_COLOR, RADIATION_GLOW_COLOR.a * (0.7 + 0.3 * pulse))


func _make_halo() -> void:
	halo = Sprite2D.new()
	halo.texture = PitHazard.glow_texture()
	halo.material = Blend.additive()
	halo.z_index = Z_ABOVE
	halo.position = Vector2(0.0, -Player.BODY_SIZE.y * 0.5)
	_player.add_child(halo)


## A stream of particles over the player's body, made from a settings dictionary like FLAMES (it stays on the player).
func _make_stream(settings: Dictionary) -> CPUParticles2D:
	var body := Player.BODY_SIZE
	var preset := ParticlePreset.new()
	preset.texture = PitHazard.glow_texture()
	preset.additive = bool(settings["additive"])
	preset.one_shot = false
	preset.explosiveness = 0.0
	preset.amount = int(settings["amount"])
	preset.lifetime = float(settings["life"])
	preset.direction = settings.get("direction", Vector2.UP)
	preset.spread = float(settings["spread"])
	preset.gravity = settings["gravity"]
	preset.speed_min = (settings["speed"] as Vector2).x
	preset.speed_max = (settings["speed"] as Vector2).y
	preset.scale_min = (settings["size"] as Vector2).x
	preset.scale_max = (settings["size"] as Vector2).y
	preset.world_space = false
	preset.colors = ParticlePreset.fade_gradient(settings["fade"], settings["fade_at"])
	var p := preset.build()
	p.color = settings["color"]
	p.z_index = Z_ABOVE
	p.position = Vector2(0.0, -body.y * float(settings["height"]))
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	var share := float(settings["share"])
	p.emission_rect_extents = Vector2(body.x * share, body.y * share)
	_player.add_child(p)
	return p
