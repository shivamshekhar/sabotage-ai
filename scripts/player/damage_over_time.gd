class_name DamageOverTime
extends RefCounted
## A hurt that keeps coming: for a number of ticks, TICK_TIME seconds apart, it deals a fixed amount. The player's poison and burning are one of these each
## (the player decides what a tick does to its health and how it looks). Applying it again restarts the count; the strongest hit wins.
##
##   var poison := DamageOverTime.new()
##   poison.apply(8, 4)                    # 8 ticks of 4 points
##   var hurt := poison.step(delta)        # every frame: the amount to take off now (0 when no tick is due)

# TICK_TIME: seconds between two ticks.
const TICK_TIME := 0.7

var _ticks := 0      # how many more times it hurts
var _amount := 0     # health lost per tick
var _timer := 0.0    # seconds until the next tick


## Start (or restart) it: `ticks` more hurts of `amount` points each (at least 1), the first one TICK_TIME from now. A longer or stronger one replaces
## a shorter or weaker one that is still running.
func apply(ticks: int, amount: int) -> void:
	_ticks = maxi(_ticks, ticks)
	_amount = maxi(1, amount)
	_timer = TICK_TIME


## True while it still has ticks to come.
func active() -> bool:
	return _ticks > 0


## Move time on by `delta`; returns the points to take off if a tick is due now, else 0.
func step(delta: float) -> int:
	if _ticks <= 0:
		return 0
	_timer -= delta
	if _timer > 0.0:
		return 0
	_timer = TICK_TIME
	_ticks -= 1
	return _amount


func clear() -> void:
	_ticks = 0
