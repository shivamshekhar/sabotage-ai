class_name MechVisual
extends Node2D
## What the mech looks like and how it moves: the crane body with the player sitting in the cockpit, the two turrets, the booster flame,
## four tentacle legs and the damage it shows. The art is assets/powerups/mech/ (tools/art/generate_mech.py and generate_mech_effects.py;
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
## its end falls off and the stump hangs, sparking), 3 smoke from the exhaust and the engine, 4 fire on the engine and the roof with soot
## over the body. The 5th hit destroys it (shatter()).

const DIR := "res://assets/powerups/mech/"

# TEX: the pictures are drawn at this scale (they are made at twice their size on screen).
const TEX := 0.5

# BELLY: the height in pixels of the underside of the hull above the ground when standing. The whole mech is about 1.5 player heights.
const BELLY := 86.0

# BODY_MIDDLE: the middle of the body picture relative to the feet (the hull's underside, 99 px below the middle, is at BELLY).
const BODY_MIDDLE := Vector2(0.0, -BELLY - 99.0 + 53.5)

# ROOTS: where each of the four hips is (pixels right of the middle), STANCE: where each foot likes to stand. NEAR: the legs drawn in front
# of the body; the others are behind it, darker.
const ROOTS := [-54.0, -24.0, 22.0, 52.0]
const STANCE := [-122.0, -66.0, 60.0, 118.0]
const NEAR := [true, false, false, true]

# MISSILE_MOUNT / LASER_MOUNT: where each turret's pivot is, in pixels from the middle of the body picture (a body picture pixel is half of
# one of these). The missile turret's base stands on the pedestal on the cab roof (body picture (146..206, 38..50)); the laser turret's
# base rests on the hull ledge at the front of the cab.
const MISSILE_MOUNT := Vector2(12.0, -50.5)
const LASER_MOUNT := Vector2(55.0, 7.5)

# FAR_SHADE: how dark the legs behind the body are.
const FAR_SHADE := 0.6

# LEG_LINKS: links per leg. LINK_THICKNESS: the thickest link in pixels (they taper to half towards the foot).
const LEG_LINKS := 6
const LINK_THICKNESS := 21.0

# STEP_TRIGGER: how far (px) a foot may be from its stance before it steps. STEP_TIME: how long a step takes. STEP_LIFT: how high the foot
# swings. LEAD: how far ahead of the body (as a fraction of the speed) a foot is put down. MAX_REACH: the farthest a foot can be from its hip.
const STEP_TRIGGER := 44.0
const STEP_TIME := 0.2
const STEP_LIFT := 32.0
const LEAD := 0.2
const MAX_REACH := 150.0

# BROKEN_LEG: the leg that snaps on the 2nd hit (the near front leg). SNAP_LINKS: how many links stay on it, the last one torn. LINK_LENGTH: how
# long each hanging link is, in pixels.
const BROKEN_LEG := 3
const SNAP_LINKS := 3
const LINK_LENGTH := 20.0

# The damage effects' places, in pixels from the middle of the body picture (the engine block's top is at y = -22.5, the cab roof at y = -30.5,
# the exhaust stack's top at (-53.5, -51)).
const SMOKE_SPOTS := [Vector2(-53.5, -51.0), Vector2(-38.0, -22.5)]
const FIRE_SPOTS := [Vector2(-44.0, -21.0), Vector2(-24.0, -21.0), Vector2(6.0, -29.5)]

var mech: Mech
var feet: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]   # the feet in the world
var damage := 0                      # the hits taken so far (0-4 while it is alive)
var hovering := false                # standing without all legs on the floor: the booster burns low
var break_tip := Vector2.ZERO        # where the snapped leg ends, in the world (while a leg is broken)

var _t := 0.0
var _walk := 0.0
var _body: Node2D
var _pilot: Sprite2D
var _cracks: Sprite2D
var _glass_cracks: Sprite2D
var _soot: Sprite2D
var _missile_turret: Node2D
var _laser_turret: Node2D
var _missile_muzzle: Node2D
var _laser_muzzle: Node2D
var _flame: Sprite2D
var _legs_far: MechLegs
var _legs_near: MechLegs
var _fires: Array[Sprite2D] = []
var _smoke: Array[CPUParticles2D] = []
var _sparks: CPUParticles2D
var _step_from: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
var _step_to: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
var _step_t: Array[float] = [-1.0, -1.0, -1.0, -1.0]
var _broken := -1
var _airborne := false
var _dip := 0.0
var _burst := 0.0
var _hurt := 0.0
var _spark_timer := 0.0
var _recoil := {&"missile": 0.0, &"laser": 0.0}
var _aim := {&"missile": 0.0, &"laser": 0.0}
var _flash := {&"missile": 0.0, &"laser": 0.0}
var _tex := {}


func _tex_of(name: String) -> Texture2D:
	if not _tex.has(name):
		_tex[name] = load(DIR + name + ".png")
	return _tex[name]


func _sprite(name: String, z: int, centered := true) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = _tex_of(name)
	s.centered = centered
	s.scale = Vector2(TEX, TEX)
	s.z_index = z
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return s


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
	var ps := 58.0 / float(_pilot.texture.get_height())
	_pilot.scale = Vector2(ps, ps)
	_pilot.position = Vector2(33.0, 3.5)
	_pilot.z_index = -1
	_body.add_child(_pilot)
	_body.add_child(_sprite("body", 0))
	_cracks = _sprite("body_cracks", 0)
	_cracks.visible = false
	_body.add_child(_cracks)
	_soot = _sprite("body_burn", 0)
	_soot.visible = false
	_body.add_child(_soot)
	_body.add_child(_sprite("canopy", 1))
	_glass_cracks = _sprite("canopy_cracks", 1)
	_glass_cracks.visible = false
	_body.add_child(_glass_cracks)
	var mt := _turret("missile_turret", Vector2(40, 50), MISSILE_MOUNT, Vector2(160, 44))
	_missile_turret = mt[0]
	_missile_muzzle = mt[1]
	var lt := _turret("laser_turret", Vector2(34, 38), LASER_MOUNT, Vector2(150, 38))
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
	# fire: three flames standing on the engine block and the cab roof (their bases are on the spots), animated in _animate_damage()
	for spot in FIRE_SPOTS:
		var f := Sprite2D.new()
		f.texture = _tex_of("fire_1")
		f.centered = false
		f.offset = Vector2(-40.0, -124.0 + 6.0)      # the base of the flame picture on the spot
		f.position = spot
		f.scale = Vector2(TEX, TEX) * 0.9
		f.z_index = 1
		f.visible = false
		f.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		_body.add_child(f)
		_fires.append(f)
	# smoke from the exhaust stack and from the engine
	for i in SMOKE_SPOTS.size():
		var p := CPUParticles2D.new()
		p.texture = _tex_of("smoke_%d" % (i + 1))
		p.position = SMOKE_SPOTS[i]
		p.local_coords = false
		p.emitting = false
		p.amount = 12
		p.lifetime = 1.6
		p.direction = Vector2(0.0, -1.0)
		p.spread = 20.0
		p.initial_velocity_min = 22.0
		p.initial_velocity_max = 46.0
		p.gravity = Vector2(0.0, -10.0)
		p.angle_min = -180.0
		p.angle_max = 180.0
		p.scale_amount_min = 0.22
		p.scale_amount_max = 0.36
		var grow := Curve.new()
		grow.add_point(Vector2(0.0, 0.45))
		grow.add_point(Vector2(1.0, 1.8))
		p.scale_amount_curve = grow
		var ramp := Gradient.new()
		ramp.offsets = PackedFloat32Array([0.0, 0.2, 1.0])
		ramp.colors = PackedColorArray([Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.8), Color(0.6, 0.6, 0.64, 0.0)])
		p.color_ramp = ramp
		p.z_index = 4
		_body.add_child(p)
		_smoke.append(p)
	# the sparks of the snapped leg (in the world, so they fall away from it)
	_sparks = CPUParticles2D.new()
	_sparks.texture = _tex_of("spark")
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_sparks.material = add
	_sparks.local_coords = false
	_sparks.emitting = false
	_sparks.one_shot = true
	_sparks.explosiveness = 0.9
	_sparks.amount = 7
	_sparks.lifetime = 0.45
	_sparks.direction = Vector2(0.0, 1.0)
	_sparks.spread = 70.0
	_sparks.initial_velocity_min = 40.0
	_sparks.initial_velocity_max = 150.0
	_sparks.gravity = Vector2(0.0, 700.0)
	_sparks.scale_amount_min = 0.18
	_sparks.scale_amount_max = 0.36
	_sparks.z_index = 4
	add_child(_sparks)


# ---------------------------------------------------------------------------------------------------------------------------
# damage
# ---------------------------------------------------------------------------------------------------------------------------
## Show the damage of `level` hits (1 to 4).
func set_damage(level: int) -> void:
	damage = level
	_cracks.visible = level >= 1
	_glass_cracks.visible = level >= 1
	if level >= 2 and _broken < 0:
		_snap_leg(BROKEN_LEG)
	var smoking := level >= 3
	for p in _smoke:
		p.emitting = smoking
		p.color = Color(0.55, 0.5, 0.5) if level >= 4 else Color.WHITE
		p.amount = 20 if level >= 4 else 12
	_soot.visible = level >= 4
	for f in _fires:
		f.visible = level >= 4


func hurt() -> void:
	_hurt = 0.25


## The curve of leg `i` as points in this node's space, from the hip to the foot: a smooth arch (a quadratic curve), cut into LEG_LINKS pieces.
func leg_points(i: int, hip: Vector2, foot: Vector2) -> Array[Vector2]:
	var d := foot - hip
	var dist := d.length()
	var n := Vector2(-d.y, d.x).normalized() if dist > 0.01 else Vector2.UP
	if n.y > 0.0:
		n = -n                                  # the leg arches upwards, like an elbow
	var curl := clampf(dist * 0.5, 20.0, 70.0)
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
		MechDebris.spawn(parent, _tex_of("link"), (a + b) / 2.0, seg.angle(), sc, Vector2(side * randf_range(40.0, 140.0), randf_range(-260.0, -120.0)), randf_range(-6.0, 6.0))
	var last := to_global(pts[LEG_LINKS]) - to_global(pts[LEG_LINKS - 1])
	MechDebris.spawn(parent, _tex_of("claw"), feet[i], last.angle(), Vector2(0.5, 0.5), Vector2(side * randf_range(60.0, 160.0), randf_range(-220.0, -100.0)), randf_range(-7.0, 7.0))
	_spark_timer = 0.0
	_sparks.global_position = to_global(pts[SNAP_LINKS])
	_sparks.amount = 14
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
			MechDebris.spawn(parent, _tex_of("link"), (a + b) / 2.0, seg.angle(), Vector2(seg.length() * 1.14 / 52.0, thick / 40.0), away * randf_range(120.0, 320.0) + Vector2(0.0, -260.0), randf_range(-9.0, 9.0))
		MechDebris.spawn(parent, _tex_of("claw"), feet[i], randf() * TAU, Vector2(0.5, 0.5), Vector2(randf_range(-260.0, 260.0), randf_range(-420.0, -200.0)), randf_range(-8.0, 8.0))
	for turret in [_missile_turret, _laser_turret]:
		var sp := (turret as Node2D).get_child(0) as Sprite2D
		MechDebris.spawn(parent, sp.texture, (turret as Node2D).global_position, (turret as Node2D).global_rotation, Vector2(0.5, 0.5), Vector2(randf_range(-240.0, 240.0), randf_range(-520.0, -300.0)), randf_range(-6.0, 6.0))
	# chunks of the body picture: the engine block, the cab and the hull (parts of the picture cut out, so they look like pieces of the mech)
	var body_tex := _tex_of("body")
	for region in [Rect2(10, 56, 122, 90), Rect2(112, 40, 188, 110), Rect2(14, 146, 280, 56), Rect2(30, 2, 30, 70)]:
		var at := AtlasTexture.new()
		at.atlas = body_tex
		at.region = region
		var middle: Vector2 = (region.position + region.size / 2.0 - Vector2(150.0, 107.0)) * TEX
		var world_at := _body.to_global(middle)
		MechDebris.spawn(parent, at, world_at, 0.0, Vector2(0.5, 0.5) * Vector2(float(_body.scale.x), 1.0), (world_at - centre).normalized() * randf_range(140.0, 300.0) + Vector2(0.0, -300.0), randf_range(-4.0, 4.0))


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
	return _dip - sin(_walk * 2.0) * 2.0 * clampf(absf(mech.player.velocity.x) / 300.0, 0.0, 1.0)


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
	var query := PhysicsRayQueryParameters2D.create(Vector2(x, p.global_position.y - 130.0), Vector2(x, p.global_position.y + 120.0), Player.LAYER_WORLD | Player.LAYER_LADDER_DECK)
	query.exclude.append(p.get_rid())
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
	var grounded := p.is_on_floor()
	var speed := absf(p.velocity.x)
	_walk += speed * delta * 0.03
	_dip = move_toward(_dip, 0.0, 40.0 * delta)
	if grounded and _airborne:
		_dip = 9.0       # landing: the body dips on its legs
	_airborne = not grounded
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


## The booster's flame: full while it lifts the mech (the jump button held with fuel), a short kick at the start of a jump, and a low
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
	for i in _fires.size():
		var f := _fires[i]
		if f.visible:
			f.texture = _tex_of("fire_%d" % ((int(_t * 11.0) + i) % 4 + 1))
			f.scale = Vector2(TEX, TEX) * (0.82 + 0.12 * sin(_t * 9.0 + i * 2.0))
	if _broken >= 0:
		_spark_timer -= delta
		if _spark_timer <= 0.0:
			_spark_timer = randf_range(0.5, 1.1)
			_sparks.global_position = break_tip
			_sparks.amount = 6
			_sparks.restart()
			_sparks.emitting = true


func _step_legs(delta: float, grounded: bool) -> void:
	var p := mech.player
	var lacking := 0
	for i in 4:
		if i == _broken:
			continue
		var hip := hip_world(i)
		if not grounded:
			# curled up under the belly
			_curl(i, hip, delta)
			continue
		if _step_t[i] >= 0.0:
			_step_t[i] += delta / STEP_TIME
			var t := clampf(_step_t[i], 0.0, 1.0)
			var e := t * t * (3.0 - 2.0 * t)
			var lift := STEP_LIFT + maxf(0.0, _step_from[i].y - _step_to[i].y)
			feet[i] = _step_from[i].lerp(_step_to[i], e) + Vector2(0.0, -lift * sin(PI * t))
			if _step_t[i] >= 1.0:
				_step_t[i] = -1.0
				feet[i] = _step_to[i]
			continue
		var stance_x: float = p.global_position.x + STANCE[i]
		var to_x := stance_x + clampf(p.velocity.x * LEAD, -60.0, 60.0)
		var floor_y := _ground_y(to_x)
		if is_nan(floor_y):
			# no floor under this foot's stance (a narrow ledge, an edge): it cannot stand, it curls up
			lacking += 1
			_curl(i, hip, delta)
			continue
		var too_far := absf(feet[i].x - stance_x) > STEP_TRIGGER or feet[i].distance_to(hip) > MAX_REACH or feet[i].y < p.global_position.y - 130.0
		if not too_far:
			continue
		# the legs of one group do not step together
		var group_busy := false
		for j in 4:
			if j != i and j % 2 == i % 2 and _step_t[j] >= 0.0:
				group_busy = true
		if group_busy and feet[i].distance_to(hip) < MAX_REACH:
			continue
		_step_from[i] = feet[i]
		_step_to[i] = Vector2(to_x, floor_y)
		_step_t[i] = 0.0
	hovering = grounded and lacking > 0
	if _broken >= 0:
		_update_break_tip()


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
		var foot := to_local(visual.feet[i])
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
