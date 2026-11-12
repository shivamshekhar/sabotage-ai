extends SceneTree
## AI Bro movement and cost: never walks off a ledge, stops at an edge while the player is out of reach,
## hops small gaps, climbs steps, sleeps when far away, and leaves nothing behind when it dies.
## Exits non-zero on failure.
## Run: godot_console --headless --fixed-fps 60 --path . --script res://tools/tests/enemy_ai_test.gd

# MAX_LEAK: how many more nodes or objects than at the start are tolerated after 200 Bros have been created and
# killed (a few frames of fading tweens and timers may still be alive). A real leak is hundreds.
const MAX_LEAK := 10

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


## A world made of solid blocks: each [x0, x1, top_y] is a column of ground whose surface is at top_y.
func _make_world(blocks: Array, player_x: float, player_y: float) -> void:
	world = Node2D.new()
	root.add_child(world)
	for b in blocks:
		_box(b[0], b[1], b[2])
	player = Player.new()
	player.position = Vector2(player_x, player_y)
	player.spawn = player.position
	world.add_child(player)


func _bro(x: float, y: float) -> AIBro:
	var b := AIBro.new()
	b.position = Vector2(x, y)
	world.add_child(b)
	return b


func _drop_world() -> void:
	world.queue_free()
	await _wait(3)


func _main() -> void:
	InputSetup.register()
	await _wait(2)

	# ---- patrolling next to a ledge: it turns round, it never falls
	_make_world([[-2000, 500, 0]], -1500.0, 0.0)
	var bro := _bro(470.0, 0.0)
	bro._home_x = 470.0
	var fell := false
	var max_x := -1e9
	for i in 600:
		await _wait(1)
		max_x = maxf(max_x, bro.global_position.x)
		if bro.global_position.y > 5.0:
			fell = true
	_check("a patrolling Bro never walks off a ledge", not fell and max_x <= 500.0 + 1.0, "y=%.0f max x=%.0f" % [bro.global_position.y, max_x])
	await _drop_world()

	# ---- chasing towards a wide gap: it stops at the edge, then paces again once the player is out of range
	_make_world([[-2000, 500, 0], [680, 2000, 0]], 700.0, 0.0)
	bro = _bro(430.0, 0.0)
	bro._home_x = 430.0
	bro._dir = 1
	var started_chase := false
	fell = false
	for i in 240:
		await _wait(1)
		if bro.state == AIBro.State.CHASE:
			started_chase = true
		if bro.global_position.y > 5.0:
			fell = true
	_check("it chases the player it sees across a gap...", started_chase)
	_check("...but stops at the edge instead of falling in", not fell and bro.global_position.x <= 500.0 + 1.0, "x=%.0f y=%.0f" % [bro.global_position.x, bro.global_position.y])
	player.global_position = Vector2(1900.0, 0.0)   # the player leaves
	player.velocity = Vector2.ZERO
	var min_x := 1e9
	max_x = -1e9
	for i in 400:
		await _wait(1)
		min_x = minf(min_x, bro.global_position.x)
		max_x = maxf(max_x, bro.global_position.x)
	_check("once the player is out of range it goes back to pacing", bro.state != AIBro.State.CHASE and max_x - min_x > 40.0, "range %.0f px, state %d" % [max_x - min_x, bro.state])
	_check("and still has not fallen", bro.global_position.y < 5.0)
	await _drop_world()

	# ---- a small gap is hopped
	_make_world([[-2000, 500, 0], [560, 2000, 0]], 640.0, 0.0)
	bro = _bro(430.0, 0.0)
	bro._home_x = 430.0
	bro._dir = 1
	await _wait(300)
	_check("a Bro hops a narrow gap to chase the player", bro.global_position.x > 560.0 and bro.global_position.y < 5.0, "x=%.0f y=%.0f" % [bro.global_position.x, bro.global_position.y])
	await _drop_world()

	# ---- steps: one tile up, then two tiles up
	_make_world([[-2000, 600, 0], [600, 700, -70], [700, 2000, -140]], 760.0, -140.0)
	bro = _bro(520.0, 0.0)
	bro._home_x = 520.0
	bro._dir = 1
	await _wait(420)
	_check("a Bro climbs steps by jumping", bro.global_position.x > 700.0 and bro.global_position.y <= -135.0, "x=%.0f y=%.0f" % [bro.global_position.x, bro.global_position.y])
	await _drop_world()

	# ---- a wall too tall to climb: it stays put (and does not jitter or fall)
	_make_world([[-2000, 600, 0], [600, 700, -400], [700, 2000, 0]], 720.0, 0.0)
	bro = _bro(500.0, 0.0)
	bro._home_x = 500.0
	bro._dir = 1
	await _wait(240)
	_check("a Bro does not try to climb a wall taller than its jump", bro.state == AIBro.State.CHASE and bro.global_position.x < 600.0 and bro.global_position.y > -5.0, "x=%.0f y=%.0f" % [bro.global_position.x, bro.global_position.y])
	await _drop_world()

	# ---- point-blank: an object thrown from inside an enemy's hit box still hits it (it used to pass through)
	_make_world([[-2000, 2000, 0]], 0.0, 0.0)
	player._facing = 1
	var close := _bro(Player.THROW_HAND.x + 6.0, 0.0)
	close.set_physics_process(false)
	await _wait(3)
	player.attack_light()
	await _wait(20)
	_check("a throw at point-blank range hits", close.health == close.max_health - roundi(close.max_health * Projectile.HIT_FRACTION), str(close.health))
	await _drop_world()

	# ---- no leaks: create and kill 200 Bros
	_make_world([[-100000, 100000, 0]], -90000.0, 0.0)
	await _wait(5)
	var nodes_before := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var objects_before := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	for i in 200:
		_bro(float(i) * 100.0, 0.0)
	await _wait(20)
	_check("200 Bros are alive", get_nodes_in_group("enemies").size() == 200, str(get_nodes_in_group("enemies").size()))
	for e in get_nodes_in_group("enemies"):
		e.take_hit(1.0)
	await _wait(60)
	_check("killed Bros leave the enemies group at once", get_nodes_in_group("enemies").is_empty())
	var nodes_after := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var objects_after := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	_check("and are freed: the node count is back to where it was", nodes_after <= nodes_before + MAX_LEAK, "%d before, %d after" % [nodes_before, nodes_after])
	_check("and so is the object count", objects_after <= objects_before + MAX_LEAK * 5, "%d before, %d after" % [objects_before, objects_after])
	_check("no orphan nodes are left behind", int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)) <= 2, str(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)))
	await _drop_world()

	# ---- sleeping: Bros far from the player do no work (Level 1)
	OS.set_environment("SABOTAGE_LEVEL", "1")
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _wait(40)
	var far_count := 0
	var asleep := 0
	for n in get_nodes_in_group("player"):
		player = n
	for e in get_nodes_in_group("enemies"):
		if absf(e.global_position.x - player.global_position.x) > Level.ENEMY_ACTIVE_RANGE + 100.0:
			far_count += 1
			if not e.is_physics_processing():
				asleep += 1
	_check("Level 1 has Bros far from the start", far_count >= 3, str(far_count))
	_check("Bros far from the player are asleep (no physics at all)", asleep == far_count, "%d of %d" % [asleep, far_count])
	var target: AIBro = null
	for e in get_nodes_in_group("enemies"):
		if not e.is_physics_processing():
			target = e
	player.global_position = Vector2(target.global_position.x - 300.0, target.global_position.y)
	await _wait(40)
	_check("and wake up when the player comes near", target.is_physics_processing())

	print("ALL PASS" if ok else "SOME FAILED")
	quit(0 if ok else 1)
