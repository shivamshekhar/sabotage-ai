extends SceneTree
## Pits are only awake while they are on screen or near it (Level.PIT_ACTIVE_BUFFER): the others are silent (hidden, their glow,
## bubbles, gas and creatures doing no work) until the player gets near, and the deadly liquid works either way. Exits non-zero on failure.
## Run: godot_console --headless --fixed-fps 60 --path . --script res://tools/tests/pit_sleep_test.gd

var ok := true
var main: Node
var level: Level
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


## The world rectangle of the screen right now, grown by the buffer: what the level treats as "near".
func _awake_zone() -> Rect2:
	var viewport := root
	var screen: Rect2 = viewport.get_canvas_transform().affine_inverse() * viewport.get_visible_rect()
	return screen.grow(Level.PIT_ACTIVE_BUFFER)


func _main() -> void:
	InputSetup.register()
	OS.set_environment("SABOTAGE_LEVEL", "level_05")
	main = load(AssetPaths.MAIN_SCENE).instantiate()
	root.add_child(main)
	await _wait(40)
	for n in main.get_children():
		if n is Player:
			player = n
		elif n is Level:
			level = n
	var pits: Array[PitHazard] = level._pits
	_check("the level has pits", pits.size() >= 2, str(pits.size()))
	var zone := _awake_zone()
	var wrong := []
	for pit in pits:
		if pit.is_active() != zone.intersects(pit.liquid_rect()):
			wrong.append(pit.liquid_rect())
	_check("each pit is awake exactly when it is on screen or within the buffer of it", wrong.is_empty(), str(wrong))
	var asleep: Array[PitHazard] = []
	var awake: Array[PitHazard] = []
	for pit in pits:
		(awake if pit.is_active() else asleep).append(pit)
	_check("pits far from the screen sleep, nearby ones are awake", asleep.size() >= 1 and awake.size() >= 1, "%d asleep, %d awake" % [asleep.size(), awake.size()])

	# the walls beside each pit are drawn in front of the player, so someone who fell in does not show their arms over them
	var uncovered := []
	for pit in pits:
		var rect := pit.liquid_rect()
		for yy in roundi(rect.size.y / Level.T):
			for side in [rect.position.x - Level.T, rect.end.x]:
				var cell_c := roundi(side / Level.T)
				var cell_r := roundi(rect.position.y / Level.T) + yy
				if not level._is_solid(cell_c, cell_r):
					continue
				var found := false
				for n in level.get_children():
					if n is Sprite2D and (n as Sprite2D).z_index == PitHazard.LIQUID_Z and (n as Sprite2D).position == Vector2(cell_c * Level.T, cell_r * Level.T):
						found = true
				if not found:
					uncovered.append(Vector2i(cell_c, cell_r))
	for pit in pits:   # and the floor under it (and the corners)
		var rect2 := pit.liquid_rect()
		var floor_r := roundi(rect2.end.y / Level.T)
		for xx in range(-1, roundi(rect2.size.x / Level.T) + 1):
			var cc := roundi(rect2.position.x / Level.T) + xx
			if not level._is_solid(cc, floor_r):
				continue
			var found2 := false
			for n in level.get_children():
				if n is Sprite2D and (n as Sprite2D).z_index == PitHazard.LIQUID_Z and (n as Sprite2D).position == Vector2(cc * Level.T, floor_r * Level.T):
					found2 = true
			if not found2:
				uncovered.append(Vector2i(cc, floor_r))
	_check("the tile walls and floor around every pit are drawn in front of the player and the creatures", uncovered.is_empty(), str(uncovered))

	var sleeper := asleep[0]
	_check("a sleeping pit's decoration is hidden and its processing is off", not sleeper._fx.visible and sleeper._fx.process_mode == Node.PROCESS_MODE_DISABLED)
	var creatures := sleeper._fx.find_children("*", "PitCreature", true, false)
	_check("and its creatures do no work at all", creatures.size() >= 1 and creatures.all(func(c: Node) -> bool: return not c.can_process()), str(creatures.size()))
	var particles := sleeper._fx.find_children("*", "CPUParticles2D", true, false)
	_check("nor do its particles", particles.all(func(p: Node) -> bool: return not p.can_process()))
	var watcher := awake[0]
	_check("an awake pit's creatures and particles are running", watcher._fx.visible and watcher._fx.find_children("*", "PitCreature", true, false).all(func(c: Node) -> bool: return c.can_process()))
	var killers := sleeper.find_children("*", "Area2D", true, false)
	_check("the deadly liquid works while the pit sleeps", killers.size() == 1 and killers[0].can_process())

	# ---- walk to the sleeping pit: it wakes before it is reached, and the ones left behind go quiet
	var target_rect := sleeper.liquid_rect()
	player.global_position = Vector2(target_rect.position.x - 900.0, 600.0)
	player.velocity = Vector2.ZERO
	# put the player on the floor next to the pit: the level's own spawn row is the walking surface
	player.global_position.y = target_rect.position.y
	await _wait(150)
	_check("the pit the player came to is awake", sleeper.is_active() and sleeper._fx.visible, "%s" % [sleeper.liquid_rect()])
	_check("its creatures run again", sleeper._fx.find_children("*", "PitCreature", true, false).all(func(c: Node) -> bool: return c.can_process()))
	var left_behind := 0
	for pit in pits:
		if not pit.is_active():
			left_behind += 1
	_check("and some others, far from it, now sleep", left_behind >= 1, str(left_behind))

	main.queue_free()
	await _wait(5)
	OS.set_environment("SABOTAGE_LEVEL", "")
	print("ALL PASS" if ok else "SOME FAILED")
	quit(0 if ok else 1)
