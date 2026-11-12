class_name PitHazard
extends Node2D
## A deadly pit: a tank of something nobody survives. Whoever falls in (the player or an enemy) loses all health
## and dies at once; for the player that is a game over (see Player.fall_in_pit()). The kinds are toxic waste
## (map character A), lava (F), nuclear waste (N) and a tank of robotic piranhas (W). Ordinary spikes
## are a different thing (see SpikeTrap): they only hurt.
##
## One PitHazard covers one rectangle of liquid cells. The liquid is drawn in front of the player, completely
## opaque, so whoever falls in disappears into it (see pit_liquid.gdshader: it drifts, wobbles and has a moving
## surface). Rising bubbles or embers and a glow make it feel alive, and a piranha tank holds robot piranhas (enemies,
## see Piranha). Everything that only decorates, the piranhas included, sits in one child node that is hidden and stops
## working while the pit is off screen.

# TILE: tile size in pixels; must match Level.T.
const TILE := 70

# SURFACE_PX: how many pixels below the top of the liquid rectangle its (waving) surface sits on average. It must match
# surface_px in pit_liquid.gdshader. The surface being below the walkway keeps the pit looking like a sunken tank.
const SURFACE_PX := 20.0

# LIQUID_Z / FISH_Z / FX_Z: draw order. The liquid is above the player (who is 2) so they vanish into it; the fish are
# between, so they hide behind the liquid when low and show above it when they leap; bubbles and glow are on top.
const LIQUID_Z := 4
const FISH_Z := 3
const FX_Z := 5

# STYLES: the look of each kind. rim: the shiny line on the surface; deep: what the liquid darkens to at the bottom;
# glow: the colour of the halo over the surface; scroll: how fast the liquid drifts (repeats per second);
# wave: height of the surface waves in pixels; mote: the colour of the rising specks; rise: their speed in pixels per
# second; above: true if they should fly up out of the liquid (embers) instead of rising only to the surface.
const STYLES := {
	"lava": {"rim": Color(1.0, 0.92, 0.55), "deep": Color(0.42, 0.04, 0.0), "glow": Color(1.0, 0.45, 0.1),
		"scroll": 0.07, "wave": 5.0, "mote": Color(1.0, 0.7, 0.2), "rise": 90.0, "above": true, "additive": true},
	"toxic_waste": {"rim": Color(0.86, 1.0, 0.5), "deep": Color(0.02, 0.28, 0.06), "glow": Color(0.4, 1.0, 0.25),
		"scroll": 0.045, "wave": 4.0, "mote": Color(0.8, 1.0, 0.5), "rise": 38.0, "above": false, "additive": false},
	"nuclear_waste": {"rim": Color(0.95, 1.0, 0.45), "deep": Color(0.0, 0.2, 0.18), "glow": Color(0.6, 1.0, 0.3),
		"scroll": 0.055, "wave": 4.5, "mote": Color(1.0, 1.0, 0.45), "rise": 55.0, "above": true, "additive": true},
	"piranha_tank": {"rim": Color(0.85, 0.96, 1.0), "deep": Color(0.0, 0.1, 0.3), "glow": Color(0.4, 0.7, 1.0),
		"scroll": 0.03, "wave": 3.5, "mote": Color(0.85, 0.95, 1.0), "rise": 30.0, "above": false, "additive": false},
}

# GLOW_ALPHA / GLOW_PULSE / GLOW_PERIOD: how strongly the halo over the surface shines, how much of that the slow pulse
# takes away (0 = steady), and how long one pulse takes in seconds. Keep GLOW_ALPHA modest so it never hides the player.
const GLOW_ALPHA := 0.4
const GLOW_PULSE := 0.35
const GLOW_PERIOD := 2.2

# MOTES_PER_TILE: how many rising specks (bubbles, embers) there are per tile of width.
const MOTES_PER_TILE := 2

# FISH_PER_TILES: one robot piranha for every this many tiles of pit width (at least one). Lower: a busier tank.
const FISH_PER_TILES := 3

const SHADER := preload("res://scripts/level/pit_liquid.gdshader")

var kind := "toxic_waste"
var _rect := Rect2()              # the liquid, in world pixels
var _fx: Node2D                   # decoration: stops working while off screen
var _surface_y := 0.0


## `liquid` is the world rectangle of liquid cells (its top row is the surface).
func _init(liquid_kind: String = "toxic_waste", liquid: Rect2 = Rect2()) -> void:
	kind = liquid_kind
	_rect = liquid


func _ready() -> void:
	_surface_y = _rect.position.y + SURFACE_PX
	var style: Dictionary = STYLES[kind]

	# the liquid itself: one opaque rectangle with the animated shader
	var liquid := ColorRect.new()
	liquid.position = _rect.position
	liquid.size = _rect.size
	liquid.z_index = LIQUID_Z
	liquid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("liquid_tex", SpriteLibrary.pit(kind, "liquid"))
	mat.set_shader_parameter("size_px", _rect.size)
	mat.set_shader_parameter("surface_px", SURFACE_PX)
	mat.set_shader_parameter("wave_px", style["wave"])
	mat.set_shader_parameter("scroll", style["scroll"])
	mat.set_shader_parameter("rim_color", style["rim"])
	mat.set_shader_parameter("deep_color", style["deep"])
	liquid.material = mat
	add_child(liquid)

	# decoration (glow, rising specks, fish) in one node that sleeps when the pit is off screen
	_fx = Node2D.new()
	add_child(_fx)
	# Sleep the decoration while the pit is off screen: a notifier switches the node's processing off and on.
	var notifier := VisibleOnScreenNotifier2D.new()
	notifier.rect = Rect2(_rect.position - Vector2(200, 300), _rect.size + Vector2(400, 500))
	add_child(notifier)
	notifier.screen_exited.connect(func() -> void:
		_fx.process_mode = Node.PROCESS_MODE_DISABLED
		_fx.visible = false)
	notifier.screen_entered.connect(func() -> void:
		_fx.process_mode = Node.PROCESS_MODE_INHERIT
		_fx.visible = true)
	_build_glow(style)
	_build_motes(style)
	if kind == "piranha_tank":
		_build_fish()

	# the death zone is the whole liquid (outside the sleeping decoration, so it always works)
	var area := Area2D.new()
	area.position = _rect.get_center()
	area.collision_mask = Player.LAYER_WORLD | Player.LAYER_ENEMY   # the player shares the world layer
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = _rect.size
	shape.shape = box
	area.add_child(shape)
	add_child(area)
	area.body_entered.connect(func(body: Node) -> void:
		if body.has_method("fall_in_pit"):
			body.fall_in_pit())


# ---------- glow and rising specks ----------

static var _glow_tex: GradientTexture2D


static func glow_texture() -> GradientTexture2D:
	if _glow_tex == null:
		var grad := Gradient.new()
		grad.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
		grad.colors = PackedColorArray([Color(1, 1, 1, 0.95), Color(1, 1, 1, 0.35), Color(1, 1, 1, 0.0)])
		_glow_tex = GradientTexture2D.new()
		_glow_tex.gradient = grad
		_glow_tex.fill = GradientTexture2D.FILL_RADIAL
		_glow_tex.fill_from = Vector2(0.5, 0.5)
		_glow_tex.fill_to = Vector2(1.0, 0.5)
		_glow_tex.width = 64
		_glow_tex.height = 64
	return _glow_tex


func _additive() -> CanvasItemMaterial:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return m


func _build_glow(style: Dictionary) -> void:
	var halo := Sprite2D.new()
	halo.texture = glow_texture()
	halo.material = _additive()
	halo.position = Vector2(_rect.get_center().x, _surface_y - 10.0)
	halo.scale = Vector2(_rect.size.x / 64.0 * 1.5, 1.6)
	halo.modulate = Color(style["glow"], GLOW_ALPHA)
	halo.z_index = FX_Z + 1
	_fx.add_child(halo)
	var tw := _fx.create_tween().set_loops()
	tw.set_trans(Tween.TRANS_SINE)
	tw.tween_property(halo, "modulate:a", GLOW_ALPHA * (1.0 - GLOW_PULSE), GLOW_PERIOD / 2.0)
	tw.tween_property(halo, "modulate:a", GLOW_ALPHA, GLOW_PERIOD / 2.0)


func _build_motes(style: Dictionary) -> void:
	var cols := roundi(_rect.size.x / TILE)
	var p := CPUParticles2D.new()
	p.amount = maxi(4, cols * MOTES_PER_TILE)
	p.texture = glow_texture()
	p.z_index = FX_Z
	if style["additive"]:
		p.material = _additive()
	var rise: float = style["rise"]
	var depth := _rect.size.y - SURFACE_PX - 8.0
	if style["above"]:
		# embers and sparks: start on the surface and fly up out of the liquid
		p.position = Vector2(_rect.get_center().x, _surface_y)
		p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		p.emission_rect_extents = Vector2(_rect.size.x / 2.0 - 8.0, 2.0)
		p.lifetime = 1.8
	else:
		# bubbles: start near the bottom and rise to the surface
		p.position = Vector2(_rect.get_center().x, _surface_y + depth / 2.0 + 4.0)
		p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		p.emission_rect_extents = Vector2(_rect.size.x / 2.0 - 10.0, depth / 2.0)
		p.lifetime = maxf(0.8, depth * 0.5 / rise)
	p.direction = Vector2(0, -1)
	p.spread = 14.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = rise * 0.6
	p.initial_velocity_max = rise
	p.scale_amount_min = 0.06
	p.scale_amount_max = 0.16
	p.color = style["mote"]
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.2, 1.0])
	fade.colors = PackedColorArray([Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.0)])
	p.color_ramp = fade
	p.preprocess = 1.0
	_fx.add_child(p)


# ---------- robot piranhas ----------

## The tank's piranhas: enemies (see Piranha), each popping up at its own spot, spread evenly along the pit.
func _build_fish() -> void:
	var count := maxi(1, roundi(_rect.size.x / TILE) / FISH_PER_TILES)
	var x0 := _rect.position.x + 40.0
	var x1 := _rect.end.x - 40.0
	for i in count:
		var spot := lerpf(x0, x1, (i + 0.5) / count)
		_fx.add_child(Piranha.new(_surface_y, spot, x0, x1))
