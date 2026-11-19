class_name PowerUps
extends RefCounted
## The kinds of power-up a box can hold. A box picks one at random when it is opened (see PowerUpBox); for now there is one: the
## four-legged mech. A new kind is a name here and a branch in grant().

# KINDS: every power-up a box can give.
const KINDS: Array[String] = ["mech"]


static func random_kind() -> String:
	return KINDS[randi() % KINDS.size()]


## Give the player the power-up `kind`; `at` is where the box was (the points text of a repair floats up from there). A player who already
## has that vehicle gets it mended and refuelled instead, and GameStats.REPAIR_SCORE points.
static func grant(player: Player, kind: String, at: Vector2 = Vector2.INF) -> void:
	match kind:
		"mech":
			if player.mech != null:
				player.mech.repair()
				GameStats.add_score(GameStats.REPAIR_SCORE, at)
			else:
				player.board_mech()
