class_name Mech
extends Node2D
## The first power-up vehicle: a four-legged mech with a yellow construction-crane body and tentacle legs. It is a child of the Player
## while the player is in it (Player.board_mech()): the player's own body, camera and every hazard check stay as they are, the mech
## only changes how the player moves, fights and takes damage:
##   - it is SIZE_IN_PLAYERS (1.5) times the player's size (the hit box grows), and the player sits in its cockpit
##   - it has no health bar, only the energy bar: it survives HITS_TO_DESTROY - 1 (2) hits of any kind (an enemy, a thrown thing; the amount does not
##     matter) and the third destroys it. Each shows on the mech itself (see MechVisual.set_damage()): cracks, then a broken leg and smoke, and on the
##     last it explodes and the player drops out on foot with their own health untouched. A deadly pit still kills the player, mech and all
##   - the legs climb a step of one tile (STEP_HEIGHT) without a jump or a stop; a taller step stops it. The jump is a rocket booster: hold the jump button and it lifts the mech while
##     there is energy (the blue bar); out of energy it falls under gravity. The energy fills back up in REFILL_TIME seconds
##   - the "light attack" works the laser turret for as long as the button is held, using up energy; the "heavy attack" fires a missile from the missile turret
##     (it uses MISSILE_ENERGY_COST of the energy, and nothing else holds it back); both turrets aim at the nearest enemy in front, otherwise straight ahead
## The picture is MechVisual (the art: assets/vehicles/mech/, made by tools/art/generate_mech.py and generate_mech_effects.py).

signal destroyed

# SIZE_IN_PLAYERS: how many times the player's size the mech is (the hit box; the picture is drawn to match).
const SIZE_IN_PLAYERS := 1.5

# HITS_TO_DESTROY: how many hits the mech survives, counting the one that destroys it.
const HITS_TO_DESTROY := 3

# SPEED / ACCEL: top speed and acceleration (pixels per second). The player's own are 380 and 1600.
const SPEED := 340.0
const ACCEL := 1500.0

# KICK_SPEED: the upward speed the booster gives at the moment of a jump from the ground (a tap on the button is a hop of about this).
const KICK_SPEED := -520.0

# THRUST: how hard the booster pushes while the jump button is held and there is energy (pixels per second squared, against gravity's 2000).
# RISE_SPEED: the upward speed the mech settles at while the booster burns, in pixels per second. (Close to KICK_SPEED, so a held jump
# lifts off smoothly instead of kicking and then slowing.)
const THRUST := 2400.0
const RISE_SPEED := 400.0

# BURN_TIME: seconds of boosting in a full tank of energy (the booster uses it while the button is held; 10% more than the 1.2 s it once was).
# REFILL_TIME: seconds the tank takes to fill up again from empty, progressively, whenever neither the booster nor the laser is on.
const BURN_TIME := 1.32
const REFILL_TIME := 3.0

# LASER_TIME: seconds of laser in a full tank of energy (the beam uses it for as long as the button is held; a booster burning at the same time
# uses its own share on top).
const LASER_TIME := 4.0

# STEPS. The mech walks up a step of one tile without a jump and without stopping; a taller step stops it (it needs the booster).
#   STEP_HEIGHT: the tallest step the legs climb, in pixels (one tile is 70; the body's underside is about 80 above the floor, so a step has to be lower).
#   STEP_MIN_RISE: a floor ahead that is not this much higher is not a step. STEP_LOOKAHEAD: how far in front of the body (px) a step is looked for, so
#   the body is already rising as it reaches the step. STEP_LIFT_SPEED: how fast the body rises (px/s); it slows as it nears the step's height (STEP_LIFT_EASE per
#   second of what is left, but never under STEP_LIFT_MIN), so it settles instead of stopping short. STEP_HOLD_TIME: the longest (seconds) the body
#   is held at the height of a step while it moves over it. STEP_SNAP: how far down (px) the feet follow the floor, so walking down steps is smooth too.
const STEP_HEIGHT := 76.0
const STEP_MIN_RISE := 3.0
const STEP_LOOKAHEAD := 64.0
const STEP_LIFT_SPEED := 520.0
const STEP_LIFT_MIN := 140.0
const STEP_LIFT_EASE := 14.0
const STEP_HOLD_TIME := 0.4
const STEP_SNAP := 80.0

# MISSILE_ENERGY_COST: the share of a full tank of energy one missile uses (0.6 = 60%); a missile needs that much energy left, and there is no other wait
# between two. LASER_HIT_INTERVAL: seconds between the hits of a laser beam that rests on an enemy (each takes LASER_DAMAGE).
const MISSILE_ENERGY_COST := 0.6
const LASER_HIT_INTERVAL := 0.5

# LASER_RANGE: how far the laser reaches (pixels). LASER_DAMAGE / MISSILE_DAMAGE: the hit points a laser hit / a missile blast takes off an enemy (see take_hit() of the
# enemies; a thrown object does Projectile.DAMAGE = 10, a Bro has 20). The blast reaches BLAST_RADIUS pixels.
const LASER_RANGE := 760.0
const BEAM_MARGIN := 6.0          # how far round an enemy's hit box the laser still hits, in pixels
const LASER_DAMAGE := 20
const MISSILE_DAMAGE := 80
const BLAST_RADIUS := 110.0

# AIM_RANGE: enemies farther than this are not aimed at. AIM_UP / AIM_DOWN: how far up and down (radians) a turret can turn from straight ahead.
const AIM_RANGE := 950.0
const AIM_UP := -0.85
const AIM_DOWN := 0.6

# CHASSIS_CUT: the solid body's two bottom corners are cut away: the flat underside is only as wide as the body's box, and from its ends the sides slant out
# steeply (CHASSIS_CUT.x px sideways over CHASSIS_CUT.y px up: steeper than the floor angle). So the hull can never rest on the edge of a ledge or a block with the
# feet dangling below it: such an edge meets a slanted side, which is not a floor, and the mech slides off it.
const CHASSIS_CUT := Vector2(30.0, 40.0)

# CHASSIS_SIZE: the solid body of the mech (the cab, the engine block and the hull, as drawn) as a second collision box, so it is stopped by walls and
# gates where it is drawn instead of sinking into them; the legs are not solid. BARREL_SIZE: the laser's barrel, which sticks out in front of the
# chassis (it follows the way the mech faces). Both are in pixels.
const CHASSIS_SIZE := Vector2(150.0, 104.0)
const BARREL_SIZE := Vector2(46.0, 14.0)

# ENERGY_BAR_CEILING_GAP: when a ceiling is closer than this above the mech's top, the energy bar moves down under the hull so it is not drawn inside the ceiling.
const ENERGY_BAR_CEILING_GAP := 50.0

# MUZZLE_PUFF: the size of the puff of fire at the missile turret's muzzle when it fires (see Explosion). EXPLOSION_OFFSET: where the mech's own
# explosion is, from its feet (the middle of its body).
const MUZZLE_PUFF := 0.2
const EXPLOSION_OFFSET := Vector2(0.0, -90.0)

var player: Player
var visual: MechVisual
var hits := 0
var energy := Energy.new()      # the one tank the booster and the laser use
var thrusting := false          # the booster is burning this step
var lasing := false             # the laser is on this step

var _energy_bar: HealthBar
var _chassis: CollisionShape2D
var _barrel: CollisionShape2D
var _bar_timer := 0
var _step_top := 0.0               # the height (y) of the step the body is climbing
var _step_hold := 0.0              # seconds left to hold the body at that height while it moves over the step
var _laser_hit_timer := 0.0
var _beam: LaserBeam            # the beam on screen while the laser is on
var _booster_sound: SfxLoop     # the roar of the booster while it burns
var _dead := false


## Get in: called by Player.board_mech() once the mech is a child of the player.
func setup(the_player: Player) -> void:
	name = "Mech"
	player = the_player
	player.set_body_scale(SIZE_IN_PLAYERS)
	player.floor_snap_length = STEP_SNAP        # (walking down a step keeps the feet on the floor)
	_make_shapes()
	visual = MechVisual.new()
	visual.mech = self
	add_child(visual)
	_energy_bar = HealthBar.new()
	_energy_bar.fill_color = Player.ENERGY_BAR_FILL
	_energy_bar.back_color = Player.ENERGY_BAR_BACK
	_energy_bar.position = Vector2(0, -(Player.BODY_SIZE.y * SIZE_IN_PLAYERS) - 22.0)
	add_child(_energy_bar)
	_booster_sound = SfxLoop.attach(self, Sfx.MECH_BOOSTER)


## The body's solid parts, added to the player (a collision shape must be a child of the body it belongs to).
func _make_shapes() -> void:
	_chassis = CollisionShape2D.new()
	var hull := ConvexPolygonShape2D.new()
	var half := CHASSIS_SIZE / 2.0
	hull.points = PackedVector2Array([Vector2(-half.x, -half.y), Vector2(half.x, -half.y), Vector2(half.x, half.y - CHASSIS_CUT.y), Vector2(half.x - CHASSIS_CUT.x, half.y),
			Vector2(-half.x + CHASSIS_CUT.x, half.y), Vector2(-half.x, half.y - CHASSIS_CUT.y)])
	_chassis.shape = hull
	_chassis.position = MechVisual.BODY_MIDDLE
	player.add_child(_chassis)
	_barrel = CollisionShape2D.new()
	var bar := RectangleShape2D.new()
	bar.size = BARREL_SIZE
	_barrel.shape = bar
	_barrel.position = _barrel_position()
	player.add_child(_barrel)
	# the bigger body must not start inside a wall: slide out of it if it does
	for i in 12:
		if not player.test_move(player.global_transform, Vector2.ZERO):
			break
		var side := 1.0 if i % 2 == 0 else -1.0
		player.global_position.x += side * 6.0 * float(i / 2 + 1)


func _barrel_position() -> Vector2:
	var reach := CHASSIS_SIZE.x / 2.0 + BARREL_SIZE.x / 2.0
	return Vector2(float(facing()) * reach, MechVisual.BODY_MIDDLE.y + MechVisual.LASER_MOUNT.y)


func facing() -> int:
	return player.facing()


func _jump_held() -> bool:
	if player.is_walking_to():
		return false     # (walking into a door: the controls do nothing)
	if Input.is_action_pressed(InputActions.JUMP):
		return true
	# (on a keyboard Up also jumps, but not at a ladder: the mech cannot climb, so Up there must not light the booster)
	return Input.is_action_pressed(InputActions.MOVE_UP) and not TouchControls.should_show() and not player.ladder_in_reach()


## Called by the player every physics step just before it moves: the legs climb steps and the booster and the laser use energy while their buttons are held.
func before_move(dir: float, delta: float) -> void:
	_laser_hit_timer = maxf(0.0, _laser_hit_timer - delta)
	_work_booster(delta)
	_barrel.position = _barrel_position()
	_bar_timer += 1
	if _bar_timer % 6 == 0:
		_place_energy_bar()
	_climb(dir, delta)


## The booster and the laser use the energy while their buttons are held; it refills while neither is on.
func _work_booster(delta: float) -> void:
	thrusting = _jump_held() and energy.drain(delta / BURN_TIME)
	_booster_sound.set_on(thrusting)
	if thrusting:
		# lift towards RISE_SPEED (a faster launch than that settles down to it)
		player.velocity.y = move_toward(player.velocity.y, -RISE_SPEED, THRUST * delta)
	_work_laser(delta)
	if not thrusting and not lasing:
		energy.recover(delta, 1.0 / REFILL_TIME)
	_energy_bar.set_ratio(energy.level)


## The energy bar floats above the mech; under a low ceiling it moves down beneath the hull instead of being drawn inside the ceiling.
func _place_energy_bar() -> void:
	var top := player.global_position + Vector2(0.0, -SIZE_IN_PLAYERS * Player.BODY_SIZE.y)
	var query := PhysicsRayQueryParameters2D.create(top, top + Vector2(0.0, -(ENERGY_BAR_CEILING_GAP + 24.0)), PhysicsLayers.WORLD)
	query.exclude = [player.get_rid()]
	var low_ceiling := not player.get_world_2d().direct_space_state.intersect_ray(query).is_empty()
	_energy_bar.position = Vector2(0.0, -64.0) if low_ceiling else Vector2(0.0, -(Player.BODY_SIZE.y * SIZE_IN_PLAYERS) - 22.0)


## True while the body is climbing a step (it is held at the step's height though the floor is not under it yet).
func climbing_step() -> bool:
	return _step_hold > 0.0


## Climb steps: a floor ahead that is up to STEP_HEIGHT higher is where the body rises to, smoothly, as it walks up to it, and it is held at that height
## (no gravity) until it is over the step. A taller step is not climbed: the mech stops at it.
func _climb(dir: float, delta: float) -> void:
	if dir != 0.0 and player.is_on_floor() or _step_hold > 0.0:
		var top := _step_ahead(dir if dir != 0.0 else float(facing()))
		if not is_nan(top):
			_step_top = top
			if _step_hold <= 0.0:
				visual.step_up()
			_step_hold = STEP_HOLD_TIME
	if _step_hold <= 0.0:
		return
	_step_hold -= delta
	var rise := player.global_position.y - _step_top                  # how far up the body still has to go
	if rise > 0.0:
		var lift := minf(rise, clampf(rise * STEP_LIFT_EASE, STEP_LIFT_MIN, STEP_LIFT_SPEED) * delta)
		if not player.test_move(player.global_transform, Vector2(0.0, -lift)):
			player.global_position.y -= lift
	player.velocity.y = minf(player.velocity.y, -1.0)         # (no gravity, and no snapping down to the floor, while it moves over the step: an upward speed switches the snap off)
	if rise <= 0.5 and player.is_on_floor():
		_step_hold = 0.0                                        # over the step: standing on it


## The y of the floor a step ahead, or NAN if there is none: a floor in front of the body (within STEP_LOOKAHEAD of its edge) that is higher than the
## feet by more than STEP_MIN_RISE and no more than STEP_HEIGHT, with room to rise to it. (A ray from above the tallest step down: a taller step is
## taller than the ray starts, so it is not found.)
func _step_ahead(dir: float) -> float:
	var feet := player.global_position
	var x := feet.x + signf(dir) * (Player.BODY_SIZE.x * SIZE_IN_PLAYERS * 0.5 + STEP_LOOKAHEAD)
	var hit := Mech.world_ray(player.get_world_2d(), Vector2(x, feet.y - STEP_HEIGHT), Vector2(x, feet.y + 4.0), player.get_rid(), PhysicsLayers.FLOOR)
	if hit.is_empty() or hit["normal"] == Vector2.ZERO:
		return NAN
	var top := float(hit["position"].y)
	var rise := feet.y - top
	if rise < STEP_MIN_RISE or rise > STEP_HEIGHT:
		return NAN
	if player.test_move(player.global_transform, Vector2(0.0, -rise)):      # no room above to rise
		return NAN
	return top


## The jump from the ground: the booster's first kick. Returns the upward speed to give the player.
func start_jump() -> float:
	visual.burst()
	return KICK_SPEED


## Back to full: no damage on the body, a full tank (a power-up box opened while already in the mech).
func repair() -> void:
	hits = 0
	_dead = false
	energy.fill()
	visual.clear_damage()
	_energy_bar.set_ratio(1.0)


## Take over a state carried from the previous level: `hit_count` hits already taken (their damage showing at once) and `energy_level` in the tank.
func set_state(hit_count: int, energy_level: float) -> void:
	hits = clampi(hit_count, 0, HITS_TO_DESTROY - 1)
	energy.set_level(energy_level)
	visual.set_damage(hits, true)
	_energy_bar.set_ratio(energy.level)


## A hit (any kind: the amount does not matter): the mech shows the damage, and on the last hit it is destroyed. Returns true if it was.
func take_damage(_amount: int = 1) -> bool:
	if _dead:
		return false
	hits += 1
	visual.hurt()
	if hits >= HITS_TO_DESTROY:
		_dead = true
		destroyed.emit()
		return true
	visual.set_damage(hits)
	return false


# ---------------------------------------------------------------------------------------------------------------------------
# weapons
# ---------------------------------------------------------------------------------------------------------------------------
## The missile turret fires (heavy attack).
func fire_missile() -> void:
	if _dead or not energy.spend(MISSILE_ENERGY_COST):
		return
	_energy_bar.set_ratio(energy.level)
	var from := visual.missile_muzzle()
	var dir := visual.missile_direction()
	MechMissile.launch(player.get_parent(), from, dir, self)
	Sfx.play(get_tree(), Sfx.MISSILE_LAUNCH)
	Explosion.spawn(player.get_parent(), from, MUZZLE_PUFF)    # a puff of fire and smoke at the muzzle
	visual.recoil(&"missile")


## The laser: on while the light attack button is held and there is energy. The beam is drawn every step from the muzzle to the first wall or
## enemy in its line (the mech's own body is never in the way), and an enemy it rests on is hurt every LASER_HIT_INTERVAL seconds.
func _work_laser(delta: float) -> void:
	lasing = not _dead and not player.is_walking_to() and Input.is_action_pressed(InputActions.ATTACK_LIGHT) and energy.drain(delta / LASER_TIME)
	if not lasing:
		_stop_laser()
		return
	var from := visual.laser_muzzle()
	var to := from + visual.laser_direction() * LASER_RANGE
	var wall := world_ray(player.get_world_2d(), from, to, player.get_rid())
	if not wall.is_empty():
		to = wall["position"]
	# the first enemy along the beam
	var best: Node = null
	var best_t := INF
	for e in get_tree().get_nodes_in_group(Groups.ENEMIES):
		var t := Geom.segment_entry(from, to, (e.hurtbox() as Rect2).grow(BEAM_MARGIN))
		if t >= 0.0 and t < best_t:
			best_t = t
			best = e
	if best != null:
		to = from + (to - from) * best_t
	if _beam == null or not is_instance_valid(_beam):
		_beam = LaserBeam.hold(player.get_parent(), from, to, best != null)
		visual.recoil(&"laser")
	_beam.aim(from, to, best != null)
	if best != null and _laser_hit_timer <= 0.0:
		_laser_hit_timer = LASER_HIT_INTERVAL
		best.take_hit(LASER_DAMAGE, from.x)
		visual.recoil(&"laser")


func _stop_laser() -> void:
	lasing = false
	if _beam != null and is_instance_valid(_beam):
		_beam.release()
	_beam = null


## A ray from `from` to `to` against the world (walls, floors, gates), as intersect_ray() answers it (empty if nothing is in the way), never hitting
## the body `own_body` (the player in the mech), against what is on the layers of `mask` (the world's). The laser and the missile start inside the mech's reach and must not hit the mech that fires them.
static func world_ray(world: World2D, from: Vector2, to: Vector2, own_body: RID, mask: int = PhysicsLayers.WORLD) -> Dictionary:
	var query := PhysicsRayQueryParameters2D.create(from, to, mask)
	query.exclude = [own_body]
	return world.direct_space_state.intersect_ray(query)


## The nearest living enemy in front of `from` within AIM_RANGE (its middle), or null.
func nearest_target(from: Vector2) -> Node:
	var best: Node = null
	var best_d := AIM_RANGE
	for e in get_tree().get_nodes_in_group(Groups.ENEMIES):
		var c := (e.hurtbox() as Rect2).get_center()
		var dx := (c.x - from.x) * facing()
		var d := from.distance_to(c)
		if dx > 20.0 and d < best_d:
			best_d = d
			best = e
	return best


## Blast every enemy near `at` (a missile exploding).
func blast(at: Vector2) -> void:
	for e in get_tree().get_nodes_in_group(Groups.ENEMIES):
		var r: Rect2 = e.hurtbox()
		var nearest := Vector2(clampf(at.x, r.position.x, r.end.x), clampf(at.y, r.position.y, r.end.y))
		if nearest.distance_to(at) <= BLAST_RADIUS:
			e.take_hit(MISSILE_DAMAGE, at.x)


## The mech blows up (the last hit) or the player leaves it: the player is back on foot. `explode` makes the blast, and the parts fly.
func release(explode: bool) -> void:
	_stop_laser()
	_booster_sound.set_on(false)
	if explode:
		visual.shatter()
		Explosion.spawn(player.get_parent(), player.global_position + EXPLOSION_OFFSET)
	player.set_body_scale(1.0)
	player.floor_snap_length = Player.FLOOR_SNAP
	_chassis.queue_free()
	_barrel.queue_free()
	queue_free()
