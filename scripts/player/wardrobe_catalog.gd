class_name WardrobeCatalog
extends RefCounted
## What the player can change about the hero's looks: the slots (hair, goggles, torso, gloves, pants, boots), the styles of each (a picture of its own per pose, see
## tools/art/generate_player.py) and the colours it can be (the picture's own tones are shifted to the colour, see recolor()). The first style and the first colour of
## a slot are the hero's original look. Everything the wardrobe offers, the screen that lists it (WardrobePanel) and the saved outfit (Outfit, Wardrobe) read from here.

# SLOTS: the slots from top to bottom, as the wardrobe lists them. The part of the figure a slot is the same name (CharacterPoses.PARTS).
const SLOTS: Array[StringName] = [&"hair", &"goggles", &"torso", &"gloves", &"pants", &"boots"]

# LABELS: the name of each slot on the screen.
const LABELS := {&"hair": "HAIR", &"goggles": "GOGGLES", &"torso": "TORSO", &"gloves": "GLOVES", &"pants": "PANTS", &"boots": "BOOTS"}

# NO_PART: the id of a style that is no picture at all (bald, no goggles, bare hands).
const NO_PART := &"none"

# The styles of a slot are not listed here: they are the folders in assets/characters/saboteur/player/<slot>/ (see styles()). A new style is a new folder there, named for
# the style ("long_sleeves": the screen says LONG SLEEVES), holding player_<pose>_<slot>.png for the poses (the same names as in the other style folders).
# ORIGINAL_STYLES: the folder of the style the hero starts in, and the one a pose without a picture in the chosen style falls back to. It is the first in the list.
const ORIGINAL_STYLES := {&"hair": &"quiff", &"goggles": &"on_chest", &"torso": &"t_shirt", &"gloves": &"fingerless", &"pants": &"cargo", &"boots": &"sneakers"}

# STYLE_COLORS: a style that comes with a colour (its picture is drawn in the slot's original colour and shown in this one when the style is put on: the spiky hair is golden).
# The player can still pick another colour afterwards. slot -> {style: colour id}.
const STYLE_COLORS := {&"hair": {&"spiky": &"yellow"}}

# FIXED_COLORS: a style whose colour is part of the style, so the wardrobe offers no colours for it (the martial-arts outfit is orange, with a blue sash, blue boots and blue
# wristbands, as it is). slot -> {style: colour id}.
const FIXED_COLORS := {
	&"torso": {&"martial_gi": &"orange"}, &"pants": {&"martial_gi": &"orange"}, &"boots": {&"martial_boots": &"blue"}, &"gloves": {&"wristbands": &"blue"},
}

# WAVE_TORSO: the torso style whose heavy attack is the energy wave (see EmpGun) and not the EMP gun, and WAVE_POSE: the picture of the shooting pose then (the whole figure with both hands
# held round a ball of energy and no gun: files player_wave_<part>.png).
const WAVE_TORSO := &"martial_gi"
const WAVE_POSE := "wave"

# NONE_LABELS: the slots that can be left empty, and what the screen says for that (the last style of the slot, with the id NO_PART and no picture).
const NONE_LABELS := {&"hair": "BALD", &"goggles": "NONE", &"gloves": "BARE HANDS"}

# PALETTES: the colours of every slot: "id" is what is saved, "label" what the screen says, "color" the colour the part is shifted to (a slot's recolour: see RULES).
const PALETTES := {
	&"hair": [
		{"id": &"auburn", "label": "AUBURN", "color": Color("#c48a51")}, {"id": &"black", "label": "BLACK", "color": Color("#2a2430")},
		{"id": &"brown", "label": "BROWN", "color": Color("#6b4428")}, {"id": &"blonde", "label": "BLONDE", "color": Color("#e6c36a")},
		{"id": &"white", "label": "WHITE", "color": Color("#e8e8ee")}, {"id": &"red", "label": "RED", "color": Color("#c4452c")},
		{"id": &"blue", "label": "BLUE", "color": Color("#3a6fd1")}, {"id": &"pink", "label": "PINK", "color": Color("#e06fa8")},
		{"id": &"green", "label": "GREEN", "color": Color("#3fae6b")}, {"id": &"yellow", "label": "YELLOW", "color": Color("#ffd21f")},
	],
	&"goggles": [
		{"id": &"yellow", "label": "YELLOW", "color": Color("#ffc61a")}, {"id": &"black", "label": "BLACK", "color": Color("#2e3040")},
		{"id": &"white", "label": "WHITE", "color": Color("#eef0f6")}, {"id": &"red", "label": "RED", "color": Color("#e0384a")},
		{"id": &"cyan", "label": "CYAN", "color": Color("#3cc8ff")}, {"id": &"green", "label": "GREEN", "color": Color("#3fc86b")},
		{"id": &"pink", "label": "PINK", "color": Color("#f070b0")},
	],
	&"torso": [
		{"id": &"green", "label": "GREEN", "color": Color("#2ecc71")}, {"id": &"red", "label": "RED", "color": Color("#d8404a")},
		{"id": &"blue", "label": "BLUE", "color": Color("#3b7fe0")}, {"id": &"black", "label": "BLACK", "color": Color("#2e3038")},
		{"id": &"white", "label": "WHITE", "color": Color("#e8eaf0")}, {"id": &"orange", "label": "ORANGE", "color": Color("#f08a24")},
		{"id": &"purple", "label": "PURPLE", "color": Color("#8d5fd0")}, {"id": &"grey", "label": "GREY", "color": Color("#8890a0")},
	],
	&"gloves": [
		{"id": &"slate", "label": "SLATE", "color": Color("#626a82")}, {"id": &"black", "label": "BLACK", "color": Color("#2c2e3a")},
		{"id": &"brown", "label": "BROWN", "color": Color("#7a5436")}, {"id": &"red", "label": "RED", "color": Color("#b83a44")},
		{"id": &"white", "label": "WHITE", "color": Color("#dcdfe8")}, {"id": &"blue", "label": "BLUE", "color": Color("#3b6fd0")},
	],
	&"pants": [
		{"id": &"blue", "label": "BLUE", "color": Color("#3498db")}, {"id": &"black", "label": "BLACK", "color": Color("#2c3038")},
		{"id": &"khaki", "label": "KHAKI", "color": Color("#b8a46a")}, {"id": &"grey", "label": "GREY", "color": Color("#7a808e")},
		{"id": &"green", "label": "GREEN", "color": Color("#3a8a56")}, {"id": &"red", "label": "RED", "color": Color("#b4404a")},
		{"id": &"orange", "label": "ORANGE", "color": Color("#f08a24")},
	],
	&"boots": [
		{"id": &"brown", "label": "BROWN", "color": Color("#c48a51")}, {"id": &"black", "label": "BLACK", "color": Color("#2e2a30")},
		{"id": &"white", "label": "WHITE", "color": Color("#e6e8ef")}, {"id": &"red", "label": "RED", "color": Color("#c0392b")},
		{"id": &"blue", "label": "BLUE", "color": Color("#3a6fd1")}, {"id": &"green", "label": "GREEN", "color": Color("#3fae6b")},
	],
}

# RULES: how a slot's pictures are recoloured: the tones in them that are the slot's colour (the hair, the shirt, ...) are shifted to the chosen colour, the rest (the outlines,
# the cyan lights, the yellow stripe, the laces) stays. "hue": a tone is the slot's colour if its hue is within this much of the original colour's (0 to 1, a whole turn of the
# colour wheel is 1); "min_sat" / "max_sat": and its saturation is between these. Larger hue: more of the picture changes (and maybe a detail with it). The original colour
# is the first colour of the slot's palette.
const RULES := {
	&"hair": {"hue": 0.07, "min_sat": 0.2, "max_sat": 1.0},
	&"goggles": {"hue": 0.04, "min_sat": 0.5, "max_sat": 1.0},
	&"torso": {"hue": 0.08, "min_sat": 0.2, "max_sat": 1.0},
	&"gloves": {"hue": 0.05, "min_sat": 0.12, "max_sat": 0.5},
	&"pants": {"hue": 0.08, "min_sat": 0.25, "max_sat": 1.0},
	&"boots": {"hue": 0.035, "min_sat": 0.2, "max_sat": 1.0},
}


static var _styles := {}     # slot -> its style entries, found in the folders the first time they are asked for


## The style entries of a slot (dictionaries with "id": the folder's name, "label": what the screen says): the original style first, the folders' others in alphabetical order,
## then the empty style if the slot has one. Found by looking at the slot's folders, so a new folder is a new style.
static func styles(slot: StringName) -> Array:
	if not _styles.has(slot):
		var ids: Array = Array(DirAccess.get_directories_at(AssetPaths.HERO_LAYERS + slot))
		ids.sort()
		ids.erase(String(ORIGINAL_STYLES[slot]))
		ids.push_front(String(ORIGINAL_STYLES[slot]))
		var entries := []
		for id: String in ids:
			entries.append({"id": StringName(id), "label": id.replace("_", " ").to_upper()})
		if NONE_LABELS.has(slot):
			entries.append({"id": NO_PART, "label": NONE_LABELS[slot]})
		_styles[slot] = entries
	return _styles[slot]


## The colour entries of a slot (dictionaries with "id", "label", "color").
static func palette(slot: StringName) -> Array:
	return PALETTES[slot]


## The colour a style has no choice about (see FIXED_COLORS), or &"" if the style can be any colour.
static func fixed_color(slot: StringName, style: StringName) -> StringName:
	return FIXED_COLORS.get(slot, {}).get(style, &"")


## The pose picture to show for `pose` when the torso is `torso_style` (the shooting pose is the energy wave's in the martial-arts top).
static func pose_for(torso_style: StringName, pose: String) -> String:
	return WAVE_POSE if pose == "shoot" and torso_style == WAVE_TORSO else pose


static func default_style(slot: StringName) -> StringName:
	return ORIGINAL_STYLES[slot]


static func default_color(slot: StringName) -> StringName:
	return PALETTES[slot][0]["id"]


## The style entry of a slot by id, or an empty dictionary if the slot has no such style.
static func style_entry(slot: StringName, id: StringName) -> Dictionary:
	for entry: Dictionary in styles(slot):
		if entry["id"] == id:
			return entry
	return {}


## The colour entry of a slot by id, or an empty dictionary.
static func color_entry(slot: StringName, id: StringName) -> Dictionary:
	for entry: Dictionary in PALETTES[slot]:
		if entry["id"] == id:
			return entry
	return {}


## The picture `image` recoloured for `slot` to `target`: every pixel whose tone is the slot's colour (see RULES) gets the hue of `target`, and its saturation and brightness scaled
## by how far `target` is from the slot's original colour, so the shading stays. Pixels of another colour (outlines, lights) are left alone.
static func recolor(image: Image, slot: StringName, target: Color) -> void:
	var rule: Dictionary = RULES[slot]
	var base: Color = PALETTES[slot][0]["color"]
	var area := image.get_used_rect()
	var sat_scale := target.s / maxf(base.s, 0.001)
	var val_scale := target.v / maxf(base.v, 0.001)
	var hue_range: float = rule["hue"]
	var sat_low: float = rule["min_sat"]
	var sat_high: float = rule["max_sat"]
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			var pixel := image.get_pixel(x, y)
			if pixel.a < 0.01 or pixel.s < sat_low or pixel.s > sat_high:
				continue
			var offset := pixel.h - base.h
			offset -= roundf(offset)          # (the hue is a circle: 0.99 is next to 0.01)
			if absf(offset) > hue_range:
				continue
			image.set_pixel(x, y, Color.from_hsv(fposmod(target.h + offset, 1.0), clampf(pixel.s * sat_scale, 0.0, 1.0), clampf(pixel.v * val_scale, 0.0, 1.0), pixel.a))
