extends SceneTree
## The creatures of the deadly pits (PitCreature): the poisonous puffer fish and poison gas of the toxic waste, the lava balls of
## the lava, the glowing eels and glow of the nuclear waste (the piranhas have their own test, piranha_test.gd). They hide, leap,
## animate in their own way, hurt for their own share of health, are destroyed by one hit and come back, and the puffer's poison
## hurts for a few seconds without ever killing. Exits non-zero on failure.
## Run: godot_console --headless --fixed-fps 60 --path . --script res://tools/tests/pit_creature_test.gd

const KINDS := {"toxic_waste": "puffer", "lava": "lava_ball", "nuclear_waste": "eel", "piranha_tank": "piranha"}

var ok := true
var world: Node2D
var player: Player


func _check(name: String, cond: bool, detail := "") -> void:
	print(("PASS  " if cond else "FAIL  "), name, "  ", detail)
	if not cond:
		ok = false


func _initialize() -> void:
	_main()


func _wait(frames: int) -> void:
	for i in frames:
		await process_frame


func _box(x0: float, x1: float, top: float) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = Player.LAYER_WORLD
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(x1 - x0, 600)
	shape.shape = rect
	body.position = Vector2((x0 + x1) / 2.0, top + 300)
	body.add_child(shape)
	world.add_child(body)


func _creatures() -> Array[PitCreature]:
	var out: Array[PitCreature] = []
	for n in get_nodes_in_group("enemies"):
		if n is PitCreature:
			out.append(n)
	return out


func _of(kind: String) -> PitCreature:
	for c in _creatures():
		if c.species_name == KINDS[kind]:
			return c
	return null


func _drop_world() -> void:
	world.queue_free()
	await _wait(3)


func _make_world(kind: String) -> void:
	world = Node2D.new()
	root.add_child(world)
	_box(-800, 0, 0)
	_box(420, 1200, 0)
	_box(0, 420, 300)
	_box(180, 240, 0)
	world.add_child(PitHazard.new(kind, Rect2(0, 90, 420, 210)))
	player = Player.new()
	player.position = Vector2(210, 0)
	player.spawn = Vector2(-100, 0)
	world.add_child(player)


func _main() -> void:
	InputSetup.register()
	await process_frame
	# ---- the art: every creature has all its frames
	for kind in SpriteLibrary.PIT_CREATURE_PARTS:
		var missing := []
		for part in SpriteLibrary.PIT_CREATURE_PARTS[kind]:
			if SpriteLibrary.pit(kind, part) == null:
				missing.append(part)
		_check("the %s creature has all its frames" % kind, missing.is_empty(), str(missing))
	for species in PitCreature.SPECIES:
		var s: Dictionary = PitCreature.SPECIES[species]
		var parts_ok := true
		for part in s["parts"]:
			if SpriteLibrary.pit(str(s["liquid"]), str(part)) == null:
				parts_ok = false
		_check("the %s species lists frames that exist" % species, parts_ok and PitHazard.CREATURES[s["liquid"]] == species)

	# ---- each pit kind holds its own creature, and the toxic waste and nuclear waste have their effects
	for kind in KINDS:
		_make_world(kind)
		await _wait(5)
		var found := _creatures()
		_check("a %s pit holds %s creatures" % [kind, KINDS[kind]], found.size() >= 1 and found.all(func(c: PitCreature) -> bool: return c.species_name == KINDS[kind]), str(found.size()))
		var gas := 0
		var radiance := 0
		for pit in world.get_children():
			if pit is PitHazard:
				for n in pit.find_children("*", "CPUParticles2D", true, false):
					if (n as CPUParticles2D).color == PitHazard.GAS_COLOR:
						gas += 1
				for n in pit.find_children("*", "Sprite2D", true, false):
					if (n as Sprite2D).scale.y > 4.0:
						radiance += 1
		_check("the toxic waste gives off poison gas, no other pit does", (gas == 1) == (kind == "toxic_waste"), "%d gas clouds" % gas)
		_check("the nuclear waste has its extra radiance, no other pit does", (radiance == 1) == (kind == "nuclear_waste"), "%d" % radiance)
		var c := _creatures()[0]
		_check("a creature hides under the liquid at first", c.state == PitCreature.State.LURK and c.hurtbox().size == Vector2.ZERO and c._body.texture == c._frames[0])
		# leaping: the animation is the species' own
		c._start_leap(null)
		var seen := {}
		var last_inflated := 0
		var total := 0
		for i in 50:
			await _wait(1)
			seen[c._body.texture] = true
			total += 1
			if c._body.texture == c._frames[c._frames.size() - 1]:
				last_inflated += 1
		match KINDS[kind]:
			"puffer":
				_check("the puffer inflates as it leaps (it shows its puffed-up frame most of the time)", seen.size() >= 2 and last_inflated > total / 3, "%d of %d frames puffed" % [last_inflated, total])
			"lava_ball":
				_check("the fireball flickers through its frames", seen.size() >= 3, str(seen.size()))
			"eel":
				_check("the eel swims through its frames", seen.size() >= 3, str(seen.size()))
			"piranha":
				_check("the piranha snaps its jaws", seen.size() >= 2, str(seen.size()))
		_check("a creature leaping is out of the liquid and is a target", c.state == PitCreature.State.LEAP or c.state == PitCreature.State.LURK)
		await _drop_world()

	# ---- damage: each species takes its own share of the player's health, and the puffer poisons
	var damage_of := {"puffer": 0.08, "lava_ball": 0.15, "eel": 0.12}
	for species in damage_of:
		var kind := ""
		for k in KINDS:
			if KINDS[k] == species:
				kind = k
		_make_world(kind)
		await _wait(5)
		var c := _of(kind)
		# a leap that is at its top, right where the player stands
		c.state = PitCreature.State.LEAP
		c._leap_from = player.global_position.x
		c._leap_to = player.global_position.x
		c._leap_height = 200.0
		c._leap_time = 10.0
		c._t = 5.0
		await _wait(3)
		var want := roundi(Player.MAX_HEALTH * float(damage_of[species]))
		_check("a %s takes %d%% of the player's health" % [species, int(float(damage_of[species]) * 100)], player.health == player.max_health - want, "health %d" % player.health)
		_check("and only the puffer poisons", player.is_poisoned() == (species == "puffer"))
		if species == "puffer":
			for other in _creatures():   # they all go back under and stay there, so only the poison hurts from now on
				other._hide_and_lurk()
				other._timer = 1.0e9
			player.global_position = Vector2(210, 0)   # the bite knocked the player about: back onto the pillar
			player.velocity = Vector2.ZERO
			var after_bite := player.health
			await _wait(int(Player.POISON_TICK_TIME * 60.0 * 5.0) + 30)
			_check("the poison keeps hurting a few times", player.health < after_bite and player.health >= 1, "%d -> %d" % [after_bite, player.health])
			_check("and then it wears off", not player.is_poisoned() and player._visuals.modulate.r > 0.99, "poisoned %s" % player.is_poisoned())
			# poison never kills
			player.health = 3
			player.apply_poison(6, 0.5)
			await _wait(int(Player.POISON_TICK_TIME * 60.0 * 7.0))
			_check("poison never takes the last health point", player.health == 1, str(player.health))
			player.fall_in_pit()
			_check("a player in a pit is not poisoned any more", not player.is_poisoned())
		await _drop_world()

	# ---- a lava ball only jumps straight up and down, from its own spot
	_make_world("lava")
	await _wait(5)
	var ball := _of("lava")
	var home := ball.home_x
	ball._start_leap(null)
	var xs := {}
	var highest := 1.0e9
	var rotations := {}
	for i in 60:
		await _wait(1)
		xs[snappedf(ball.global_position.x, 0.5)] = true
		highest = minf(highest, ball.global_position.y)
		rotations[snappedf(ball.rotation, 0.2)] = true
	_check("it never moves sideways", xs.size() == 1 and xs.has(home), str(xs.keys()))
	_check("it jumps well above the liquid", highest < ball.surface_y - 120.0, "top at %.0f, surface %.0f" % [highest, ball.surface_y])
	_check("and its flame trails behind it (it points up on the way up and down on the way down)", rotations.has(snappedf(-PI / 2.0, 0.2)) or rotations.has(snappedf(PI / 2.0, 0.2)))
	ball._hide_and_lurk()
	var appearances := {"peek": 0, "leap": 0}
	for i in 12:
		ball._timer = 0.0
		ball._appear()
		appearances["peek" if ball.state == PitCreature.State.PEEK else "leap"] += 1
		ball._hide_and_lurk()
	_check("it never just peeks out, it always jumps", appearances["peek"] == 0 and appearances["leap"] == 12, str(appearances))

	# ---- a thrown object burns up in a fireball, which cannot be hurt
	ball.state = PitCreature.State.LEAP
	ball._leap_from = home
	ball._leap_to = home
	ball._leap_height = 200.0
	ball._leap_time = 10.0
	ball._t = 5.0
	await _wait(2)
	var destroyed := [false]
	ball.defeated.connect(func() -> void: destroyed[0] = true)
	var thrown := Projectile.launch(world, "book", ball.global_position + Vector2(-60, 0), 1, Vector2.ZERO)
	await _wait(10)
	_check("a thrown object that flies into a fireball burns up", not thrown.is_in_group("projectiles") and thrown._done)
	_check("and the fireball is not put out", not destroyed[0] and ball.state != PitCreature.State.DEAD)
	ball.take_hit(1.0)
	_check("nothing hurts it", ball.state != PitCreature.State.DEAD and not destroyed[0])
	await _wait(60)
	_check("the burnt object is gone", not is_instance_valid(thrown))
	await _drop_world()

	# ---- burning: like poison, a quarter as fast for four times as long, and it halves the range of throws
	_make_world("lava")
	await _wait(5)
	var fire := _of("lava")
	fire.state = PitCreature.State.LEAP
	fire._leap_from = player.global_position.x
	fire._leap_to = player.global_position.x
	fire._leap_height = 200.0
	fire._leap_time = 10.0
	fire._t = 5.0
	await _wait(3)
	var health_after_hit := player.health
	_check("a lava ball takes 15% and sets the player on fire", health_after_hit == player.max_health - 15 and player.is_burning())
	_check("a burning player is tinted orange and has flames", player._visuals.modulate.r > 0.99 and player._visuals.modulate.b < 0.6 and player._flames != null and player._flames.emitting)
	_check("burning halves the range of a throw", is_equal_approx(player.throw_range_scale(), 0.5))
	var normal := Projectile.launch(world, "book", Vector2(0, -400), 1, Vector2.ZERO)
	var short := Projectile.launch(world, "book", Vector2(0, -400), 1, Vector2.ZERO, player.throw_range_scale())
	var range_of := func(p: Projectile) -> float:
		return p.velocity.x * (2.0 * -p.velocity.y / Projectile.GRAVITY)   # flat-ground range of the arc
	_check("(the burning throw goes half as far)", is_equal_approx(range_of.call(short) / range_of.call(normal), 0.5), "%.0f vs %.0f" % [range_of.call(short), range_of.call(normal)])
	normal.queue_free()
	short.queue_free()
	for other in _creatures():
		other._hide_and_lurk()
		other._timer = 1.0e9
	player.global_position = Vector2(210, 0)
	player.velocity = Vector2.ZERO
	await _wait(int(Player.POISON_TICK_TIME * 60.0 * 8.0))
	var after_half := player.health
	_check("the burn hurts a little at a time (1% a tick)", after_half < health_after_hit and health_after_hit - after_half <= 9, "%d -> %d after 8 ticks" % [health_after_hit, after_half])
	await _wait(int(Player.POISON_TICK_TIME * 60.0 * 9.0))
	_check("and goes on for 16 ticks, about 11 seconds, then it is over", not player.is_burning() and player.health == health_after_hit - 16 and player.throw_range_scale() == 1.0 and not player._flames.emitting, "health %d, burning %s" % [player.health, player.is_burning()])
	player.health = 3
	player.apply_burn(10, 0.5)
	await _wait(int(Player.POISON_TICK_TIME * 60.0 * 11.0))
	_check("burning never takes the last health point either", player.health == 1, str(player.health))
	await _drop_world()

	# ---- an object thrown into a pit sinks and never lies at the bottom
	_make_world("toxic_waste")
	await _wait(5)
	for x in [10.0, 100.0, 410.0]:   # at the walls and in the middle of the pit
		var sinking := Projectile.launch(world, "paintbrush", Vector2(x, -150.0), 1, Vector2.ZERO)
		sinking.velocity = Vector2.ZERO
		await _wait(70)
		_check("an object dropped into a pit (x=%d) sinks out of sight and is gone" % int(x), not is_instance_valid(sinking) or sinking._done)
		_check("and does not lie at the bottom", not is_instance_valid(sinking) or not sinking.is_in_group("landed_projectiles"))
	await _drop_world()

	# ---- one hit destroys the other creatures, and they return at the same spot
	_make_world("toxic_waste")
	await _wait(5)
	var pufferfish := _of("toxic_waste")
	var spot := pufferfish.home_x
	pufferfish.state = PitCreature.State.PEEK
	pufferfish._t = 0.5
	pufferfish.global_position = Vector2(spot, pufferfish.surface_y - 30.0)
	var gone := [false]
	pufferfish.defeated.connect(func() -> void: gone[0] = true)
	pufferfish.take_hit(0.001)
	await _wait(5)
	_check("one thrown object destroys a puffer fish", gone[0] and pufferfish.state == PitCreature.State.DEAD)
	pufferfish._timer = 0.1
	await _wait(12)
	_check("and it comes back at the same spot", pufferfish.state != PitCreature.State.DEAD and is_equal_approx(pufferfish.home_x, spot))
	await _drop_world()

	print("ALL PASS" if ok else "SOME FAILED")
	quit(0 if ok else 1)
