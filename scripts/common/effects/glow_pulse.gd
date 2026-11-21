class_name GlowPulse
extends Sprite2D
## A soft additive glow that breathes: it brightens and dims for ever (a warning light). Two of them with phases half a cycle apart alternate: one is at its
## brightest when the other is at its dimmest. A decor tile in the tile registry can have some by listing `glows` (see Level._build_generic).
##
##   parent.add_child(GlowPulse.make(Vector2(10, 3), Color(1.0, 0.15, 0.1), 26.0, 0.0))     # at a spot, its colour, its diameter in px, its phase (0 to 1)

# PERIOD: seconds for one full cycle (bright, dim, bright). Longer: a slower pulse.
const PERIOD := 1.1

# DIM / BRIGHT: how strong (0 to 1) the glow is at its dimmest and brightest. SIZE_SWING: how much its size follows it (0.2 = 20% bigger when bright).
const DIM := 0.08
const BRIGHT := 1.0
const SIZE_SWING := 0.25

# SHARPNESS: above 1 the pulse spends more time near bright or dim and less in between, like a lamp that is switched, not faded.
const SHARPNESS := 1.8

var phase := 0.0
var _base_scale := 1.0
var _clock := 0.0


## A glow centred at `at` (in its parent's space) of `color`, `diameter` px across, `cycle_phase` (0 to 1) into its cycle.
static func make(at: Vector2, color: Color, diameter: float, cycle_phase: float) -> GlowPulse:
	var g := GlowPulse.new()
	g.texture = PitHazard.glow_texture()
	g.position = at
	g.self_modulate = color
	g.material = Blend.additive()
	g.phase = cycle_phase
	g._base_scale = diameter / float(g.texture.get_width())
	g._apply()
	return g


## How bright the glow is now, 0 to 1 (DIM to BRIGHT).
func brightness() -> float:
	return modulate.a


func _process(delta: float) -> void:
	_clock += delta
	_apply()


func _apply() -> void:
	var wave := 0.5 + 0.5 * sin(TAU * (_clock / PERIOD + phase))
	var k := pow(wave, SHARPNESS)
	modulate.a = lerpf(DIM, BRIGHT, k)
	scale = Vector2.ONE * _base_scale * (1.0 + SIZE_SWING * k)
