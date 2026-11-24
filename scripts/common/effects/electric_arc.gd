class_name ElectricArc
extends HeldEffect
## A bolt of lightning from one point to another with a few forked branches, for as long as something holds it on. It shoots out from the start in a moment, then stays at full
## strength while its owner keeps aiming it, and fades out smoothly once it is let go. Like real lightning it is made of straight, jagged pieces (every piece is a kink in the line, with
## smaller kinks inside it), and it does not flow: every REFRESH seconds it strikes a new path at once, forks and all, so it crackles and flickers. It lights the air round it with
## soft additive glows. There is a flare where it starts, and sparks fly where it ends. The node removes itself when everything is gone. Anything can use it (the player's EMP gun, an
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

# The shape. REFRESH: seconds a path lasts before the bolt strikes a new one (shorter: a more nervous bolt; about 0.05 is a crackle). DEPTH: how many times every piece is split in two
# with a kink in the middle (the bolt has 2 to the power DEPTH pieces: more: finer kinks). JAG: how far (a fraction of a piece's length) a kink strays to either side (larger: wilder).
const REFRESH := 0.05
const DEPTH := 5
const JAG := 0.28

# The forks: how many branches come off the bolt, how long each is (pixels) and how many times its pieces are split (DEPTH for a fork), how far (degrees) it leaves the bolt's direction,
# how late each starts (seconds: they sprout one after the other) and how much sooner than the bolt it fades (1 = together). Every new path has new forks.
const BRANCHES := 3
const BRANCH_LENGTH := 130.0
const BRANCH_DEPTH := 3
const BRANCH_ANGLE := 50.0
const BRANCH_DELAY := 0.05
const BRANCH_FADE := 0.75

# The glow round the bolt, widest first: [width in pixels, strength]; the layers add up to a soft falloff, a hot core (CORE_WIDTH) and a white line inside it (WHITE_WIDTH).
# A fork is thinner by BRANCH_THIN.
const GLOW_LAYERS := [[30.0, 0.04], [20.0, 0.07], [12.0, 0.12], [7.0, 0.22]]
const CORE_WIDTH := 3.2
const WHITE_WIDTH := 1.4
const BRANCH_THIN := 0.55

# The flicker of the whole bolt: its strength swings between 1 - FLICKER and 1, at FLICKER_SPEED radians per second.
const FLICKER := 0.2
const FLICKER_SPEED := 61.0

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
var _clock := 0.0                              # always runs: the flicker
var _since_aim := 0.0
var _since_strike := 0.0                       # seconds since the current path was struck
var _path := PackedVector2Array()              # the bolt's path: x = how far along it (0 to 1), y = how far (pixels) to the side of the straight line
var _forks: Array[Dictionary] = []             # each: {at: how far along the bolt it starts (0 to 1), side: 1 or -1, angle: radians off the bolt's direction, path: PackedVector2Array
                                               # of (pixels along the fork, pixels to the side)}
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
	_strike()
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


## Strike a new path: a new jagged line and new forks, all at once.
func _strike() -> void:
	_since_strike = 0.0
	_path = _jagged(Vector2(0.0, 0.0), Vector2(1.0, 0.0), maxf(_from.distance_to(_to), 1.0), DEPTH)
	_forks.clear()
	for k in BRANCHES:
		var angle := deg_to_rad(BRANCH_ANGLE) * (1.0 if k % 2 == 0 else -1.0) * randf_range(0.6, 1.0)
		var length := BRANCH_LENGTH * randf_range(0.7, 1.0)
		_forks.append({"at": randf_range(0.2, 0.8), "angle": angle, "path": _jagged(Vector2.ZERO, Vector2(length, 0.0), 1.0, BRANCH_DEPTH)})


## A jagged line from `a` to `b` made by splitting every piece in two `depth` times and moving the middle to the side by a random part (JAG) of the piece's length. `scale` is how many
## pixels one unit along x is (1 for a line already in pixels), so the kinks are in pixels whatever the units.
func _jagged(a: Vector2, b: Vector2, scale: float, depth: int) -> PackedVector2Array:
	var line := PackedVector2Array([a, b])
	for pass_number in depth:
		var next := PackedVector2Array([line[0]])
		for i in line.size() - 1:
			var p := line[i]
			var q := line[i + 1]
			var piece := Vector2((q.x - p.x) * scale, q.y - p.y)
			var middle := p.lerp(q, 0.5)
			middle.y += randf_range(-1.0, 1.0) * piece.length() * JAG
			next.append(middle)
			next.append(q)
		line = next
	return line


func _process(delta: float) -> void:
	_clock += delta
	_since_strike += delta
	if _since_strike >= REFRESH:
		_strike()
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


## How strong the bolt is: full while it is held (with a flicker), then a smooth fade to nothing over FADE_TIME once it is let go.
func _strength() -> float:
	var fade := 1.0 - smoothstep(0.0, FADE_TIME, _fade_age)
	return clampf(fade * (1.0 - FLICKER + FLICKER * sin(_clock * FLICKER_SPEED)), 0.0, 1.0)


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
	var along := b - a
	var forward := along.normalized() if along.length() > 0.001 else Vector2.RIGHT
	var side := forward.orthogonal()
	var line := PackedVector2Array()
	for point in _path:
		line.append(a + along * point.x + side * point.y)
	var grown := clampf(_age / GROW_TIME, 0.0, 1.0)
	_draw_bolt(_prefix(line, grown), strength, 1.0)
	for k in _forks.size():
		var started := _age - BRANCH_DELAY * float(k + 1)
		if started <= 0.0:
			continue
		var fork: Dictionary = _forks[k]
		var origin := a + along * float(fork["at"]) + side * _path_side(float(fork["at"]))
		var heading := forward.rotated(float(fork["angle"]))
		var piece := PackedVector2Array()
		for point: Vector2 in fork["path"]:
			piece.append(origin + heading * point.x + heading.orthogonal() * point.y)
		var fork_strength := (1.0 - smoothstep(0.0, FADE_TIME * BRANCH_FADE, _fade_age)) * clampf(started / GROW_TIME, 0.0, 1.0) * strength
		_draw_bolt(_prefix(piece, clampf(started / GROW_TIME, 0.0, 1.0)), fork_strength, BRANCH_THIN)


## How far to the side of the straight line the bolt's path is at `t` (0 to 1) along it (so a fork starts on the bolt).
func _path_side(t: float) -> float:
	for i in _path.size() - 1:
		if _path[i + 1].x >= t:
			var span := maxf(_path[i + 1].x - _path[i].x, 0.00001)
			return lerpf(_path[i].y, _path[i + 1].y, (t - _path[i].x) / span)
	return 0.0


## Draw one bolt: the soft glow layers, then the hot core and the white line, all with sharp corners (it is straight pieces, not a curve).
func _draw_bolt(points: PackedVector2Array, strength: float, thin: float) -> void:
	if points.size() < 2 or strength <= 0.0:
		return
	for layer in GLOW_LAYERS:
		draw_polyline(points, Color(COLOR, float(layer[1]) * strength), float(layer[0]) * thin, true)
	draw_polyline(points, Color(COLOR_LIGHT, 0.95 * strength), CORE_WIDTH * thin, true)
	draw_polyline(points, Color(1, 1, 1, strength), WHITE_WIDTH * thin, true)
