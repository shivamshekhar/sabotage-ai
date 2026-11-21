extends SceneTree
## The player's EMP gun (the heavy attack on foot): it keeps firing for as long as the button is held, and uses the energy bar up very fast (1.5 s for a full bar); it does 40 damage
## to the first enemy it rests on every 0.6 s, reaches 560 px, shows the gun in the hand and draws a held bolt of electricity; it stops when the button is let go or the energy runs
## out, hurts nothing out of reach, and does not fire in the mech (where the heavy attack is the missile). Played in the test arena (tools/tests/lib/test_arena.gd). Exits non-zero on
## failure.
## Run: godot_console --headless --fixed-fps 60 --path . --script res://tools/tests/emp_test.gd

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


## A Bro that stays where it is and has a lot of health, so the damage can be read off it.
func _target(main: Node, x: float) -> AIBro:
	var bro := AIBro.new()
	bro.configure({"sight_range": 1.0, "lose_range": 1.0, "sight_height": 1.0, "patrol_radius": 1.0}, "DUMMY")
	bro.health_fraction = 10.0
	bro.position = Vector2(x, TestArena.FLOOR_Y)
	main.add_child(bro)
	return bro


func _arcs(main: Node) -> int:
	var count := 0
	for n in main.get_children():
		if n is ElectricArc:
			count += 1
	return count


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
	player._facing = 1
	await _wait(30)

	_check("the numbers: 40 damage every 0.6 s, a full bar lasts 1.5 s", EmpGun.DAMAGE == 40 and is_equal_approx(EmpGun.HIT_INTERVAL, 0.6) and is_equal_approx(EmpGun.TIME, 1.5))
	_check("the gun is put away to begin with", not player.visuals().gun_shown())
	player.energy.fill()

	var near := _target(main, player.global_position.x + 400.0)
	await _wait(10)
	var health := near.health
	var energy := player.energy.level
	Input.action_press(InputActions.ATTACK_HEAVY)
	await _wait(6)
	_check("at once the first hit lands: 40 damage", near.health == health - EmpGun.DAMAGE, "%d -> %d" % [health, near.health])
	_check("a bolt of electricity is drawn, and it is one bolt", _arcs(main) == 1, str(_arcs(main)))
	_check("the gun is in the hand", player.visuals().gun_shown())
	var muzzle := player.visuals().gun_muzzle()
	_check("its muzzle is in front of the player, at about chest height", muzzle.x > player.global_position.x + 40.0 and muzzle.y < player.global_position.y - 40.0 and muzzle.y > player.global_position.y - 130.0, str(muzzle - player.global_position))
	_check("it keeps firing while the button is held: another hit after 0.6 s", await _hit_again(near, health - EmpGun.DAMAGE, 50), "%d" % near.health)
	_check("it is still one bolt (not a new one for each hit)", _arcs(main) == 1, str(_arcs(main)))
	_check("it uses the energy fast: 1 / 1.5 of the bar a second", player.energy.level < energy - 0.3, "%.2f -> %.2f" % [energy, player.energy.level])

	# it runs dry: the bar is used up in 1.5 s and the firing stops (until it has refilled a little)
	await _wait(100)
	_check("it stops when the energy is used up", not player._emp_firing and player.energy.is_dry())
	var after_dry := near.health
	await _wait(60)
	_check("and the enemy takes no more damage while it is dry", near.health == after_dry)
	Input.action_release(InputActions.ATTACK_HEAVY)
	await _wait(int((ElectricArc.FADE_TIME + ElectricArc.TAIL) * 60.0) + 20)
	_check("letting go ends the bolt", _arcs(main) == 0, str(_arcs(main)))
	await _wait(int(EmpGun.POSE_TIME * 60.0) + 10)
	_check("the gun is put away", not player.visuals().gun_shown())

	# out of reach
	player.energy.fill()
	var far := _target(main, player.global_position.x + EmpGun.RANGE + 200.0)
	near.global_position.x = player.global_position.x - 400.0
	await _wait(10)
	var far_health := far.health
	Input.action_press(InputActions.ATTACK_HEAVY)
	await _wait(40)
	Input.action_release(InputActions.ATTACK_HEAVY)
	_check("an enemy beyond its reach is not hurt", far.health == far_health)
	await _wait(int((ElectricArc.FADE_TIME + ElectricArc.TAIL) * 60.0) + 20)

	# in the mech the heavy attack is the missile: no EMP fire, the player's own energy is untouched
	player.energy.fill()
	player.board_mech()
	await _wait(30)
	Input.action_press(InputActions.ATTACK_HEAVY)
	await _wait(30)
	Input.action_release(InputActions.ATTACK_HEAVY)
	_check("in the mech the EMP gun does not fire (the player's own energy is untouched)", is_equal_approx(player.energy.level, 1.0) and not player.visuals().gun_shown() and _arcs(main) == 0)

	print("ALL PASS" if ok else "SOME FAILED")
	quit(0 if ok else 1)


## Wait up to `frames` for the enemy's health to drop below `from_health`: true if it did.
func _hit_again(enemy: AIBro, from_health: int, frames: int) -> bool:
	var waited := 0
	while enemy.health >= from_health and waited < frames:
		await process_frame
		waited += 1
	return enemy.health < from_health
