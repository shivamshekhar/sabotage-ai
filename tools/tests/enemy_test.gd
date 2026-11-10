extends SceneTree
## AI Bro enemies, thrown objects and spike pits. Exits non-zero on failure.
## Run: godot_console --headless --fixed-fps 60 --path . --script res://tools/tests/enemy_test.gd

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


## A flat world: one long floor whose top is at y = 0, the player on it at x = px.
func _flat_world(px: float) -> void:
	world = Node2D.new()
	root.add_child(world)
	var floor_body := StaticBody2D.new()
	floor_body.collision_layer = Player.LAYER_WORLD
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(12000, 200)
	shape.shape = rect
	floor_body.position = Vector2(0, 100)
	floor_body.add_child(shape)
	world.add_child(floor_body)
	player = Player.new()
	player.position = Vector2(px, 0)
	player.spawn = player.position
	world.add_child(player)


func _bro(x: float) -> AIBro:
	var b := AIBro.new()
	b.position = Vector2(x, 0)
	world.add_child(b)
	return b


func _main() -> void:
	InputSetup.register()
	await _wait(2)

	# ---- numbers
	_check("a Bro has 20% of the player's health", AIBro.starting_health() == roundi(Player.MAX_HEALTH * 0.2), str(AIBro.starting_health()))
	_check("a Bro's hit takes 10% of the player's health", AIBro.contact_damage() == roundi(Player.MAX_HEALTH * 0.1), str(AIBro.contact_damage()))
	_check("spikes take 20% of the player's health", Player.hazard_damage() == roundi(Player.MAX_HEALTH * 0.2), str(Player.hazard_damage()))
	_check("a thrown object takes 50% of a Bro's health", Projectile.HIT_FRACTION == 0.5)

	# ---- patrol
	_flat_world(-3000.0)
	var bro := _bro(0.0)
	await _wait(5)
	_check("the Bro starts with full health", bro.health == bro.max_health and bro.max_health == AIBro.starting_health())
	var lo := 1e9
	var hi := -1e9
	for i in 400:
		await _wait(1)
		lo = minf(lo, bro.global_position.x)
		hi = maxf(hi, bro.global_position.x)
	_check("it paces back and forth", hi - lo > 100.0, "range %.0f px" % (hi - lo))
	_check("and stays near its home", lo >= -AIBro.PATROL_RADIUS - 30.0 and hi <= AIBro.PATROL_RADIUS + 30.0, "%.0f .. %.0f" % [lo, hi])
	_check("it is still patrolling (nobody to chase)", bro.state == AIBro.State.PATROL)

	# ---- it only chases what it is facing
	player.global_position = Vector2(bro.global_position.x + 300.0, 0.0)
	player.velocity = Vector2.ZERO
	bro._dir = -1   # facing away from the player
	await _wait(3)
	_check("facing away: no chase", bro.state == AIBro.State.PATROL)
	bro._dir = 1
	await _wait(3)
	_check("facing the player within range: it chases", bro.state == AIBro.State.CHASE)

	# ---- and hits when it arrives
	var damage_log: Array[int] = []
	player.health_changed.connect(func(current: int, _m: int) -> void: damage_log.append(current))
	await _wait(150)
	_check("it reached the player and hit them for 10%", damage_log.size() > 0 and damage_log[0] == Player.MAX_HEALTH - AIBro.contact_damage(), str(damage_log))
	world.queue_free()
	await _wait(3)

	# ---- thrown objects fly in a parabola and hit for 50%
	_flat_world(0.0)
	player._facing = 1
	var target := _bro(0.0)
	target.set_physics_process(false)   # keep it still so we can aim
	# where the arc comes down through the Bro's body (60 px above its feet)
	var a := deg_to_rad(Projectile.THROW_ANGLE_DEGREES)
	var vx := Projectile.THROW_SPEED * cos(a)
	var vy := -Projectile.THROW_SPEED * sin(a)
	var g := Projectile.GRAVITY
	var y0 := Player.THROW_HAND.y
	var want_y := -60.0
	var t_hit := (-vy + sqrt(vy * vy - 2.0 * g * (y0 - want_y))) / g
	target.global_position = Vector2(Player.THROW_HAND.x + vx * t_hit, 0.0)
	await _wait(3)
	player.attack_light()
	_check("the wind-up pose is shown first (nothing thrown yet)", player._pose_state(0.0) == &"throw_windup" and get_nodes_in_group("projectiles").is_empty())
	var waited := 0
	while get_nodes_in_group("projectiles").is_empty() and waited < 30:
		await _wait(1)
		waited += 1
	var shots := get_nodes_in_group("projectiles")
	_check("attack_light throws an object after the wind-up", shots.size() == 1 and waited <= ceili(Player.THROW_WINDUP * 60.0) + 2, "%d frames" % waited)
	_check("then the release pose is shown", player._pose_state(0.0) == &"throw_release")
	var ys: Array[float] = []
	for i in 80:
		await _wait(1)
		if shots.is_empty() or not is_instance_valid(shots[0]):
			break
		ys.append(shots[0].global_position.y)
	var peak: float = ys.min() if not ys.is_empty() else 0.0
	_check("the object rises then falls (a parabola)", ys.size() > 10 and peak < ys[0] - 20.0 and ys[ys.size() - 1] > peak + 5.0,
		"%d samples, start %.0f peak %.0f end %.0f" % [ys.size(), ys[0] if not ys.is_empty() else 0.0, peak, ys[ys.size() - 1] if not ys.is_empty() else 0.0])
	# second differences of a parabola are constant: check mid-flight
	if ys.size() > 12:
		var d1 := ys[8] - 2.0 * ys[7] + ys[6]
		var d2 := ys[11] - 2.0 * ys[10] + ys[9]
		_check("constant vertical acceleration (ballistic)", absf(d1 - d2) < 0.5 and d1 > 0.0, "%.2f vs %.2f" % [d1, d2])
	_check("the hit took 50% of the Bro's health", target.health == target.max_health - roundi(target.max_health * 0.5), str(target.health))
	await _wait(25)   # cooldown
	_check("the throwing pose ends", player._pose_state(0.0) != &"throw_release" and player._pose_state(0.0) != &"throw_windup")
	player.attack_light()
	var second_throw_hits := false
	for i in 80:
		await _wait(1)
		if target.health == 0:
			second_throw_hits = true
			break
	_check("a second hit defeats it", second_throw_hits)
	await _wait(40)
	_check("and it is gone", not is_instance_valid(target) or target.is_queued_for_deletion())
	world.queue_free()
	await _wait(3)

	# ---- a thrown object lands, lies there for REST_TIME, then blinks and goes
	_flat_world(0.0)
	player._facing = 1
	player.attack_light()
	var landed_at := -1
	var obj: Node2D = null
	var first_blink := -1
	var gone_at := -1
	var p1 := Vector2.ZERO
	var moved := false
	for fr in 400:
		await _wait(1)
		if landed_at < 0:
			var lying := get_nodes_in_group("landed_projectiles")
			if lying.size() == 1:
				obj = lying[0]
				landed_at = fr
				p1 = obj.global_position
				_check("it rests on the ground (not in the air)", absf(obj.global_position.y) < 40.0, "y=%.0f" % obj.global_position.y)
			continue
		if not is_instance_valid(obj) or obj.is_queued_for_deletion():
			gone_at = fr - landed_at
			break
		if obj.global_position != p1:
			moved = true
		if first_blink < 0 and obj.get_child(0).modulate.a < 0.99:
			first_blink = fr - landed_at
	_check("a missed throw lands on the floor", landed_at >= 0)
	_check("it lies still on the floor", not moved)
	var rest_frames := int(Projectile.REST_TIME * 60.0)
	_check("it stays fully visible for REST_TIME, then starts to blink", absi(first_blink - rest_frames) <= 8, "blink after %d frames, expected about %d" % [first_blink, rest_frames])
	var total := int((Projectile.REST_TIME + Projectile.BLINK_TIME) * 60.0)
	_check("and disappears after the blinking", absi(gone_at - total) <= 12, "gone after %d frames, expected about %d" % [gone_at, total])
	world.queue_free()
	await _wait(3)

	# ---- shallow floor spikes do not hurt a Bro (test level has a one-deep spike strip)
	OS.set_environment("SABOTAGE_LEVEL", "test")
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _wait(5)
	var shallow := AIBro.new()
	shallow.position = Vector2(16.5 * 70.0, 13.0 * 70.0)
	main.add_child(shallow)
	await _wait(150)
	_check("floor spikes don't hurt a Bro", shallow.health == shallow.max_health and is_instance_valid(shallow), str(shallow.health))
	main.queue_free()
	await _wait(5)

	# ---- deep spike pits kill whoever falls in (Level 1's first pit: columns 14 to 16)
	OS.set_environment("SABOTAGE_LEVEL", "1")
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _wait(5)
	var level: Level
	for n in main.get_children():
		if n is Player:
			player = n
		elif n is Level:
			level = n
	var pit_bro := AIBro.new()
	pit_bro.position = Vector2(15.5 * 70.0, 26.0 * 70.0 - 30.0)
	level.add_child(pit_bro)
	await _wait(90)
	_check("a Bro that falls into a deep spike pit dies", not is_instance_valid(pit_bro) or pit_bro.health == 0)

	var causes: Array[String] = []
	player.died.connect(func(c: String) -> void: causes.append(c))
	player.global_position = Vector2(13.5 * 70.0, 26.0 * 70.0)   # on the lip of the pit
	player.velocity = Vector2.ZERO
	await _wait(30)
	_check("standing on the lip of a deep pit is safe", causes.is_empty(), str(causes))
	player.global_position = Vector2(15.5 * 70.0, 26.0 * 70.0 + 40.0)   # dropped in
	player.velocity = Vector2.ZERO
	await _wait(32)   # about 25 frames to fall, then it lands and starts blinking
	_check("a player in a deadly pit falls all the way down first", player.global_position.y > 28.0 * 70.0 - 20.0, "y=%.0f" % player.global_position.y)
	_check("with no game over yet, and no health left", causes.is_empty() and player.health == 0, "%s health %d" % [causes, player.health])
	_check("and blinks while it waits", player._visuals.modulate.a < 1.0 or player._visuals._blink_tween != null)
	Input.action_press("jump")
	await _wait(8)
	Input.action_release("jump")
	_check("and cannot jump out", player.global_position.y > 28.0 * 70.0 - 20.0)
	await _wait(int(Player.PIT_DEATH_DELAY * 60.0) + 10)
	_check("the player that falls into a deep spike pit dies", causes == ["pit"], str(causes))
	_check("and is back at the respawn point with full health", player.global_position.distance_to(player.spawn) < 5.0 and player.health == Player.MAX_HEALTH)

	print("ALL PASS" if ok else "SOME FAILED")
	quit(0 if ok else 1)
