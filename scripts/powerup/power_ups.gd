class_name PowerUps
extends RefCounted
## The kinds of power-up a box can hold. A box picks one at random when it is opened (see PowerUpBox); for now there is one: the
## four-legged mech. A new kind is a name here and a branch in grant().

# KINDS: every power-up a box can give.
const KINDS: Array[String] = ["mech"]


static func random_kind() -> String:
	return KINDS[randi() % KINDS.size()]


## Give the player the power-up `kind` (the mech is assembled round them first, which takes a moment, see MechAssembly); `at` is where the box was (the points text of a repair floats up from there). A player who already
## has that vehicle gets it mended and its energy filled instead, and GameStats.REPAIR_SCORE points.
static func grant(player: Player, kind: String, at: Vector2 = Vector2.INF) -> void:
	if player.is_frozen_for_pickup():
		return
	match kind:
		"mech":
			if player.mech != null:
				player.mech.repair()
				GameStats.add_score(GameStats.REPAIR_SCORE, at)
				if is_instance_valid(player.get_parent()):
					WhiteFlash.burst(player.get_parent(), player.global_position + Vector2(0.0, -Player.BODY_SIZE.y * 0.5), Player.BODY_SIZE.y * WhiteFlash.PLAYER_SIZES)     # a glow: it is mended
			else:
				MechAssembly.start(player)     # the player is held in place while the mech is built round them, then gets in
