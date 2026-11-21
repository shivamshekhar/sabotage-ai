class_name LaserBeam
extends Node2D
## The mech's laser: a long thin beam with a soft blue glow round it, a bright white-blue flare at the muzzle and where it ends, drifting blue embers
## along it and a burst of sparks where it hits. Everything is drawn additively, so it brightens whatever is behind it. It lives for a moment and
## removes itself.
##
##   LaserBeam.show_beam(get_parent(), muzzle_position, end_position, true)

# TIME: seconds the beam stays visible while it fades; the node lives TAIL longer so the embers can finish.
const TIME := 0.22
const TAIL := 0.4

const BLUE := Color(0.27, 0.58, 1.0)
const BLUE_LIGHT := Color(0.75, 0.88, 1.0)

# The layers of the glow round the beam, widest first: [width in pixels, strength]. CORE_WIDTH / WHITE_WIDTH: the bright core and the white line.
const GLOW_LAYERS := [[40.0, 0.07], [26.0, 0.12], [14.0, 0.22]]
const CORE_WIDTH := 4.0
const WHITE_WIDTH := 1.8

# The shimmer: a faint wavy line along the beam. SHIMMER_STEP: pixels between its points; SHIMMER_AMPLITUDE: how far it waves; SHIMMER_WAVELENGTH /
# SHIMMER_SPEED: how fast the waves run along it.
const SHIMMER_STEP := 18.0
const SHIMMER_AMPLITUDE := 1.8
const SHIMMER_WAVELENGTH := 0.07
const SHIMMER_SPEED := 60.0
const SHIMMER_WIDTH := 4.0

# The flares (the picture is laser_orb): their start and end size on the muzzle, and on the end of the beam (bigger when it hit something).
const MUZZLE_FLARE := Vector2(0.9, 1.7)
const END_FLARE_HIT := Vector2(0.8, 1.5)
const END_FLARE_MISS := Vector2(0.45, 0.8)
const FLARE_TURN := 0.8
# HELD_FLARE / HELD_FLARE_SPEED: a held beam's flares breathe between these stages of the fade (average, swing), at this speed (radians per second).
const HELD_FLARE := Vector2(0.35, 0.2)
const HELD_FLARE_SPEED := 22.0

# The embers that drift off the beam: how many, where they start (EMBER_POINTS points along the beam) and how they move.
const EMBERS := 18
const EMBER_POINTS := 14
const EMBER_LIFE := 0.55
const EMBER_SPEED := Vector2(8.0, 44.0)
const EMBER_SIZE := Vector2(0.1, 0.22)
# The burst where the beam hits something.
const HIT_SPARKS := 12
const HIT_SPARK_LIFE := 0.4
const HIT_SPARK_SPEED := Vector2(90.0, 300.0)
const HIT_SPARK_SIZE := Vector2(0.15, 0.32)

var _from := Vector2.ZERO
var _to := Vector2.ZERO
var _hit := false
var _age := 0.0
var _held := false              # a beam that stays on until release() (otherwise it fades by itself)
var _clock := 0.0               # always runs (the shimmer)
var _flare_muzzle: Sprite2D
var _flare_end: Sprite2D
var _embers: CPUParticles2D
var _burst: CPUParticles2D


## Show a beam from `from` to `to` (world positions) under `parent`; `hit` gives a bigger flare and a burst of sparks at the end. It fades by itself.
static func show_beam(parent: Node, from: Vector2, to: Vector2, hit: bool) -> LaserBeam:
	return _create(parent, from, to, hit, false)


## A beam that stays on while the button is held: move its ends every step with aim(), and end it with release() (it then fades).
static func hold(parent: Node, from: Vector2, to: Vector2, hit: bool) -> LaserBeam:
	return _create(parent, from, to, hit, true)


static func _create(parent: Node, from: Vector2, to: Vector2, hit: bool, held: bool) -> LaserBeam:
	var b := LaserBeam.new()
	b._from = from
	b._to = to
	b._hit = hit
	b._held = held
	b.z_index = 4
	b.material = Blend.additive()
	parent.add_child(b)
	b._build()
	return b


## Move the ends of a held beam (world positions); `hit` says whether it ends on an enemy.
func aim(from: Vector2, to: Vector2, hit: bool) -> void:
	_from = from
	_to = to
	_hit = hit
	_flare_muzzle.global_position = from
	_flare_end.global_position = to
	var points := PackedVector2Array()
	for i in EMBER_POINTS:
		points.append(to_local(from.lerp(to, float(i) / float(EMBER_POINTS - 1))))
	_embers.emission_points = points
	_burst.position = to_local(to)
	_burst.emitting = hit
	var direction := (from - to).normalized()
	_burst.direction = direction


## Let go of a held beam: it fades out like any other.
func release() -> void:
	_held = false
	_embers.emitting = false
	_burst.emitting = false
	_age = 0.0


func _build() -> void:
	var orb := AssetPaths.effect("laser_orb")
	_flare_muzzle = Sprites.glow(orb, MUZZLE_FLARE.x)
	_flare_muzzle.global_position = _from
	add_child(_flare_muzzle)
	_flare_end = Sprites.glow(orb, (END_FLARE_HIT if _hit else END_FLARE_MISS).x)
	_flare_end.global_position = _to
	add_child(_flare_end)
	var fade := ParticlePreset.fade_gradient([Color(1, 1, 1, 0.9), Color(0.6, 0.8, 1.0, 0.6), Color(0.3, 0.5, 1.0, 0.0)])
	var embers := ParticlePreset.new()
	embers.texture = AssetPaths.effect("spark_blue")
	embers.additive = true
	embers.amount = EMBERS
	embers.lifetime = EMBER_LIFE
	embers.one_shot = not _held
	embers.explosiveness = 0.0 if _held else 0.7
	embers.spread = 70.0
	embers.speed_min = EMBER_SPEED.x
	embers.speed_max = EMBER_SPEED.y
	embers.gravity = Vector2(0.0, -20.0)
	embers.scale_min = EMBER_SIZE.x
	embers.scale_max = EMBER_SIZE.y
	embers.colors = fade
	var points := PackedVector2Array()
	for i in EMBER_POINTS:
		points.append(_from.lerp(_to, float(i) / float(EMBER_POINTS - 1)))
	embers.emission_points = points
	_embers = embers.build()
	add_child(_embers)
	if _hit or _held:
		var burst := ParticlePreset.new()
		burst.texture = AssetPaths.effect("spark_blue")
		burst.additive = true
		burst.one_shot = not _held
		burst.explosiveness = 0.0 if _held else 1.0
		burst.amount = HIT_SPARKS
		burst.lifetime = HIT_SPARK_LIFE
		burst.direction = (_from - _to).normalized()
		burst.spread = 60.0
		burst.speed_min = HIT_SPARK_SPEED.x
		burst.speed_max = HIT_SPARK_SPEED.y
		burst.gravity = Vector2(0.0, 500.0)
		burst.scale_min = HIT_SPARK_SIZE.x
		burst.scale_max = HIT_SPARK_SIZE.y
		burst.colors = fade
		_burst = burst.build()
		_burst.position = _to
		_burst.emitting = _hit
		add_child(_burst)


func _process(delta: float) -> void:
	_clock += delta
	if not _held:
		_age += delta
	if _age >= TIME + TAIL:
		queue_free()
		return
	# (a held beam's flares breathe instead of fading)
	var t := clampf(_age / TIME, 0.0, 1.0) if not _held else HELD_FLARE.x + HELD_FLARE.y * sin(_clock * HELD_FLARE_SPEED)
	_flare_muzzle.scale = Vector2.ONE * lerpf(MUZZLE_FLARE.x, MUZZLE_FLARE.y, t)
	_flare_muzzle.rotation = t * FLARE_TURN
	_flare_muzzle.modulate.a = 1.0 - t
	var end_sizes := END_FLARE_HIT if _hit else END_FLARE_MISS
	_flare_end.scale = Vector2.ONE * lerpf(end_sizes.x, end_sizes.y, t)
	_flare_end.modulate.a = 1.0 - t
	queue_redraw()


func _draw() -> void:
	var t := clampf(1.0 - _age / TIME, 0.0, 1.0)
	if t <= 0.0:
		return
	var a := to_local(_from)
	var b := to_local(_to)
	var dir := (b - a).normalized()
	var normal := Vector2(-dir.y, dir.x)
	var length := a.distance_to(b)
	# the glow: soft wide layers round a thin bright core, like a real laser
	for layer in GLOW_LAYERS:
		draw_line(a, b, Color(BLUE, float(layer[1]) * t), float(layer[0]))
	# a faint shimmer: a wavy line along the beam
	var points := PackedVector2Array()
	var steps := maxi(2, int(length / SHIMMER_STEP))
	for i in steps + 1:
		var u := float(i) / steps
		points.append(a.lerp(b, u) + normal * sin(u * length * SHIMMER_WAVELENGTH - _clock * SHIMMER_SPEED) * SHIMMER_AMPLITUDE)
	draw_polyline(points, Color(BLUE_LIGHT, 0.5 * t), SHIMMER_WIDTH)
	draw_line(a, b, Color(BLUE_LIGHT, 0.95 * t), CORE_WIDTH)
	draw_line(a, b, Color(1, 1, 1, t), WHITE_WIDTH)
