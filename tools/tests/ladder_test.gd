extends SceneTree
## Headless test of the ladder and jump rules (Up is both jump and climb). Exits non-zero on failure.
## Run: godot_console --headless --fixed-fps 60 --path . --script res://tools/tests/ladder_test.gd
## Throwaway: verifies the ladder + jump rules (Up is both jump and climb).

# LX: the x position of the centre of the ladder in level 1. If you move that ladder in the
# map, update this (and the same constant in controls_test.gd and level_bot.gd).
const LX := 1995.0

var main: Node
var player: Player
var frames := 0
var step := 0
var t := 0
var ok := true
var xs := []
var mark_y := 0.0


func _initialize() -> void:
	OS.set_environment("SABOTAGE_LEVEL", "test")
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _check(name: String, cond: bool, detail := "") -> void:
	print(("PASS  " if cond else "FAIL  "), name, "  ", detail)
	if not cond:
		ok = false


func _release_all() -> void:
	for a in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(a)


func _tp(x: float, y: float) -> void:
	player.global_position = Vector2(x, y)
	player.velocity = Vector2.ZERO


func _next(s: int) -> void:
	step = s
	t = 0


func _process(_d: float) -> bool:
	frames += 1
	if frames == 3:
		for n in main.get_children():
			if n is Player:
				player = n
		print("has jump action: ", InputMap.has_action("jump"), " | up bound to: ", InputMap.action_get_events("move_up").size(), " keys")
		_tp(300.0, 840.0)  # far from any ladder
		return false
	if player == null or frames < 8:
		return false
	t += 1

	match step:
		0:  # Up away from a ladder = jump
			Input.action_press("move_up")
			if t == 6:
				_check("Up away from a ladder jumps", not player.climbing and player.global_position.y < 835.0,
					"y=%d climbing=%s" % [int(player.global_position.y), player.climbing])
				_release_all()
				_tp(LX + 25.0, 840.0)
				_next(1)
		1:  # 25px off-centre (<75%): no grab -> up jumps instead
			Input.action_press("move_up")
			if t == 6:
				_check("25px off-centre does not grab (jumps)", not player.climbing and player.global_position.y < 835.0)
				_release_all()
				_tp(LX + 15.0, 840.0)
				_next(2)
		2:  # >= 75% overlap at the bottom: Up climbs instead of jumping
			Input.action_press("move_up")
			if t == 10:
				_check("Up at the ladder bottom climbs", player.climbing)
				_check("snaps to the centre line", is_equal_approx(player.global_position.x, LX), "x=%s" % player.global_position.x)
				_next(3)
		3:  # sideways input ignored while climbing; climb to the top
			Input.action_press("move_up")
			Input.action_press("move_right" if (t / 20) % 2 == 0 else "move_left")
			xs.append(player.global_position.x)
			if not player.climbing or t > 600:
				var steady := true
				for x in xs:
					if not is_equal_approx(x, LX):
						steady = false
				_check("only moves up/down while climbing", steady)
				_check("stops on the top deck", not player.climbing and is_equal_approx(player.global_position.y, 420.0),
					"y=%s" % player.global_position.y)
				_release_all()
				_next(4)
		4:  # On the deck: Up jumps (nothing further to climb)
			if t == 15:
				_check("stands on the deck", player.is_on_floor())
			if t >= 15:
				Input.action_press("move_up")
			if t == 22:
				_check("Up on the top deck jumps", not player.climbing and player.global_position.y < 415.0,
					"y=%s climbing=%s" % [player.global_position.y, player.climbing])
				_release_all()
				_tp(LX, 420.0)
				_next(5)
		5:  # Down on the deck grabs the ladder and climbs down; no jumping on the ladder
			if t < 40:
				Input.action_press("move_down")
				if t == 10:
					_check("Down on the deck climbs down", player.climbing and player.global_position.y > 420.0,
						"climbing=%s y=%s" % [player.climbing, player.global_position.y])
			elif t == 40:
				_release_all()
				mark_y = player.global_position.y
			elif t == 44:
				_check("holds still on the ladder when no key is pressed", player.climbing and is_equal_approx(player.global_position.y, mark_y))
				Input.action_press("move_up")  # up on a ladder climbs; it must not launch the player
			elif t == 52:
				_check("Up while on a ladder climbs, doesn't jump",
					player.climbing and absf(player.velocity.y) <= Player.CLIMB_SPEED + 1.0 and player.global_position.y < mark_y,
					"vy=%s y=%s (was %s)" % [player.velocity.y, player.global_position.y, mark_y])
				_release_all()
				Input.action_press("move_down")
			if t > 52 and (not player.climbing or t > 600):
				_check("reaches the bottom and steps off", not player.climbing and is_equal_approx(player.global_position.y, 840.0),
					"y=%s" % player.global_position.y)
				_release_all()
				_tp(LX, 600.0)  # in the air beside/in the ladder
				_next(6)
		6:  # Catch the ladder mid-air by holding Up
			Input.action_press("move_up")
			if t == 6:
				_check("catching the ladder mid-air starts climbing", player.climbing and is_equal_approx(player.global_position.x, LX),
					"climbing=%s x=%s" % [player.climbing, player.global_position.x])
				_release_all()
				print("ALL PASS" if ok else "SOME FAILED")
				quit(0 if ok else 1)
	return false
