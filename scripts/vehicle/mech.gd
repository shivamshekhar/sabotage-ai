class_name Mech
extends Node2D
## The first power-up vehicle: a four-legged mech with a yellow construction-crane body and tentacle legs. It is a child of the Player
## while the player is in it (Player.board_mech()): the player's own body, camera and every hazard check stay as they are, the mech
## only changes how the player moves, fights and takes damage:
##   - it is SIZE_IN_PLAYERS (1.5) times the player's size (the hit box grows), and the player sits in its cockpit
##   - it has no health bar: it survives HITS_TO_DESTROY (5) hits of any kind (an enemy, spikes, a thrown thing; the amount does not
##     matter), each one showing on the mech itself (see MechVisual.set_damage()): cracks, a broken leg, smoke, fire, and on the last
##     it explodes and the player drops out on foot with their own health untouched. A deadly pit still kills the player, mech and all
##   - the legs climb steps (STEP_HEIGHT) without a jump. The jump is a rocket booster: hold the jump button and it lifts the mech while
##     there is fuel (the blue bar); out of fuel it falls under gravity. The fuel fills back up in REFILL_TIME seconds
##   - "light attack" (Q) fires a missile from the missile turret, "heavy attack" (S) a laser from the laser turret; both turrets aim at
##     the nearest enemy in front, otherwise straight ahead
## The picture is MechVisual (the art: assets/powerups/mech/, made by tools/art/generate_mech.py and generate_mech_effects.py).

signal destroyed

# SIZE_IN_PLAYERS: how many times the player's size the mech is (the hit box; the picture is drawn to match).
const SIZE_IN_PLAYERS := 1.5

# HITS_TO_DESTROY: how many hits the mech survives, counting the one that destroys it.
const HITS_TO_DESTROY := 5

# SPEED / ACCEL: top speed and acceleration (pixels per second). The player's own are 380 and 1600.
const SPEED := 340.0
const ACCEL := 1500.0

# KICK_SPEED: the upward speed the booster gives at the moment of a jump from the ground (a tap on the button is a hop of about this).
const KICK_SPEED := -700.0

# THRUST: how hard the booster pushes while the jump button is held and there is fuel (pixels per second squared, against gravity's 2000).
# RISE_SPEED: the upward speed the mech settles at while the booster burns, in pixels per second.
const THRUST := 3200.0
const RISE_SPEED := 340.0

# BURN_TIME: seconds of fuel in a full tank (the booster burns it while the button is held). REFILL_TIME: seconds the tank takes to fill
# up again from empty, progressively, whenever the booster is off. RESTART_FUEL: after the tank has run dry the booster only lights again
# when it has filled this far (a share of a full tank), so it cannot stutter on the last drops.
const BURN_TIME := 1.2
const REFILL_TIME := 3.0
const RESTART_FUEL := 0.2

# STEP_HEIGHT: the tallest step the legs climb without a jump, in pixels (one tile is 70). STEP_LIFT_SPEED: how fast the body rises over it.
const STEP_HEIGHT := 84.0
const STEP_LIFT_SPEED := 560.0

# MISSILE_COOLDOWN / LASER_COOLDOWN: seconds between shots.
const MISSILE_COOLDOWN := 0.9
const LASER_COOLDOWN := 0.5

# LASER_RANGE: how far the laser reaches (pixels). LASER_FRACTION / MISSILE_FRACTION: the share of an enemy's health a laser hit /
# a missile blast takes (see take_hit() of the enemies; a thrown object takes 0.5). The blast reaches BLAST_RADIUS pixels.
const LASER_RANGE := 760.0
const LASER_FRACTION := 0.34
const MISSILE_FRACTION := 1.0
const BLAST_RADIUS := 110.0

# AIM_RANGE: enemies farther than this are not aimed at. AIM_UP / AIM_DOWN: how far up and down (radians) a turret can turn from straight ahead.
const AIM_RANGE := 950.0
const AIM_UP := -0.85
const AIM_DOWN := 0.6

# FUEL_COLOR / FUEL_BACK: the colours of the fuel bar (blue on dark blue).
const FUEL_COLOR := Color("#3aa0ff")
const FUEL_BACK := Color("#14223c")

var player: Player
var visual: MechVisual
var hits := 0
var fuel := 1.0                 # 0 = empty, 1 = full
var thrusting := false          # the booster is burning this step

var _fuel_bar: HealthBar
var _step_lift := 0.0
var _missile_timer := 0.0
var _laser_timer := 0.0
var _dead := false
var _dry := false               # the tank ran empty and has not refilled enough to restart


## Get in: called by Player.board_mech() once the mech is a child of the player.
func setup(the_player: Player) -> void:
	name = "Mech"
	player = the_player
	player.set_body_scale(SIZE_IN_PLAYERS)
	visual = MechVisual.new()
	visual.mech = self
	add_child(visual)
	_fuel_bar = HealthBar.new()
	_fuel_bar.fill_color = FUEL_COLOR
	_fuel_bar.back_color = FUEL_BACK
	_fuel_bar.position = Vector2(0, -(Player.BODY_SIZE.y * SIZE_IN_PLAYERS) - 22.0)
	_fuel_bar.set_title("FUEL")
	add_child(_fuel_bar)


func facing() -> int:
	return player.facing()


func _jump_held() -> bool:
	return Input.is_action_pressed("jump") or (Input.is_action_pressed("move_up") and not TouchControls.should_show())


## Called by the player every physics step just before it moves: the legs climb steps and the booster burns fuel while the button is held.
func before_move(dir: float, delta: float) -> void:
	_missile_timer = maxf(0.0, _missile_timer - delta)
	_laser_timer = maxf(0.0, _laser_timer - delta)
	_work_booster(delta)
	if _step_lift > 0.0:
		var lift := minf(_step_lift, STEP_LIFT_SPEED * delta)
		if not player.test_move(player.global_transform, Vector2(0.0, -lift)):
			player.global_position.y -= lift
		_step_lift -= lift
		player.velocity.y = minf(player.velocity.y, 0.0) if _step_lift > 0.0 else player.velocity.y
	elif dir != 0.0 and player.is_on_floor():
		_try_step(dir)


func _work_booster(delta: float) -> void:
	if _dry and fuel >= RESTART_FUEL:
		_dry = false
	thrusting = _jump_held() and fuel > 0.0 and not _dry
	if thrusting:
		# lift towards RISE_SPEED (a faster launch than that settles down to it), burning fuel
		player.velocity.y = move_toward(player.velocity.y, -RISE_SPEED, THRUST * delta)
		fuel = maxf(0.0, fuel - delta / BURN_TIME)
		if fuel <= 0.0:
			_dry = true
	else:
		fuel = minf(1.0, fuel + delta / REFILL_TIME)
	_fuel_bar.set_ratio(fuel)


## A wall ahead that is low enough to step over: find how high it is and start rising over it.
func _try_step(dir: float) -> void:
	var ahead := Vector2(signf(dir) * 6.0, 0.0)
	if not player.test_move(player.global_transform, ahead):
		return
	var h := 10.0
	while h <= STEP_HEIGHT:
		var raised := player.global_transform.translated(Vector2(0.0, -h))
		if not player.test_move(raised, ahead):
			if not player.test_move(player.global_transform, Vector2(0.0, -h)):   # room above to rise
				_step_lift = h + 2.0
				visual.step_up()
			return
		h += 7.0


## The jump from the ground: the booster's first kick. Returns the upward speed to give the player.
func start_jump() -> float:
	visual.burst()
	return KICK_SPEED


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
## The missile turret fires (light attack).
func fire_missile() -> void:
	if _missile_timer > 0.0 or _dead:
		return
	_missile_timer = MISSILE_COOLDOWN
	var from := visual.missile_muzzle()
	var dir := visual.missile_direction()
	MechMissile.launch(player.get_parent(), from, dir, self)
	MechBeam.explosion(player.get_parent(), from, 0.2)    # a puff of fire and smoke at the muzzle
	visual.recoil(&"missile")


## The laser turret fires (heavy attack): an instant beam to the first wall or enemy in its line.
func fire_laser() -> void:
	if _laser_timer > 0.0 or _dead:
		return
	_laser_timer = LASER_COOLDOWN
	var from := visual.laser_muzzle()
	var dir := visual.laser_direction()
	var to := from + dir * LASER_RANGE
	var space := player.get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(from, to, Player.LAYER_WORLD)
	query.exclude.append(player.get_rid())
	var wall := space.intersect_ray(query)
	if not wall.is_empty():
		to = wall["position"]
	# the first enemy along the beam
	var best: Node = null
	var best_t := INF
	for e in get_tree().get_nodes_in_group("enemies"):
		var t := _beam_hits(from, to, (e.hurtbox() as Rect2).grow(6.0))
		if t >= 0.0 and t < best_t:
			best_t = t
			best = e
	if best != null:
		to = from + (to - from) * best_t
		best.take_hit(LASER_FRACTION, from.x)
	MechBeam.show_beam(player.get_parent(), from, to, best != null)
	visual.recoil(&"laser")


## Where along the segment a-b (0 to 1) it first enters the rectangle, or -1.
func _beam_hits(a: Vector2, b: Vector2, r: Rect2) -> float:
	var t0 := 0.0
	var t1 := 1.0
	var d := b - a
	for axis in 2:
		if absf(d[axis]) < 0.00001:
			if a[axis] < r.position[axis] or a[axis] > r.end[axis]:
				return -1.0
		else:
			var ta: float = (r.position[axis] - a[axis]) / d[axis]
			var tb: float = (r.end[axis] - a[axis]) / d[axis]
			t0 = maxf(t0, minf(ta, tb))
			t1 = minf(t1, maxf(ta, tb))
			if t0 > t1:
				return -1.0
	return t0


## The nearest living enemy in front of `from` within AIM_RANGE (its middle), or null.
func nearest_target(from: Vector2) -> Node:
	var best: Node = null
	var best_d := AIM_RANGE
	for e in get_tree().get_nodes_in_group("enemies"):
		var c := (e.hurtbox() as Rect2).get_center()
		var dx := (c.x - from.x) * facing()
		var d := from.distance_to(c)
		if dx > 20.0 and d < best_d:
			best_d = d
			best = e
	return best


## Blast every enemy near `at` (a missile exploding).
func blast(at: Vector2) -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		var r: Rect2 = e.hurtbox()
		var nearest := Vector2(clampf(at.x, r.position.x, r.end.x), clampf(at.y, r.position.y, r.end.y))
		if nearest.distance_to(at) <= BLAST_RADIUS:
			e.take_hit(MISSILE_FRACTION, at.x)


## The mech blows up (the last hit) or the player leaves it: the player is back on foot. `explode` makes the blast, and the parts fly.
func release(explode: bool) -> void:
	if explode:
		visual.shatter()
		MechBeam.explosion(player.get_parent(), player.global_position + Vector2(0.0, -90.0))
	player.set_body_scale(1.0)
	queue_free()
