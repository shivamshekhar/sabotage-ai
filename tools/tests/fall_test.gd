extends SceneTree
## Fall death and level selection. Exits non-zero on failure.
## Run: godot_console --headless --fixed-fps 60 --path . --script res://tools/tests/fall_test.gd

# FLOOR_Y: feet y of the test level's long ground floor. Must match the map in LevelData.test_level().
const FLOOR_Y := 840.0

# DROP_X: an open x position on that floor.
const DROP_X := 300.0

var main: Node
var player: Player
var frames := 0
var step := 0
var t := 0
var ok := true
var deaths: Array[String] = []


func _check(name: String, cond: bool, detail := "") -> void:
	print(("PASS  " if cond else "FAIL  "), name, "  ", detail)
	if not cond:
		ok = false


func _initialize() -> void:
	_check("the default level is level 1", LevelData.DEFAULT_ID == "1")
	_check("both levels are known", LevelData.has_level("1") and LevelData.has_level("test"))
	_check("unknown ids are rejected", not LevelData.has_level("nope"))
	_check("the test level is untouched (60 columns, 14 rows)",
		LevelData.test_level().size() == 14 and LevelData.test_level()[0].length() == 60)
	OS.set_environment("SABOTAGE_LEVEL", "test")
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _drop_from(height: float) -> void:
	player.global_position = Vector2(DROP_X, FLOOR_Y - height)
	player.velocity = Vector2.ZERO
	player.health = Player.MAX_HEALTH
	deaths.clear()
	t = 0


func _process(_d: float) -> bool:
	frames += 1
	if frames == 3:
		for n in main.get_children():
			if n is Player:
				player = n
		player.died.connect(func(cause: String) -> void: deaths.append(cause))
		_drop_from(0.0)
		return false
	if player == null or frames < 8:
		return false
	t += 1
	if t < 120:
		return false
	match step:
		0:
			_check("standing still does not kill", deaths.is_empty())
			_drop_from(450.0)
			step = 1
		1:
			_check("a moderate drop is survived", deaths.is_empty(), str(deaths))
			_check("and the player is standing on the floor", is_equal_approx(player.global_position.y, FLOOR_Y), str(player.global_position))
			# The test level is not tall enough to fall that far, so pretend the fall began higher up.
			_drop_from(200.0)
			player._peak_y = FLOOR_Y - (Player.FALL_DEATH_HEIGHT + 60.0)
			step = 2
		2:
			_check("a tall drop kills (cause: fall)", deaths == ["fall"], str(deaths))
			_check("and respawns at the spawn point", player.global_position.distance_to(player.spawn) < 5.0, str(player.global_position))
			_check("with full health", player.health == Player.MAX_HEALTH)
			print("ALL PASS" if ok else "SOME FAILED")
			quit(0 if ok else 1)
	return false
