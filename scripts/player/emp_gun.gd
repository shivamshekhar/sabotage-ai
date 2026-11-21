class_name EmpGun
extends RefCounted
## The player's EMP gun (the heavy attack on foot; in the mech the heavy attack is the missile): while the button is held it keeps firing a stream of electricity straight ahead
## from the gun's muzzle, and it uses the energy bar up very fast. The stream reaches RANGE pixels, stops at a wall, and hurts the first enemy it rests on for DAMAGE hit points
## every HIT_INTERVAL seconds. The player owns one and calls work() every physics step.
##
##   var _emp := EmpGun.new()
##   firing = _emp.work(self, button_held, delta)

# TIME: seconds of firing a full energy bar lasts (the gun uses the bar for as long as the button is held; compare the mech's laser, 4 s). Lower: it runs dry sooner.
const TIME := 1.5

# HIT_INTERVAL: seconds between the hits of a stream that rests on an enemy (the first hit is at once). It counts on while the gun is off, so tapping the button cannot
# hit more often. Higher: slower damage.
const HIT_INTERVAL := 0.6

# DAMAGE: the hit points a hit takes off an enemy (a thrown object does Projectile.DAMAGE = 10, the mech's laser 20, a missile 80).
const DAMAGE := 40

# RANGE: how far the stream reaches, in pixels. A wall in the way shortens it. Higher: it hits enemies further off.
const RANGE := 560.0

# HIT_MARGIN: how far round an enemy's hit box the stream still hits, in pixels (the stream is a thin line; this makes it forgiving).
const HIT_MARGIN := 8.0

# POSE_TIME: seconds the gun stays in the player's hand and the arm stays out after the last moment of firing.
const POSE_TIME := 0.25

var _beam: ElectricArc          # the stream on screen while the gun fires
var _hit_wait := 0.0            # seconds until the next hit may land


## One physics step of `delta` seconds: if `wanted` (the button is held and nothing stops it) and the energy lasts, the gun fires, otherwise it is off. Returns whether it fired.
func work(shooter: Player, wanted: bool, delta: float) -> bool:
	_hit_wait = maxf(0.0, _hit_wait - delta)
	if not wanted or not shooter.energy.drain(delta / TIME):
		_stop()
		return false
	var visuals := shooter.visuals()
	visuals.set_gun(true, shooter.facing())
	var muzzle := visuals.gun_muzzle()
	var end := muzzle + Vector2(float(shooter.facing()) * RANGE, 0.0)
	var wall := Mech.world_ray(shooter.get_world_2d(), muzzle, end, shooter.get_rid())
	if not wall.is_empty():
		end = wall["position"]
	var target: Node = null
	var nearest := INF
	for enemy in shooter.get_tree().get_nodes_in_group(Groups.ENEMIES):
		var box: Rect2 = enemy.hurtbox()
		if box.size == Vector2.ZERO:
			continue      # (a boss that cannot be hurt right now)
		var entry := Geom.segment_entry(muzzle, end, box.grow(HIT_MARGIN))
		if entry >= 0.0 and entry < nearest:
			nearest = entry
			target = enemy
	if target != null:
		end = muzzle + (end - muzzle) * nearest
		if _hit_wait <= 0.0:
			_hit_wait = HIT_INTERVAL
			target.take_hit(DAMAGE, muzzle.x)
	if _beam == null or not is_instance_valid(_beam):
		_beam = ElectricArc.hold(shooter.get_parent(), muzzle, end, target != null)
	_beam.aim(muzzle, end, target != null)
	return true


## True while the stream is on screen and held.
func is_firing() -> bool:
	return _beam != null and is_instance_valid(_beam)


func _stop() -> void:
	if _beam != null and is_instance_valid(_beam):
		_beam.release()
	_beam = null
