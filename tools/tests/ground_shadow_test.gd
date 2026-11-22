extends SceneTree
## The shadow of the player on the floor (GroundShadow): it lies on the floor under the feet, stays there when the player jumps (it does not rise with them), gets smaller and
## fainter the higher they are, and comes back to full size on landing. Played in the test arena (tools/tests/lib/test_arena.gd). Exits non-zero on failure.
## Run: godot_console --headless --fixed-fps 60 --path . --script res://tools/tests/ground_shadow_test.gd

# MAX_FRAMES: the most frames the jump is waited for.
const MAX_FRAMES := 240

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
	InputSetup.register()
	await _wait(2)
	TestArena.use()
	var main: Node = load(AssetPaths.MAIN_SCENE).instantiate()
	root.add_child(main)
	await _wait(5)
	LevelData.selected_id = ""
	var player: Player = null
	for p in get_nodes_in_group(Groups.PLAYER):
		player = p
	player.global_position = Vector2(TestArena.FLAT_X, TestArena.FLOOR_Y)
	await _wait(30)
	var shadow: GroundShadow = _find_shadow(player)
	_check("the player has a shadow on the floor", shadow != null)
	if shadow == null:
		print("SOME FAILED")
		quit(1)
		return

	var floor_scale := shadow._sprite.scale
	var floor_alpha := shadow._sprite.modulate.a
	_check("standing, it lies on the floor under the feet", shadow.visible and absf(shadow.global_position.y - (TestArena.FLOOR_Y - GroundShadow.SURFACE_LIFT)) < 2.0 and absf(shadow.global_position.x - player.global_position.x) < 2.0,
			str(shadow.global_position - player.global_position))
	_check("at its full size and opacity", is_equal_approx(floor_alpha, PlayerShadow.CONTACT_ALPHA) and floor_scale.x > 0.0)

	# jump: at the top it stays on the floor, smaller and fainter
	Input.action_press(InputActions.JUMP)
	await _wait(3)
	Input.action_release(InputActions.JUMP)
	var highest := 0.0
	var smallest := floor_scale.x
	var faintest := floor_alpha
	var floor_kept := true
	for i in MAX_FRAMES:
		await process_frame
		highest = maxf(highest, TestArena.FLOOR_Y - player.global_position.y)
		smallest = minf(smallest, shadow._sprite.scale.x)
		faintest = minf(faintest, shadow._sprite.modulate.a)
		if player.global_position.y < TestArena.FLOOR_Y - 20.0 and absf(shadow.global_position.y - (TestArena.FLOOR_Y - GroundShadow.SURFACE_LIFT)) > 2.0:
			floor_kept = false
		if i > 20 and player.is_on_floor():
			break
	_check("the player jumped well off the floor", highest > 60.0, "%.0f px" % highest)
	_check("the shadow stayed on the floor all the way up and down", floor_kept)
	_check("it was smaller while the player was in the air", smallest < floor_scale.x - 0.01, "%.3f -> %.3f" % [floor_scale.x, smallest])
	_check("and fainter", faintest < floor_alpha - 0.01, "%.2f -> %.2f" % [floor_alpha, faintest])
	await _wait(20)
	_check("back on the floor it is at its full size again", absf(shadow._sprite.scale.x - floor_scale.x) < 0.01 and absf(shadow._sprite.modulate.a - floor_alpha) < 0.01, "%.3f %.2f" % [shadow._sprite.scale.x, shadow._sprite.modulate.a])

	# a player high above the floor: the smallest and faintest it gets
	player.global_position = Vector2(TestArena.FLAT_X, TestArena.FLOOR_Y - GroundShadow.FADE_HEIGHT - 40.0)
	player.velocity = Vector2.ZERO
	shadow._follow()
	_check("very high up it is at its smallest and faintest", is_equal_approx(shadow._sprite.scale.x, floor_scale.x * GroundShadow.SMALLEST) and is_equal_approx(shadow._sprite.modulate.a, floor_alpha * GroundShadow.FAINTEST),
			"%.3f %.2f" % [shadow._sprite.scale.x, shadow._sprite.modulate.a])
	# with no floor within reach (a long way above it) it is not shown
	player.global_position = Vector2(TestArena.FLAT_X, TestArena.FLOOR_Y - GroundShadow.MAX_DROP - 100.0)
	shadow._follow()
	_check("with no floor within reach there is no shadow", not shadow.visible)

	print("ALL PASS" if ok else "SOME FAILED")
	quit(0 if ok else 1)


## The GroundShadow somewhere below the player.
func _find_shadow(node: Node) -> GroundShadow:
	if node is GroundShadow:
		return node
	for c in node.get_children():
		var found := _find_shadow(c)
		if found != null:
			return found
	return null
