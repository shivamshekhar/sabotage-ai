extends SceneTree
## What goes with the player from level to level and the points text: the health and the vehicle (with its damage and energy) are carried into the
## next level; points float up as a small pooled text; opening a power-up box while in the mech mends it and gives 500 points; the mech walks
## over spikes unharmed; enemies keep their distance from its wide body and it is stopped by walls where it is drawn; Up at a ladder does not
## light its booster. Exits non-zero on failure.
## Run: godot_console --headless --fixed-fps 60 --path . --script res://tools/tests/carry_test.gd

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


func _popups() -> Array:
	var out := []
	if ScorePopups._instance != null and is_instance_valid(ScorePopups._instance):
		for c in ScorePopups._instance.get_children():
			out.append(c)
	return out


func _level() -> Node:
	TestArena.use()
	var main = load(AssetPaths.MAIN_SCENE).instantiate()
	root.add_child(main)
	await _wait(4)
	LevelData.selected_id = ""
	return main


func _main() -> void:
	InputSetup.register()
	GameStats.reset()
	await _wait(2)

	# ---- the points text: pooled, small, floating, then gone
	GameStats.add_score(100, Vector2(100.0, 300.0))
	await _wait(30)
	GameStats.add_score(500, Vector2(240.0, 260.0))
	_check("the score rises at once", GameStats.score == 600, str(GameStats.score))
	await _wait(50)
	_check("nothing is shown while awards keep coming within a second of each other", _popups().is_empty())
	await _wait(30)
	var shown := _popups()
	_check("a second after the last one, ONE text shows the sum", shown.size() == 1 and (shown[0] as ScorePopups.ScorePopup).text == "+600", str(shown.size()))
	_check("where the last one was earned", shown.size() == 1 and absf((shown[0] as Node2D).position.x - 240.0) < 1.0)
	var start_y: float = (shown[0] as Node2D).position.y
	await _wait(35)
	_check("it floats up", shown.size() == 1 and is_instance_valid(shown[0]) and (shown[0] as Node2D).position.y < start_y - 10.0)
	_check("and the font is small", ScorePopups.FONT_SIZE <= 20)
	await _wait(60)
	_check("then it is gone", _popups().is_empty())
	GameStats.add_score(100, Vector2(10.0, 10.0))
	await _wait(75)
	_check("a lone award shows by itself after the pooling time", _popups().size() == 1 and (_popups()[0] as ScorePopups.ScorePopup).text == "+100")
	await _wait(100)
	# a long chain still shows eventually
	var chain_shown := false
	for i in 8:
		GameStats.add_score(10, Vector2(float(i), 0.0))
		for k in 40:
			await _wait(1)
			chain_shown = chain_shown or not _popups().is_empty()
	_check("a long chain does not wait for ever (it shows within %.1f s)" % ScorePopups.MAX_WAIT, chain_shown)
	await _wait(120)

	# ---- an enemy's death scores above its head
	var bro := AIBro.new()
	bro.configure({"sight_range": 1.0, "lose_range": 1.0, "sight_height": 1.0, "patrol_radius": 1.0}, "X")
	bro.position = Vector2(500.0, 600.0)
	root.add_child(bro)
	await _wait(3)
	var before := GameStats.score
	bro.take_hit(1.0)
	_check("killing a Bro scores %d, shown above its head" % GameStats.KILL_SCORE, GameStats.score == before + GameStats.KILL_SCORE and ScorePopups._instance._pending == GameStats.KILL_SCORE and ScorePopups._instance._at.y < 600.0 - 100.0)
	await _wait(200)

	# ---- what is carried to the next level
	var main = await _level()
	var player: Player = get_first_node_in_group(Groups.PLAYER)
	player.health = 63
	player.board_mech()
	await _wait(5)
	player.mech.take_damage()
	player.mech.take_damage()
	player.mech.take_damage()
	player.mech.energy.set_level(0.5)
	GameStats.save_player(player)
	_check("the player's state is remembered: health, vehicle, its damage and energy", int(GameStats.carried["health"]) == 63 and GameStats.carried["mech"] == true and int(GameStats.carried["mech_hits"]) == 3 and is_equal_approx(float(GameStats.carried["mech_energy"]), 0.5), str(GameStats.carried))
	main.queue_free()
	await _wait(3)
	main = await _level()
	player = get_first_node_in_group(Groups.PLAYER)
	_check("the next level starts with the same health", player.health == 63, str(player.health))
	var carried_mech := player.mech
	_check("and the same vehicle", carried_mech != null)
	if carried_mech != null:
		_check("in the same state: three hits, the cracks, the broken leg and the smoke showing", carried_mech.hits == 3 and carried_mech.visual._cracks.visible and carried_mech.visual._broken == MechVisual.BROKEN_LEG and carried_mech.visual._smoke[0].emitting and not carried_mech.visual._fires[0].visible)
		_check("and the energy it had", carried_mech.energy.level >= 0.5 and carried_mech.energy.level < 0.6, "%.2f" % carried_mech.energy.level)
		var debris := 0
		for n in main.get_children():
			if n is Debris:
				debris += 1
		_check("nothing falls off as it arrives", debris == 0)
		await _wait(40)
		var floating := 0.0
		for f in carried_mech.visual.feet:
			floating = maxf(floating, player.global_position.y - f.y)
		_check("it arrives standing: all four feet are on the floor, not hovering above it", player.is_on_floor() and floating < 4.0, "feet up to %.1f px above the floor" % floating)
	main.queue_free()
	await _wait(3)
	GameStats.reset()
	_check("a new game carries nothing", GameStats.carried.is_empty() and GameStats.score == 0)
	main = await _level()
	player = get_first_node_in_group(Groups.PLAYER)
	_check("and starts on foot with full health", player.mech == null and player.health == player.max_health)

	# ---- a power-up box opened while in the mech mends it, fills its energy and gives 500 points
	player.board_mech()
	await _wait(5)
	for i in 3:
		player.mech.take_damage()
	player.mech.energy.set_level(0.1)
	var box := PowerUpBox.new()
	box.position = Vector2(TestArena.FLAT_X, TestArena.FLOOR_Y - 2.5 * Level.T)
	main.add_child(box)
	await _wait(2)
	var score_before := GameStats.score
	player.global_position = Vector2(box.position.x, box.position.y - 150.0)
	player.velocity = Vector2(0.0, 520.0)
	await _wait(20)
	var m := player.mech
	player.global_position = Vector2(300.0, TestArena.FLOOR_Y)       # (back to the floor: the box hangs over a deadly pit)
	player.velocity = Vector2.ZERO
	_check("the box mends the mech (no damage) and fills the tank", m != null and m.hits == 0 and m.energy.level >= 0.99 and m.visual.damage == 0 and not m.visual._cracks.visible and m.visual._broken == -1)
	_check("and gives %d points" % GameStats.REPAIR_SCORE, GameStats.score == score_before + GameStats.REPAIR_SCORE, str(GameStats.score - score_before))
	await _wait(100)
	_check("the points float up from the box", not _popups().is_empty() and (_popups()[0] as ScorePopups.ScorePopup).text == "+500")
	await _wait(100)

	# ---- spikes: they hurt on foot, but not the mech
	var health_start := player.health
	player.mech.release(false)
	player.mech = null
	player._visuals.visible = true
	player._health_bar.visible = true
	player.set_body_scale(1.0)
	player._invuln_timer = 0.0
	player.global_position = Vector2(TestArena.SPIKES_X, TestArena.FLOOR_Y)
	player.velocity = Vector2.ZERO
	await _wait(60)
	_check("on foot, spikes hurt", player.health < health_start, "%d -> %d" % [health_start, player.health])
	player._invuln_timer = 0.0
	player.board_mech()
	await _wait(5)
	for e in get_nodes_in_group(Groups.ENEMIES):
		e.queue_free()      # (the level's own Bros would hit it)
	await _wait(2)
	player.global_position = Vector2(TestArena.SPIKES_X, TestArena.FLOOR_Y)
	player.velocity = Vector2.ZERO
	await _wait(200)
	_check("the mech stands among the spikes unharmed", player.mech != null and player.mech.hits == 0, "hits %d" % (player.mech.hits if player.mech != null else -1))

	# ---- the mech is stopped by a wall where it is drawn
	player.global_position = Vector2(300.0, TestArena.FLOOR_Y)
	player.velocity = Vector2.ZERO
	await _wait(40)
	Input.action_press(InputActions.MOVE_LEFT)
	await _wait(150)
	Input.action_release(InputActions.MOVE_LEFT)
	var left_edge := player.global_position.x - Mech.CHASSIS_SIZE.x / 2.0
	_check("walking into the level's left wall, the body stops at the wall (not sunk into it)", left_edge >= TestArena.WALL_X - 3.0, "body edge %.0f, wall at %d" % [left_edge, int(TestArena.WALL_X)])
	_check("and the barrel too", player.global_position.x - (Mech.CHASSIS_SIZE.x / 2.0 + Mech.BARREL_SIZE.x) >= TestArena.WALL_X - 3.0, "x %.0f" % player.global_position.x)
	_check("standing against a wall is not hovering: the legs fold in and stand", not player.mech.visual.hovering and not player.mech.visual._flame.visible)
	var longest := 0.0
	for i in 4:
		longest = maxf(longest, player.mech.visual.feet[i].distance_to(player.mech.visual.hip_world(i)))
	_check("no leg is longer than its limit", longest <= MechVisual.MAX_REACH + 0.5, "%.0f px" % longest)

	# ---- Up at a ladder does not light the booster
	player.global_position = Vector2(TestArena.LADDER_X, TestArena.FLOOR_Y)
	player.velocity = Vector2.ZERO
	await _wait(40)
	var y0 := player.global_position.y
	var thrust_seen := false
	Input.action_press(InputActions.MOVE_UP)
	for k in 30:
		await _wait(1)
		thrust_seen = thrust_seen or player.mech.thrusting
	Input.action_release(InputActions.MOVE_UP)
	_check("at a ladder, Up does not fire the booster (the mech cannot climb)", not thrust_seen and absf(player.global_position.y - y0) < 4.0, "y moved %.0f" % (player.global_position.y - y0))
	player.global_position = Vector2(TestArena.FLAT_X, TestArena.FLOOR_Y)
	player.velocity = Vector2.ZERO
	await _wait(40)
	thrust_seen = false
	Input.action_press(InputActions.MOVE_UP)
	for k in 10:
		await _wait(1)
		thrust_seen = thrust_seen or player.mech.thrusting
	Input.action_release(InputActions.MOVE_UP)
	_check("away from a ladder, Up still lifts off", thrust_seen)
	await _wait(150)

	# ---- enemies keep their distance from the wide body
	var chaser := AIBro.new()
	chaser.configure({"sight_range": 3000.0, "lose_range": 4000.0, "sight_height": 800.0, "patrol_radius": 100.0}, "CHASER")
	chaser.position = Vector2(player.global_position.x + 600.0, TestArena.FLOOR_Y)
	main.add_child(chaser)
	chaser.set_meta("always_awake", true)
	chaser.state = AIBro.State.CHASE
	await _wait(240)
	var gap := absf(chaser.global_position.x - player.global_position.x)
	var closest_allowed := AIBro.HIT_RANGE * AIBro.STANDOFF_MIN + (Mech.CHASSIS_SIZE.x - Player.BODY_SIZE.x) / 2.0 - 4.0     # (each Bro picks its own stopping distance, at least STANDOFF_MIN of its reach)
	_check("a chasing Bro stops at the edge of the mech's body (%.0f px from its middle at least), not inside it" % closest_allowed, gap >= closest_allowed, "%.0f px apart" % gap)

	main.queue_free()
	await _wait(3)
	print("ALL PASS" if ok else "SOME FAILED")
	quit(0 if ok else 1)
