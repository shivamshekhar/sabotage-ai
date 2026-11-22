extends SceneTree
## Headless test of the asset folder layout: every image is in the folder SpriteLibrary says it is,
## nothing is left loose in a style folder, and every sprite the game asks for actually loads.
## Exits non-zero on failure.
## Run: godot_console --headless --fixed-fps 60 --path . --script res://tools/tests/assets_test.gd

# BACKGROUND_LAYERS: the image names LevelBackground loads from its folder.
const BACKGROUND_LAYERS := ["far", "mid_base", "mid_leds_a", "mid_leds_b", "cables"]

var ok := true


func _check(name: String, cond: bool, detail := "") -> void:
	print(("PASS  " if cond else "FAIL  "), name, "  ", detail)
	if not cond:
		ok = false


func _initialize() -> void:
	_check_tiles(SpriteLibrary.TILE_DIR, "original Kenney tiles")
	_check_tiles(SpriteLibrary.THEMED_TILE_DIR, "themed tiles")
	_check_machines()
	_check_characters()
	_check_projectiles()
	_check_pits()
	_check_backgrounds()
	print("ALL PASS" if ok else "SOME FAILED")
	quit(0 if ok else 1)


## Names of the .png files directly inside a folder (not their .import files).
func _pngs(dir: String) -> Array:
	var out := []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".png"):
			out.append(f)
	return out


func _check_tiles(dir: String, label: String) -> void:
	var stray := _pngs(dir)
	_check("%s: nothing loose at the top of the style folder" % label, stray.is_empty(), str(stray))
	var count := 0
	var wrong := []
	var unloadable := []
	for category in DirAccess.get_directories_at(dir):
		for f in _pngs(dir + category):
			count += 1
			var sprite: String = f.trim_suffix(".png")
			var expected: String = SpriteLibrary.TILE_CATEGORIES.get(sprite.get_slice("_", 0), "")
			if expected != category:
				wrong.append("%s/%s (table says '%s')" % [category, f, expected])
			elif SpriteLibrary.tile(sprite) == null:
				unloadable.append(sprite)
	_check("%s: %d files, each in the category folder the table says" % [label, count], wrong.is_empty() and count > 0, str(wrong))
	_check("%s: every sprite loads" % label, unloadable.is_empty(), str(unloadable))
	var valid_categories := SpriteLibrary.TILE_CATEGORIES.values()
	var odd_folders := []
	for category in DirAccess.get_directories_at(dir):
		if not valid_categories.has(category):
			odd_folders.append(category)
	_check("%s: only known category folders" % label, odd_folders.is_empty(), str(odd_folders))


func _check_machines() -> void:
	var dir := SpriteLibrary.MACHINE_DIR
	_check("machines: nothing loose at the top of the style folder", _pngs(dir).is_empty(), str(_pngs(dir)))
	var count := 0
	var wrong := []
	var unloadable := []
	for folder in DirAccess.get_directories_at(dir):
		for f in _pngs(dir + folder):
			count += 1
			var sprite: String = f.trim_suffix(".png")
			if SpriteLibrary.machine_folder(sprite) != folder:
				wrong.append("%s/%s (rule says '%s')" % [folder, f, SpriteLibrary.machine_folder(sprite)])
			elif SpriteLibrary.machine(sprite) == null:
				unloadable.append(sprite)
	_check("machines: %d files, each in the folder the naming rule says" % count, wrong.is_empty() and count > 0, str(wrong))
	_check("machines: every sprite loads", unloadable.is_empty(), str(unloadable))
	# every machine the level can place has all four images
	var missing := []
	for letter in Level.MACHINES:
		var sprite: String = Level.MACHINES[letter]["sprite"]
		for variant in ["", "_leds_a", "_leds_b", "_shadow"]:
			if SpriteLibrary.machine(sprite + variant) == null:
				missing.append(sprite + variant)
	_check("machines: every placeable machine has its image, LED layers and shadow", missing.is_empty(), str(missing))
	_check("machines: the fan blade sprite loads", SpriteLibrary.machine(MachineFans.FAN_SPRITE) != null)


func _check_projectiles() -> void:
	var missing := []
	for object_name in SpriteLibrary.PROJECTILES:
		if SpriteLibrary.projectile(object_name) == null:
			missing.append(object_name)
	_check("projectiles: all %d throwable objects load" % SpriteLibrary.PROJECTILES.size(), missing.is_empty() and SpriteLibrary.PROJECTILES.size() > 0, str(missing))
	var dir := SpriteLibrary.PROJECTILE_DIR
	var strays := []
	for group in DirAccess.get_directories_at(dir):
		for f in _pngs(dir + group):
			var n: String = f.trim_suffix(".png").trim_prefix("projectile_")
			if not SpriteLibrary.PROJECTILES.has(n) or SpriteLibrary.PROJECTILES[n] != group:
				strays.append("%s/%s" % [group, f])
	_check("projectiles: every file is listed in SpriteLibrary.PROJECTILES, in its group folder", strays.is_empty(), str(strays))


func _check_pits() -> void:
	var missing := []
	for kind in SpriteLibrary.PIT_KINDS:
		for part in SpriteLibrary.PIT_PARTS:
			if SpriteLibrary.pit(kind, part) == null:
				missing.append("%s/%s" % [kind, part])
	for part in SpriteLibrary.PIT_FISH_PARTS:
		if SpriteLibrary.pit("piranha_tank", part) == null:
			missing.append("piranha_tank/" + part)
	for kind in SpriteLibrary.PIT_CREATURE_PARTS:
		for part in SpriteLibrary.PIT_CREATURE_PARTS[kind]:
			if SpriteLibrary.pit(kind, part) == null:
				missing.append("%s/%s" % [kind, part])
	_check("pit hazards: every kind has its liquid tile, and its creatures their frames", missing.is_empty(), str(missing))
	var chars := {}
	for kind in SpriteLibrary.PIT_KINDS:
		chars[SpriteLibrary.PIT_KINDS[kind]] = true
	_check("pit hazards: each kind has its own map character", chars.size() == SpriteLibrary.PIT_KINDS.size())
	var strays := []
	var dir := SpriteLibrary.PIT_DIR
	for kind in DirAccess.get_directories_at(dir):
		if not SpriteLibrary.PIT_KINDS.has(kind):
			strays.append(kind)
		for f in _pngs(dir + kind):
			if not f.begins_with("pit_%s_" % kind):
				strays.append("%s/%s" % [kind, f])
	_check("pit hazards: nothing but known kinds and correctly named files", strays.is_empty(), str(strays))


func _check_characters() -> void:
	var characters: Array = SpriteLibrary.CHARACTER_STYLES.keys()
	var missing := []
	for character in characters:
		for pose in CharacterPoses.all_poses(character):
			if SpriteLibrary.character_pose(character, pose) == null:
				missing.append("%s/%s" % [character, pose])
	_check("characters: every character has every picture CharacterPoses shows", missing.is_empty(), str(missing))
	_check("characters: the configured hero exists", characters.has(PlayerSprite.CHARACTER), PlayerSprite.CHARACTER)
	var folders := []
	for style in DirAccess.get_directories_at(AssetPaths.CHARACTERS):
		for character in DirAccess.get_directories_at(AssetPaths.CHARACTERS + style):
			folders.append(character)
	_check("characters: every character folder is a character the game knows (nothing left over)", folders.size() == characters.size() and folders.all(func(f): return characters.has(f)), str(folders))
	var states_ok := true
	for character in characters:
		for state in [&"idle", &"walk", &"jump", &"fall", &"climb", &"climb_idle", &"hurt", &"throw_windup", &"throw_release", &"shoot"]:
			states_ok = states_ok and CharacterPoses.table(character).has(state)
	_check("characters: every character has a picture for every state", states_ok)


func _check_backgrounds() -> void:
	var missing := []
	for id in LevelData.level_ids():   # every level has its own background folder with every layer
		for layer in LevelBackground.LAYERS:
			if load(LevelData.art_dir(id) + LevelData.BACKGROUND_FOLDER + "/" + layer + ".png") == null:
				missing.append("%s/%s" % [id, layer])
	for layer in BACKGROUND_LAYERS:
		if load(LevelData.background_dir(LevelData.DEFAULT_ID) + layer + ".png") == null:
			missing.append(layer)
	_check("backgrounds: all layers load", missing.is_empty(), str(missing))
