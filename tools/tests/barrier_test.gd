extends SceneTree
## The invisible wall tile ("invisible_wall", behaviour "barrier"): only the player is stopped by it, enemies and thrown objects pass,
## nothing is drawn for it in the game, and the level solver and the enemies see it as empty air. Played on the boss stage's arena, which
## is fenced by two columns of it. Exits non-zero on failure.
## Run: godot_console --headless --fixed-fps 60 --path . --script res://tools/tests/barrier_test.gd

const ARENA := "res://levels/level_06/level.sablevel.json"

var ok := true


func _check(name: String, cond: bool, detail := "") -> void:
	print(("PASS  " if cond else "FAIL  "), name, "  ", detail)
	if not cond:
		ok = false


func _initialize() -> void:
	_main()


func _wait(frames: int) -> void:
	for i in frames:
		await process_frame


func _main() -> void:
	InputSetup.register()
	await _wait(2)
	var kind := TileRegistry.kind_for_key("invisible_wall")
	_check("the registry has the invisible wall", not kind.is_empty() and str(kind["behavior"]) == "barrier", str(kind.get("id")))
	var ch := str(kind["char"])
	_check("physics: it is its own class, not solid ground and not empty air", TileRegistry.physics_char(ch) == TileRegistry.BARRIER_CHAR and not Level.SOLID.contains(TileRegistry.BARRIER_CHAR))
	_check("the editor has a picture for it", SpriteLibrary.tile(str((kind["sprite"] as Dictionary)["tile"])) != null)

	var loaded := LevelFile.load_file(ARENA)
	LevelData.use_file(loaded["data"], ARENA.get_base_dir())
	var level := Level.new()
	level.level_id = LevelData.FILE_ID
	root.add_child(level)
	await _wait(3)
	var kinds := LevelData.map(LevelData.FILE_ID)
	var row_index := 5
	var wall_col := (kinds[row_index] as String).find(ch)
	_check("the arena has invisible walls", wall_col > 0, "column %d" % wall_col)
	var wall_x := (wall_col + 0.5) * Level.T
	var mid_y := (row_index + 0.5) * Level.T

	# what collides with it
	var space := level.get_world_2d().direct_space_state
	var from := Vector2(wall_x - 200.0, mid_y)
	var to := Vector2(wall_x + 200.0, mid_y)
	var hit_player_layer := space.intersect_ray(PhysicsRayQueryParameters2D.create(from, to, Player.LAYER_BARRIER))
	var hit_world_layer := space.intersect_ray(PhysicsRayQueryParameters2D.create(from, to, Player.LAYER_WORLD | Player.LAYER_LADDER_DECK))
	_check("the player's layer for it stops a ray", not hit_player_layer.is_empty())
	_check("but the world layer (enemies, thrown objects, enemy sensing) does not see it", hit_world_layer.is_empty())

	# nothing is drawn
	var drawn := false
	for n in level.get_children():
		if n is Sprite2D and absf((n as Sprite2D).position.x - wall_col * Level.T) < 1.0 and (n as Sprite2D).position.y < 10 * Level.T and (n as Sprite2D).position.y > 0.0:
			drawn = true
	_check("nothing is drawn for it in the game", not drawn)

	# the player cannot get through, an enemy can
	var player := Player.new()
	player.position = Vector2(wall_x - 200.0, 10.0 * Level.T)
	player.spawn = player.position
	root.add_child(player)
	var bro := AIBro.new()
	bro.configure({"sight_range": 4000.0, "lose_range": 6000.0, "sight_height": 800.0}, "TEST BRO")
	bro.position = Vector2(wall_x - 150.0, 10.0 * Level.T)
	root.add_child(bro)
	bro.set_meta("always_awake", true)
	Input.action_press("move_right")
	await _wait(240)
	Input.action_release("move_right")
	_check("the player running into it is stopped", player.global_position.x < wall_x, "player %.0f, wall %.0f" % [player.global_position.x, wall_x])
	# put the player on the far side so the Bro (chasing) walks through the wall
	player.global_position = Vector2(wall_x + 400.0, 10.0 * Level.T)
	player.velocity = Vector2.ZERO
	bro.global_position = Vector2(wall_x - 150.0, 10.0 * Level.T)
	bro.state = AIBro.State.CHASE
	await _wait(300)
	_check("an enemy walks straight through it", bro.global_position.x > wall_x + 60.0, "bro %.0f, wall %.0f" % [bro.global_position.x, wall_x])
	level.queue_free()
	player.queue_free()
	bro.queue_free()
	await _wait(3)
	print("ALL PASS" if ok else "SOME FAILED")
	quit(0 if ok else 1)
