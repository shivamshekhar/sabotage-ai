extends SceneTree
## The player's energy bar (throwing costs 5%, it refills at 4% a second, gradually) and the two ailments that go with it: bleeding (a piranha bite: health
## loss like a burn, energy refills at half speed, the player flashes red) and radiation sickness (an eel: health loss at 0.75 of a burn's rate for 1.25 times
## as long, left/right and up/down swapped, a radioactive glow). Also that the mech's weapons are never blocked by the mech itself. Played in the test arena.
## Exits non-zero on failure.
## Run: godot_console --headless --fixed-fps 60 --path . --script res://tools/tests/energy_test.gd

# FRAMES_PER_SECOND: the fixed physics rate the tests run at (--fixed-fps 60).
const FRAMES_PER_SECOND := 60

# CLEAR_X: a spot on the arena's flat ground with room to walk a little either way (no pit, spikes or wall near).
const CLEAR_X := 29.5 * Level.T

# WAIT_CAP: the most frames to wait for a condition before giving up.
const WAIT_CAP := 600

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


func _wait_until(cond: Callable) -> void:
	var n := 0
	while not cond.call() and n < WAIT_CAP:
		await process_frame
		n += 1


## All the points an effect takes off over its whole life, and how many seconds that is.
func _lifetime_total(ticks: int, amount: float) -> Array:
	var dot := DamageOverTime.new()
	dot.apply(ticks, amount)
	var total := 0
	var seconds := 0.0
	while dot.active():
		seconds += DamageOverTime.TICK_TIME
		total += dot.step(DamageOverTime.TICK_TIME)
	return [total, seconds]


func _main() -> void:
	InputSetup.register()
	await _wait(2)

	# ---- the tank
	var e := Energy.new()
	_check("a tank starts full", is_equal_approx(e.level, 1.0) and not e.is_dry())
	_check("a payment takes its share", e.spend(0.05) and is_equal_approx(e.level, 0.95))
	e.set_level(0.03)
	_check("a payment it cannot cover is refused and takes nothing", not e.spend(0.05) and is_equal_approx(e.level, 0.03))
	e.set_level(0.1)
	e.drain(0.2)
	_check("running dry makes it unusable until it has refilled a little", e.is_dry() and not e.drain(0.01))
	e.recover(1.0, Energy.RESTART_LEVEL + 0.01)
	_check("and then it can be used again", not e.is_dry() and e.drain(0.01))

	# ---- the ailments' numbers
	var burn := _lifetime_total(16, 0.01 * Player.MAX_HEALTH)
	var radiation := _lifetime_total(20, 0.0075 * Player.MAX_HEALTH)
	_check("a burn takes 16 points in 11.2 s", burn[0] == 16 and is_equal_approx(burn[1], 16 * DamageOverTime.TICK_TIME), str(burn))
	_check("radiation takes 0.75 of the rate (0.75 a tick) for 1.25 times as long (15 points in 14 s)", radiation[0] == 15 and is_equal_approx(radiation[1] / burn[1], 1.25), str(radiation))
	var bleed_species: Array = PitCreature.SPECIES["piranha"]["bleed"]
	var burn_species: Array = PitCreature.SPECIES["lava_ball"]["burn"]
	_check("a piranha's bite makes the player bleed at the rate and for the time of a burn", bleed_species == burn_species, str(bleed_species))
	_check("an eel's touch gives radiation sickness, and nothing else does", PitCreature.SPECIES["eel"].has("radiation") and not PitCreature.SPECIES["puffer"].has("radiation") and not PitCreature.SPECIES["piranha"].has("radiation") and not PitCreature.SPECIES["eel"].has("bleed"))

	# ---- the player's energy bar
	TestArena.use()
	var main = load(AssetPaths.MAIN_SCENE).instantiate()
	root.add_child(main)
	await _wait(5)
	LevelData.selected_id = ""
	var player: Player = get_first_node_in_group(Groups.PLAYER)
	var bar: HealthBar = player._energy_bar
	_check("the player has a blue energy bar under the health bar", bar != null and bar.visible and bar.fill_color.b > 0.8 and bar.fill_color.r < 0.4 and bar.position.y > player._health_bar.position.y and bar.bar_size.y < player._health_bar.bar_size.y)
	_check("it starts full", is_equal_approx(player.energy.level, 1.0) and is_equal_approx(bar.ratio, 1.0))
	var thrown := [0]
	player.threw.connect(func(_p: Projectile) -> void: thrown[0] += 1)
	await _wait(10)
	player.attack_light()
	await _wait_until(func() -> bool: return thrown[0] == 1)
	_check("a throw costs 5% of the bar", thrown[0] == 1 and is_equal_approx(player.energy.level, 1.0 - Player.THROW_ENERGY_COST) and is_equal_approx(bar.ratio, player.energy.level), "%.3f" % player.energy.level)

	await _wait_until(func() -> bool: return player._throw_timer <= 0.0)
	var base := player.energy.level
	var steps: Array[float] = []
	for k in 10:
		await process_frame
		steps.append(player.energy.level)
	var gradual := true
	for k in steps.size():
		gradual = gradual and steps[k] > (base if k == 0 else steps[k - 1])
	_check("the bar refills a little every step (not once a second)", gradual and steps[0] - base < 0.002, "first step +%.5f" % (steps[0] - base))
	var level_before := player.energy.level
	await _wait(FRAMES_PER_SECOND)
	var gained := player.energy.level - level_before
	_check("and by 4%% of the bar in one second", absf(gained - Player.ENERGY_RECOVERY) < 0.004, "%.4f" % gained)

	player.energy.set_level(Player.THROW_ENERGY_COST * 0.5)
	thrown[0] = 0
	player.attack_light()
	await _wait(30)
	_check("with less than 5% left nothing is thrown", thrown[0] == 0)
	player.energy.set_level(1.0)

	# ---- bleeding
	player.energy.set_level(0.5)
	player.apply_bleed(16, 0.01)
	_check("a bite makes the player bleed", player.is_bleeding() and not player.is_burning())
	var greens: Array[float] = []
	var health_before := player.health
	level_before = player.energy.level
	for k in FRAMES_PER_SECOND:
		await process_frame
		greens.append(player._visuals.modulate.g)
	_check("the bleeding player flashes red", greens.min() < 0.4 and greens.max() > 0.85, "%.2f .. %.2f" % [greens.min(), greens.max()])
	_check("and drips blood", player._status.drips != null and player._status.drips.emitting)
	_check("they lose health like a burn: 1 point at the first tick", player.health == health_before - 1, "%d -> %d" % [health_before, player.health])
	gained = player.energy.level - level_before
	_check("the energy refills at half speed meanwhile (2%% a second)", absf(gained - Player.ENERGY_RECOVERY * PlayerStatus.BLEED_ENERGY_RECOVERY) < 0.004, "%.4f" % gained)
	player._clear_status()
	await _wait(2)
	_check("it ends: no flashing, no blood, normal recovery", not player.is_bleeding() and player._visuals.modulate.g > 0.99 and not player._status.drips.emitting and is_equal_approx(player._status.energy_recovery_scale(), 1.0))

	# ---- radiation sickness
	player.apply_radiation(20, 0.0075)
	player.health = player.max_health
	_check("an eel's touch gives radiation sickness", player.is_radiated() and player.controls_swapped())
	_check("the player glows radioactive", player._status.halo != null and player._status.halo.visible and player._status.halo.material != null)
	_check("and left/right and up/down are swapped", player.up_action() == InputActions.MOVE_DOWN)
	player.global_position = Vector2(CLEAR_X, TestArena.FLOOR_Y)
	player.velocity = Vector2.ZERO
	await _wait(20)
	Input.action_press(InputActions.MOVE_RIGHT)
	await _wait_until(func() -> bool: return absf(player.velocity.x) > 50.0)
	var went_left := player.velocity.x < 0.0
	Input.action_release(InputActions.MOVE_RIGHT)
	await _wait_until(func() -> bool: return absf(player.velocity.x) < 1.0)
	Input.action_press(InputActions.MOVE_LEFT)
	await _wait_until(func() -> bool: return absf(player.velocity.x) > 50.0)
	var went_right := player.velocity.x > 0.0
	Input.action_release(InputActions.MOVE_LEFT)
	await _wait_until(func() -> bool: return absf(player.velocity.x) < 1.0)
	_check("the right key moves the player left and the left key right", went_left and went_right)
	player.global_position = Vector2(CLEAR_X, TestArena.FLOOR_Y)
	await _wait(20)
	Input.action_press(InputActions.MOVE_UP)
	await _wait(6)
	var up_jumped := not player.is_on_floor()
	Input.action_release(InputActions.MOVE_UP)
	await _wait(90)
	Input.action_press(InputActions.MOVE_DOWN)
	await _wait(6)
	var down_jumped := not player.is_on_floor()
	Input.action_release(InputActions.MOVE_DOWN)
	_check("the up key no longer jumps, the down key does", not up_jumped and down_jumped, "%s %s" % [up_jumped, down_jumped])
	await _wait(90)
	player.health = player.max_health
	player._status.radiation.clear()
	player.apply_radiation(20, 0.0075)
	await _wait(int(DamageOverTime.TICK_TIME * FRAMES_PER_SECOND * 4.0) + 12)
	_check("it takes 3 points in the first 4 ticks (0.75 each)", player.health == player.max_health - 3, str(player.max_health - player.health))
	player._clear_status()
	await _wait(2)
	_check("when it ends the controls are back and the glow is off", not player.controls_swapped() and player.up_action() == InputActions.MOVE_UP and not player._status.halo.visible and player._visuals.modulate.r > 0.99)

	# ---- in the mech: no ailments, and nothing the mech fires is stopped by the mech
	player.board_mech()
	await _wait(5)
	player.apply_bleed(16, 0.01)
	player.apply_radiation(20, 0.0075)
	_check("the mech's hull keeps both out", not player.is_bleeding() and not player.is_radiated())
	await _wait(60)
	var above := player.global_position + Vector2(0.0, -300.0)
	var below := player.global_position + Vector2(0.0, 5.0)
	var query := PhysicsRayQueryParameters2D.create(above, below, PhysicsLayers.WORLD)
	var raw := player.get_world_2d().direct_space_state.intersect_ray(query)
	_check("(a ray down through the mech does hit it if it is not told to look past it)", not raw.is_empty() and raw["collider"] == player)
	var ray := Mech.world_ray(player.get_world_2d(), above, below, player.get_rid())
	_check("but the weapons' ray looks past the mech and sees the floor", not ray.is_empty() and ray["collider"] != player and absf(float(ray["position"].y) - player.global_position.y) < 8.0, str(ray.get("position")))
	var m := MechMissile.launch(main, player.global_position + Vector2(20.0, -90.0), Vector2(0.85, 0.53).normalized(), player.mech)
	var flown := 0
	while is_instance_valid(m) and not m._done and flown < WAIT_CAP:
		await process_frame
		flown += 1
	_check("a missile fired down and forward flies on to the floor instead of blowing up on the mech", flown > 8, "%d frames" % flown)

	print("ALL PASS" if ok else "SOME FAILED")
	quit(0 if ok else 1)
