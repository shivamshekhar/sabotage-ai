class_name PitHazard
extends Node2D
## A deadly pit: a tank of something nobody survives. Whoever falls in (the player or an enemy) loses all health
## and dies at once; for the player that is a game over (see Player.fall_in_pit()). The kinds are toxic waste
## (map character A), lava (F), nuclear waste (N) and a tank of robotic piranhas (W). Ordinary spikes
## are a different thing (see SpikeTrap): they only hurt. Every kind has creatures that leap out of it (CREATURES): poisonous
## puffer fish in the toxic waste, which also gives off drifting poison gas, lava balls in the lava, glowing eels in the
## nuclear waste, which glows, and robot piranhas in the tank.
##
## One PitHazard covers one rectangle of liquid cells. The liquid is drawn in front of the player, completely
## opaque, so whoever falls in disappears into it (see pit_liquid.gdshader: it drifts, wobbles and has a moving
## surface). Rising bubbles or embers and a glow make it feel alive, and each pit holds creatures (enemies, see PitCreature).
## Everything that only decorates, the creatures included, sits in one child node. A pit is only "awake" while it is on screen or
## near it (Level decides, see Level.PIT_ACTIVE_BUFFER and set_active()); a sleeping pit's decoration is hidden and does no work at
## all, so a level can hold any number of pits. The deadly liquid itself always works.

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
		"scroll": 0.045, "wave": 4.0, "mote": Color(0.8, 1.0, 0.5), "rise": 38.0, "above": false, "additive": false, "gas": true},
	"nuclear_waste": {"rim": Color(0.95, 1.0, 0.45), "deep": Color(0.0, 0.2, 0.18), "glow": Color(0.6, 1.0, 0.3),
		"scroll": 0.055, "wave": 4.5, "mote": Color(1.0, 1.0, 0.45), "rise": 55.0, "above": true, "additive": true,
		"radiant": true},
	"piranha_tank": {"rim": Color(0.85, 0.96, 1.0), "deep": Color(0.0, 0.1, 0.3), "glow": Color(0.4, 0.7, 1.0),
		"scroll": 0.03, "wave": 3.5, "mote": Color(0.85, 0.95, 1.0), "rise": 30.0, "above": false, "additive": false},
}

# GLOW_ALPHA / GLOW_PULSE / GLOW_PERIOD: how strongly the halo over the surface shines, how much of that the slow pulse
# takes away (0 = steady), and how long one pulse takes in seconds. Keep GLOW_ALPHA modest so it never hides the player.
const GLOW_ALPHA := 0.4
const GLOW_PULSE := 0.35
const GLOW_PERIOD := 2.2

# GAS_PER_TILE / GAS_COLOR: the poison gas of the toxic waste (style `gas`): how many drifting clouds there are per tile of width, and
# their colour (the alpha is how thick they look at their thickest). GAS_LIFE: seconds one cloud lasts, GAS_RISE: how fast it
# rises in pixels per second.
const GAS_PER_TILE := 2.4
const GAS_COLOR := Color(0.5, 0.9, 0.2, 0.5)
const GAS_LIFE := 3.6
const GAS_RISE := 30.0

# RADIANT_ALPHA / RADIANT_PERIOD: the extra glow of the nuclear waste (style `radiant`): a big soft halo over the whole pit that
# swells and fades out of step with the normal halo, and the seconds one swell takes.
const RADIANT_ALPHA := 0.55
const RADIANT_PERIOD := 3.4

# MOTES_PER_TILE: how many rising specks (bubbles, embers) there are per tile of width.
const MOTES_PER_TILE := 2

# FISH_PER_TILES: one creature for every this many tiles of pit width (at least one). Lower: a busier pit.
const FISH_PER_TILES := 3

# CREATURES: which creature (a key of PitCreature.SPECIES) lives in each kind of pit.
const CREATURES := {"piranha_tank": "piranha", "toxic_waste": "puffer", "lava": "lava_ball", "nuclear_waste": "eel"}

const SHADER := preload("res://scripts/level/pit_liquid.gdshader")

var kind := "toxic_waste"
var _rect := Rect2()              # the liquid, in world pixels
var _fx: Node2D                   # decoration: stops working while the pit sleeps
var _active := true
var _surface_y := 0.0
var _settings := {}


## `liquid` is the world rectangle of liquid cells (its top row is the surface).
## `settings` are optional values from a level file for the pit's creatures: fish_count (0 = automatic), bite_fraction, respawn_time.
func _init(liquid_kind: String = "toxic_waste", liquid: Rect2 = Rect2(), settings: Dictionary = {}) -> void:
	kind = liquid_kind
	_rect = liquid
	_settings = settings


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

	# decoration (glow, rising specks, creatures) in one node that sleeps when the pit is far from the screen (see set_active())
	_fx = Node2D.new()
	add_child(_fx)
	_build_glow(style)
	_build_motes(style)
	if bool(style.get("gas", false)):
		_build_gas()
	if bool(style.get("radiant", false)):
		_build_radiance(style)
	_build_creatures()

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


## The liquid's rectangle in world pixels (Level uses it to decide whether the pit is near the screen).
func liquid_rect() -> Rect2:
	return _rect


## True while the pit is awake.
func is_active() -> bool:
	return _active


## Wake the pit up or put it to sleep (Level does this: only pits on screen or near it are awake). A sleeping pit's glow, bubbles,
## gas and creatures are hidden and do no work at all (the node's processing, its tweens and its particles are all switched off),
## and they pick up where they were when it wakes. The deadly liquid keeps working either way.
func set_active(value: bool) -> void:
	if value == _active:
		return
	_active = value
	_fx.process_mode = Node.PROCESS_MODE_INHERIT if value else Node.PROCESS_MODE_DISABLED
	_fx.visible = value


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
	var alpha := GLOW_ALPHA * (1.5 if bool(style.get("radiant", false)) else 1.0)
	halo.modulate = Color(style["glow"], alpha)
	halo.z_index = FX_Z + 1
	_fx.add_child(halo)
	var tw := _fx.create_tween().set_loops()
	tw.set_trans(Tween.TRANS_SINE)
	tw.tween_property(halo, "modulate:a", alpha * (1.0 - GLOW_PULSE), GLOW_PERIOD / 2.0)
	tw.tween_property(halo, "modulate:a", alpha, GLOW_PERIOD / 2.0)


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


# ---------- poison gas and radiance ----------

## The poison gas of the toxic waste: soft green clouds that rise off the surface, swell and drift sideways before they fade.
func _build_gas() -> void:
	var cols := roundi(_rect.size.x / TILE)
	var p := CPUParticles2D.new()
	p.amount = maxi(6, roundi(cols * GAS_PER_TILE))
	p.texture = glow_texture()
	p.z_index = FX_Z + 2
	p.position = Vector2(_rect.get_center().x, _surface_y - 4.0)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(_rect.size.x / 2.0, 3.0)
	p.lifetime = GAS_LIFE
	p.direction = Vector2(0, -1)
	p.spread = 28.0
	p.gravity = Vector2(7, -3)
	p.initial_velocity_min = GAS_RISE * 0.5
	p.initial_velocity_max = GAS_RISE
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.2
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.45))
	grow.add_point(Vector2(1.0, 1.5))
	p.scale_amount_curve = grow
	p.color = GAS_COLOR
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.25, 0.7, 1.0])
	fade.colors = PackedColorArray([Color(1, 1, 1, 0.0), Color(1, 1, 1, 1.0), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0.0)])
	p.color_ramp = fade
	p.preprocess = GAS_LIFE
	_fx.add_child(p)


## The extra glow of the nuclear waste: a big soft halo over the whole pit that swells and fades slowly.
func _build_radiance(style: Dictionary) -> void:
	var halo := Sprite2D.new()
	halo.texture = glow_texture()
	halo.material = _additive()
	halo.position = Vector2(_rect.get_center().x, _surface_y - 40.0)
	halo.scale = Vector2(_rect.size.x / 64.0 * 2.0 + 1.0, 4.2)
	halo.modulate = Color(style["glow"], RADIANT_ALPHA * 0.4)
	halo.z_index = FX_Z + 1
	_fx.add_child(halo)
	var tw := _fx.create_tween().set_loops()
	tw.set_trans(Tween.TRANS_SINE)
	tw.tween_property(halo, "modulate:a", RADIANT_ALPHA, RADIANT_PERIOD / 2.0)
	tw.tween_property(halo, "modulate:a", RADIANT_ALPHA * 0.3, RADIANT_PERIOD / 2.0)


# ---------- the creatures ----------

## The pit's creatures: enemies (see PitCreature), each popping up at its own spot, spread evenly along the pit.
func _build_creatures() -> void:
	var count := maxi(1, roundi(_rect.size.x / TILE) / FISH_PER_TILES)
	if int(_settings.get("fish_count", 0)) > 0:
		count = int(_settings["fish_count"])
	var x0 := _rect.position.x + 40.0
	var x1 := _rect.end.x - 40.0
	var species: String = CREATURES[kind]
	for i in count:
		var spot := lerpf(x0, x1, (i + 0.5) / count)
		var creature: PitCreature
		if species == "piranha":
			creature = Piranha.new(_surface_y, spot, x0, x1)
		else:
			creature = PitCreature.new(_surface_y, spot, x0, x1, species)
		creature.bite_fraction = float(_settings.get("bite_fraction", creature.bite_fraction))
		creature.respawn_time = float(_settings.get("respawn_time", creature.respawn_time))
		_fx.add_child(creature)
