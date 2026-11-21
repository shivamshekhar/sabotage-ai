extends SceneTree
## The boss stage demo (level_06, played through the game's Main scene): RAM Saltman is 2.16 times the player's height, hovers where thrown objects can reach it,
## swoops over the player and turns upside down to spray hardware (and cannot be hurt then), flips back and hovers again, and is
## defeated by MAX_HEALTH hit points of damage. Exits non-zero on failure.
## Run: godot_console --headless --fixed-fps 60 --path . --script res://tools/tests/boss_test.gd

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


## Wait until the boss is in `state` (at most `seconds`); true if it got there.
func level_width(scene: Node) -> float:
	return float(scene.level.world_w)


func _until(boss: SaltShakerBoss, state: SaltShakerBoss.State, seconds: float) -> bool:
	var frames := int(seconds * 60.0)
	while boss.state != state and frames > 0:
		await process_frame
		frames -= 1
	return boss.state == state


func _main() -> void:
	_check("level 5 leads to the boss level", LevelData.next_id("level_05") == "level_06" and BossFight.boss_of("level_06") == "salt_shaker")
	_check("it is the last level", LevelData.next_id("level_06") == "" and LevelData.level_ids().back() == "level_06")
	_check("the HUD calls it 1-6", LevelData.stage_label("level_06") == "1-6")
	_check("no other level has a boss", BossFight.boss_of("level_01") == "" and BossFight.boss_of("level_05") == "")
	LevelData.selected_id = "level_06"
	var main = load(AssetPaths.MAIN_SCENE).instantiate()
	root.add_child(main)
	await _wait(3)
	LevelData.selected_id = ""
	var scene: BossFight = main.fight
	_check("the game starts the fight", scene != null)
	_check("the floor is the one the player stands on", is_equal_approx(scene.floor_y, 700.0), str(scene.floor_y))
	var boss: SaltShakerBoss = scene.boss
	var player: Player = scene.player
	_check("the stage has a player and a boss", boss != null and player != null)

	# size: 2.16 players tall
	var visual: SaltmanVisual = boss.visual
	var height := visual.size.y * visual.scale.y
	_check("the boss is 2.16 times as tall as the player", absf(height - SaltShakerBoss.SIZE_IN_PLAYERS * Player.BODY_SIZE.y) < 2.0, "%.0f px vs player %.0f px" % [height, Player.BODY_SIZE.y])

	# hovering: vulnerable and within reach of a throw from the ground
	_check("it starts hovering", boss.state == SaltShakerBoss.State.HOVER)
	_check("with an angry idle face", visual.expression == "idle")
	_check("and 500 hit points", SaltShakerBoss.MAX_HEALTH == 500)
	var reach := boss.hurtbox().grow(Projectile.HIT_RADIUS)
	var hand := Vector2(boss.global_position.x, boss.floor_y - 92.0)
	_check("a thrown object leaving the hand can reach its body", reach.has_point(hand + Vector2(0.0, -20.0)), str(reach))
	_check("the boss is in the enemies group (thrown objects find it)", boss.is_in_group(Groups.ENEMIES))

	# the level has no visible walls at its sides, only invisible ones that keep the player in
	var rows := LevelData.map("level_06")
	var open_sides := true
	for r in range(1, 10):
		open_sides = open_sides and not (rows[r].begins_with("#") or rows[r].ends_with("#"))
	_check("the arena has no visible walls at either side", open_sides)
	var gap := absf(boss.global_position.x - player.global_position.x)
	_check("the player and the boss start far apart", gap > 800.0, "%.0f px" % gap)
	var start_view: Rect2 = scene.view_rect()
	_check("and both are on the screen at the start", start_view.grow(-120.0).has_point(Vector2(player.global_position.x, start_view.get_center().y)) and start_view.grow(-120.0).has_point(Vector2(boss.global_position.x, start_view.get_center().y)), "view x %.0f..%.0f, player %.0f, boss %.0f" % [start_view.position.x, start_view.end.x, player.global_position.x, boss.global_position.x])
	_check("and the boss's arena is between the invisible walls", boss.arena.size.x > 2000.0 and boss.arena.size.x < level_width(scene) - 600.0, str(boss.arena))
	await _wait(240)
	_check("so nothing hurts the player during the calm start", player.health == player.max_health and boss.state == SaltShakerBoss.State.HOVER)
	boss._hover_left = 9999.0       # (he keeps hovering while the player runs to the walls)
	for side in [-1, 1]:
		var action := InputActions.MOVE_LEFT if side < 0 else InputActions.MOVE_RIGHT
		Input.action_press(action)
		await _wait(60 * 12)
		Input.action_release(action)
		var wall_x: float = boss.arena.position.x if side < 0 else boss.arena.end.x
		_check("running %s, the player is stopped at the invisible wall" % ("left" if side < 0 else "right"), absf(player.global_position.x - wall_x) < 90.0 and player.is_on_floor(), "player %.0f, wall %.0f" % [player.global_position.x, wall_x])
		await _wait(60)
		var view: Rect2 = scene.view_rect()
		var edge_ok: bool = view.position.x >= boss.arena.position.x - 1.0 if side < 0 else view.end.x <= boss.arena.end.x + 1.0
		_check("at the %s wall the camera shows nothing behind it" % ("left" if side < 0 else "right"), edge_ok, "view %s, arena %s" % [view, boss.arena])
	_check("the camera is limited to the arena", scene.camera.limit_left == int(boss.arena.position.x) and scene.camera.limit_right == int(boss.arena.end.x))
	player.global_position = Vector2(boss.arena.get_center().x - 1000.0, player.global_position.y)
	player.velocity = Vector2.ZERO
	await _wait(30)
	boss._hover_left = 5.0

	# attack: swoop, flip, spray. The player stands to the left, so the Bros must come from the right.
	player.global_position.x -= 600.0
	await _wait(60)
	boss._hover_left = 0.05
	_check("it swoops over the player", await _until(boss, SaltShakerBoss.State.WINDUP, 1.0))
	await _wait(10)
	_check("it charges with a different face", visual.expression == "charge")
	_check("then turns over", await _until(boss, SaltShakerBoss.State.FLIP_DOWN, 4.0))
	_check("then sprays", await _until(boss, SaltShakerBoss.State.SPRAY, 2.0))
	await _wait(30)
	_check("it is upside down while spraying (rocking a little)", absf(absf(visual.rotation) - PI) < 0.5, "%.2f rad" % visual.rotation)
	_check("with its attack face and glowing cap", visual.expression == "attack")
	_check("it is above the player", absf(boss.global_position.x - player.global_position.x) < 400.0 and boss.global_position.y < player.global_position.y - 200.0)
	_check("it cannot be hurt while attacking", boss.hurtbox().size == Vector2.ZERO)
	var health_before := boss.health
	boss.take_hit(Projectile.DAMAGE)
	_check("a hit while attacking does nothing", boss.health == health_before)
	# AI Bros come in from both sides during the spray: one each, never more
	var seen_off_screen := false
	var first_bro: AIBro = null
	var waited := 0
	while first_bro == null and waited < 120 and boss.state == SaltShakerBoss.State.SPRAY:
		await process_frame
		waited += 1
		for side in [-1, 1]:
			if scene._bros[side] != null and is_instance_valid(scene._bros[side]):
				first_bro = scene._bros[side]
	_check("an AI Bro comes in while he sprays", first_bro != null)
	if first_bro != null:
		_check("from the side the player is farther from (the player is on the left)", first_bro.global_position.x > player.global_position.x + 500.0, "bro %.0f, player %.0f" % [first_bro.global_position.x, player.global_position.x])
		_check("starting off screen, so it walks in", not scene.view_rect().has_point(first_bro.global_position))
		_check("and it is not on top of the player", absf(first_bro.global_position.x - player.global_position.x) > 400.0)
	_check("only one comes at first", (scene._bros[-1] == null) != (scene._bros[1] == null))
	var most := 0
	var kinds := {}
	var rock_min := 99.0
	var rock_max := -99.0
	var bounce_min := 1.0e9
	var bounce_max := -1.0e9
	var pile_up := 0.0
	var max_pieces := 0
	var frames := 0
	while boss.state == SaltShakerBoss.State.SPRAY and frames < 600:
		await process_frame
		frames += 1
		rock_min = minf(rock_min, visual.rotation)
		rock_max = maxf(rock_max, visual.rotation)
		bounce_min = minf(bounce_min, visual.position.y)
		bounce_max = maxf(bounce_max, visual.position.y)
		pile_up = maxf(pile_up, -visual.get_child(1).get_child(0).position.y)
		var bros := 0
		for n in main.get_children():
			if n is AIBro:
				bros += 1
		most = maxi(most, bros)
		var pieces := get_nodes_in_group(Groups.BOSS_BULLETS)
		max_pieces = maxi(max_pieces, pieces.size())
		for b in pieces:
			kinds[(b as BossBullet).kind] = true
	_check("it sprays pieces of hardware", max_pieces >= 4, "%d at once" % max_pieces)
	_check("it rocks side to side while shaking", rock_max - rock_min > 0.25, "%.2f rad swing" % (rock_max - rock_min))
	_check("and jerks up and down", bounce_max - bounce_min > 15.0, "%.0f px" % (bounce_max - bounce_min))
	_check("and the hardware inside is thrown about", pile_up > 5.0, "%.0f px up" % pile_up)
	_check("never more than one Bro per side (%d at most)" % most, most <= 2)
	_check("RAM sticks, CPUs and chipsets all appear", kinds.has("ram_stick") and (kinds.has("cpu") or kinds.has("chipset")), str(kinds.keys()))
	_check("the spray hurts a player standing still under it", player.health < player.max_health, "%d / %d" % [player.health, player.max_health])

	# back to hovering
	_check("it flips back and returns", await _until(boss, SaltShakerBoss.State.RETURN, 3.0))
	_check("and hovers again", await _until(boss, SaltShakerBoss.State.HOVER, 4.0))
	await _wait(5)
	_check("upright again", absf(visual.rotation) < 0.3, "%.2f rad" % visual.rotation)
	_check("and back to his idle face", visual.expression == "idle")
	_check("it can be hurt again", boss.hurtbox().size != Vector2.ZERO)
	boss._hover_left = 999.0

	# hits
	var seen_defeat := [false]
	boss.defeated.connect(func() -> void: seen_defeat[0] = true)
	boss.take_hit(Projectile.DAMAGE)
	_check("a thrown object takes %d hit points off" % Projectile.DAMAGE, boss.health == SaltShakerBoss.MAX_HEALTH - Projectile.DAMAGE)
	await _wait(2)
	_check("and he winces", visual.expression == "hurt")
	for i in SaltShakerBoss.MAX_HEALTH / Projectile.DAMAGE - 1:
		boss.take_hit(Projectile.DAMAGE)
	_check("%d thrown objects defeat it" % (SaltShakerBoss.MAX_HEALTH / Projectile.DAMAGE), seen_defeat[0] and boss.state == SaltShakerBoss.State.DEAD)
	_check("a defeated boss is no longer an enemy", not boss.is_in_group(Groups.ENEMIES))
	await _wait(3)
	_check("and has the dead face", visual.expression == "dead")
	main.queue_free()
	await _wait(3)
	print("ALL PASS" if ok else "SOME FAILED")
	quit(0 if ok else 1)
