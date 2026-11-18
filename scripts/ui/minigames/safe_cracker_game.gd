class_name SafeCrackerGame
extends RingLockGame
## "Safe cracker": several rings inside each other, each turning (alternate rings the opposite way, each a different speed) with a
## green arc. Lock the outer ring first, then the next one in, and so on: press LOCK when the arc of the ring being aimed at is under
## the marker. A locked ring stops. A miss turns them all loose again.

# RINGS: how many rings (and so how many locks to make). Higher: longer and a more crowded dial.
const RINGS := 3

# RING_GAP: the distance in pixels between neighbouring rings' centre lines.
const RING_GAP := 32.0


func _init() -> void:
	_concentric = true
	instructions = "Lock the rings one by one, outside in."


## One ring per lock, the outer first. Inner rings are faster and smaller-arced; neighbours turn opposite ways.
func _make_rings() -> void:
	var count := int(_p("rings", RINGS))
	var base_speed: float = TAU / float(_p("turn_time", TURN_TIME))
	for i in count:
		var radius := RING_RADIUS + 10.0 - RING_GAP * float(i)
		var direction := 1.0 if i % 2 == 0 else -1.0
		var width := deg_to_rad(float(_p("arc_start", ARC_START))) * pow(0.85, i)
		_rings.append(_new_ring(radius, direction, width, base_speed * (1.0 + 0.25 * float(i))))


func _needed() -> int:
	return int(_p("rings", RINGS))


func _update_status() -> void:
	_status.text = "LOCKED  %d / %d" % [_stage, _needed()]
