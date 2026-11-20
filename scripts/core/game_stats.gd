class_name GameStats
extends RefCounted
## The player's running totals, shown on the HUD (see Hud), and what the player carries from one level to the next. They live for the whole
## session, so they carry over from level to level; the game starts them again from zero when it restarts from the first level.

# KILL_SCORE: points for defeating an ordinary enemy (an AI Bro). BOSS_HIT_SCORE: points for each hit on a boss. BOSS_SCORE: points for
# defeating a boss. REPAIR_SCORE: points for opening a power-up box while already in a vehicle (the vehicle is also repaired and its energy filled).
const KILL_SCORE := 100
const BOSS_HIT_SCORE := 100
const BOSS_SCORE := 2500
const REPAIR_SCORE := 500

static var score := 0

# carried: what the player takes into the next level: {"health": int, "energy": float, "mech": bool, "mech_hits": int, "mech_energy": float}, empty = nothing yet
# (a new game). Saved when a level is finished (save_player()), applied when the next one starts (apply_to()).
static var carried := {}


## Raise the score. With a world position `at` the points also float up from that spot as a small text (pooled with others that come in
## quick succession, see ScorePopups).
static func add_score(points: int, at: Vector2 = Vector2.INF) -> void:
	score += points
	if at != Vector2.INF:
		ScorePopups.add(points, at)


static func reset() -> void:
	score = 0
	carried = {}


## Remember the player's state to carry into the next level: their health and the vehicle they are in, with its damage and energy, and the player's own energy.
static func save_player(player: Player) -> void:
	carried = {"health": player.health, "energy": player.energy.level, "mech": player.mech != null,
			"mech_hits": player.mech.hits if player.mech != null else 0, "mech_energy": player.mech.energy.level if player.mech != null else 1.0}


## Give a player who has just been created what was carried from the last level (nothing in a new game): the same health, and the vehicle in the
## same state, with its damage showing.
static func apply_to(player: Player) -> void:
	if carried.is_empty():
		return
	player.health = clampi(int(carried["health"]), 1, player.max_health)
	player.health_changed.emit(player.health, player.max_health)
	player.energy.set_level(float(carried["energy"]))
	if bool(carried["mech"]):
		player.board_mech(true)
		player.mech.set_state(int(carried["mech_hits"]), float(carried["mech_energy"]))
