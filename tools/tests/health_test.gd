extends SceneTree
## Headless test of the health system: spikes damage, death at 0, respawn with full health. Exits non-zero on failure.
## Run: godot_console --headless --fixed-fps 60 --path . --script res://tools/tests/health_test.gd

var main: Node
var player: Player
var frames := 0
var log := []
var respawned := false
var min_health := 100


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_d: float) -> bool:
	frames += 1
	if frames == 3:
		for n in main.get_children():
			if n is Player:
				player = n
		print("start health=", player.health, " hazard_count=", player.hazard_count)
		player.global_position = Vector2(16 * 70 + 35, 12 * 70 + 55)  # inside the spike pit
	if player == null:
		return false
	if frames > 3:
		min_health = mini(min_health, player.health)
		if frames % 20 == 0:
			print("f=", frames, " health=", player.health, " pos=(", int(player.global_position.x), ",", int(player.global_position.y), ") hazards=", player.hazard_count)
		if player.global_position.distance_to(player.spawn) < 5.0 and not respawned and frames > 10:
			respawned = true
			print("RESPAWNED at frame ", frames, " health=", player.health, " (lowest seen: ", min_health, ")")
		if frames == 600:
			print("after respawn: health=", player.health, " hazard_count=", player.hazard_count, " (should be 100 and 0)")
			var ok := respawned and player.health == 100 and player.hazard_count == 0
			print("PASS" if ok else "FAIL")
			quit(0 if ok else 1)
	return false
