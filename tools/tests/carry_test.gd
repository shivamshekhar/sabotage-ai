extends SceneTree
## What goes with the player from level to level and the points text: the health and the vehicle (with its damage and energy) are carried into the
## next level; every award floats up at once as a small text of its own (nothing is delayed or added together), and the score survives a respawn and a level change; opening a power-up box while in the mech mends it and gives 500 points; the mech walks
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
	return get_nodes_in_group(Groups.SCORE_POPUPS)


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

	# ---- the points text: at once, one per award, small, floating up, then gone
	GameStats.add_score(100, Vector2(100.0, 300.0))
	_check("the score rises at once", GameStats.score == 100, str(GameStats.score))
	var first := _popups()
	_check("and so does its text, with no waiting", first.size() == 1 and (first[0] as ScorePopups.ScorePopup).text == "+100" and absf((first[0] as Node2D).position.x - 100.0) < 1.0, str(first.size()))
	GameStats.add_score(500, Vector2(240.0, 260.0))
	GameStats.add_score(50, Vector2(300.0, 260.0))
	var several := _popups()
	var texts := several.map(func(n: Node) -> String: return (n as ScorePopups.ScorePopup).text)
	_check("awards are not added together: each has its own text", several.size() == 3 and texts.has("+100") and texts.has("+500") and texts.has("+50"), str(texts))
	_check("and the score is their sum", GameStats.score == 650, str(GameStats.score))
	var start_y: float = (first[0] as Node2D).position.y
	await _wait(35)
	_check("a text floats up", is_instance_valid(first[0]) and (first[0] as Node2D).position.y < start_y - 10.0)
	_check("and the font is small", ScorePopups.FONT_SIZE <= 20)
	await _wait(60)
	_check("then it is gone", _popups().is_empty())

	# ---- an enemy's death scores above its head, at once
	var bro := AIBro.new()
	bro.configure({"sight_range": 1.0, "lose_range": 1.0, "sight_height": 1.0, "patrol_radius": 1.0}, "X")
	bro.position = Vector2(500.0, 600.0)
	root.add_child(bro)
	await _wait(3)
	var before := GameStats.score
	bro.take_hit(bro.max_health)
	var kill_text := _popups()
	_check("killing a Bro scores %d, and the text floats up from above its head at that moment" % GameStats.KILL_SCORE, GameStats.score == before + GameStats.KILL_SCORE and kill_text.size() == 1 and (kill_text[0] as Node2D).position.y < 600.0 - 100.0 and (kill_text[0] as ScorePopups.ScorePopup).text == "+%d" % GameStats.KILL_SCORE)
	await _wait(100)

	# ---- so does destroying a creature of a pit (the fireball, which cannot be destroyed, scores nothing)
	for kind in ["piranha", "puffer", "eel", "lava_ball"]:
		var creature := PitCreature.new(600.0, 800.0, 700.0, 900.0, kind)
		root.add_child(creature)
		await _wait(2)
		creature.state = PitCreature.State.PEEK
		creature.position = Vector2(800.0, 560.0)
		var score_before := GameStats.score
		creature.take_hit(Projectile.DAMAGE)
		var expected: int = 0 if kind == "lava_ball" else GameStats.PIT_CREATURE_SCORE
		_check("destroying a %s scores %d" % [kind, expected], GameStats.score == score_before + expected, str(GameStats.score - score_before))
		if expected > 0:
			var text := _popups()
			_check("and its points float up from it", text.size() == 1 and (text[0] as ScorePopups.ScorePopup).text == "+%d" % expected)
		else:
			_check("(and no text)", _popups().is_empty())
		creature.queue_free()
		await _wait(80)
	var twice := PitCreature.new(600.0, 800.0, 700.0, 900.0, "piranha")
	root.add_child(twice)
	await _wait(2)
	twice.state = PitCreature.State.PEEK
	twice.position = Vector2(800.0, 560.0)
	twice.take_hit(Projectile.DAMAGE)
	var after_one := GameStats.score
	twice.take_hit(Projectile.DAMAGE)
	_check("a creature that is already destroyed does not score again", GameStats.score == after_one)
	twice.queue_free()
	await _wait(80)

	# ---- what is carried to the next level
	var main = await _level()
	var player: Player = get_first_node_in_group(Groups.PLAYER)
	GameStats.add_score(GameStats.KILL_SCORE)
	var score_before_death := GameStats.score
	player.die("health")
	_check("the score is kept when the player respawns", GameStats.score == score_before_death and score_before_death > 0, str(GameStats.score))
	player.health = 63
	player.board_mech()
	await _wait(5)
	player.mech.take_damage()
	player.mech.take_damage()
	player.mech.energy.set_level(0.5)
	GameStats.save_player(player)
	_check("the player's state is remembered: health, vehicle, its damage and energy", int(GameStats.carried["health"]) == 63 and GameStats.carried["mech"] == true and int(GameStats.carried["mech_hits"]) == 2 and is_equal_approx(float(GameStats.carried["mech_energy"]), 0.5), str(GameStats.carried))
	GameStats.add_score(GameStats.KILL_SCORE)
	var score_at_exit := GameStats.score
	main.queue_free()
	await _wait(3)
	main = await _level()
	player = get_first_node_in_group(Groups.PLAYER)
	_check("the score is kept into the next level, and points still add up there", GameStats.score == score_at_exit and score_at_exit > 0, str(GameStats.score))
	GameStats.add_score(GameStats.KILL_SCORE)
	_check("(a level change does not lose what comes after it either)", GameStats.score == score_at_exit + GameStats.KILL_SCORE)
	_check("the next level starts with the same health", player.health == 63, str(player.health))
	var carried_mech := player.mech
	_check("and the same vehicle", carried_mech != null)
	if carried_mech != null:
		_check("in the same state: two hits, the cracks, the broken leg and the smoke showing", carried_mech.hits == 2 and carried_mech.visual._cracks.visible and carried_mech.visual._broken == MechVisual.BROKEN_LEG and carried_mech.visual._smoke[0].emitting)
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
	if carried_mech != null:
		for i in Mech.HITS_TO_DESTROY:
			player._invuln_timer = 0.0
			player.take_damage(1)
			await _wait(2)
		_check("a destroyed mech is lost for good: it is no longer what is carried", player.mech == null and GameStats.carried["mech"] == false)
		main.queue_free()
		await _wait(3)
		main = await _level()
		player = get_first_node_in_group(Groups.PLAYER)
		_check("so a level that starts again (the boss fight after a defeat) does not give it back", player.mech == null)
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
	for i in 2:
		player.mech.take_damage()
	player.mech.energy.set_level(0.1)
	var box := PowerUpBox.new()
	box.position = Vector2(TestArena.FLAT_X, TestArena.FLOOR_Y - 2.5 * Level.T)
	main.add_child(box)
	await _wait(2)
	var score_before := GameStats.score
	player.global_position = Vector2(box.position.x, box.position.y - 150.0)
	player.velocity = Vector2(0.0, 520.0)
	await _wait(45)
	var m := player.mech
	player.global_position = Vector2(300.0, TestArena.FLOOR_Y)       # (back to the floor: the box hangs over a deadly pit)
	player.velocity = Vector2.ZERO
	_check("the box mends the mech (no damage) and fills the tank", m != null and m.hits == 0 and m.energy.level >= 0.99 and m.visual.damage == 0 and not m.visual._cracks.visible and m.visual._broken == -1)
	_check("and gives %d points" % GameStats.REPAIR_SCORE, GameStats.score == score_before + GameStats.REPAIR_SCORE, str(GameStats.score - score_before))
	var box_text := _popups().filter(func(n: Node) -> bool: return (n as ScorePopups.ScorePopup).text == "+500")
	_check("the points float up from the box", box_text.size() == 1)
	await _wait(100)
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
