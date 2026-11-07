extends SceneTree
## Headless test of the spinning machine fans: one blade sprite per fan housing, each one turning
## every frame, at different speeds, and each sitting on its housing. Exits non-zero on failure.
## Run: godot_console --headless --fixed-fps 60 --path . --script res://tools/tests/fans_test.gd

var main: Node
var level: Level
var frames := 0
var ok := true


func _initialize() -> void:
	OS.set_environment("SABOTAGE_LEVEL", "test")
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _check(name: String, cond: bool, detail := "") -> void:
	print(("PASS  " if cond else "FAIL  "), name, "  ", detail)
	if not cond:
		ok = false


func _wait(n: int) -> void:
	for i in n:
		await process_frame


func _process(_d: float) -> bool:
	# _process must not contain `await` (a coroutine's return value makes Godot quit).
	frames += 1
	if frames == 5:
		_main()
	if frames > 600:
		print("FAIL  test timed out before finishing")
		quit(1)
	return false


func _fans() -> Array:
	var fans := []
	var tex := SpriteLibrary.machine(MachineFans.FAN_SPRITE)
	for n in level.get_children():
		if n is Sprite2D and n.texture == tex:
			fans.append(n)
	return fans


func _main() -> void:
	for n in main.get_children():
		if n is Level:
			level = n

	var expected := 0
	for row in LevelData.test_level():
		for ch in row:
			if ch == "G":
				expected += MachineFans.centres("machine_gpu_rack").size()
	_check("the generator wrote fan positions for the GPU rack", MachineFans.centres("machine_gpu_rack").size() > 0,
		"%d fans per rack" % MachineFans.centres("machine_gpu_rack").size())
	_check("a machine with no fans gets none", MachineFans.centres("machine_supercomputer").is_empty())

	var fans := _fans()
	_check("one blade sprite per fan housing in the level", fans.size() == expected and expected > 0,
		"%d sprites, %d expected" % [fans.size(), expected])

	var before := []
	for f in fans:
		before.append(f.rotation)
	await _wait(30)
	var turned := 0
	for i in fans.size():
		if absf(fans[i].rotation - before[i]) > 0.05:
			turned += 1
	_check("every fan is turning", turned == fans.size(), "%d of %d moved" % [turned, fans.size()])

	# speeds differ between fans (so they don't look synchronised)
	var speeds := {}
	var mark := []
	for f in fans:
		mark.append(f.rotation)
	await _wait(10)
	for i in fans.size():
		speeds[snappedf(absf(fans[i].rotation - mark[i]), 0.001)] = true
	if Level.FAN_SPIN_MIN < Level.FAN_SPIN_MAX:
		_check("fans spin at different speeds", speeds.size() > 1, "%d distinct speeds" % speeds.size())

	# each blade sits exactly on a housing centre of the rack
	var rack_pos := Vector2.ZERO
	var rows := LevelData.test_level()
	for r in rows.size():
		for c in rows[r].length():
			if rows[r][c] == "G":
				rack_pos = Vector2(c * Level.T, (r + 1 - int(Level.MACHINES["G"]["h"])) * Level.T)
	var on_housing := 0
	for f in fans:
		for centre in MachineFans.centres("machine_gpu_rack"):
			if f.position.distance_to(rack_pos + centre) < 0.01:
				on_housing += 1
				break
	_check("each blade sprite is centred on a fan housing", on_housing == fans.size())

	print("ALL PASS" if ok else "SOME FAILED")
	quit(0 if ok else 1)
