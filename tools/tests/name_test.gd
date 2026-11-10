extends SceneTree
## Names above the health bars. Exits non-zero on failure.
## Run: godot_console --headless --fixed-fps 60 --path . --script res://tools/tests/name_test.gd

# SPRITE_WIDTH: the drawn width in pixels of the player sprite (the art is 80 px wide, scaled by
# PlayerSprite.SCALE). A name must be narrower than this so it never sticks out past the character.
const SPRITE_WIDTH := 80.0 * PlayerSprite.SCALE

var ok := true


func _check(name: String, cond: bool, detail := "") -> void:
	print(("PASS  " if cond else "FAIL  "), name, "  ", detail)
	if not cond:
		ok = false


func _initialize() -> void:
	_main()


func _main() -> void:
	InputSetup.register()
	await process_frame
	var player := Player.new()
	root.add_child(player)
	var bro := AIBro.new()
	root.add_child(bro)
	await process_frame

	_check("the player has a name above the bar", player._health_bar.title == Player.DEFAULT_NAME and Player.DEFAULT_NAME != "", player._health_bar.title)
	_check("the enemy is labelled AI Bro", bro._bar.title == "AI Bro", bro._bar.title)

	player.display_name = "Bartholomew the Great"
	_check("a long name is cut to the limit", player.display_name == "Bartholome" and player.display_name.length() == Player.MAX_NAME_LENGTH, player.display_name)
	_check("and the bar shows the cut name", player._health_bar.title == player.display_name)
	player.display_name = "   Ada   "
	_check("spaces around a name are trimmed", player.display_name == "Ada", "'%s'" % player.display_name)
	player.display_name = "   "
	_check("an empty name falls back to the default", player.display_name == Player.DEFAULT_NAME)
	player.display_name = "1234567890"
	_check("a name of exactly the limit is kept whole", player.display_name == "1234567890")

	var widest := player._health_bar.title_width("W".repeat(Player.MAX_NAME_LENGTH))
	_check("even the widest 10-letter name is narrower than the sprite", widest < SPRITE_WIDTH, "%.0f px of %.0f" % [widest, SPRITE_WIDTH])

	print("ALL PASS" if ok else "SOME FAILED")
	quit(0 if ok else 1)
