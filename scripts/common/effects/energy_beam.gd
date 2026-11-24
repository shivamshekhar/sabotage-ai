class_name EnergyBeam
extends HeldEffect
## A wave of blue energy from one point to another, for as long as something holds it on, drawn flat like pixel art: a round end at the start and a big round bulb at the head, joined
## by a shaft (smoothly, in a curve), in bands of colour from a dark outline to a pale core, with flame-like wisps trailing back from the bulbs, soft puffs drifting along
## the shaft and fine crackles inside the bulbs, and a soft glow round it all that makes it sit in the scene. Sparks fly if it hits something. It shoots out from the start, stays at
## full strength while its owner keeps aiming it, and fades out smoothly once it is let go. It is a HeldEffect like ElectricArc, so whatever fires one can fire the other. The node
## removes itself when everything is gone. The player's energy wave (the martial-arts outfit's version of the EMP gun) uses it.
##
## `start_position` is the middle of the ball of energy it grows out of, `end_position` is where the head ends.
##   var beam := EnergyBeam.hold(get_parent(), start_position, end_position, false)
##   beam.aim(start_position, end_position, true)      # every step while it is on (the ends move, `true`: it hits something, so sparks fly)
##   beam.release()                                    # let it go: it fades out (it also lets go by itself if it is not aimed for HELD_TIMEOUT seconds)

# GROW_TIME: seconds the head of the wave takes to travel from the start to the end. FADE_TIME: seconds the fade out takes once it is let go. TAIL: seconds the node lives after that,
# for the last sparks. HELD_TIMEOUT: seconds without aim() after which a held wave lets go by itself (a pause, a cutscene).
const GROW_TIME := 0.14
const FADE_TIME := 0.45
const TAIL := 0.5
const HELD_TIMEOUT := 0.15

# HALF_WIDTH: half of the shaft's width in pixels (the EMP gun's HIT_MARGIN for the wave is this much: what looks inside the shaft is hit). BULB_HEAD: the radius of the head as a multiple
# of HALF_WIDTH. NECK: how smoothly (a multiple of HALF_WIDTH) the head flows into the shaft: larger, a longer curve. START_BACK: how far (pixels) behind the start position the wave
# begins: the start position is the middle of the ball of energy it grows out of, and the wave begins round the ball's back, with a round end (as round as the shaft is wide).
const HALF_WIDTH := 16.0
const BULB_HEAD := 2.1
const NECK := 0.9
const START_BACK := 10.0

# MIN_LENGTH: the wave is not drawn until it is this long (pixels): shorter than two bulbs it has no shape yet.
const MIN_LENGTH := 36.0

# The shaft breathes: its width swings by RIPPLE (a fraction), with a ripple every RIPPLE_LENGTH pixels along it, running forward at RIPPLE_SPEED radians per second. SAMPLE_STEP: pixels
# between the points the outline is made of (smaller: rounder bulbs).
const RIPPLE := 0.06
const RIPPLE_LENGTH := 70.0
const RIPPLE_SPEED := 12.0
const SAMPLE_STEP := 5.0

# HALO: the soft light round the wave that makes it sit in the scene: soft round glows (PitHazard.glow_texture()) every HALO_STEP pixels along it, each as wide as HALO_SCALE times the
# wave's half width there, at HALO_ALPHA of full strength, in additive light (they overlap, so the light is smooth and round at the ends too).
const HALO_STEP := 14.0
const HALO_SCALE := 3.0
const HALO_ALPHA := 0.13
const HALO_COLOR := Color(0.25, 0.65, 1.0)

# The bands of colour, widest first: [the width of the band as a fraction of the full width, its colour]. OUTLINE_WIDTH: pixels the dark outline is wider than the first band.
const OUTLINE := Color(0.04, 0.38, 0.63)
const BANDS := [
	[1.0, Color(0.09, 0.71, 1.0)],
	[0.84, Color(0.52, 0.84, 1.0)],
	[0.64, Color(0.89, 0.96, 1.0)],
]
const OUTLINE_WIDTH := 2.0

# The wisps trailing back from the bulbs: WISPS on each side of each bulb, as long as WISP_LENGTH times the bulb's radius (they flicker by WISP_FLICKER, a fraction, at
# WISP_SPEED radians per second), at these angles round the bulb, in degrees from the way the wave goes.
const WISP_ANGLES := [96.0, 118.0, 140.0]
const WISP_LENGTH := 0.85
const WISP_WIDTH := 3.2
const WISP_FLICKER := 0.3
const WISP_SPEED := 30.0

# The puffs drifting forward along the shaft (how many, how fast in pixels per second, how big as a multiple of HALF_WIDTH) and the crackles inside the bulbs (how many on each, and
# how long as a fraction of the bulb's radius).
const PUFFS := 2
const PUFF_SPEED := 90.0
const PUFF_SIZE := Vector2(1.6, 0.55)
const CRACKLES := 9
const CRACKLE_LENGTH := 0.28

# The soft glow where the wave ends, as a size at full strength and at the end of the fade, and how much smaller it is when the wave hits nothing.
const END_GLOW := Vector2(2.6, 4.2)
const END_MISS_SCALE := 0.6

# The sparks where the wave hits something: how many there are at a time, how long they live and how fast (pixels per second) they fly.
const SPARKS := 30
const SPARK_LIFE := 0.6
const SPARK_SPEED := Vector2(90.0, 320.0)
const SPARK_SIZE := Vector2(0.18, 0.4)

var _from := Vector2.ZERO
var _to := Vector2.ZERO
var _hit := false
var _held := true
var _age := 0.0
var _fade_age := 0.0
var _clock := 0.0
var _since_aim := 0.0
var _end_glow: Sprite2D
var _sparks: CPUParticles2D
var _halo: Node2D


## The node that draws the halo behind the wave, in additive light (a node of its own because a node has one blend mode).
class Halo extends Node2D:
	var beam: Node2D

	func _draw() -> void:
		beam.call(&"draw_halo", self)


## A wave from `from` to `to` (world positions) under `parent` that stays on until release(); `hit` says whether it ends on something (sparks fly there).
static func hold(parent: Node, from: Vector2, to: Vector2, hit: bool) -> EnergyBeam:
	var beam := EnergyBeam.new()
	beam._from = from
	beam._to = to
	beam._hit = hit
	beam.z_index = 4
	parent.add_child(beam)
	beam._build()
	return beam


## Move the ends of the wave (world positions) and say whether it ends on something. Call it every step while the wave is on.
func aim(from: Vector2, to: Vector2, hit: bool) -> void:
	_from = from
	_to = to
	_hit = hit
	_since_aim = 0.0
	_end_glow.global_position = to
	_sparks.global_position = to
	_sparks.direction = (from - to).normalized()
	_sparks.emitting = hit and _held


## Let the wave go: it fades out.
func release() -> void:
	if _held:
		_held = false
		_sparks.emitting = false


func _build() -> void:
	_halo = Halo.new()
	_halo.beam = self
	_halo.show_behind_parent = true
	_halo.material = Blend.additive()
	add_child(_halo)
	_end_glow = Sprites.glow(PitHazard.glow_texture(), END_GLOW.x)
	_end_glow.modulate = Color(0.6, 0.85, 1.0, 0.0)
	add_child(_end_glow)
	var fade := ParticlePreset.fade_gradient([Color(1, 1, 1, 0.9), Color(0.5, 0.8, 1.0, 0.6), Color(0.25, 0.5, 1.0, 0.0)])
	var sparks := ParticlePreset.new()
	sparks.texture = AssetPaths.effect("spark_blue")
	sparks.additive = true
	sparks.amount = SPARKS
	sparks.lifetime = SPARK_LIFE
	sparks.one_shot = false
	sparks.explosiveness = 0.0
	sparks.spread = 80.0
	sparks.speed_min = SPARK_SPEED.x
	sparks.speed_max = SPARK_SPEED.y
	sparks.gravity = Vector2(0.0, 420.0)
	sparks.scale_min = SPARK_SIZE.x
	sparks.scale_max = SPARK_SIZE.y
	sparks.colors = fade
	_sparks = sparks.build()
	add_child(_sparks)
	aim(_from, _to, _hit)


func _process(delta: float) -> void:
	_clock += delta
	if _held:
		_age += delta
		_since_aim += delta
		if _since_aim > HELD_TIMEOUT:
			release()
	else:
		_fade_age += delta
		if _fade_age >= FADE_TIME + TAIL:
			queue_free()
			return
	var strength := _strength()
	_end_glow.scale = Vector2.ONE * lerpf(END_GLOW.x, END_GLOW.y, 1.0 - strength) * (1.0 if _hit else END_MISS_SCALE)
	_end_glow.modulate.a = 0.5 * strength * clampf(_age / GROW_TIME, 0.0, 1.0)
	modulate.a = strength
	queue_redraw()
	_halo.queue_redraw()


## How strong the wave is: full while it is held, then a smooth fade to nothing over FADE_TIME once it is let go.
func _strength() -> float:
	return 1.0 - smoothstep(0.0, FADE_TIME, _fade_age)


## The smooth larger of two numbers (the shaft and a bulb meet in a curve, not a corner); `k` is how wide the curve is.
static func _smooth_max(a: float, b: float, k: float) -> float:
	var h := clampf(0.5 + 0.5 * (a - b) / k, 0.0, 1.0)
	return lerpf(b, a, h) + k * h * (1.0 - h)


## The half width of a circle of radius `r` centred `centre` along the wave, `s` along it (0 outside it).
static func _circle(s: float, centre: float, r: float) -> float:
	var d := absf(s - centre)
	return sqrt(r * r - d * d) if d < r else 0.0


## Half of the wave's width `s` pixels from its start when it is `length` long: the shaft with a round end, and the head, joined smoothly.
func _half(s: float, length: float) -> float:
	var shaft := HALF_WIDTH * (1.0 + RIPPLE * sin(s / RIPPLE_LENGTH * TAU - _clock * RIPPLE_SPEED))
	shaft = minf(shaft, _circle(s, HALF_WIDTH, HALF_WIDTH) if s < HALF_WIDTH else shaft)
	var head_radius := minf(BULB_HEAD * HALF_WIDTH, length * 0.55)
	return _smooth_max(shaft, _circle(s, length - head_radius, head_radius), NECK * HALF_WIDTH)


## The wave's shape now, or an empty dictionary if there is nothing to draw: where it starts (`origin`, behind the middle of the first bulb), the way it goes, its `side`, how long it is
## (`length`) and its half width at points along it (`halves`).
func _shape() -> Dictionary:
	var a := to_local(_from)
	var b := to_local(_to)
	var full := a.distance_to(b)
	if _strength() <= 0.0 or full < 4.0:
		return {}
	var direction := (b - a) / full
	var total := full + START_BACK
	var length := total * clampf(_age / GROW_TIME, 0.0, 1.0)
	if length < MIN_LENGTH:
		return {}
	var count := maxi(4, int(length / SAMPLE_STEP) + 1)
	var halves := PackedFloat32Array()
	for i in count:
		halves.append(_half(length * float(i) / float(count - 1), length))
	return {"origin": a - direction * START_BACK, "direction": direction, "side": direction.orthogonal(), "length": length, "halves": halves}


func _draw() -> void:
	var shape := _shape()
	if shape.is_empty():
		return
	var origin: Vector2 = shape["origin"]
	var direction: Vector2 = shape["direction"]
	var side: Vector2 = shape["side"]
	var length: float = shape["length"]
	var halves: PackedFloat32Array = shape["halves"]
	_draw_band(self, origin, direction, side, length, halves, 1.0, OUTLINE_WIDTH, OUTLINE)
	for band in BANDS:
		_draw_band(self, origin, direction, side, length, halves, band[0], 0.0, band[1])
	var head_radius := minf(BULB_HEAD * HALF_WIDTH, length * 0.55)
	_draw_wisps(origin + direction * (length - head_radius), direction, side, head_radius)       # (none at the start: nothing trails over the hands)
	_draw_puffs(origin, direction, side, length)
	_draw_crackles(origin + direction * (length - head_radius), direction, side, head_radius)


## The halo, drawn by the Halo node (`canvas`): a row of soft round glows along the wave.
func draw_halo(canvas: CanvasItem) -> void:
	var shape := _shape()
	if shape.is_empty():
		return
	var origin: Vector2 = shape["origin"]
	var direction: Vector2 = shape["direction"]
	var length: float = shape["length"]
	var halves: PackedFloat32Array = shape["halves"]
	var glow := PitHazard.glow_texture()
	var steps := maxi(2, int(length / HALO_STEP) + 1)
	for i in steps:
		var along := length * float(i) / float(steps - 1)
		var radius := halves[int(float(halves.size() - 1) * along / length)] * HALO_SCALE
		canvas.draw_texture_rect(glow, Rect2(origin + direction * along - Vector2(radius, radius), Vector2(radius, radius) * 2.0), false, Color(HALO_COLOR, HALO_ALPHA))


## One band of colour on `canvas`: the outline of the wave with every width scaled by `scale` (and `extra` pixels wider), filled with `color`.
func _draw_band(canvas: CanvasItem, a: Vector2, direction: Vector2, side: Vector2, length: float, halves: PackedFloat32Array, scale: float, extra: float, color: Color) -> void:
	var count := halves.size()
	var top := PackedVector2Array()
	var bottom := PackedVector2Array()
	for i in count:
		var along := length * float(i) / float(count - 1)
		var half := halves[i] * scale + extra
		top.append(a + direction * along + side * half)
		bottom.append(a + direction * along - side * half)
	bottom.reverse()
	top.append_array(bottom)
	canvas.draw_colored_polygon(top, color)


## The wisps trailing back from a bulb centred at `centre` with radius `radius`: thin flame-like points that flicker.
func _draw_wisps(centre: Vector2, direction: Vector2, side: Vector2, radius: float) -> void:
	for sign_of_side: float in [1.0, -1.0]:
		for k in WISP_ANGLES.size():
			var angle := deg_to_rad(WISP_ANGLES[k])
			var out := direction * cos(angle) + side * sin(angle) * sign_of_side
			var base := centre + out * radius
			var flicker := 1.0 + WISP_FLICKER * sin(_clock * WISP_SPEED + float(k) * 1.9 + sign_of_side)
			var tip := base - direction * radius * WISP_LENGTH * flicker + side * sign_of_side * radius * 0.12
			var width := side * WISP_WIDTH * (1.0 - 0.2 * float(k))
			draw_colored_polygon(PackedVector2Array([base - width - direction * 2.0, tip, base + width - direction * 2.0]), BANDS[0][1])


## The soft puffs drifting forward along the shaft.
func _draw_puffs(a: Vector2, direction: Vector2, side: Vector2, length: float) -> void:
	for k in PUFFS:
		var s := fposmod(_clock * PUFF_SPEED + float(k) * length / float(PUFFS), length)
		var points := PackedVector2Array()
		for i in 16:
			var t := TAU * float(i) / 16.0
			points.append(a + direction * (s + cos(t) * PUFF_SIZE.x * HALF_WIDTH) + side * (sin(t) * PUFF_SIZE.y * HALF_WIDTH + (HALF_WIDTH * 0.25 if k % 2 == 0 else -HALF_WIDTH * 0.25)))
		draw_colored_polygon(points, Color(BANDS[1][1] as Color, 0.55))


## Fine lines inside the back of a bulb, like the crackle of energy gathering.
func _draw_crackles(centre: Vector2, direction: Vector2, side: Vector2, radius: float) -> void:
	for k in CRACKLES:
		var angle := PI + (float(k) - float(CRACKLES - 1) / 2.0) * 0.22
		var wobble := 0.85 + 0.15 * sin(_clock * WISP_SPEED + float(k) * 2.1)
		var inner := centre + (direction * cos(angle) + side * sin(angle)) * radius * (0.62 - CRACKLE_LENGTH * wobble)
		var outer := centre + (direction * cos(angle) + side * sin(angle)) * radius * 0.62
		draw_line(inner, outer, BANDS[1][1], 1.6, true)
