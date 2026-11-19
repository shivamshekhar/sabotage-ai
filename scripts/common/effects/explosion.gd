class_name Explosion
extends Node2D
## An explosion: a flash, a lumpy fireball that burns down into smoke (8 pictures, assets/effects/explosion_*.png), flying sparks, floating embers and
## rising smoke. Anything can use it (a missile, a vehicle blowing up, a boss); `strength` scales the whole thing (1 = a vehicle's own, small for a muzzle
## puff or a missile).
##
##   Explosion.spawn(get_parent(), global_position, 0.55)

# FRAMES: the number of fireball pictures. FRAME_TIME: seconds each is shown. LIFE: seconds before the effect is removed (the smoke is the last
# thing to go). FADE_TIME: how long the last picture takes to fade out.
const FRAMES := 8
const FRAME_TIME := 0.055
const LIFE := 1.7
const FADE_TIME := 0.3

# FIREBALL_SCALE: the size of the fireball picture on screen, per unit of strength (the pictures are 256 px; this shows them about 1.9 times their
# half size). FLASH_SCALE: the size of the glow behind the fireball, per unit of strength. FLASH_FRAMES: how many frames the flash lasts.
const FIREBALL_SCALE := 0.5 * 1.9
const FLASH_SCALE := 3.4
const FLASH_FRAMES := 4
const MAX_TILT := 0.4

# What flies out. Counts are for strength 1 and shrink with it (never below MIN_STRENGTH's share).
const MIN_STRENGTH := 0.5
const SPARKS := 26
const SPARK_LIFE := 0.7
const SPARK_SPEED := Vector2(140.0, 460.0)
const SPARK_GRAVITY := Vector2(0.0, 900.0)
const SPARK_SIZE := Vector2(0.25, 0.6)
const EMBERS := 12
const EMBER_LIFE := 1.1
const EMBER_SPEED := Vector2(20.0, 90.0)
const EMBER_GRAVITY := Vector2(0.0, -30.0)
const EMBER_SIZE := Vector2(0.1, 0.2)
const SMOKE_PUFFS := 8
const SMOKE_LIFE := 1.4
const SMOKE_SPEED := Vector2(20.0, 90.0)
const SMOKE_GRAVITY := Vector2(0.0, -30.0)
const SMOKE_SIZE := Vector2(0.35, 0.7)
const SMOKE_GROWTH := Vector2(0.5, 1.7)
const SMOKE_VARIANTS := 3

var _age := 0.0
var _strength := 1.0
var _fireball: Sprite2D
var _flash: Sprite2D


## Set off an explosion at the world position `at` under `parent`.
static func spawn(parent: Node, at: Vector2, strength := 1.0) -> Explosion:
	var e := Explosion.new()
	e._strength = strength
	e.global_position = at
	e.z_index = 4
	parent.add_child(e)
	e._build()
	return e


func _build() -> void:
	var s := maxf(_strength, MIN_STRENGTH)
	_flash = Sprites.glow(AssetPaths.effect("missile_glow"), FLASH_SCALE * _strength)
	add_child(_flash)
	_fireball = Sprites.make(AssetPaths.effect_frame("explosion", 0), FIREBALL_SCALE * _strength)
	_fireball.rotation = randf_range(-MAX_TILT, MAX_TILT)
	add_child(_fireball)

	var heat := ParticlePreset.fade_gradient([Color(1.0, 0.95, 0.75, 1.0), Color(1.0, 0.6, 0.2, 0.9), Color(0.6, 0.2, 0.08, 0.0)])
	var sparks := ParticlePreset.new()
	sparks.texture = AssetPaths.effect("spark")
	sparks.additive = true
	sparks.amount = int(SPARKS * s)
	sparks.lifetime = SPARK_LIFE
	sparks.speed_min = SPARK_SPEED.x * _strength
	sparks.speed_max = SPARK_SPEED.y * _strength
	sparks.gravity = SPARK_GRAVITY
	sparks.scale_min = SPARK_SIZE.x
	sparks.scale_max = SPARK_SIZE.y
	sparks.colors = heat
	add_child(sparks.build())

	var embers := ParticlePreset.new()
	embers.texture = AssetPaths.effect("spark")
	embers.additive = true
	embers.amount = int(EMBERS * s)
	embers.lifetime = EMBER_LIFE
	embers.explosiveness = 0.6
	embers.spread = 100.0
	embers.speed_min = EMBER_SPEED.x
	embers.speed_max = EMBER_SPEED.y * _strength
	embers.gravity = EMBER_GRAVITY
	embers.scale_min = EMBER_SIZE.x
	embers.scale_max = EMBER_SIZE.y
	embers.colors = heat
	add_child(embers.build())

	var smoke := ParticlePreset.new()
	smoke.texture = AssetPaths.effect("smoke_%d" % (randi() % SMOKE_VARIANTS + 1))
	smoke.amount = int(SMOKE_PUFFS * maxf(_strength, 0.6))
	smoke.lifetime = SMOKE_LIFE
	smoke.explosiveness = 0.85
	smoke.spread = 70.0
	smoke.speed_min = SMOKE_SPEED.x
	smoke.speed_max = SMOKE_SPEED.y * _strength
	smoke.gravity = SMOKE_GRAVITY
	smoke.scale_min = SMOKE_SIZE.x * _strength + 0.1
	smoke.scale_max = SMOKE_SIZE.y * _strength + 0.15
	smoke.grow = ParticlePreset.grow_curve(SMOKE_GROWTH.x, SMOKE_GROWTH.y)
	smoke.colors = ParticlePreset.fade_gradient([Color(0.9, 0.8, 0.6, 0.0), Color(0.5, 0.48, 0.5, 0.7), Color(0.2, 0.2, 0.22, 0.0)])
	add_child(smoke.build())


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFE:
		queue_free()
		return
	var frame := mini(FRAMES - 1, int(_age / FRAME_TIME))
	_fireball.texture = AssetPaths.effect_frame("explosion", frame)
	var last_start := FRAME_TIME * (FRAMES - 1)
	_fireball.modulate.a = 1.0 if frame < FRAMES - 1 else clampf(1.0 - (_age - last_start) / FADE_TIME, 0.0, 1.0)
	_flash.modulate.a = clampf(1.0 - _age / (FRAME_TIME * FLASH_FRAMES), 0.0, 1.0)
