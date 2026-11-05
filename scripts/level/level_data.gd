class_name LevelData
extends RefCounted
## Level layouts as ASCII tile maps. One character = one 70px tile.
##
## Legend
##   .  empty              #  ground (auto-picks start/middle/end/fill)
##   =  one-way ledge      H  ladder
##   ^  floor spikes       v  ceiling spikes
##   X  metal crate        O  orange crate
##   P  player spawn       E  exit terminal
## Machines (decor). The letter marks the BOTTOM-LEFT tile; the rest of the footprint
## (to the right and up) must be left as '.'.
##   G  GPU rack 2x3        S  supercomputer 3x3
##   M  monitoring station 3x2     R  server tower 1x3
## Other background decor
##   k controls panel   w dark panel   r ceiling rail   m monitor   t tv monitor
##   g gear   i siren   l lamp   c canister   ~ slime
##
## Rows are built with helpers so run lengths can't be miscounted; Level
## validates that every row has the same width.


static func _d(n: int) -> String:
	return ".".repeat(n)


## Level 1: DATA CENTER 01 (60 x 14 tiles).
## Act 1: start room + spike pit. Act 2: ladder up to the hazard corridor.
## Act 3: ledge staircase to the exit terminal.
static func level_1() -> Array[String]:
	var m: Array[String] = []
	m.append("#".repeat(60))                                                            # 0  ceiling
	m.append("#" + "r".repeat(58) + "#")                                                # 1  ceiling rail
	m.append("#" + _d(58) + "#")                                                        # 2
	m.append("#" + _d(7) + "g" + _d(13) + "g" + _d(7) + "." + _d(28) + "#")             # 3  gears
	m.append("#" + _d(32) + "m" + _d(4) + "t" + _d(4) + "m" + _d(11) + "m" + "." + "t" + "." + "#")  # 4  monitors
	m.append("#" + _d(30) + "l" + _d(3) + "^^" + "." + "i" + _d(2) + "^^" + _d(2) + "l" + _d(13) + "#")  # 5  corridor hazards
	m.append("#" + _d(27) + "H" + "#".repeat(19) + _d(11) + "#")                         # 6  ladder top + upper slab
	m.append("#" + _d(27) + "H" + _d(17) + "O" + _d(9) + "E" + _d(2) + "#")              # 7  exit
	m.append("#" + _d(27) + "H" + _d(17) + "O" + _d(8) + "===" + "." + "#")              # 8
	m.append("#" + _d(27) + "H" + _d(17) + "O" + _d(6) + "==" + _d(4) + "#")                # 9
	m.append("#" + _d(9) + "X" + _d(17) + "H" + _d(17) + "O" + _d(4) + "==" + _d(6) + "#")  # 10
	m.append("#" + ".lP." + "S.." + "." + "XX" + _d(4) + "===" + _d(3) + "cc" + "." + "i" + _d(3) + "H" + _d(2) + "M.." + _d(2) + "G.R" + _d(2) + "S.." + _d(2) + "O" + _d(2) + "==" + "~".repeat(7) + "." + "#")  # 11  machines
	m.append("#".repeat(14) + "^".repeat(5) + "#".repeat(41))                           # 12 floor + spike pit
	m.append("#".repeat(60))                                                            # 13 floor fill
	return m
