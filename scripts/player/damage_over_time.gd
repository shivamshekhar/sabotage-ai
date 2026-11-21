class_name DamageOverTime
extends RefCounted
## A hurt that keeps coming: for a number of ticks, TICK_TIME seconds apart, it deals a fixed amount. The player's poison, burning, bleeding and
## radiation sickness are one of these each (the player decides what a tick does to its health and how it looks). Applying it again restarts the
## count. The amount may be a fraction of a point (0.75 per tick): the part that does not make a whole point is kept and paid later, so the
## rate is exact over time.
##
##   var poison := DamageOverTime.new()
##   poison.apply(8, 4.0)                  # 8 ticks of 4 points
##   var hurt := poison.step(delta)        # every frame: the whole points to take off now (0 when no tick is due)

# TICK_TIME: seconds between two ticks.
const TICK_TIME := 0.7

var _ticks := 0      # how many more times it hurts
var _amount := 0.0   # health lost per tick (may be a fraction)
var _carry := 0.0    # the fraction of a point owed but not yet paid
var _timer := 0.0    # seconds until the next tick


## Start (or restart) it: `ticks` more hurts of `amount` points each (a positive number), the first one TICK_TIME from now. A longer one replaces a
## shorter one that is still running.
func apply(ticks: int, amount: float) -> void:
	_ticks = maxi(_ticks, ticks)
	_amount = maxf(0.01, amount)
	_carry = 0.0
	_timer = TICK_TIME


## True while it still has ticks to come.
func active() -> bool:
	return _ticks > 0


## Move time on by `delta`; returns the whole points to take off if a tick is due now, else 0.
func step(delta: float) -> int:
	if _ticks <= 0:
		return 0
	_timer -= delta
	if _timer > 0.0:
		return 0
	_timer = TICK_TIME
	_ticks -= 1
	_carry += _amount
	var whole := int(floor(_carry + 0.0001))
	_carry -= float(whole)
	return whole


func clear() -> void:
	_ticks = 0
	_carry = 0.0
