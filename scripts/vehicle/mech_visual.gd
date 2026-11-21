class_name MechVisual
extends Node2D
## What the mech looks like and how it moves: the crane body with the player sitting in the cockpit, the two turrets, the booster flame,
## four tentacle legs and the damage it shows. The art is assets/vehicles/mech/ (tools/art/generate_mech.py and generate_mech_effects.py;
## every picture faces right, drawn at twice the size it is shown at). The origin is the player's feet.
##
## THE LEGS are what makes it move like an octopus. Each leg has a hip under the hull and a foot that stands in the world. A leg is drawn
## as a smooth arched curve from the hip to the foot, made of LEG_LINKS links with a joint between each and a claw on the end, so
## whatever the distance or height of the foot, the leg bends to reach it. A foot stays where it was put until it is too far from its
## stance; then it lifts and swings to a new spot found by a ray at ground level (so on steps it lands on the step). The legs take turns
## in two groups, so the mech is never off the ground. In the air they curl up under the belly. A leg whose stance has no floor under
## it (the mech stands on a narrow ledge or at an edge) curls up too, and the booster burns at a low flame (see hovering): the mech is
## not floating, it is held up.
##
## DAMAGE (set_damage(), one step for each hit the mech has taken): 1 cracks on the body and the glass, 2 a leg snaps (the front leg:
## its end falls off and the stump hangs, sparking) and smoke streams from the exhaust and the engine. The 3rd hit destroys it (shatter()).

# TEX: the pictures are drawn at this scale (they are made at twice their size on screen).
const TEX := 0.5

# BELLY: the height in pixels of the underside of the hull above the ground when standing. The whole mech is about 1.5 player heights.
const BELLY := 86.0

# BODY_MIDDLE: the middle of the body picture relative to the feet (the hull's underside, 99 px below the middle, is at BELLY).
const BODY_MIDDLE := Vector2(0.0, -BELLY - 99.0 + 53.5)

# ROOTS: where each of the four hips is (pixels right of the middle), STANCE: where each foot likes to stand. NEAR: the legs drawn in front
# of the body; the others are behind it, darker.
const ROOTS := [-54.0, -24.0, 22.0, 52.0]
const STANCE := [-100.0, -60.0, 60.0, 100.0]
const NEAR := [true, false, false, true]

# MISSILE_MOUNT / LASER_MOUNT: where each turret's pivot is, in pixels from the middle of the body picture (a body picture pixel is half of
# one of these). The missile turret's base stands on the pedestal on the cab roof (body picture (146..206, 38..50)); the laser turret's
# base rests on the hull ledge at the front of the cab.
const MISSILE_MOUNT := Vector2(12.0, -50.5)
const LASER_MOUNT := Vector2(55.0, 7.5)

# MISSILE_PIVOT / LASER_PIVOT: the point of each turret's picture it turns about, in picture pixels.
const MISSILE_PIVOT := Vector2(40, 50)
const LASER_PIVOT := Vector2(34, 38)

# PILOT_HEIGHT / PILOT_AT: the picture of the player sitting in the cockpit: how tall it is (px) and where, from the middle of the body picture.
const PILOT_HEIGHT := 58.0
const PILOT_AT := Vector2(33.0, 3.5)

# FAR_SHADE: how dark the legs behind the body are.
const FAR_SHADE := 0.6

# LEG_LINKS: links per leg. LINK_THICKNESS: the thickest link in pixels (they taper to half towards the foot).
const LEG_LINKS := 6
const LINK_THICKNESS := 21.0

# THE GAIT. The mech walks with a diagonal trot: its legs are two pairs (legs 0 and 2, legs 1 and 3, counting from the rear), and while one pair is
# in the air the other carries the body, so at least two feet are always down. The cycle advances with the distance walked, not with time, so the
# steps follow the speed: slower walking, slower steps.
#   GAIT_STRIDE: how far (px) the mech walks in one full cycle, which is how far each foot is carried forward in its one step per cycle.
#   GAIT_SWING: the share of the cycle a foot is in the air (the rest it stands: 0.4 means a foot is down 60% of the time).
#   GAIT_SLOW_SPEED: a step is timed as if the mech walked at least this fast (px/s), so a step started just before stopping is not endless.
#   GAIT_IDLE_SPEED / SETTLE_DELAY / SETTLE_OFFSET: below this speed the mech stands; after SETTLE_DELAY seconds standing, a foot more than SETTLE_OFFSET px
#   from its stance takes one more step to stand square (a pair at a time).
#   GAIT_BOB: how far (px) the body rises and sinks with the steps at full speed (twice a cycle, once for each pair that takes the weight).
const GAIT_STRIDE := 120.0
const GAIT_SWING := 0.4
const GAIT_SLOW_SPEED := 120.0
const GAIT_IDLE_SPEED := 30.0
const SETTLE_DELAY := 0.15
const SETTLE_OFFSET := 14.0
const GAIT_BOB := 3.0

# STEP_TRIGGER: how far (px) a foot may be from its stance before it takes an extra step out of the rhythm (a wall dragged it, or the mech turned
# round). STEP_TIME: how long such an emergency step, and a step down from the air, takes. STEP_LIFT: how high the foot swings. MAX_REACH: the
# farthest a foot can be from its hip.
const STEP_TRIGGER := 80.0
const STEP_TIME := 0.2
const STEP_LIFT := 32.0
const MAX_REACH := 145.0

# REACH_SOFT: a foot farther than this from its hip steps at once, whatever the other legs are doing; MAX_REACH is the hard limit: a foot is never
# allowed farther than that (it is dragged along with the body), so a leg never stretches into a long rod. A leg at rest is about 116 long.
const REACH_SOFT := 136.0

# LEG_ARCH / LEG_ARCH_MIN / LEG_ARCH_MAX: how high a leg arches out of the straight line from hip to foot: this share of that distance, kept between the two limits (px).
const LEG_ARCH := 0.38
const LEG_ARCH_MIN := 12.0
const LEG_ARCH_MAX := 56.0

# CLAW_REACH: how far the claw reaches past the end of the drawn leg (the claw's tip is the foot, which stands on the floor). A foot that is down
# shows the open claw instead (claw_open.png: an upright foot, palm on top, three toes spread out flat on the floor): the leg then ends CLAW_OPEN_REACH
# above the floor, at the palm, and the picture's empty bottom rows (CLAW_OPEN_PAD, in picture pixels) sit under the floor line. CLAW_LEAN_RATE: how fast
# (per second) a leg's end moves between the two, so the foot does not jump when it lifts off or comes down.
const CLAW_REACH := 34.0
const CLAW_OPEN_REACH := 26.0
const CLAW_OPEN_PAD := 3.0
const CLAW_LEAN_RATE := 10.0

# FOOT_LIFT_LIMIT: a foot that starts a step more than this many pixels above the floor it comes down on (a curled one after a jump) just drops: it does
# not swing up first (see _step_legs()).
const FOOT_LIFT_LIMIT := 24.0

# FOOT_FLOAT_LIMIT: a foot that is meant to be standing is never more than this many pixels above the floor: one that is comes down at once (a mech
# that arrives in a level, or lands from a tiny hop, would otherwise stand on its toes). CURL_DELAY: seconds the mech must have been off the floor
# before its legs curl up (a frame in the air, as at the start of a level or over a bump, does not move them).
const FOOT_FLOAT_LIMIT := 4.0
const CURL_DELAY := 0.1

# BROKEN_LEG: the leg that snaps on the 2nd hit (the near front leg). SNAP_LINKS: how many links stay on it, the last one torn. LINK_LENGTH: how
# long each hanging link is, in pixels.
const BROKEN_LEG := 3
const SNAP_LINKS := 3
const LINK_LENGTH := 20.0

# The damage effects: the smoke streams from the SMOKE_SPOTS (see _make_damage_effects()); the snapped leg's sparks.
const SMOKE_AMOUNT := 12
const SMOKE_LIFE := 1.6
const SMOKE_SPREAD := 20.0
const SMOKE_SPEED := Vector2(22.0, 46.0)
const SMOKE_GRAVITY := Vector2(0.0, -10.0)
const SMOKE_SIZE := Vector2(0.22, 0.36)
const SMOKE_GROWTH := Vector2(0.45, 1.8)
const SPARK_AMOUNT := 7
const SPARK_AMOUNT_SNAP := 14
const SPARK_AMOUNT_IDLE := 6
const SPARK_LIFE := 0.45
const SPARK_SPEED := Vector2(40.0, 150.0)
const SPARK_GRAVITY := Vector2(0.0, 700.0)
const SPARK_SIZE := Vector2(0.18, 0.36)
const SPARK_EVERY := Vector2(0.5, 1.1)       # seconds between the sparks of the hanging stump
# The damage effects' places, in pixels from the middle of the body picture (the engine block's top is at y = -22.5, the cab roof at y = -30.5,
# the exhaust stack's top at (-53.5, -51)).
const SMOKE_SPOTS := [Vector2(-53.5, -51.0), Vector2(-38.0, -22.5)]

var mech: Mech
var feet: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]   # the feet in the world
var damage := 0                      # the hits taken so far (0-2 while it is alive)
var hovering := false                # standing without all legs on the floor: the booster burns low
var break_tip := Vector2.ZERO        # where the snapped leg ends, in the world (while a leg is broken)

var _t := 0.0
var _gait := 0.0                     # where the walking cycle is (0 to 1), see GAIT_STRIDE
var _air_time := 0.0                 # seconds since the mech was last on the floor
var _standing_for := 1.0             # seconds the mech has stood still
var _body: Node2D
var _pilot: Sprite2D
var _cracks: Sprite2D
var _glass_cracks: Sprite2D
var _missile_turret: Node2D
var _laser_turret: Node2D
var _missile_muzzle: Node2D
var _laser_muzzle: Node2D
var _flame: Sprite2D
var _legs_far: MechLegs
var _legs_near: MechLegs
var _smoke: Array[CPUParticles2D] = []
var _sparks: CPUParticles2D
var _step_from: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
var _step_to: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
var _step_t: Array[float] = [-1.0, -1.0, -1.0, -1.0]
var foot_down: Array[bool] = [true, true, true, true]       # the foot stands on the floor (it shows the open claw)
var _claw_lean: Array[float] = [1.0, 1.0, 1.0, 1.0]            # 1 when the foot is down, 0 in the air: how the end of the leg and the claw are shown
var _step_time: Array[float] = [STEP_TIME, STEP_TIME, STEP_TIME, STEP_TIME]   # how long each foot's step in the air takes
var _broken := -1
var _airborne := false
var _dip := 0.0
var _burst := 0.0
var _hurt := 0.0
var _spark_timer := 0.0
var _recoil := {&"missile": 0.0, &"laser": 0.0}
var _aim := {&"missile": 0.0, &"laser": 0.0}
var _flash := {&"missile": 0.0, &"laser": 0.0}


func _tex_of(name: String) -> Texture2D:
	return AssetPaths.mech(name)


func _sprite(name: String, z: int, centered := true) -> Sprite2D:
	return Sprites.make(_tex_of(name), TEX, z, centered)


func _turret(name: String, pivot: Vector2, mount: Vector2, muzzle_tex: Vector2) -> Array:
	var node := Node2D.new()
	node.position = mount
	node.z_index = 2
	var sp := _sprite(name, 0, false)
	sp.offset = -pivot
	node.add_child(sp)
	var m := Node2D.new()
	m.position = (muzzle_tex - pivot) * TEX
	node.add_child(m)
	_body.add_child(node)
	return [node, m, sp]


func _ready() -> void:
	z_index = 0
	var player := mech.player
	_legs_far = MechLegs.new()
	_legs_far.visual = self
	_legs_far.indices = [1, 2]
	_legs_far.shade = FAR_SHADE
	_legs_far.z_index = -3
	add_child(_legs_far)
	_flame = _sprite("flame_1", -2, false)
	_flame.offset = Vector2(-32.0, 0.0)
	_flame.position = Vector2(0.0, -BELLY + 7.0)
	_flame.visible = false
	add_child(_flame)

	_body = Node2D.new()
	_body.position = BODY_MIDDLE
	add_child(_body)
	# the pilot: the player, sitting in the cockpit behind the glass
	_pilot = Sprite2D.new()
	_pilot.texture = SpriteLibrary.character_pose(PlayerSprite.CHARACTER, "idle")
	var ps := PILOT_HEIGHT / float(_pilot.texture.get_height())
	_pilot.scale = Vector2(ps, ps)
	_pilot.position = PILOT_AT
	_pilot.z_index = -1
	_body.add_child(_pilot)
	_body.add_child(_sprite("body", 0))
	_cracks = _sprite("body_cracks", 0)
	_cracks.visible = false
	_body.add_child(_cracks)
	_body.add_child(_sprite("canopy", 1))
	_glass_cracks = _sprite("canopy_cracks", 1)
	_glass_cracks.visible = false
	_body.add_child(_glass_cracks)
	var mt := _turret("missile_turret", MISSILE_PIVOT, MISSILE_MOUNT, Vector2(176, 44))
	_missile_turret = mt[0]
	_missile_muzzle = mt[1]
	var lt := _turret("laser_turret", LASER_PIVOT, LASER_MOUNT, Vector2(150, 38))
	_laser_turret = lt[0]
	_laser_muzzle = lt[1]
	_make_damage_effects()

	_legs_near = MechLegs.new()
	_legs_near.visual = self
	_legs_near.indices = [0, 3]
	_legs_near.shade = 1.0
	_legs_near.z_index = 3
	add_child(_legs_near)

	# the feet start on the ground under their stances
	for i in 4:
		feet[i] = Vector2(player.global_position.x + STANCE[i], _ground_y(player.global_position.x + STANCE[i], player.global_position.y))
	_body.scale.x = float(mech.facing())


func _make_damage_effects() -> void:
	# smoke from the exhaust stack and from the engine (it only streams once the mech is damaged enough, see set_damage())
	for i in SMOKE_SPOTS.size():
		var puffs := ParticlePreset.new()
		puffs.texture = AssetPaths.effect("smoke_%d" % (i + 1))
		puffs.one_shot = false
		puffs.explosiveness = 0.0
		puffs.amount = SMOKE_AMOUNT
		puffs.lifetime = SMOKE_LIFE
		puffs.direction = Vector2.UP
		puffs.spread = SMOKE_SPREAD
		puffs.speed_min = SMOKE_SPEED.x
		puffs.speed_max = SMOKE_SPEED.y
		puffs.gravity = SMOKE_GRAVITY
		puffs.random_angle = true
		puffs.scale_min = SMOKE_SIZE.x
		puffs.scale_max = SMOKE_SIZE.y
		puffs.grow = ParticlePreset.grow_curve(SMOKE_GROWTH.x, SMOKE_GROWTH.y)
		puffs.colors = ParticlePreset.fade_gradient([Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.8), Color(0.6, 0.6, 0.64, 0.0)])
		var p := puffs.build()
		p.position = SMOKE_SPOTS[i]
		p.emitting = false
		p.z_index = 4
		_body.add_child(p)
		_smoke.append(p)
	# the sparks of the snapped leg (in the world, so they fall away from it)
	var sparks := ParticlePreset.new()
	sparks.texture = AssetPaths.effect("spark")
	sparks.additive = true
	sparks.explosiveness = 0.9
	sparks.amount = SPARK_AMOUNT
	sparks.lifetime = SPARK_LIFE
	sparks.direction = Vector2.DOWN
	sparks.spread = 70.0
	sparks.speed_min = SPARK_SPEED.x
	sparks.speed_max = SPARK_SPEED.y
	sparks.gravity = SPARK_GRAVITY
	sparks.scale_min = SPARK_SIZE.x
	sparks.scale_max = SPARK_SIZE.y
	_sparks = sparks.build()
	_sparks.emitting = false
	_sparks.z_index = 4
	add_child(_sparks)


# ---------------------------------------------------------------------------------------------------------------------------
# damage
# ---------------------------------------------------------------------------------------------------------------------------
## Show the damage of `level` hits (1 to 2).
func set_damage(level: int, silent := false) -> void:
	damage = level
	_cracks.visible = level >= 1
	_glass_cracks.visible = level >= 1
	if level >= 2 and _broken < 0:
		if silent:
			_broken = BROKEN_LEG       # (carried in from the last level: the leg is already gone, nothing falls off now)
		else:
			_snap_leg(BROKEN_LEG)
	for p in _smoke:
		p.emitting = level >= 2


## Mend everything (see Mech.repair()): the cracks and the smoke go, the leg is whole again.
func clear_damage() -> void:
	damage = 0
	_broken = -1
	_cracks.visible = false
	_glass_cracks.visible = false
	for p in _smoke:
		p.emitting = false


func hurt() -> void:
	_hurt = 0.25


## The curve of leg `i` as points in this node's space, from the hip to the foot: a smooth arch (a quadratic curve), cut into LEG_LINKS pieces.
func leg_points(i: int, hip: Vector2, foot: Vector2) -> Array[Vector2]:
	var d := foot - hip
	var dist := d.length()
	var n := Vector2(-d.y, d.x).normalized() if dist > 0.01 else Vector2.UP
	if n.y > 0.0:
		n = -n                                  # the leg arches upwards, like an elbow
	var curl := clampf(dist * LEG_ARCH, LEG_ARCH_MIN, LEG_ARCH_MAX)
	var sway := sin(_t * 2.3 + float(i) * 1.7) * 3.0
	var outward := Vector2(signf(ROOTS[i]) * dist * 0.2, 0.0)
	var ctrl := hip + d * 0.5 + n * (curl + sway) + outward
	var points: Array[Vector2] = []
	for k in LEG_LINKS + 1:
		var t := float(k) / LEG_LINKS
		points.append(hip.lerp(ctrl, t).lerp(ctrl.lerp(foot, t), t))
	return points


## The leg snaps: the lower part (the links past SNAP_LINKS, their joints and the claw) falls off and tumbles away; what is left hangs.
func _snap_leg(i: int) -> void:
	_broken = i
	var hip := hip_world(i)
	var pts := leg_points(i, to_local(hip), to_local(feet[i]))
	var parent := mech.player.get_parent()
	var side := signf(ROOTS[i])
	for k in range(SNAP_LINKS, LEG_LINKS):
		var a := to_global(pts[k])
		var b := to_global(pts[k + 1])
		var seg := b - a
		var thick := LINK_THICKNESS * (1.0 - 0.5 * float(k) / LEG_LINKS)
		var sc := Vector2(seg.length() * 1.14 / 52.0, thick / 40.0)
		Debris.spawn(parent, _tex_of("link"), (a + b) / 2.0, seg.angle(), sc, Vector2(side * randf_range(40.0, 140.0), randf_range(-260.0, -120.0)), randf_range(-6.0, 6.0))
	var last := to_global(pts[LEG_LINKS]) - to_global(pts[LEG_LINKS - 1])
	Debris.spawn(parent, _tex_of("claw"), feet[i], last.angle(), Vector2(0.5, 0.5), Vector2(side * randf_range(60.0, 160.0), randf_range(-220.0, -100.0)), randf_range(-7.0, 7.0))
	_spark_timer = 0.0
	_sparks.global_position = to_global(pts[SNAP_LINKS])
	_sparks.amount = SPARK_AMOUNT_SNAP
	_sparks.restart()
	_sparks.emitting = true


## The last hit: the mech flies apart. Pieces of it (the legs' links and claws, the turrets, chunks of the body picture) are thrown out.
func shatter() -> void:
	var parent := mech.player.get_parent()
	var centre := to_global(BODY_MIDDLE)
	for i in 4:
		if i == _broken:
			continue
		var pts := leg_points(i, to_local(hip_world(i)), to_local(feet[i]))
		for k in range(0, LEG_LINKS, 2):
			var a := to_global(pts[k])
			var b := to_global(pts[k + 1])
			var seg := b - a
			var thick := LINK_THICKNESS * (1.0 - 0.5 * float(k) / LEG_LINKS)
			var away := (a - centre).normalized()
			Debris.spawn(parent, _tex_of("link"), (a + b) / 2.0, seg.angle(), Vector2(seg.length() * 1.14 / 52.0, thick / 40.0), away * randf_range(120.0, 320.0) + Vector2(0.0, -260.0), randf_range(-9.0, 9.0))
		Debris.spawn(parent, _tex_of("claw"), feet[i], randf() * TAU, Vector2(0.5, 0.5), Vector2(randf_range(-260.0, 260.0), randf_range(-420.0, -200.0)), randf_range(-8.0, 8.0))
	for turret in [_missile_turret, _laser_turret]:
		var sp := (turret as Node2D).get_child(0) as Sprite2D
		Debris.spawn(parent, sp.texture, (turret as Node2D).global_position, (turret as Node2D).global_rotation, Vector2(0.5, 0.5), Vector2(randf_range(-240.0, 240.0), randf_range(-520.0, -300.0)), randf_range(-6.0, 6.0))
	# chunks of the body picture: the engine block, the cab and the hull (parts of the picture cut out, so they look like pieces of the mech)
	var body_tex := _tex_of("body")
	for region in [Rect2(10, 56, 122, 90), Rect2(112, 40, 188, 110), Rect2(14, 146, 280, 56), Rect2(30, 2, 30, 70)]:
		var at := AtlasTexture.new()
		at.atlas = body_tex
		at.region = region
		var middle: Vector2 = (region.position + region.size / 2.0 - Vector2(150.0, 107.0)) * TEX
		var world_at := _body.to_global(middle)
		Debris.spawn(parent, at, world_at, 0.0, Vector2(0.5, 0.5) * Vector2(float(_body.scale.x), 1.0), (world_at - centre).normalized() * randf_range(140.0, 300.0) + Vector2(0.0, -300.0), randf_range(-4.0, 4.0))


func burst() -> void:
	_burst = 0.16
	_dip = -4.0


## A weapon just fired: kick the turret back and flash the muzzle.
func recoil(which: StringName) -> void:
	_recoil[which] = 1.0
	_flash[which] = 0.09


func step_up() -> void:
	_dip = 5.0


# ---------------------------------------------------------------------------------------------------------------------------
# places on the mech
# ---------------------------------------------------------------------------------------------------------------------------
## The hip of leg `i` in the world.
func hip_world(i: int) -> Vector2:
	return to_global(Vector2(ROOTS[i], -BELLY - 8.0 + _body_offset()))


## How far the body is moved down from its standing height (a dip when landing, a small bob while walking).
func _body_offset() -> float:
	return _dip - sin(_gait * TAU * 2.0) * GAIT_BOB * clampf(absf(mech.player.velocity.x) / 300.0, 0.0, 1.0)


func missile_muzzle() -> Vector2:
	return _missile_muzzle.global_position


func laser_muzzle() -> Vector2:
	return _laser_muzzle.global_position


func missile_direction() -> Vector2:
	return (_missile_muzzle.global_position - _missile_turret.global_position).normalized()


func laser_direction() -> Vector2:
	return (_laser_muzzle.global_position - _laser_turret.global_position).normalized()


## The floor under `x` within reach of the mech: its y, or `fallback` if there is none.
func _ground_y(x: float, fallback: float = NAN) -> float:
	var p := mech.player
	var query := PhysicsRayQueryParameters2D.create(Vector2(x, p.global_position.y - 130.0), Vector2(x, p.global_position.y + 120.0), PhysicsLayers.FLOOR)
	query.exclude = [p.get_rid()]
	query.hit_from_inside = true
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return fallback
	if hit["normal"] == Vector2.ZERO:
		return p.global_position.y if is_nan(fallback) else fallback      # the stance is inside a wall (the mech is against it): the foot stands at the mech's own level
	return float(hit["position"].y)


# ---------------------------------------------------------------------------------------------------------------------------
# every physics step
# ---------------------------------------------------------------------------------------------------------------------------
func _physics_process(delta: float) -> void:
	var p := mech.player
	_t += delta
	var grounded := p.is_on_floor() or mech.climbing_step()      # (climbing a step the legs stay down)
	var speed := absf(p.velocity.x)
	_dip = move_toward(_dip, 0.0, 40.0 * delta)
	if grounded and _airborne:
		_dip = 9.0       # landing: the body dips on its legs
	_airborne = not grounded
	_air_time = 0.0 if grounded else _air_time + delta
	_burst = maxf(0.0, _burst - delta)
	_hurt = maxf(0.0, _hurt - delta)
	_body.scale.x = float(mech.facing())
	_body.position = BODY_MIDDLE + Vector2(0.0, _body_offset())
	_body.modulate = Color(1.0, 1.0 - _hurt * 2.5, 1.0 - _hurt * 2.5) if _hurt > 0.0 else Color.WHITE
	_pilot.texture = SpriteLibrary.character_pose(PlayerSprite.CHARACTER, "hurt" if _hurt > 0.0 else "idle")
	_animate_turrets(delta)
	_step_legs(delta, grounded)
	_animate_flame()
	_animate_damage(delta)
	_legs_far.queue_redraw()
	_legs_near.queue_redraw()
	queue_redraw()


func _animate_turrets(delta: float) -> void:
	for which in [&"missile", &"laser"]:
		var turret: Node2D = _missile_turret if which == &"missile" else _laser_turret
		var target := mech.nearest_target(turret.global_position)
		var want := 0.0
		if target != null:
			var d: Vector2 = (target.hurtbox() as Rect2).get_center() - turret.global_position
			want = clampf(atan2(d.y, absf(d.x)), Mech.AIM_UP, Mech.AIM_DOWN)
		_aim[which] = lerp_angle(float(_aim[which]), want, 1.0 - exp(-10.0 * delta))
		turret.rotation = float(_aim[which])
		_recoil[which] = maxf(0.0, float(_recoil[which]) - delta * 6.0)
		_flash[which] = maxf(0.0, float(_flash[which]) - delta)
		(turret.get_child(0) as Sprite2D).position.x = -float(_recoil[which]) * 7.0


## The booster's flame: full while it lifts the mech (the jump button held with energy), a short kick at the start of a jump, and a low
## flicker while the mech stands without all legs on a floor (hovering).
func _animate_flame() -> void:
	var big := mech.thrusting or _burst > 0.0
	_flame.visible = big or hovering
	if not _flame.visible:
		return
	_flame.texture = _tex_of("flame_%d" % (int(_t * 24.0) % 3 + 1))
	if big:
		_flame.scale = Vector2(TEX, TEX * (0.85 + 0.3 * sin(_t * 60.0)))
	else:
		_flame.scale = Vector2(TEX * 0.62, TEX * 0.42 * (0.85 + 0.25 * sin(_t * 47.0)))


func _animate_damage(delta: float) -> void:
	if _broken >= 0:
		_spark_timer -= delta
		if _spark_timer <= 0.0:
			_spark_timer = randf_range(SPARK_EVERY.x, SPARK_EVERY.y)
			_sparks.global_position = break_tip
			_sparks.amount = SPARK_AMOUNT_IDLE
			_sparks.restart()
			_sparks.emitting = true


func _step_legs(delta: float, grounded: bool) -> void:
	var p := mech.player
	var speed := absf(p.velocity.x)
	var moving := grounded and speed > GAIT_IDLE_SPEED
	var cycle_before := _gait
	if moving:
		if _standing_for > 0.0:
			_gait = 1.0 - 0.0001          # setting off: the first pair steps at once
			cycle_before = _gait
		_standing_for = 0.0
		_gait = fposmod(_gait + speed * delta / GAIT_STRIDE, 1.0)
	elif grounded:
		_standing_for += delta
	var lacking := 0
	for i in 4:
		if i == _broken:
			continue
		var hip := hip_world(i)
		foot_down[i] = false
		if not grounded:
			if _air_time > CURL_DELAY:
				# curled up under the belly
				_curl(i, hip, delta)
			else:
				foot_down[i] = _step_t[i] < 0.0      # (just left the floor: the legs stay as they are for a moment)
			continue
		if _step_t[i] >= 0.0:
			_step_t[i] += delta / _step_time[i]
			var t := clampf(_step_t[i], 0.0, 1.0)
			var e := t * t * (3.0 - 2.0 * t)
			# (a foot that is already well above its floor, like a curled one after a jump, just drops: no swing up first)
			var lift := (STEP_LIFT if _step_from[i].y >= _step_to[i].y - FOOT_LIFT_LIMIT else 0.0) + maxf(0.0, _step_from[i].y - _step_to[i].y)
			feet[i] = _step_from[i].lerp(_step_to[i], e) + Vector2(0.0, -lift * sin(PI * t))
			if _step_t[i] >= 1.0:
				_step_t[i] = -1.0
				feet[i] = _step_to[i]
				foot_down[i] = true
			continue
		var stance_x: float = _stance_x(i)
		# where the foot comes down for a step in the rhythm: ahead of its stance by half of what the body walks while the foot stands, and further
		# by what the body walks while the foot is in the air
		var swing_time := GAIT_SWING * GAIT_STRIDE / maxf(speed, GAIT_SLOW_SPEED)
		var heading := signf(p.velocity.x) if moving else 0.0
		var to_x := _landing_x(i, stance_x, speed, heading, swing_time)
		var floor_y := _ground_y(to_x)
		if is_nan(floor_y):
			# no floor under this foot's stance (a narrow ledge, an edge): it cannot stand, it curls up
			lacking += 1
			_curl(i, hip, delta)
			continue
		# a foot well above the floor it should stand on (curled up after a jump, or left on a crate the mech has walked off) comes down at once
		var off_ground := feet[i].y < floor_y - FOOT_FLOAT_LIMIT
		var over_reach := feet[i].distance_to(hip) > REACH_SOFT
		var emergency := off_ground or over_reach or absf(feet[i].x - stance_x) > STEP_TRIGGER or feet[i].y < p.global_position.y - 130.0
		var in_rhythm := moving and _swing_starts(i, cycle_before)
		var settling := not moving and _standing_for > SETTLE_DELAY and absf(feet[i].x - stance_x) > SETTLE_OFFSET and not _other_pair_stepping(i)
		if not (emergency or in_rhythm or settling):
			foot_down[i] = true
			continue
		var rhythm_step := in_rhythm and not emergency
		var duration := swing_time if rhythm_step else STEP_TIME
		if not rhythm_step:
			to_x = _landing_x(i, stance_x, speed, heading, STEP_TIME)
			floor_y = _ground_y(to_x, floor_y)
		_step_from[i] = feet[i]
		_step_to[i] = Vector2(to_x, floor_y)
		_step_time[i] = duration
		_step_t[i] = 0.0
	hovering = grounded and lacking > 0
	for i in 4:
		_claw_lean[i] = move_toward(_claw_lean[i], 1.0 if foot_down[i] else 0.0, CLAW_LEAN_RATE * delta)
	# no leg is ever longer than MAX_REACH: a foot that would be is dragged in towards its hip
	for i in 4:
		if i == _broken:
			continue
		var along := feet[i] - hip_world(i)
		if along.length() > MAX_REACH:
			feet[i] = hip_world(i) + along.normalized() * MAX_REACH
	if _broken >= 0:
		_update_break_tip()


## Where a foot that steps now, and is in the air for `air_time` seconds, comes down: ahead of its stance in the direction of travel (`heading`, 0 when
## standing) by half of what the body walks while a foot stands, and further by what it walks meanwhile, so the foot is where the stance is by then.
func _landing_x(i: int, stance_x: float, speed: float, heading: float, air_time: float) -> float:
	return _stance_x_toward(i, stance_x + heading * (GAIT_STRIDE * (1.0 - GAIT_SWING) * 0.5 + speed * air_time))


## True if leg `i` starts its step in the air in this step of the cycle (the cycle was at `before`, it is at _gait now). One pair starts as the cycle
## wraps, the other half a cycle later.
func _swing_starts(i: int, before: float) -> bool:
	var offset := 0.5 * float(i % 2)
	return fposmod(_gait + offset, 1.0) < fposmod(before + offset, 1.0)


## True while a leg of the other pair than leg `i` is in the air.
func _other_pair_stepping(i: int) -> bool:
	for j in 4:
		if j % 2 != i % 2 and _step_t[j] >= 0.0:
			return true
	return false


## Where leg `i`'s foot likes to stand: its stance beside the mech, but never inside a wall: a wall beside the mech makes the leg fold in and
## stand in front of it.
func _stance_x(i: int) -> float:
	return _stance_x_toward(i, mech.player.global_position.x + STANCE[i])


func _stance_x_toward(i: int, want: float) -> float:
	var p := mech.player
	var from := Vector2(p.global_position.x, p.global_position.y - 20.0)
	var query := PhysicsRayQueryParameters2D.create(from, Vector2(want, from.y), PhysicsLayers.WORLD)
	query.exclude = [p.get_rid()]
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return want
	return float(hit["position"].x) - signf(want - from.x) * 10.0


func _curl(i: int, hip: Vector2, delta: float) -> void:
	_step_t[i] = -1.0
	var tuck := hip + Vector2(ROOTS[i] * 0.55 + signf(ROOTS[i]) * 8.0, 40.0 + 10.0 * (i % 2))
	feet[i] = feet[i].lerp(tuck, 1.0 - exp(-16.0 * delta))


## The hanging stump of the snapped leg swings a little with the mech's movement.
func broken_points(hip: Vector2) -> Array[Vector2]:
	var v := mech.player.velocity
	var side := signf(ROOTS[_broken])
	var swing := sin(_t * 2.6) * 0.12 - clampf(v.x / 1400.0, -0.4, 0.4) + clampf(v.y * 0.0002, -0.2, 0.2)
	var a := PI / 2.0 - side * 0.28 + swing
	var pts: Array[Vector2] = [hip]
	for k in SNAP_LINKS + 1:
		a += 0.34 * side + sin(_t * 3.1 + k) * 0.03
		pts.append(pts[k] + Vector2.from_angle(a) * LINK_LENGTH)
	return pts


func _update_break_tip() -> void:
	var pts := broken_points(to_local(hip_world(_broken)))
	var last := pts[SNAP_LINKS + 1] - pts[SNAP_LINKS]
	break_tip = to_global(pts[SNAP_LINKS] + last * 0.62)


func _draw() -> void:
	# a muzzle flash for a moment after a shot
	if float(_flash[&"missile"]) > 0.0:
		draw_circle(to_local(_missile_muzzle.global_position), 9.0, Color(1.0, 0.8, 0.3, 0.85))
		draw_circle(to_local(_missile_muzzle.global_position), 5.0, Color(1.0, 1.0, 0.9, 0.95))
	if float(_flash[&"laser"]) > 0.0:
		draw_circle(to_local(_laser_muzzle.global_position), 11.0, Color(0.3, 0.6, 1.0, 0.7))
		draw_circle(to_local(_laser_muzzle.global_position), 5.0, Color(0.9, 0.96, 1.0, 0.95))


## Draws some of the legs (see MechVisual): two of these, one behind the body and one in front of it.
class MechLegs:
	extends Node2D

	var visual: MechVisual
	var indices: Array = []
	var shade := 1.0

	func _draw() -> void:
		for i in indices:
			if int(i) == visual._broken:
				_draw_broken(int(i))
			else:
				_draw_leg(int(i))

	func _draw_leg(i: int) -> void:
		var hip := to_local(visual.hip_world(i))
		var tip := to_local(visual.feet[i])
		# the leg ends where the claw starts. In the air the claw points on along the leg and its tip is the foot; on the floor it stands upright and open,
		# and the leg ends at its palm
		var lean: float = visual._claw_lean[i]
		var pointing := (tip - hip).normalized().lerp(Vector2.DOWN, lean).normalized()
		var foot := tip - pointing * lerpf(MechVisual.CLAW_REACH, MechVisual.CLAW_OPEN_REACH, lean)
		var points := visual.leg_points(i, hip, foot)
		var col := Color(shade, shade, shade, 1.0)
		var links := MechVisual.LEG_LINKS
		# the hip joint
		draw_set_transform(hip, 0.0, Vector2.ONE)
		draw_texture_rect(visual._tex_of("hip"), Rect2(-14, -14, 28, 28), false, col)
		var link_tex := visual._tex_of("link")
		var joint_tex := visual._tex_of("joint")
		for k in links:
			var a := points[k]
			var b := points[k + 1]
			var seg := b - a
			var thick := MechVisual.LINK_THICKNESS * (1.0 - 0.5 * float(k) / links)
			var len := seg.length() * 1.14
			draw_set_transform((a + b) / 2.0, seg.angle(), Vector2(1.0, -1.0 if seg.x < 0.0 else 1.0))
			draw_texture_rect(link_tex, Rect2(-len / 2.0, -thick / 2.0, len, thick), false, col)
			draw_set_transform(b, 0.0, Vector2.ONE)
			var jr := thick * 0.62
			draw_texture_rect(joint_tex, Rect2(-jr, -jr, jr * 2.0, jr * 2.0), false, col)
		if lean > 0.5:
			# the open claw, standing on the floor: its toe pads are at the foot
			var open_tex := visual._tex_of("claw_open")
			var size := open_tex.get_size() * MechVisual.TEX
			draw_set_transform(tip, 0.0, Vector2.ONE)
			draw_texture_rect(open_tex, Rect2(-size.x / 2.0, -size.y + MechVisual.CLAW_OPEN_PAD * MechVisual.TEX, size.x, size.y), false, col)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			return
		# the claw, pointing along the last link
		var last := points[links] - points[links - 1]
		draw_set_transform(foot - last.normalized() * 6.0, last.angle(), Vector2(1.0, -1.0 if last.x < 0.0 else 1.0))
		draw_texture_rect(visual._tex_of("claw"), Rect2(-6, -19, 46, 39), false, col)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	## The snapped leg: the links that stayed hang from the hip, the last of them torn off short (wires and a bent piston stick out of it).
	func _draw_broken(i: int) -> void:
		var hip := to_local(visual.hip_world(i))
		var pts := visual.broken_points(hip)
		var col := Color(shade, shade, shade, 1.0)
		var count := MechVisual.SNAP_LINKS
		draw_set_transform(hip, 0.0, Vector2.ONE)
		draw_texture_rect(visual._tex_of("hip"), Rect2(-14, -14, 28, 28), false, col)
		for k in count + 1:
			var a := pts[k]
			var b := pts[k + 1]
			var seg := b - a
			var thick := MechVisual.LINK_THICKNESS * (1.0 - 0.5 * float(k) / MechVisual.LEG_LINKS)
			var len := seg.length() * 1.14
			var flip := Vector2(1.0, -1.0 if seg.x < 0.0 else 1.0)
			draw_set_transform((a + b) / 2.0, seg.angle(), flip)
			if k < count:
				draw_texture_rect(visual._tex_of("link"), Rect2(-len / 2.0, -thick / 2.0, len, thick), false, col)
				draw_set_transform(b, 0.0, Vector2.ONE)
				var jr := thick * 0.62
				draw_texture_rect(visual._tex_of("joint"), Rect2(-jr, -jr, jr * 2.0, jr * 2.0), false, col)
			else:
				# the torn link: its picture is wider (room for the wires); the link's own part keeps the usual size
				var sx := len / 52.0
				draw_texture_rect(visual._tex_of("link_broken"), Rect2(-len / 2.0, -thick * 46.0 / 40.0 / 2.0, 62.0 * sx, thick * 46.0 / 40.0), false, col)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
