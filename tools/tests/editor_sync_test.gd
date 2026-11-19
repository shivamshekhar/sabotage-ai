extends SceneTree
## The level editor stays up to date with the game: everything the game can place is in the editor's palette and inspectors. Every tile kind has a
## picture, every kind shows in the palette, every minigame and every level-file "meta" key the game knows is in the catalog, and no tile picture is
## left out of the tile registry (tools/sync_editor.py adds the missing ones). Exits non-zero on failure.
## Run: godot_console --headless --fixed-fps 60 --path . --script res://tools/tests/editor_sync_test.gd

var ok := true


func _check(name: String, cond: bool, detail := "") -> void:
	print(("PASS  " if cond else "FAIL  "), name, "  ", detail)
	if not cond:
		ok = false


func _initialize() -> void:
	_main()


func _main() -> void:
	var catalog := EditorCatalog.get_instance()

	# every tile kind of the registry has a picture the editor can draw
	var no_picture := []
	for kind in TileRegistry.kinds():
		var sprite: Dictionary = kind.get("sprite", {})
		if sprite.has("tile") and SpriteLibrary.tile(str(sprite["tile"])) == null:
			no_picture.append(str(kind["key"]))
	_check("every tile kind in the registry has a picture", no_picture.is_empty(), str(no_picture))

	# every kind is offered by the palette (unless the registry marks it hidden)
	var offered := {}
	for item in catalog.palette_items():
		offered[str(item.get("key", ""))] = true
	var not_offered := []
	for kind in TileRegistry.kinds():
		if not bool(kind.get("hidden", false)) and not offered.has(str(kind["key"])):
			not_offered.append(str(kind["key"]))
	_check("every tile kind of the registry is in the editor's palette", not_offered.is_empty(), str(not_offered))

	# every minigame the game can pick is in the catalog
	var catalog_games := {}
	for m in catalog.minigame_kinds:
		catalog_games[str(m["kind"])] = true
	var missing_games := []
	for game in HackPopup.GAME_NAMES:
		if not catalog_games.has(game):
			missing_games.append(game)
	_check("every minigame is in the editor's catalog", missing_games.is_empty(), str(missing_games))

	# every level-file meta key the game reads can be edited
	var catalog_meta := {}
	for m in catalog.meta_props:
		catalog_meta[str(m["key"])] = true
	var missing_meta := []
	for key in LevelFile.META_KEYS:
		if not catalog_meta.has(key):
			missing_meta.append(key)
	_check("every level meta key the game reads is in the editor's inspector", missing_meta.is_empty(), str(missing_meta))

	# no tile picture is left out of the registry (needs Python; skipped without it)
	var output := []
	var code := OS.execute("python", [ProjectSettings.globalize_path("res://tools/sync_editor.py"), "--check"], output)
	if code == -1:
		print("SKIP  no tile picture is left out of the registry  (python not found)")
	else:
		_check("no tile picture is left out of the tile registry (run python tools/sync_editor.py to add them)", code == 0, "".join(output).strip_edges())

	print("ALL PASS" if ok else "SOME FAILED")
	quit(0 if ok else 1)
