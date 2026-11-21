class_name ElectricArc
extends Node2D
## A bolt of lightning from one point to another with a few forked branches, for as long as something holds it on. It shoots out from the start in a moment, then stays at full
## strength while its owner keeps aiming it, and fades out smoothly once it is let go. Its shape flows instead of jumping (every point of it sways on its own slow waves with a small
## fast shiver on top, and the corners are rounded off), light ripples along it, and it lights the air round it with soft additive glows, so it sits in the scene instead of lying
## on top of it. There is a flare where it starts, and sparks fly where it ends. The node removes itself when everything is gone. Anything can use it (the player's EMP gun, an
## electric trap).
##
##   var arc := ElectricArc.hold(get_parent(), muzzle_position, end_position, false)
##   arc.aim(muzzle_position, end_position, true)      # every step while it is on (the ends move, `true`: it hits something, so sparks fly)
##   arc.release()                                     # let it go: it fades out (it also lets go by itself if it is not aimed for HELD_TIMEOUT seconds)

# GROW_TIME: seconds the bolt takes to shoot from its start to its end. HOLD: seconds from the start at which it is at full strength and stays so while it is held. FADE_TIME: seconds
# the fade out takes once it is let go (the fade is smooth). TAIL: seconds the node lives after that, for the last sparks.
const GROW_TIME := 0.09
const HOLD := 0.35
const FADE_TIME := 0.65
const TAIL := 0.6

# HELD_TIMEOUT: seconds without aim() after which a held bolt lets go by itself (so a bolt whose owner stopped working it, in a pause or a cutscene, does not stay forever).
const HELD_TIMEOUT := 0.15

# The shape. STEP: pixels between the control points of the bolt. JITTER: the most (pixels) a point sways to either side of the straight line; it tapers to nothing at both ends,
# so the bolt meets its two points. SWAY_SPEEDS: the speeds (radians per second) of the two slow waves every point sways on (smaller: a calmer bolt). SHIVER: the size (pixels)
# and SHIVER_SPEED the speed of the small fast shake on top. SMOOTHING: how many times the corners are rounded off (each makes the line smoother and its points twice as many).
const STEP := 30.0
const JITTER := 17.0
const SWAY_SPEEDS := Vector2(4.5, 9.5)
const SHIVER := 2.6
const SHIVER_SPEED := 41.0
const SMOOTHING := 2

# The forks: how many branches come off the bolt, how many STEP-long pieces each has, how far (degrees) it leaves the bolt's direction, how late each starts (seconds: they
# sprout one after the other) and how much sooner than the bolt it fades (1 = together).
const BRANCHES := 3
const BRANCH_PIECES := 4
const BRANCH_ANGLE := 50.0
const BRANCH_DELAY := 0.05
const BRANCH_FADE := 0.75

# The glow round the bolt, widest first: [width in pixels, strength]; the layers add up to a soft falloff, a hot core (CORE_WIDTH) and a white line inside it (WHITE_WIDTH).
# A fork is thinner by BRANCH_THIN.
const GLOW_LAYERS := [[40.0, 0.04], [28.0, 0.06], [19.0, 0.09], [12.0, 0.14], [7.0, 0.22]]
const CORE_WIDTH := 3.4
const WHITE_WIDTH := 1.5
const BRANCH_THIN := 0.55

# The ripple of light that runs along the bolt (its strength swings between 1 - RIPPLE and 1): RIPPLE_WAVES waves along it, running at RIPPLE_SPEED radians per second. The whole
# bolt also flickers a little, by FLICKER, at FLICKER_SPEED.
const RIPPLE := 0.3
const RIPPLE_WAVES := 3.0
const RIPPLE_SPEED := 24.0
const FLICKER := 0.12
const FLICKER_SPEED := 53.0

# The light the bolt gives the air round it: AMBIENT_COUNT soft round glows (a 64 px picture, PitHazard.glow_texture()) along it, each AMBIENT_SCALE times its size, at AMBIENT_ALPHA of
# full strength.
const AMBIENT_COUNT := 5
const AMBIENT_SCALE := 3.2
const AMBIENT_ALPHA := 0.3

# The flare at the muzzle (the picture is laser_orb) and the soft round glow where the bolt ends: their size while it is on and at the end of the fade. The glow at the end is
# smaller (END_MISS_SCALE times) when the bolt hits nothing.
const FLARE_SCALE := Vector2(0.9, 1.7)
const END_GLOW := Vector2(1.6, 3.4)
const END_MISS_SCALE := 0.5

# The sparks where the bolt hits something: how many there are at a time, how long they live and how fast (pixels per second) they fly.
const SPARKS := 26
const SPARK_LIFE := 0.7
const SPARK_SPEED := Vector2(70.0, 280.0)
const SPARK_SIZE := Vector2(0.15, 0.34)

const COLOR := Color(0.35, 0.78, 1.0)
const COLOR_LIGHT := Color(0.82, 0.94, 1.0)

var _from := Vector2.ZERO
var _to := Vector2.ZERO
var _hit := false
var _held := true
var _age := 0.0                                # seconds since it started; it stops at HOLD while the bolt is held
var _fade_age := 0.0                           # seconds since it was let go
var _clock := 0.0                              # always runs: the sway, the shiver, the ripple and the flicker
var _since_aim := 0.0
var _phases := PackedFloat32Array()            # three numbers per control point of the bolt: its two sway phases and its shiver phase
var _forks: Array[Dictionary] = []             # each: {at: the control point it starts from, heading: radians, phases: PackedFloat32Array}
var _flare: Sprite2D
var _end_glow: Sprite2D
var _ambient: Array[Sprite2D] = []
var _sparks: CPUParticles2D


## A bolt from `from` to `to` (world positions) under `parent` that stays on until release(); `hit` says whether it ends on something (sparks fly there).
static func hold(parent: Node, from: Vector2, to: Vector2, hit: bool) -> ElectricArc:
	var arc := ElectricArc.new()
	arc._from = from
	arc._to = to
	arc._hit = hit
	arc.z_index = 4
	arc.material = Blend.additive()
	parent.add_child(arc)
	arc._build()
	return arc


## Move the ends of the bolt (world positions) and say whether it ends on something. Call it every step while the bolt is on.
func aim(from: Vector2, to: Vector2, hit: bool) -> void:
	_from = from
	_to = to
	_hit = hit
	_since_aim = 0.0
	_flare.global_position = from
	_end_glow.global_position = to
	for i in _ambient.size():
		_ambient[i].global_position = from.lerp(to, (float(i) + 0.5) / AMBIENT_COUNT)
	_sparks.global_position = to
	_sparks.direction = (from - to).normalized()
	_sparks.emitting = hit and _held


## Let the bolt go: it fades out.
func release() -> void:
	if _held:
		_held = false
		_sparks.emitting = false


func _build() -> void:
	var count := _control_count(to_local(_from), to_local(_to))
	for i in count * 3:
		_phases.append(randf() * TAU)
	var heading := (to_local(_to) - to_local(_from)).angle()
	for i in BRANCHES:
		var phases := PackedFloat32Array()
		for k in BRANCH_PIECES * 3 + 3:
			phases.append(randf() * TAU)
		_forks.append({"at": randi_range(maxi(1, count / 5), maxi(2, count * 4 / 5)), "heading": heading + deg_to_rad(BRANCH_ANGLE) * (1.0 if i % 2 == 0 else -1.0) * randf_range(0.6, 1.0), "phases": phases})
	_flare = Sprites.glow(AssetPaths.effect("laser_orb"), FLARE_SCALE.x)
	add_child(_flare)
	_end_glow = Sprites.glow(PitHazard.glow_texture(), END_GLOW.x)
	_end_glow.modulate = Color(COLOR_LIGHT, 0.0)
	add_child(_end_glow)
	for i in AMBIENT_COUNT:
		var blob := Sprites.glow(PitHazard.glow_texture(), AMBIENT_SCALE)
		blob.modulate = Color(COLOR, 0.0)
		add_child(blob)
		_ambient.append(blob)
	var fade := ParticlePreset.fade_gradient([Color(1, 1, 1, 0.9), Color(0.5, 0.78, 1.0, 0.6), Color(0.25, 0.5, 1.0, 0.0)])
	var sparks := ParticlePreset.new()
	sparks.texture = AssetPaths.effect("spark_blue")
	sparks.additive = true
	sparks.amount = SPARKS
	sparks.lifetime = SPARK_LIFE
	sparks.one_shot = false
	sparks.explosiveness = 0.0
	sparks.spread = 75.0
	sparks.speed_min = SPARK_SPEED.x
	sparks.speed_max = SPARK_SPEED.y
	sparks.gravity = Vector2(0.0, 480.0)
	sparks.scale_min = SPARK_SIZE.x
	sparks.scale_max = SPARK_SIZE.y
	sparks.colors = fade
	_sparks = sparks.build()
	add_child(_sparks)
	aim(_from, _to, _hit)


func _control_count(a: Vector2, b: Vector2) -> int:
	return maxi(2, int(a.distance_to(b) / STEP) + 1)


func _process(delta: float) -> void:
	_clock += delta
	if _held:
		_age = minf(_age + delta, HOLD)
		_since_aim += delta
		if _since_aim > HELD_TIMEOUT:
			release()
	else:
		_fade_age += delta
		if _fade_age >= FADE_TIME + TAIL:
			queue_free()
			return
	var strength := _strength()
	var grown := clampf(_age / GROW_TIME, 0.0, 1.0)
	var life := 1.0 - strength
	_flare.scale = Vector2.ONE * lerpf(FLARE_SCALE.x, FLARE_SCALE.y, life)
	_flare.modulate.a = strength
	_end_glow.scale = Vector2.ONE * lerpf(END_GLOW.x, END_GLOW.y, life) * (1.0 if _hit else END_MISS_SCALE)
	_end_glow.modulate.a = 0.8 * strength * grown
	for blob in _ambient:
		blob.modulate.a = AMBIENT_ALPHA * strength * (0.85 + 0.15 * sin(_clock * FLICKER_SPEED + blob.position.x * 0.05))
	queue_redraw()


## How strong the bolt is: full while it is held (with a slight flicker), then a smooth fade to nothing over FADE_TIME once it is let go.
func _strength() -> float:
	var fade := 1.0 - smoothstep(0.0, FADE_TIME, _fade_age)
	return clampf(fade * (1.0 - FLICKER + FLICKER * sin(_clock * FLICKER_SPEED)), 0.0, 1.0)


## The control points of a line from `a` to `b` swaying on their own waves; `phases` has three numbers per point, `amount` scales how far they sway.
func _swaying(a: Vector2, b: Vector2, count: int, phases: PackedFloat32Array, amount: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var normal := (b - a).orthogonal().normalized()
	for i in count:
		var u := float(i) / float(count - 1)
		var taper := sin(u * PI)
		var sway := 0.6 * sin(phases[i * 3] + _clock * SWAY_SPEEDS.x) + 0.4 * sin(phases[i * 3 + 1] + _clock * SWAY_SPEEDS.y)
		var shiver := SHIVER * sin(phases[i * 3 + 2] + _clock * SHIVER_SPEED)
		points.append(a.lerp(b, u) + normal * (JITTER * amount * sway + shiver) * taper)
	return points


## Round off the corners of a line (Chaikin's way: every corner is cut at a quarter and three quarters) `SMOOTHING` times; the ends stay where they are.
func _rounded(points: PackedVector2Array) -> PackedVector2Array:
	var line := points
	for pass_number in SMOOTHING:
		var next := PackedVector2Array([line[0]])
		for i in line.size() - 1:
			next.append(line[i].lerp(line[i + 1], 0.25))
			next.append(line[i].lerp(line[i + 1], 0.75))
		next.append(line[line.size() - 1])
		line = next
	return line


## The first `fraction` of a line, by its length (the bolt shooting out).
func _prefix(points: PackedVector2Array, fraction: float) -> PackedVector2Array:
	if fraction >= 1.0:
		return points
	var total := 0.0
	for i in points.size() - 1:
		total += points[i].distance_to(points[i + 1])
	var left := total * fraction
	var out := PackedVector2Array([points[0]])
	for i in points.size() - 1:
		var piece := points[i].distance_to(points[i + 1])
		if piece >= left:
			out.append(points[i].lerp(points[i + 1], left / maxf(piece, 0.0001)))
			return out
		left -= piece
		out.append(points[i + 1])
	return out


func _draw() -> void:
	var strength := _strength()
	if strength <= 0.0:
		return
	var a := to_local(_from)
	var b := to_local(_to)
	var count := _control_count(a, b)
	if _phases.size() < count * 3:
		for i in count * 3 - _phases.size():
			_phases.append(randf() * TAU)       # (the bolt got longer than it began: its new points get waves of their own)
	var control := _swaying(a, b, count, _phases, 1.0)
	_draw_bolt(_prefix(_rounded(control), clampf(_age / GROW_TIME, 0.0, 1.0)), strength, 1.0)
	for k in _forks.size():
		var started := _age - BRANCH_DELAY * float(k + 1)
		if started <= 0.0:
			continue
		var fork: Dictionary = _forks[k]
		var origin: Vector2 = control[mini(int(fork["at"]), control.size() - 1)]
		var tip := origin + Vector2.from_angle(float(fork["heading"])) * STEP * BRANCH_PIECES
		var pieces := _swaying(origin, tip, BRANCH_PIECES + 1, fork["phases"], 0.7)
		var fork_strength := (1.0 - smoothstep(0.0, FADE_TIME * BRANCH_FADE, _fade_age)) * clampf(started / GROW_TIME, 0.0, 1.0) * strength
		_draw_bolt(_prefix(_rounded(pieces), clampf(started / GROW_TIME, 0.0, 1.0)), fork_strength, BRANCH_THIN)


## Draw one bolt: the soft glow layers, then the hot core and the white line, with the ripple of light running along them.
func _draw_bolt(points: PackedVector2Array, strength: float, thin: float) -> void:
	if points.size() < 2 or strength <= 0.0:
		return
	for layer in GLOW_LAYERS:
		draw_polyline(points, Color(COLOR, float(layer[1]) * strength), float(layer[0]) * thin, true)
	var total := 0.0
	for i in points.size() - 1:
		total += points[i].distance_to(points[i + 1])
	var core_colors := PackedColorArray()
	var white_colors := PackedColorArray()
	var along := 0.0
	for i in points.size():
		if i > 0:
			along += points[i - 1].distance_to(points[i])
		var ripple := 1.0 - RIPPLE + RIPPLE * (0.5 + 0.5 * sin(along / maxf(total, 1.0) * RIPPLE_WAVES * TAU - _clock * RIPPLE_SPEED))
		core_colors.append(Color(COLOR_LIGHT, 0.95 * strength * ripple))
		white_colors.append(Color(1, 1, 1, strength * ripple))
	draw_polyline_colors(points, core_colors, CORE_WIDTH * thin, true)
	draw_polyline_colors(points, white_colors, WHITE_WIDTH * thin, true)
