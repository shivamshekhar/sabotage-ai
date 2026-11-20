extends SceneTree
## The power-up box and the first vehicle, the four-legged mech: the box tile and its art, jumping on it, the mech's size, five-hit
## durability and the damage it shows, steps, hovering, the energy and the booster, missiles, laser and legs, and getting out again. Played in the test arena (tools/tests/lib/test_arena.gd), not in a real level.
## Exits non-zero on failure.
## Run: godot_console --headless --fixed-fps 60 --path . --script res://tools/tests/mech_test.gd

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


func _wait_until(cond: Callable, max_frames: int) -> int:
	var n := 0
	while not cond.call() and n < max_frames:
		await process_frame
		n += 1
	return n


func _bro(pos: Vector2) -> AIBro:
	var bro := AIBro.new()
	bro.configure({"sight_range": 1.0, "lose_range": 1.0, "sight_height": 1.0, "patrol_radius": 1.0}, "DUMMY")
	bro.position = pos
	bro.set_meta("always_awake", false)
	return bro


func _main() -> void:
	InputSetup.register()
	await _wait(2)

	# ---- the tile and the art
	var kind := TileRegistry.kind_for_key("powerup_box")
	_check("the registry has the power-up box tile", not kind.is_empty() and str(kind["behavior"]) == "powerup", str(kind.get("id")))
	_check("it is not solid (nothing in the physics map)", TileRegistry.physics_char(str(kind["char"])) == ".")
	_check("the editor has a picture for it", SpriteLibrary.tile("powerup_box") != null and SpriteLibrary.tile("powerup_box").get_width() == 70)
	var files := ["box_base", "box_question"]
	for i in 6:
		files.append("box_break_%d" % (i + 1))
	_check("the box and its six break-apart frames exist", files.all(func(f: String) -> bool: return ResourceLoader.exists("res://assets/powerups/%s.png" % f)))
	var mech_parts := ["body", "canopy", "missile_turret", "laser_turret", "link", "joint", "claw", "claw_open", "hip", "flame_1", "flame_2", "flame_3", "missile",
			"body_cracks", "canopy_cracks", "link_broken", "body_burn", "missile_flame_1", "missile_flame_2", "missile_flame_3"]
	_check("every mech part has its picture", mech_parts.all(func(f: String) -> bool: return ResourceLoader.exists(AssetPaths.MECH + f + ".png")))
	var effects := ["spark", "spark_blue", "smoke_1", "smoke_2", "smoke_3", "fire_1", "fire_2", "fire_3", "fire_4", "missile_glow", "laser_orb"]
	for i in Explosion.FRAMES:
		effects.append("explosion_%d" % (i + 1))
	_check("every generic effect (explosion, smoke, fire, sparks, glows) has its picture in assets/effects", effects.all(func(f: String) -> bool: return ResourceLoader.exists(AssetPaths.EFFECTS + f + ".png")))

	var q0 := PowerUpBox.question_color(0.0)
	var colors := {}
	var blinked := false
	var dim := false
	for k in 700:
		var c := PowerUpBox.question_color(k * 0.02)
		colors[roundi(c.h * 10.0)] = true
		blinked = blinked or c.a < 0.2
		dim = dim or (c.a < 0.7 and c.a > 0.4)
	_check("the question mark's colour slowly changes through many hues, breathes and blinks", colors.size() >= 6 and blinked and dim, "%d hues" % colors.size())

	# ---- the box in the game
	TestArena.use()
	var main = load(AssetPaths.MAIN_SCENE).instantiate()
	root.add_child(main)
	await _wait(5)
	LevelData.selected_id = ""
	var player: Player = null
	for p in get_nodes_in_group(Groups.PLAYER):
		player = p
	# a box of the test's own, a tile and a half above the floor near the spawn
	var own_box := PowerUpBox.new()
	own_box.position = Vector2(8.5 * Level.T, (TestArena.FLOOR_ROW - 0.5) * Level.T)
	main.add_child(own_box)
	await _wait(2)
	var boxes := get_nodes_in_group(Groups.POWERUP_BOXES)
	_check("the box is in the level", boxes.size() == 1)
	var box: PowerUpBox = boxes[0]
	_check("the player starts on foot", player != null and player.mech == null)
	var ground_y := player.spawn.y
	_check("the box floats above the ground, jumpable from the floor", box.position.y < ground_y - 80.0 and box.position.y > ground_y - 150.0, "box %.0f, ground %.0f" % [box.position.y, ground_y])

	# walking under or beside it does nothing
	player.global_position = Vector2(box.position.x - 200.0, ground_y)
	player.velocity = Vector2.ZERO
	Input.action_press(InputActions.MOVE_RIGHT)
	await _wait(60)
	Input.action_release(InputActions.MOVE_RIGHT)
	_check("walking into it from the side does nothing", player.mech == null and is_instance_valid(box) and not box._breaking)

	# jumping on it
	player.global_position = Vector2(box.position.x, box.position.y - 110.0)
	player.velocity = Vector2(0.0, 520.0)
	var opened := [""]
	box.opened.connect(func(k: String) -> void: opened[0] = k)
	await _wait(8)
	_check("coming down on it opens it", opened[0] == "mech", opened[0])
	_check("and bounces the player up", player.velocity.y < -200.0 or player.global_position.y < box.position.y - 80.0)
	await _wait(24)
	_check("the box breaks apart and the mech appears", player.mech != null)
	await _wait(30)
	_check("the box is gone after its frames", not is_instance_valid(box))
	player.global_position = Vector2(150.0, ground_y)       # back to the flat floor near the start
	player.velocity = Vector2.ZERO

	# ---- the mech
	var mech: Mech = player.mech
	_check("it is 1.5 times the player's size", is_equal_approx(player._body_rect.size.y, Player.BODY_SIZE.y * 1.5) and is_equal_approx(player._body_rect.size.x, Player.BODY_SIZE.x * 1.5), str(player._body_rect.size))
	_check("it survives five hits and starts undamaged", Mech.HITS_TO_DESTROY == 5 and mech.hits == 0 and mech.visual.damage == 0)
	var energy_bar: HealthBar = mech._energy_bar
	_check("the only bar is a blue energy bar with no word above it (no health or hits are shown)", not player._health_bar.visible and not player._energy_bar.visible and energy_bar.title == "" and energy_bar.fill_color.b > 0.8 and energy_bar.fill_color.r < 0.4)
	var bars := 0
	for n in player.get_children() + mech.get_children():
		if n is HealthBar and n.visible:
			bars += 1
	_check("and it is the only visible bar", bars == 1, str(bars))
	_check("the player's own picture is hidden", not player._visuals.visible)
	_check("the player sits in the cockpit (a picture of them is in the mech)", mech.visual._pilot != null and mech.visual._pilot.texture != null)
	await _wait(90)
	_check("it stands on the ground", player.is_on_floor())

	# the legs
	var vis: MechVisual = mech.visual
	var feet_ok := true
	for f in vis.feet:
		feet_ok = feet_ok and absf(f.y - ground_y) < 8.0
	_check("all four feet stand on the ground", feet_ok, str(vis.feet))
	var spread: float = vis.feet.map(func(f: Vector2) -> float: return f.x).max() - vis.feet.map(func(f: Vector2) -> float: return f.x).min()
	_check("the legs are spread out under the body", spread > 150.0, "%.0f px" % spread)

	# walking: the feet step (they do not just slide along)
	var start_x := player.global_position.x
	var feet_before := vis.feet.duplicate()
	Input.action_press(InputActions.MOVE_RIGHT)
	await _wait(25)
	var stepping := 0
	var max_lift := 0.0
	for k in 40:
		await process_frame
		for f in vis.feet:
			max_lift = maxf(max_lift, ground_y - f.y)
		for t in vis._step_t:
			if float(t) >= 0.0:
				stepping += 1
	Input.action_release(InputActions.MOVE_RIGHT)
	_check("walking: the feet take steps, lifting off the ground", stepping > 5 and max_lift > 14.0, "%d step frames, lift %.0f" % [stepping, max_lift])
	_check("and the mech moved on", player.global_position.x > start_x + 150.0)
	var moved := 0
	for i in 4:
		if absf(vis.feet[i].x - feet_before[i].x) > 30.0:
			moved += 1
	_check("every foot was put down somewhere new", moved == 4, str(moved))
	await _wait(40)

	player.global_position = Vector2(150.0, ground_y)
	player.velocity = Vector2.ZERO
	# the booster: a tap is a hop, a held button lifts the mech while there is energy (the bar drains), then it falls; the energy fills back in 3 s
	player.global_position = Vector2(150.0, ground_y)
	player.velocity = Vector2.ZERO
	await _wait(20)
	_check("the tank starts full", is_equal_approx(mech.energy.level, 1.0))
	var peak_tap := ground_y
	Input.action_press(InputActions.JUMP)
	await _wait(2)
	Input.action_release(InputActions.JUMP)
	var flame_seen := false
	for k in 90:
		await process_frame
		peak_tap = minf(peak_tap, player.global_position.y)
		flame_seen = flame_seen or vis._flame.visible
	await _wait(200)
	_check("the energy is full again after a hop", mech.energy.level > 0.99)
	var peak_hold := ground_y
	var feet_tucked := true
	var energy_at_half := 1.0
	Input.action_press(InputActions.JUMP)
	for k in 60:
		await process_frame
		peak_hold = minf(peak_hold, player.global_position.y)
		if k == 36:
			energy_at_half = mech.energy.level
			for f in vis.feet:
				feet_tucked = feet_tucked and ground_y - f.y > 18.0
	_check("holding jump uses energy: about half the %.1f s tank has gone after 0.6 s" % Mech.BURN_TIME, energy_at_half > 0.3 and energy_at_half < 0.7, "%.2f" % energy_at_half)
	var rose_while_held := ground_y - player.global_position.y
	_check("held, the booster lifts the mech well above a hop (%.0f vs %.0f px)" % [rose_while_held, ground_y - peak_tap], rose_while_held > ground_y - peak_tap + 60.0)
	var fell := false
	var apex_y := player.global_position.y
	for k in 150:
		await process_frame
		apex_y = minf(apex_y, player.global_position.y)
		if player.velocity.y > 100.0:
			fell = true
	_check("out of energy the mech drops, even with the button held", mech.energy.level < 0.25 and fell, "energy %.2f" % mech.energy.level)
	Input.action_release(InputActions.JUMP)
	_check("the flame shows on a jump", flame_seen)
	_check("in the air the legs curl up under the belly", feet_tucked)
	_check("it flew a long way up on one tank (%.0f px)" % (ground_y - apex_y), ground_y - apex_y > 220.0)
	await _wait(150)
	_check("it lands", player.is_on_floor())
	await _wait(30)
	var planted := true
	for f in vis.feet:
		planted = planted and absf(f.y - ground_y) < 8.0
	_check("after landing all four feet come down onto the floor (the legs do not stay curled)", planted, str(vis.feet))
	mech.energy.set_level(0.0)
	await _wait(90)
	_check("the energy fills back up progressively (about half after 1.5 s)", mech.energy.level > 0.35 and mech.energy.level < 0.65, "%.2f" % mech.energy.level)
	await _wait(100)
	_check("and is full after 3 s", mech.energy.level > 0.97, "%.2f" % mech.energy.level)

	# the gait, on a long flat floor of its own (the arena's floor has crates and steps on it): a diagonal trot, calm, with the body bobbing and the claws on the floor
	var flat := StaticBody2D.new()
	flat.collision_layer = PhysicsLayers.WORLD
	flat.collision_mask = 0
	var flat_shape := CollisionShape2D.new()
	var flat_rect := RectangleShape2D.new()
	flat_rect.size = Vector2(5000.0, 40.0)
	flat_shape.shape = flat_rect
	var flat_y := ground_y - 700.0
	flat.position = Vector2(2500.0, flat_y + 20.0)
	flat.add_child(flat_shape)
	root.add_child(flat)
	player.global_position = Vector2(600.0, flat_y - 4.0)
	player.velocity = Vector2.ZERO
	await _wait(60)
	Input.action_press(InputActions.MOVE_RIGHT)
	await _wait(30)
	var thin_frames := 0
	var pairs_mixed := 0
	var steps_started := 0
	var lowest_claw := 0.0
	var was_in_air := [false, false, false, false]
	var walk_frames := 120
	for k in walk_frames:
		await process_frame
		var in_air := 0
		for i in 4:
			var up: bool = float(vis._step_t[i]) >= 0.0
			in_air += 1 if up else 0
			steps_started += 1 if up and not was_in_air[i] else 0
			was_in_air[i] = up
			lowest_claw = maxf(lowest_claw, vis.feet[i].y - flat_y)
		thin_frames += 1 if in_air > 2 else 0
		# a diagonal trot: the legs in the air at one time are of one pair (0 and 2, or 1 and 3), never one of each
		var even_up: bool = float(vis._step_t[0]) >= 0.0 or float(vis._step_t[2]) >= 0.0
		var odd_up: bool = float(vis._step_t[1]) >= 0.0 or float(vis._step_t[3]) >= 0.0
		pairs_mixed += 1 if even_up and odd_up else 0
	Input.action_release(InputActions.MOVE_RIGHT)
	_check("the gait is a trot: two feet are on the ground all the time (bar a frame or two as the pairs hand over)", thin_frames <= 2, "%d frames with fewer" % thin_frames)
	_check("the two pairs of legs take turns (never one leg of each pair in the air together, bar a frame or two)", pairs_mixed <= 2, "%d frames mixed" % pairs_mixed)
	var steps_per_second := float(steps_started) / (float(walk_frames) / 60.0) / 4.0
	_check("each foot steps at a calm rate (under 3.5 steps a second at full speed; it was nearly 4)", steps_per_second > 1.5 and steps_per_second < 3.5, "%.1f steps/s per foot" % steps_per_second)
	_check("no foot is ever below the floor", lowest_claw < 3.0, "%.1f px" % lowest_claw)
	await _wait(60)
	var square := true
	for i in 4:
		square = square and absf(vis.feet[i].x - (player.global_position.x + MechVisual.STANCE[i])) < MechVisual.SETTLE_OFFSET + 2.0
	_check("standing again, the feet settle square under their stances", square)
	flat.queue_free()
	player.global_position = Vector2(150.0, ground_y)
	player._peak_y = ground_y       # (a teleport, not a fall)
	player.velocity = Vector2.ZERO
	await _wait(60)

	# hovering: on a narrow platform not all the legs have a floor, so the booster burns low (just for show) and those legs curl up
	var plat := StaticBody2D.new()
	plat.collision_layer = PhysicsLayers.WORLD
	plat.collision_mask = 0
	var ps := CollisionShape2D.new()
	var pr := RectangleShape2D.new()
	pr.size = Vector2(130.0, 24.0)
	ps.shape = pr
	plat.position = Vector2(400.0, ground_y - 330.0 + 12.0)
	plat.add_child(ps)
	root.add_child(plat)
	player.global_position = Vector2(400.0, ground_y - 330.0 - 4.0)
	player.velocity = Vector2.ZERO
	await _wait(60)
	_check("on a narrow platform it is hovering: the booster burns low", player.is_on_floor() and vis.hovering and vis._flame.visible and not mech.thrusting, "hovering %s" % vis.hovering)
	var curled := 0
	for f in vis.feet:
		if f.y < ground_y - 330.0 - 8.0:
			curled += 1
	_check("and the legs with no floor are curled up under the belly", curled >= 2, "%d" % curled)
	player.global_position = Vector2(150.0, ground_y)
	player.velocity = Vector2.ZERO
	await _wait(60)
	_check("back on wide ground it is not hovering and the flame is off", not vis.hovering and not vis._flame.visible)
	plat.queue_free()
	await _wait(10)

	# steps: two steps of one tile each, climbed by walking
	var steps := StaticBody2D.new()
	steps.collision_layer = PhysicsLayers.WORLD
	steps.collision_mask = 0
	player.global_position = Vector2(150.0, ground_y)
	player.velocity = Vector2.ZERO
	await _wait(30)
	var x0 := player.global_position.x + 260.0
	for k in 2:
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(110.0, 70.0 * (k + 1))
		shape.shape = rect
		shape.position = Vector2(x0 + k * 110.0, ground_y - 35.0 * (k + 1))
		steps.add_child(shape)
	root.add_child(steps)
	var before_x := player.global_position.x
	Input.action_press(InputActions.MOVE_RIGHT)
	var best_y := ground_y
	var jumped := false
	var longest_leg := 0.0
	for k in 130:
		await process_frame
		best_y = minf(best_y, player.global_position.y)
		for i in 4:
			longest_leg = maxf(longest_leg, vis.feet[i].distance_to(vis.hip_world(i)))
	Input.action_release(InputActions.MOVE_RIGHT)
	_check("the legs climb a one-tile step and then a two-tile step without a jump", ground_y - best_y > 120.0 and player.global_position.x > x0 + 60.0, "x %.0f -> %.0f, highest %.0f px" % [before_x, player.global_position.x, ground_y - best_y])
	_check("climbing, no leg stretches beyond its limit (%.0f px)" % longest_leg, longest_leg <= MechVisual.MAX_REACH + 0.5)
	steps.queue_free()
	player.global_position = Vector2(150.0, ground_y)
	player.velocity = Vector2.ZERO
	await _wait(60)

	# weapons
	var bro := _bro(Vector2(player.global_position.x + 440.0, ground_y))
	main.add_child(bro)
	await _wait(10)
	var hp := bro.health
	player._facing = 1
	var energy_before := mech.energy.level
	Input.action_press(InputActions.ATTACK_HEAVY)
	await _wait(6)
	_check("the laser hurts what is in front of it", bro.health < hp, "%d -> %d" % [hp, bro.health])
	_check("the laser's reach is limited", mech.LASER_RANGE < 900.0)
	var beam_seen := false
	for n in main.get_children():
		beam_seen = beam_seen or n is LaserBeam
	_check("a beam is drawn", beam_seen)
	var flares := 0
	var ember_nodes := 0
	for n in main.get_children():
		if n is LaserBeam:
			for c in n.get_children():
				if c is Sprite2D and (c as Sprite2D).texture.resource_path.ends_with("laser_orb.png"):
					flares += 1
				if c is CPUParticles2D:
					ember_nodes += 1
	_check("the laser is blue and glows: a flare at both ends, blue embers and sparks along it", LaserBeam.BLUE.b > 0.9 and LaserBeam.BLUE.r < 0.4 and flares >= 2 and ember_nodes >= 1, "%d flares, %d particle emitters" % [flares, ember_nodes])
	await _wait(54)
	_check("the laser stays on while the button is held, and uses energy", mech.lasing and mech.energy.level < energy_before - 0.1, "energy %.2f -> %.2f" % [energy_before, mech.energy.level])
	var held_beams := 0
	for n in main.get_children():
		held_beams += 1 if n is LaserBeam else 0
	_check("one beam is drawn all the time it is held (not a new one each step)", held_beams == 1, str(held_beams))
	Input.action_release(InputActions.ATTACK_HEAVY)
	await _wait(60)
	_check("letting go turns it off and the beam fades away", not mech.lasing and main.get_children().all(func(n: Node) -> bool: return not (n is LaserBeam)))
	player.attack_light()
	await _wait(3)
	var missiles := 0
	for n in main.get_children():
		if n is MechMissile:
			missiles += 1
	_check("the missile turret launches a missile", missiles == 1)
	_check("then it needs %.0f s to fire the next (fixed)" % Mech.MISSILE_COOLDOWN, Mech.MISSILE_COOLDOWN == 3.0 and mech._missile_timer > Mech.MISSILE_COOLDOWN - 0.2)
	var detailed := false
	for n in main.get_children():
		if n is MechMissile:
			var sprites := 0
			var emitters := 0
			for c in n.get_children():
				sprites += 1 if c is Sprite2D else 0
				emitters += 1 if c is CPUParticles2D else 0
			detailed = sprites >= 3 and emitters >= 2 and n._flame != null and n._glow != null
	_check("the missile has an exhaust flame, a glow, sparks and a smoke trail", detailed)
	await _wait(60)
	player.attack_light()
	_check("a second press after one second does not fire (the wait is not restarted either)", mech._missile_timer < Mech.MISSILE_COOLDOWN - 0.9)
	await _wait(150)
	_check("the missile blows up the Bro", not is_instance_valid(bro) or bro.health == 0 or bro._dead)
	var before: Vector2 = mech.visual.missile_muzzle()
	_check("both turrets have a muzzle in front of the mech", mech.visual.laser_muzzle().x > player.global_position.x and before.x > player.global_position.x - 40.0)

	# damage: any hit counts the same; each one shows on the mech; the fifth destroys it and the player is on foot again
	await _wait(80)
	var ph := player.health
	var vis2: MechVisual = mech.visual
	var took := player.take_damage(1)
	_check("a hit counts one, the player is untouched", took and mech.hits == 1 and player.health == ph, "hits %d, player %d" % [mech.hits, player.health])
	_check("while hit it is briefly safe", not player.take_damage(10) and mech.hits == 1)
	_check("hit 1: cracks on the mech and the glass", vis2._cracks.visible and vis2._glass_cracks.visible and vis2._broken == -1)
	var smoke_on := false
	await _wait(80)
	player.take_damage(50)
	await _wait(5)
	var pieces := 0
	for n in main.get_children():
		if n is Debris:
			pieces += 1
	_check("hit 2: a leg breaks (a big hit counts the same as a small one)", mech.hits == 2 and vis2._broken == MechVisual.BROKEN_LEG and pieces >= 3, "hits %d, %d pieces fell" % [mech.hits, pieces])
	var tip_gap := vis2.break_tip.distance_to(vis2.hip_world(MechVisual.BROKEN_LEG))
	_check("the broken leg hangs from the hip with a torn end", tip_gap > 30.0 and tip_gap < 110.0, "%.0f" % tip_gap)
	_check("and nothing is smoking yet", not vis2._smoke[0].emitting)
	await _wait(80)
	player.take_damage(5)
	await _wait(5)
	for sp in vis2._smoke:
		smoke_on = smoke_on or sp.emitting
	_check("hit 3: smoke comes from the mech", mech.hits == 3 and smoke_on and not vis2._fires[0].visible)
	await _wait(80)
	player.take_damage(100)
	await _wait(5)
	_check("hit 4: the mech is on fire and sooty", mech.hits == 4 and vis2._fires.all(func(f: Sprite2D) -> bool: return f.visible) and vis2._soot.visible)
	_check("still the player's own health is untouched", player.health == ph and player.mech != null)
	await _wait(80)
	player.take_damage(1)
	await _wait(3)
	_check("hit 5: the mech is destroyed and the player is out of it", player.mech == null and not is_instance_valid(mech))
	_check("the player lost nothing", player.health == ph)
	_check("they are normal sized again, and visible", is_equal_approx(player._body_rect.size.y, Player.BODY_SIZE.y) and player._visuals.visible and player._health_bar.visible)
	var wreck_seen := false
	var parts := 0
	for n in main.get_children():
		wreck_seen = wreck_seen or n is Explosion
		if n is Debris:
			parts += 1
	_check("there was an explosion and the parts flew", wreck_seen and parts >= 8, "%d parts" % parts)

	# a second power-up, then a deadly pit takes the mech and the player
	player.board_mech()
	await _wait(5)
	_check("a power-up can be taken again", player.mech != null)
	player.board_mech()
	_check("taking another while in the mech does nothing", player.get_children().filter(func(n: Node) -> bool: return n is Mech).size() == 1)
	player.fall_in_pit()
	_check("falling into a pit ends the ride (and the player's life)", player.mech == null and player.health == 0)

	main.queue_free()
	await _wait(3)
	print("ALL PASS" if ok else "SOME FAILED")
	quit(0 if ok else 1)
