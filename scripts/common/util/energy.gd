class_name Energy
extends RefCounted
## A tank of energy that is spent and refills on its own, shown as a blue bar (the player's throws, the mech's booster and laser). The level is
## 0 (empty) to 1 (full). Spending is exact; refilling is continuous: a little every physics step, never in jumps once a second.
##
##   var energy := Energy.new()
##   if energy.spend(0.05): throw()           # one throw costs 5%
##   energy.recover(delta, 0.04)              # 4% of the tank per second
##   energy.drain(delta / 1.32)               # a continuous use (the booster): false once the tank is empty

# RESTART_LEVEL: after the tank has run completely dry it only counts as usable again once it has refilled this far (a share of a full tank), so
# a continuous use (the booster, the laser) cannot stutter on the last drops. Higher: a longer wait after running dry.
const RESTART_LEVEL := 0.2

var level := 1.0
var _dry := false       # ran empty and has not refilled to RESTART_LEVEL yet


## True if `cost` can be paid right now.
func can_afford(cost: float) -> bool:
	return level >= cost - 0.0001


## Pay `cost` if possible (all or nothing). Returns whether it was paid.
func spend(cost: float) -> bool:
	if not can_afford(cost):
		return false
	level = maxf(0.0, level - cost)
	return true


## Use `amount` of the tank continuously (a step of a booster or a beam). Returns false, and uses nothing, while the tank is dry; running empty
## makes it dry until it has refilled to RESTART_LEVEL.
func drain(amount: float) -> bool:
	if is_dry():
		return false
	level = maxf(0.0, level - amount)
	if level <= 0.0:
		_dry = true
	return true


## Refill `rate` of the whole tank per second for this step of `delta` seconds (never above full).
func recover(delta: float, rate: float) -> void:
	level = minf(1.0, level + rate * delta)
	if _dry and level >= RESTART_LEVEL:
		_dry = false


## True while the tank is empty or has not yet refilled enough to be used again.
func is_dry() -> bool:
	return _dry or level <= 0.0


## Set the level (a carried-over tank, a repair): clamped to 0..1.
func set_level(value: float) -> void:
	level = clampf(value, 0.0, 1.0)
	_dry = level <= 0.0


func fill() -> void:
	set_level(1.0)
