extends SceneTree
## The robot piranhas of a piranha tank: they are enemies, hide until they pop up, leap at the player and bite for 10%, are
## destroyed by one hit and come back at the same spot only after that, have no health bar, and do no work while asleep.
## Exits non-zero on failure.
## Run: godot_console --headless --fixed-fps 60 --path . --script res://tools/tests/piranha_test.gd

# BITE_WAIT_FRAMES: the longest the test waits for a piranha to bite a player standing right above the tank.
const BITE_WAIT_FRAMES := 1500

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


func _fish() -> Array[Piranha]:
	var out: Array[Piranha] = []
	for n in get_nodes_in_group("enemies"):
		if n is Piranha:
			out.append(n)
	return out


func _main() -> void:
	InputSetup.register()
	await process_frame
	world = Node2D.new()
	root.add_child(world)
	# the floor is at y = 0; a tank 420 px wide is sunk into it to the right of x = 0, and the player stands on a block in the middle of it
	_box(-800, 0, 0)
	_box(420, 1200, 0)
	_box(0, 420, 300)            # the bottom of the tank
	_box(180, 240, 0)            # a pillar in the tank to stand on
	world.add_child(PitHazard.new("piranha_tank", Rect2(0, 90, 420, 210)))
	player = Player.new()
	player.position = Vector2(210, 0)
	player.spawn = Vector2(-100, 0)
	world.add_child(player)
	await _wait(5)

	var fish := _fish()
	_check("a piranha tank holds piranhas (enemies)", fish.size() >= 2, str(fish.size()))
	var no_bar := true
	for f in fish:
		for ch in f.find_children("*", "HealthBar", true, false):
			no_bar = false
	_check("they have no health bar", no_bar)
	var spots := {}
	for f in fish:
		spots[f.home_x] = true
	_check("each has its own spot to pop up from", spots.size() == fish.size())
	_check("a hidden piranha cannot be hit", fish[0].hurtbox().size == Vector2.ZERO)
	_check("a bite takes 10% of the player's health", Piranha.bite_damage() == roundi(Player.MAX_HEALTH * 0.1), str(Piranha.bite_damage()))

	# They leap at the player standing above the tank and bite.
	var waited := 0
	while player.health == Player.MAX_HEALTH and waited < BITE_WAIT_FRAMES:
		await _wait(1)
		waited += 1
	_check("a piranha leaps at the player and bites", player.health == Player.MAX_HEALTH - Piranha.bite_damage(), "health %d after %d frames" % [player.health, waited])

	# One hit destroys it; it comes back at the same spot, only after RESPAWN_TIME.
	var target := fish[0]
	target.state = Piranha.State.PEEK     # make it show itself above the surface
	target._t = 0.5
	target.position = Vector2(target.home_x, target.surface_y - 10.0)
	_check("a piranha above the surface can be hit", target.hurtbox().size != Vector2.ZERO)
	var path_hits := Projectile._segment_hits_rect(Vector2(target.home_x - 200.0, target.position.y), Vector2(target.home_x + 200.0, target.position.y), target.hurtbox().grow(Projectile.HIT_RADIUS))
	_check("a thrown object's path through it counts as a hit", path_hits)
	var destroyed := [false]
	target.defeated.connect(func() -> void: destroyed[0] = true)
	target.take_hit(0.01)      # a feeble hit still destroys it: it has no health
	_check("one hit destroys it, however light", destroyed[0] and target.state == Piranha.State.DEAD)
	_check("a destroyed piranha cannot be hit or bite", target.hurtbox().size == Vector2.ZERO)
	await _wait(int(Piranha.RESPAWN_TIME * 60.0) - 30)
	_check("it stays gone until RESPAWN_TIME is up", target.state == Piranha.State.DEAD)
	var back_at := Vector2(-1.0e9, -1.0e9)
	for i in 120:
		await _wait(1)
		if target.state != Piranha.State.DEAD:
			back_at = target.position
			break
	_check("then it is back, at the same spot", absf(back_at.x - target.home_x) < 1.0 and back_at.y > target.surface_y, str(back_at))
	_check("and the other piranhas were never replaced", _fish().size() == fish.size())

	# Asleep (off screen): hidden and no work.
	for f in fish:
		f.set_active(false)
	await _wait(3)
	var all_asleep := true
	for f in fish:
		if f.visible or f.is_physics_processing():
			all_asleep = false
	_check("a sleeping piranha is hidden and does no physics", all_asleep)
	for f in fish:
		f.set_active(true)
	await _wait(3)
	_check("and wakes up again", fish[0].is_physics_processing())

	print("ALL PASS" if ok else "SOME FAILED")
	quit(0 if ok else 1)
