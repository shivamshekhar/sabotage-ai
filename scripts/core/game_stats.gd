class_name GameStats
extends RefCounted
## The player's running totals, shown on the HUD (see Hud). They live for the whole session, so they carry over from level to level;
## the game starts them again from zero when it restarts from the first level.

# KILL_SCORE: points for defeating an ordinary enemy (an AI Bro). BOSS_HIT_SCORE: points for each hit on a boss. BOSS_SCORE: points for
# defeating a boss.
const KILL_SCORE := 100
const BOSS_HIT_SCORE := 100
const BOSS_SCORE := 2500

static var score := 0


static func add_score(points: int) -> void:
	score += points


static func reset() -> void:
	score = 0
