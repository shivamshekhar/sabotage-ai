extends SceneTree
## The HUD along the top of the screen: it shows the score and the level number ("1-1" like Super Mario Bros), sits on a solid bar across
## the whole top of the screen above the vignette, follows the score, and every level of the game shows it. Exits non-zero on failure.
## Run: godot_console --headless --fixed-fps 60 --path . --script res://tools/tests/hud_test.gd

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


func _texts(node: Node, found: Array) -> Array:
	if node is Label:
		found.append((node as Label).text)
	for c in node.get_children():
		_texts(c, found)
	return found


func _collect(node: Node, found: Array) -> void:
	if node is Label:
		found.append(node)
	for c in node.get_children():
		_collect(c, found)


func _all(node: Node) -> Array:
	var out := [node]
	for c in node.get_children():
		out.append_array(_all(c))
	return out


func _main() -> void:
	InputSetup.register()
	GameStats.reset()
	await _wait(2)

	# the numbering
	var ids := LevelData.level_ids()
	var labels := []
	for id in ids:
		if id != LevelData.TEST_ID:
			labels.append(LevelData.stage_label(id))
	_check("levels are numbered like Super Mario Bros", labels.slice(0, 5) == ["1-1", "1-2", "1-3", "1-4", "2-1"] and labels.back() == "BOSS", str(labels))
	_check("the test level is called TEST", LevelData.stage_label(LevelData.TEST_ID) == "TEST")

	# the bar
	var hud := Hud.add_to(root, "3-2")
	await _wait(3)
	var texts := _texts(hud, [])
	_check("it shows the level number", texts.has("3-2"), str(texts))
	_check("and the score, starting at zero", texts.has("000000"), str(texts))
	_check("each value has a caption ending in a colon", texts.has("SCORE:") and texts.has("WORLD:"), str(texts))
	var lines := 0
	for c in _all(hud):
		if c is HBoxContainer and (c as HBoxContainer).get_child_count() == 2 and (c.get_child(0) is Label):
			lines += 1
			_check("caption and value are the same (small) size", (c.get_child(0) as Label).get_theme_font_size("font_size") == (c.get_child(1) as Label).get_theme_font_size("font_size"))
	_check("the score and the level each sit on one line", lines == 2, str(lines))
	var panels := 0
	var plain := true
	var labels_found := []
	_collect(hud, labels_found)
	for n in labels_found:
		var l := n as Label
		plain = plain and l.get_theme_constant("outline_size") >= 6 and l.get_theme_color("font_shadow_color").a > 0.3
		if l.global_position.y > 80.0:
			plain = false
	for c in _all(hud):
		if c is PanelContainer or c is Panel or c is ColorRect or c is TextureRect:
			panels += 1
	_check("it floats: no bar, panel or backdrop behind it", panels == 0, str(panels))
	_check("every letter has a thick outline and a shadow, and sits at the top of the screen", plain and labels_found.size() >= 4)
	_check("it is above the vignette, below the touch controls, banners and puzzles", Hud.LAYER > 5 and Hud.LAYER < 10, str(Hud.LAYER))
	GameStats.add_score(350)
	await _wait(2)
	_check("it follows the score", _texts(hud, []).has("000350"), str(_texts(hud, [])))
	hud.queue_free()
	await _wait(2)

	# the real game shows it
	GameStats.reset()
	LevelData.selected_id = ""
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _wait(5)
	var game_hud = main.get_node_or_null("Hud")
	_check("the game has the HUD", game_hud != null)
	_check("showing level 1-1", game_hud != null and _texts(game_hud, []).has("1-1"))
	main.queue_free()
	await _wait(3)
	print("ALL PASS" if ok else "SOME FAILED")
	quit(0 if ok else 1)
