extends SceneTree
## The things that keep the game smooth: WarmUp (jobs done a few a frame), SpriteBatch (many tiles in a few nodes), OffscreenSleeper (far things sleep), the hero's pictures made in
## advance and kept, the effects' warm-up, the cached sounds, the level's batched tiles and the debug overlay. Exits non-zero on failure.
## Run: godot_console --headless --fixed-fps 60 --path . --script res://tools/tests/performance_test.gd

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
	await _warm_up()
	_batch()
	await _sleeper()
	await _composer()
	_sfx()
	await _effects()
	await _level()
	await _overlay()
	print("ALL PASS" if ok else "SOME FAILED")
	quit(0 if ok else 1)


func _warm_up() -> void:
	var done := [0]
	var jobs: Array[Callable] = []
	for i in 40:
		jobs.append(func() -> void: done[0] += 1)
	var warm := WarmUp.run(root, jobs)
	var finished := [false]
	warm.finished.connect(func() -> void: finished[0] = true)
	_check("the jobs have not been done yet when the WarmUp starts", done[0] == 0 and warm.pending() == 40)
	await _wait(2)
	_check("they get done from the first frames on", done[0] >= 1)
	await _wait(10)
	_check("all of them get done", done[0] == 40 and finished[0])
	await process_frame
	_check("and the WarmUp removes itself", not is_instance_valid(warm))
	# a slow job: still one a frame, and the others wait
	var slow_done := [0]
	var slow: Array[Callable] = []
	for i in 3:
		slow.append(func() -> void:
			OS.delay_msec(int(WarmUp.BUDGET_MS) * 3)
			slow_done[0] += 1)
	WarmUp.run(root, slow)
	await process_frame
	_check("a job longer than the budget is done alone in its frame", slow_done[0] == 1, str(slow_done[0]))
	await _wait(6)
	_check("and the rest follow", slow_done[0] == 3)


func _batch() -> void:
	var texture: Texture2D = SpriteLibrary.tile("ground_start")
	var other: Texture2D = SpriteLibrary.tile("ground_middle")
	var batch := SpriteBatch.new()
	for i in 5:
		batch.add(texture, Vector2(i * 70, 140), 0, Color.WHITE)
	batch.add(texture, Vector2(0, 0), 0, Color(0.5, 0.5, 0.5))      # (another tint)
	batch.add(texture, Vector2(0, 0), -1, Color.WHITE)               # (another depth)
	batch.add(other, Vector2(70, 70), 0, Color.WHITE)                # (another texture)
	_check("the pictures are counted", batch.count() == 8)
	var holder := Node2D.new()
	root.add_child(holder)
	var made := batch.flush(holder)
	_check("one node for every texture, depth and tint", made.size() == 4 and holder.get_child_count() == 4, str(made.size()))
	_check("and none left in the batch", batch.count() == 0)
	_check("what was drawn where can still be asked", batch.drawn_at(Vector2(140, 140), 0) and not batch.drawn_at(Vector2(140, 140), -1) and batch.count_at(Vector2(0, 0)) == 2)
	var five: MultiMeshInstance2D = null
	for node in made:
		if node.multimesh.instance_count == 5:
			five = node
	_check("the five of the same kind are one node", five != null and five.texture == texture and five.z_index == 0)
	var tinted := false
	for node in made:
		tinted = tinted or node.modulate.is_equal_approx(Color(0.5, 0.5, 0.5))
	_check("a tint is the node's modulate", tinted)
	holder.queue_free()


func _sleeper() -> void:
	var camera := Camera2D.new()
	camera.position = Vector2.ZERO
	root.add_child(camera)
	camera.make_current()
	var sleeper := OffscreenSleeper.new()
	root.add_child(sleeper)
	var near := Node2D.new()
	var far := Node2D.new()
	root.add_child(near)
	root.add_child(far)
	sleeper.watch(near, Rect2(0, 0, 100, 100))
	sleeper.watch(far, Rect2(9000, 0, 100, 100))
	await _wait(3)
	sleeper.check()
	_check("a thing near the screen stays awake", near.process_mode == Node.PROCESS_MODE_INHERIT)
	_check("a thing far from it goes to sleep (it does not run)", far.process_mode == Node.PROCESS_MODE_DISABLED and sleeper.sleeping_count() == 1)
	camera.position = Vector2(9000, 0)
	await _wait(3)
	sleeper.check()
	_check("when the camera comes near it wakes up, and the one left behind sleeps", far.process_mode == Node.PROCESS_MODE_INHERIT and near.process_mode == Node.PROCESS_MODE_DISABLED)
	camera.position = Vector2(9000 - get_root().get_visible_rect().size.x / 2.0 - OffscreenSleeper.MARGIN / 2.0, 0)
	await _wait(3)
	sleeper.check()
	_check("it wakes before it comes into view (the margin)", far.process_mode == Node.PROCESS_MODE_INHERIT)
	for node in [camera, sleeper, near, far]:
		node.queue_free()
	await process_frame


func _composer() -> void:
	var one := Outfit.new()
	one.wear(&"painter")
	var two := Outfit.new()
	two.wear(&"painter")
	two.set_style(&"boots", &"plain")
	var torso_one := OutfitComposer.part_image(one, "idle1", &"torso")
	var torso_two := OutfitComposer.part_image(two, "idle1", &"torso")
	_check("a part that is the same in two outfits is recoloured once (the same picture)", torso_one != null and torso_one == torso_two)
	var rocker := Outfit.new()
	rocker.wear(&"rocker")
	_check("another colour is another picture", OutfitComposer.part_image(rocker, "idle1", &"torso") != torso_one)
	var before := OutfitComposer._textures.size()
	var ninja := Outfit.new()
	ninja.wear(&"masked_ninja")
	OutfitComposer.warm_up(root, ninja)
	await _wait(2)
	_check("the poses are not all made in the first frame", OutfitComposer._textures.size() - before < CharacterPoses.all_poses(CharacterPoses.CHARACTER_HERO).size())
	var waited := 0
	var all := CharacterPoses.all_poses(CharacterPoses.CHARACTER_HERO).size()
	while OutfitComposer._textures.size() - before < all and waited < 600:
		await process_frame
		waited += 1
	_check("but every pose of the outfit gets made, a little at a time", OutfitComposer._textures.size() - before == all, "%d frames" % waited)
	var texture := OutfitComposer.texture(ninja, "jump")
	_check("and a made picture is the one that is used", texture == OutfitComposer.texture(ninja, "jump"))
	OutfitComposer.warm_up(root, one)
	OutfitComposer.warm_up(root, two)
	await process_frame
	_check("asking again gives up what was being made for the other outfit", is_instance_valid(OutfitComposer._warmer))
	await _wait(5)


func _sfx() -> void:
	var again := Sfx.stream(Sfx.CLICK)
	_check("a sound is read once and kept", Sfx.stream(Sfx.CLICK) == again and again != null)
	_check("every sound can be read in advance", Sfx.warm_up_jobs().size() == Sfx.ALL.size() and Sfx.ALL.all(func(n: StringName) -> bool: return Sfx.stream(n) != null))


func _effects() -> void:
	var children_before := root.get_child_count()
	var jobs := EffectWarmUp.jobs(root)
	var warm := WarmUp.run(root, jobs)
	await _wait(12)
	_check("the effects are made (on a stage that is nearly invisible)", not is_instance_valid(warm) and root.get_child_count() > children_before - 1)
	var layer: CanvasLayer = null
	for child in root.get_children():
		if child is CanvasLayer and (child as CanvasLayer).layer == EffectWarmUp.STAGE_LAYER:
			layer = child
	_check("the stage is a layer of the screen whose things are almost transparent", layer != null and is_equal_approx(layer.get_child(0).modulate.a, EffectWarmUp.HIDDEN_ALPHA) and layer.get_child(0).get_child_count() >= 1)
	await create_timer(EffectWarmUp.SHOW_TIME + 0.5).timeout
	_check("and it is removed again afterwards", not is_instance_valid(layer))


func _level() -> void:
	OS.set_environment("SABOTAGE_LEVEL", "test")
	var main: Node = load(AssetPaths.MAIN_SCENE).instantiate()
	root.add_child(main)
	await _wait(4)
	var level: Level
	for n in main.get_children():
		if n is Level:
			level = n
	var tile_sprites := 0
	var batches := 0
	for n in level.get_children():
		if n is Sprite2D and (n as Sprite2D).z_index == 0:
			tile_sprites += 1
		if n is MultiMeshInstance2D:
			batches += 1
	_check("the ground is drawn by batches, not a sprite for each tile", batches >= 2 and tile_sprites == 0, "%d batches, %d sprites at the ground's depth" % [batches, tile_sprites])
	_check("the level has things that can sleep and looks after them", level.sleeper != null and level.sleeper.get_parent() == level)
	main.queue_free()
	await _wait(3)


func _overlay() -> void:
	OS.set_environment(PerfOverlay.ENV_VARIABLE, "")
	_check("the overlay is not made unless SABOTAGE_PERF is set", PerfOverlay.add_to(root) == null)
	OS.set_environment(PerfOverlay.ENV_VARIABLE, "1")
	var overlay := PerfOverlay.add_to(root)
	_check("it is made when it is", overlay != null and overlay.layer == PerfOverlay.LAYER)
	await _wait(int(PerfOverlay.WINDOW * 60.0) + 10)
	_check("it shows the frame rate and the number of nodes", overlay._label.text.contains("fps") and overlay._label.text.contains("nodes"), overlay._label.text)
	OS.set_environment(PerfOverlay.ENV_VARIABLE, "")
	overlay.queue_free()
	await process_frame
