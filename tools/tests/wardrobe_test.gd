extends SceneTree
## The hero's wardrobe: the catalog (every style and colour it offers has its pictures), the outfit (set, step, save, load), the pictures made for an outfit (the parts put
## together, recoloured, kept), what wears it (PlayerSprite, SpriteLibrary), what keeps it (Wardrobe, in a file of its own here) and the window that changes it (WardrobePanel).
## Exits non-zero on failure.
## Run: godot_console --headless --fixed-fps 60 --path . --script res://tools/tests/wardrobe_test.gd

# TEST_FILE: where the wardrobe keeps the outfit in this test (never the player's own file).
const TEST_FILE := "user://wardrobe_test.cfg"

# REQUIRED_PARTS: the parts every pose that has parts of its own must have a picture of.
const REQUIRED_PARTS: Array[StringName] = [&"boots", &"pants", &"arms", &"torso", &"gloves", &"head", &"hair"]

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


## How many pixels of the image are (a little) opaque.
func _opaque(image: Image) -> int:
	var count := 0
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a > 0.5:
				count += 1
	return count


## The number of pixels that differ between two images of the same size.
func _differing(a: Image, b: Image) -> int:
	var count := 0
	for y in a.get_height():
		for x in a.get_width():
			if a.get_pixel(x, y) != b.get_pixel(x, y):
				count += 1
	return count


func _main() -> void:
	Wardrobe.file = TEST_FILE
	Wardrobe.forget()
	_catalog()
	_pictures()
	_outfit()
	_presets()
	_composer()
	_store()
	await _wearers()
	await _panel()
	Wardrobe.file = Wardrobe.DEFAULT_FILE
	Wardrobe.forget()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_FILE))
	print("ALL PASS" if ok else "SOME FAILED")
	quit(0 if ok else 1)


func _catalog() -> void:
	var complete := true
	var unique := true
	var rules := true
	for slot in WardrobeCatalog.SLOTS:
		var styles := WardrobeCatalog.styles(slot)
		var colors := WardrobeCatalog.palette(slot)
		complete = complete and styles.size() >= 2 and colors.size() >= 3 and WardrobeCatalog.LABELS.has(slot) and WardrobeCatalog.RULES.has(slot)
		var ids := []
		for entry: Dictionary in styles:
			unique = unique and not ids.has(entry["id"])
			ids.append(entry["id"])
		ids = []
		for entry: Dictionary in colors:
			unique = unique and not ids.has(entry["id"])
			ids.append(entry["id"])
		rules = rules and CharacterPoses.PARTS.has(slot)
	_check("every slot has styles, colours, a name and a recolour rule", complete)
	_check("no style or colour has the same id as another of its slot", unique)
	_check("every slot is a part of the figure", rules)


## Every picture the catalog and the poses need is there.
func _pictures() -> void:
	var missing := []
	for pose in CharacterPoses.all_poses(CharacterPoses.CHARACTER_HERO):
		if CharacterPoses.SHARED_PARTS.has(pose):
			if not ResourceLoader.exists(OutfitComposer.path(pose, &"head", "")):
				missing.append("%s head" % pose)
			continue
		for part in REQUIRED_PARTS:
			if not ResourceLoader.exists(OutfitComposer.path(pose, part, WardrobeCatalog.default_style(part) if WardrobeCatalog.SLOTS.has(part) else &"")):
				missing.append("%s %s" % [pose, part])
	_check("every pose has the pictures of its parts (the head only, for a blink or a glance)", missing.is_empty(), str(missing))
	missing = []
	for slot in WardrobeCatalog.SLOTS:
		for entry: Dictionary in WardrobeCatalog.styles(slot):
			if entry["id"] != WardrobeCatalog.NO_PART and not ResourceLoader.exists(OutfitComposer.path("idle1", slot, entry["id"])):
				missing.append("%s %s" % [slot, entry["id"]])
	_check("every style the wardrobe offers has its picture of the standing pose", missing.is_empty(), str(missing))
	_check("a pose with only a head of its own wears another pose's other parts", CharacterPoses.part_pose("blink2", &"torso") == "idle2" and CharacterPoses.part_pose("blink2", &"head") == "blink2" and CharacterPoses.part_pose("walk1", &"torso") == "walk1")


func _outfit() -> void:
	var outfit := Outfit.new()
	var original := outfit.signature()
	_check("a new outfit is the original look", outfit.style(&"hair") == &"quiff" and outfit.color_id(&"torso") == &"green" and outfit.color(&"torso") == WardrobeCatalog.palette(&"torso")[0]["color"])
	_check("a style or colour the slot has can be set", outfit.set_style(&"hair", &"crop") and outfit.set_color(&"hair", &"black") and outfit.style(&"hair") == &"crop" and outfit.color_id(&"hair") == &"black")
	_check("one it has not is refused and nothing changes", not outfit.set_style(&"hair", &"visor") and not outfit.set_color(&"hair", &"orange") and not outfit.set_style(&"cape", &"quiff") and outfit.style(&"hair") == &"crop" and outfit.color_id(&"hair") == &"black")
	_check("a changed outfit has another signature", outfit.signature() != original)
	outfit.reset()
	_check("reset puts the original look back", outfit.signature() == original)
	var count := WardrobeCatalog.styles(&"goggles").size()
	for i in count:
		outfit.step_style(&"goggles", 1)
	_check("stepping through the styles goes round", outfit.style(&"goggles") == &"on_chest")
	outfit.step_style(&"goggles", -1)
	_check("and back the other way", outfit.style(&"goggles") == WardrobeCatalog.styles(&"goggles")[count - 1]["id"])
	outfit.reset()
	while outfit.style(&"hair") != &"spiky":
		outfit.step_style(&"hair", 1)
	_check("a style that comes with a colour (spiky hair: yellow) puts it on", outfit.color_id(&"hair") == &"yellow")
	var hair_colors := WardrobeCatalog.palette(&"hair").map(func(e): return e["id"])
	_check("the hair can be yellow, blue, red, black and pink", [&"yellow", &"blue", &"red", &"black", &"pink"].all(func(id): return hair_colors.has(id)))
	for table: Dictionary in [WardrobeCatalog.STYLE_COLORS, WardrobeCatalog.FIXED_COLORS]:
		for slot in table:
			for style in table[slot]:
				_check("%s %s: the style and the colour it comes with exist" % [slot, style], not WardrobeCatalog.style_entry(slot, style).is_empty() and not WardrobeCatalog.color_entry(slot, table[slot][style]).is_empty())
	outfit.reset()
	outfit.wear(&"martial_arts")
	_check("the martial-arts pieces keep their own colours (orange outfit, blue sash, boots and wristbands)", outfit.color_id(&"torso") == &"orange" and outfit.color_id(&"pants") == &"orange" and outfit.color_id(&"boots") == &"blue" and outfit.color_id(&"gloves") == &"blue")
	_check("and no other colour can be chosen for them", not outfit.set_color(&"torso", &"red") and not outfit.set_color(&"boots", &"white") and outfit.color_id(&"torso") == &"orange" and outfit.to_dict()["torso"]["color"] == "orange")
	_check("in the martial-arts top the shooting pose is the energy wave's (both hands, no gun); nothing else changes", WardrobeCatalog.pose_for(&"martial_gi", "shoot") == "wave" and WardrobeCatalog.pose_for(&"t_shirt", "shoot") == "shoot" and WardrobeCatalog.pose_for(&"martial_gi", "walk1") == "walk1")
	var wave_missing := []
	for part in REQUIRED_PARTS:
		if not ResourceLoader.exists(OutfitComposer.path("wave", part, WardrobeCatalog.default_style(part) if WardrobeCatalog.SLOTS.has(part) else &"")):
			wave_missing.append(part)
	_check("the energy wave's pose has a picture of every part", wave_missing.is_empty() and ResourceLoader.exists(OutfitComposer.path("wave", &"gun")), str(wave_missing))
	var wave_hands := OutfitComposer.part_image(outfit, "shoot", &"gun")
	var plain := Outfit.new()
	var gun := OutfitComposer.part_image(plain, "shoot", &"gun")
	_check("each outfit has its own shooting hands (the gun, or the cupped hands)", wave_hands != null and gun != null and wave_hands.get_data() != gun.get_data())
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	outfit.shuffle(rng)
	var valid := true
	for slot in WardrobeCatalog.SLOTS:
		valid = valid and not WardrobeCatalog.style_entry(slot, outfit.style(slot)).is_empty() and not WardrobeCatalog.color_entry(slot, outfit.color_id(slot)).is_empty()
	_check("a made-up outfit only has what the catalog has", valid)
	var copy := outfit.copy()
	copy.reset()
	_check("a copy is its own outfit", copy.signature() != outfit.signature() or outfit.signature() == original)
	var loaded := Outfit.new()
	loaded.load_dict(outfit.to_dict())
	_check("an outfit survives being saved as data and read back", loaded.signature() == outfit.signature())
	loaded.load_dict({"hair": {"style": "pompadour", "color": "chrome"}, "cape": {"style": "x"}})
	_check("what the catalog does not know (an old file) is left out", loaded.signature() == outfit.signature())


## The whole outfits (WardrobeCatalog.OUTFITS): they only use what the catalog has, put every piece on, are told apart from a mix of the player's own, and make a hero in every pose.
func _presets() -> void:
	var valid := true
	var detail := []
	for preset: Dictionary in WardrobeCatalog.OUTFITS:
		for slot: StringName in preset["slots"]:
			var entry: Array = preset["slots"][slot]
			var style_ok: bool = not WardrobeCatalog.style_entry(slot, entry[0]).is_empty()
			var color_ok: bool = entry[1] == &"" or not WardrobeCatalog.color_entry(slot, entry[1]).is_empty()
			if not (style_ok and color_ok):
				valid = false
				detail.append("%s %s %s" % [preset["id"], slot, entry])
	_check("every outfit only uses styles and colours the catalog has", valid, str(detail))
	var outfit := Outfit.new()
	_check("the first outfit is the original look", WardrobeCatalog.OUTFITS[0]["id"] == &"original" and outfit.wear(&"original") and outfit.signature() == Outfit.new().signature())
	_check("an outfit that does not exist is refused", not outfit.wear(&"clown"))
	for preset: Dictionary in WardrobeCatalog.OUTFITS:
		outfit.wear(preset["id"])
		_check("outfit %s: every piece is on and it is recognised" % preset["id"], outfit.preset_id() == preset["id"])
	outfit.wear(&"painter")
	_check("the painter wears a red beret, a smock, painted trousers and work boots", outfit.style(&"hair") == &"beret" and outfit.color_id(&"hair") == &"red" and outfit.style(&"torso") == &"smock"
			and outfit.style(&"pants") == &"painted" and outfit.style(&"boots") == &"work_boots")
	_check("the rocker has a pink mohawk, the ninja a mask and a headband", (func() -> bool:
		var other := Outfit.new()
		other.wear(&"rocker")
		var mohawk: bool = other.style(&"hair") == &"mohawk" and other.color_id(&"hair") == &"pink"
		other.wear(&"masked_ninja")
		return mohawk and other.style(&"goggles") == &"mask_and_band").call())
	outfit.set_style(&"boots", &"plain")
	_check("a changed piece makes it a custom outfit", outfit.preset_id() == &"")
	var thin := []
	for preset: Dictionary in WardrobeCatalog.OUTFITS:
		outfit.wear(preset["id"])
		for pose in ["idle1", "walk1", "jump", "hurt", "action2", "climb1", "shoot"]:
			var pixels := _opaque(OutfitComposer.compose(outfit, pose))
			if pixels < 1500:
				thin.append("%s %s: %d px" % [preset["id"], pose, pixels])
	_check("every outfit makes a whole hero in every pose", thin.is_empty(), str(thin))
	var painter := Outfit.new()
	painter.wear(&"painter")
	var rocker := Outfit.new()
	rocker.wear(&"rocker")
	_check("the outfits do not look alike", _differing(OutfitComposer.compose(painter, "idle1"), OutfitComposer.compose(rocker, "idle1")) > 1000)


func _composer() -> void:
	var outfit := Outfit.new()
	var image := OutfitComposer.compose(outfit, "idle1")
	_check("the original look makes a picture of the hero's size", image.get_size() == Vector2i(CharacterPoses.HERO_FRAME), str(image.get_size()))
	var original_pixels := _opaque(image)
	_check("with the hero in it", original_pixels > 1500, "%d px" % original_pixels)
	outfit.set_color(&"hair", &"black")
	var dark_hair := OutfitComposer.compose(outfit, "idle1")
	var hair_changed := _differing(image, dark_hair)
	_check("another hair colour changes the hair and not the shape of the hero", hair_changed > 100 and _opaque(dark_hair) == original_pixels, "%d px differ" % hair_changed)
	outfit.reset()
	outfit.set_color(&"torso", &"red")
	var red := OutfitComposer.compose(outfit, "idle1")
	var shirt := red.get_pixel(CharacterPoses.HERO_FRAME.x / 2, 82)
	_check("a red shirt is red, with its shading", shirt.r > shirt.g * 1.5 and shirt.r > shirt.b * 1.5, str(shirt))
	outfit.reset()
	outfit.set_style(&"hair", &"none")
	var bald := OutfitComposer.compose(outfit, "idle1")
	_check("bald has no quiff (fewer pixels, and the head is bare)", _opaque(bald) < original_pixels - 300, "%d -> %d" % [original_pixels, _opaque(bald)])
	outfit.reset()
	outfit.set_style(&"gloves", &"none")
	outfit.set_style(&"goggles", &"none")
	_check("bare hands and no goggles show other pixels", _differing(image, OutfitComposer.compose(outfit, "idle1")) > 100)
	outfit.reset()
	outfit.set_style(&"hair", &"crop")
	_check("short hair is a smaller picture than the quiff", _opaque(OutfitComposer.compose(outfit, "idle1")) < original_pixels - 100)
	outfit.reset()
	var same := OutfitComposer.texture(outfit, "walk1")
	_check("a picture is made once and kept", OutfitComposer.texture(outfit, "walk1") == same and OutfitComposer.texture(Outfit.new(), "walk1") == same)
	outfit.set_color(&"pants", &"black")
	_check("another outfit has pictures of its own", OutfitComposer.texture(outfit, "walk1") != same)
	var every_pose := true
	for pose in CharacterPoses.all_poses(CharacterPoses.CHARACTER_HERO):
		every_pose = every_pose and OutfitComposer.compose(outfit, pose).get_size() == Vector2i(CharacterPoses.HERO_FRAME) and _opaque(OutfitComposer.compose(outfit, pose)) > 1000
	_check("every pose can be made for an outfit", every_pose)
	var blink := OutfitComposer.compose(Outfit.new(), "blink1")
	var idle := OutfitComposer.compose(Outfit.new(), "idle1")
	var differing := _differing(blink, idle)
	_check("a blink is the standing pose with only the eyes different", differing > 20 and differing < 400, "%d px" % differing)
	var low := Outfit.new()
	low.set_color(&"gloves", &"black")
	var glow_kept := true
	var base_image := OutfitComposer.compose(Outfit.new(), "idle1")
	var dark_image := OutfitComposer.compose(low, "idle1")
	# the cyan glow of the wristband is not the gloves' colour: it stays
	for y in base_image.get_height():
		for x in base_image.get_width():
			var c := base_image.get_pixel(x, y)
			if c.a > 0.9 and c.b > 0.9 and c.g > 0.7 and c.r < 0.4 and dark_image.get_pixel(x, y) != c:
				glow_kept = false
	_check("recolouring the gloves leaves the cyan lights on them alone", glow_kept)


func _store() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_FILE))
	Wardrobe.forget()
	var before := Wardrobe.version
	_check("the wardrobe starts with the original look", Wardrobe.outfit().signature() == Outfit.new().signature())
	_check("changing a slot works", Wardrobe.change(&"boots", &"plain", &"red") and Wardrobe.outfit().style(&"boots") == &"plain" and Wardrobe.outfit().color_id(&"boots") == &"red")
	_check("and is counted, so what wears it notices", Wardrobe.version > before)
	_check("a style the slot does not have is refused", not Wardrobe.change(&"boots", &"visor"))
	var worn := Wardrobe.outfit().signature()
	_check("it is kept in a file", FileAccess.file_exists(TEST_FILE))
	Wardrobe.forget()
	_check("forgotten, it is read back from the file", Wardrobe.outfit().signature() == worn)
	Wardrobe.reset()
	Wardrobe.forget()
	_check("put back to the original look, that is kept too", Wardrobe.outfit().signature() == Outfit.new().signature())
	Wardrobe.step_preset(1)
	_check("the next outfit from the original look is the one after it", Wardrobe.outfit().preset_id() == WardrobeCatalog.OUTFITS[1]["id"])
	Wardrobe.step_preset(-1)
	Wardrobe.step_preset(-1)
	_check("the previous one goes round to the last", Wardrobe.outfit().preset_id() == WardrobeCatalog.OUTFITS[WardrobeCatalog.OUTFITS.size() - 1]["id"])
	Wardrobe.change(&"boots", &"plain")
	Wardrobe.step_preset(1)
	_check("from a custom outfit the next one is the first", Wardrobe.outfit().preset_id() == WardrobeCatalog.OUTFITS[0]["id"])
	Wardrobe.reset()


## The things that wear the outfit: the hero's sprite and the library, and the zombie that does not.
func _wearers() -> void:
	Wardrobe.reset()
	var sprite := PlayerSprite.new()
	root.add_child(sprite)
	sprite.update_pose(&"jump", 1, 0.0)
	var first := sprite.texture
	_check("the hero's sprite shows the outfit's picture", first == SpriteLibrary.character_pose("player", "jump"))
	Wardrobe.change(&"hair", &"crop", &"pink")
	sprite.update_pose(&"jump", 1, 0.0)
	_check("and changes it when the outfit changes", sprite.texture != first and sprite.texture == SpriteLibrary.character_pose("player", "jump"))
	_check("the zombie wears no outfit", SpriteLibrary.character_pose("zombie", "idle") == SpriteLibrary.character_pose("zombie", "idle") and SpriteLibrary.character_pose("zombie", "idle").get_width() == 80)
	sprite.queue_free()
	Wardrobe.reset()
	await _wait(1)


func _panel() -> void:
	Wardrobe.reset()
	var panel := WardrobePanel.open(root)
	await _wait(3)
	var closed := [false]
	panel.closed.connect(func() -> void: closed[0] = true)
	var slots_shown := panel._style_labels.size() == WardrobeCatalog.SLOTS.size()
	var swatches := 0
	for slot in panel._swatches:
		swatches += (panel._swatches[slot] as Dictionary).size()
	var expected := 0
	for slot in WardrobeCatalog.SLOTS:
		expected += WardrobeCatalog.palette(slot).size()
	_check("the window has a row for every slot and a swatch for every colour", slots_shown and swatches == expected, "%d swatches" % swatches)
	_check("it says the style worn now", (panel._style_labels[&"hair"] as Label).text == "QUIFF")
	_check("and the outfit worn", panel._outfit_label.text == "ORIGINAL")
	panel._step_outfit(1)
	_check("the outfit arrows put on a whole outfit", Wardrobe.outfit().preset_id() == WardrobeCatalog.OUTFITS[1]["id"] and panel._outfit_label.text == WardrobeCatalog.OUTFITS[1]["label"])
	panel._step(&"hair", 1)
	_check("a piece changed by hand makes the outfit CUSTOM", panel._outfit_label.text == WardrobePanel.CUSTOM_OUTFIT)
	Wardrobe.reset()
	panel._refresh()
	panel._step(&"hair", 1)
	var second: Dictionary = WardrobeCatalog.styles(&"hair")[1]
	_check("an arrow puts on the next style", Wardrobe.outfit().style(&"hair") == second["id"] and (panel._style_labels[&"hair"] as Label).text == second["label"])
	panel._step(&"hair", -1)
	_check("and the other one the previous", Wardrobe.outfit().style(&"hair") == &"quiff")
	panel._pick_color(&"torso", &"orange")
	_check("a swatch puts on its colour", Wardrobe.outfit().color_id(&"torso") == &"orange")
	var button: Button = panel._swatches[&"torso"][&"orange"]
	_check("and marks it as the one worn", (button.get_theme_stylebox("normal") as StyleBoxFlat).border_color == WardrobePanel.SWATCH_SELECTED_COLOR)
	panel._show_state(&"walk")
	await _wait(5)
	_check("the hero in the window can be shown walking", panel._sprite._pose_name.begins_with("walk"), panel._sprite._pose_name)
	panel._close()
	await _wait(2)
	_check("closing the window says so and takes it away", closed[0] and not is_instance_valid(panel))
	Wardrobe.reset()
