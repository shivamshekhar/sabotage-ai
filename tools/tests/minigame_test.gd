extends SceneTree
## Every unlock puzzle: it can be solved, a mistake does not solve it, it restarts, it fits in the popup,
## and the popup picks a different one each time. Exits non-zero on failure.
## Run: godot_console --headless --fixed-fps 60 --path . --script res://tools/tests/minigame_test.gd

# MAX_PANEL_HEIGHT: the tallest the popup window may become, in the game's 720-pixel-high reference screen.
# A puzzle that needs more would run off the screen.
const MAX_PANEL_HEIGHT := 700.0

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
	_check("there are several puzzles to choose from", HackPopup.GAME_NAMES.size() >= 8, str(HackPopup.GAME_NAMES.size()))

	for game_name in HackPopup.GAME_NAMES:
		HackPopup.force_game = game_name
		var popup := HackPopup.open(root, "1", "random")
		await _wait(4)
		var game: Minigame = popup.game
		_check("%s: has instructions" % game_name, game.instructions != "")
		var panel := popup.get_child(1).get_child(0) as Control
		_check("%s: fits in the popup on screen" % game_name, panel.size.y <= MAX_PANEL_HEIGHT, "panel %.0f px tall" % panel.size.y)
		var done := [false]
		game.solved.connect(func() -> void: done[0] = true)

		await game.auto_fail()
		await _wait(int(Minigame.RETRY_DELAY * 60.0) + 20)
		_check("%s: a mistake does not solve it" % game_name, not done[0])
		await game.auto_solve()
		var waited := 0
		while not done[0] and waited < 900:
			await _wait(1)
			waited += 1
		_check("%s: it can be solved" % game_name, done[0], "%d frames" % waited)
		popup.close_popup()
		await _wait(3)

	# The popup picks a different puzzle every time.
	HackPopup.force_game = ""
	var seen := {}
	var last := ""
	var repeats := 0
	for i in 40:
		var popup := HackPopup.open(root, "1", "random")
		if popup.game_name == last:
			repeats += 1
		last = popup.game_name
		seen[popup.game_name] = true
		popup.close_popup()
		await _wait(1)
	_check("a random puzzle is picked each time (%d of %d seen in 40 uses)" % [seen.size(), HackPopup.GAME_NAMES.size()], seen.size() >= 6, str(seen.keys()))
	_check("never the same puzzle twice in a row", repeats == 0, "%d repeats" % repeats)

	print("ALL PASS" if ok else "SOME FAILED")
	quit(0 if ok else 1)
