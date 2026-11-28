class_name Outfit
extends RefCounted
## What the hero wears: a style and a colour for every slot of the WardrobeCatalog. A new outfit is the original look. Only styles and colours the catalog has can be set.

var _styles := {}   # slot -> style id
var _colors := {}   # slot -> colour id


func _init() -> void:
	reset()


## The original look: the first style and the first colour of every slot.
func reset() -> void:
	for slot in WardrobeCatalog.SLOTS:
		_styles[slot] = WardrobeCatalog.default_style(slot)
		_colors[slot] = WardrobeCatalog.default_color(slot)


func style(slot: StringName) -> StringName:
	return _styles[slot]


## The colour id of a slot (a style with a fixed colour, the martial-arts outfit, always has that one).
func color_id(slot: StringName) -> StringName:
	var fixed := WardrobeCatalog.fixed_color(slot, _styles[slot])
	return fixed if fixed != &"" else _colors[slot]


## Put on a preset outfit (see WardrobeCatalog.OUTFITS): the original look with the preset's styles and colours on top. False if the preset is not known (nothing changes).
func wear(id: StringName) -> bool:
	var preset := WardrobeCatalog.outfit_preset(id)
	if preset.is_empty():
		return false
	reset()
	var slots: Dictionary = preset["slots"]
	for slot: StringName in slots:
		var entry: Array = slots[slot]
		set_style(slot, entry[0])
		var color_id: StringName = entry[1]
		if color_id != &"":
			set_color(slot, color_id)
	return true


## The id of the preset this outfit is exactly (what the OUTFIT row of the wardrobe shows), or an empty id if it is a mix of the player's own.
func preset_id() -> StringName:
	for preset: Dictionary in WardrobeCatalog.OUTFITS:
		var other := Outfit.new()
		other.wear(preset["id"])
		if other.signature() == signature():
			return preset["id"]
	return &""


## The colour a slot is, as a Color.
func color(slot: StringName) -> Color:
	return WardrobeCatalog.color_entry(slot, color_id(slot))["color"]


## Set a slot's style; false (and nothing changes) if the slot has no such style.
func set_style(slot: StringName, id: StringName) -> bool:
	if not WardrobeCatalog.SLOTS.has(slot) or WardrobeCatalog.style_entry(slot, id).is_empty():
		return false
	_styles[slot] = id
	return true


## Set a slot's colour; false (and nothing changes) if the slot has no such colour or its style has a fixed one.
func set_color(slot: StringName, id: StringName) -> bool:
	if not WardrobeCatalog.SLOTS.has(slot) or WardrobeCatalog.color_entry(slot, id).is_empty() or WardrobeCatalog.fixed_color(slot, _styles[slot]) != &"":
		return false
	_colors[slot] = id
	return true


## The next (step 1) or the previous (step -1) style of a slot, going round (and in the colour the style comes with, if it has one: WardrobeCatalog.STYLE_COLORS).
func step_style(slot: StringName, step: int) -> void:
	var all := WardrobeCatalog.styles(slot)
	var index := 0
	for i in all.size():
		if all[i]["id"] == _styles[slot]:
			index = i
	_styles[slot] = all[posmod(index + step, all.size())]["id"]
	var own_color: StringName = WardrobeCatalog.STYLE_COLORS.get(slot, {}).get(_styles[slot], &"")     # (a style that comes with a colour puts it on)
	if own_color != &"":
		_colors[slot] = own_color


## A made-up outfit: a style and a colour at random for every slot.
func shuffle(rng: RandomNumberGenerator) -> void:
	for slot in WardrobeCatalog.SLOTS:
		_styles[slot] = WardrobeCatalog.styles(slot)[rng.randi() % WardrobeCatalog.styles(slot).size()]["id"]
		_colors[slot] = WardrobeCatalog.palette(slot)[rng.randi() % WardrobeCatalog.palette(slot).size()]["id"]


## A text that is the same for outfits that look the same (the key of the pictures made for an outfit).
func signature() -> String:
	var parts: PackedStringArray = []
	for slot in WardrobeCatalog.SLOTS:
		parts.append("%s:%s:%s" % [slot, _styles[slot], color_id(slot)])
	return ";".join(parts)


func copy() -> Outfit:
	var other := Outfit.new()
	other._styles = _styles.duplicate()
	other._colors = _colors.duplicate()
	return other


## The outfit as plain data (slot -> {"style", "color"}), for saving.
func to_dict() -> Dictionary:
	var out := {}
	for slot in WardrobeCatalog.SLOTS:
		out[String(slot)] = {"style": String(_styles[slot]), "color": String(color_id(slot))}
	return out


## Take what is in `data` (as to_dict() makes it); a slot, style or colour the catalog does not know (an old file) is left as it was.
func load_dict(data: Dictionary) -> void:
	for slot in WardrobeCatalog.SLOTS:
		var entry: Variant = data.get(String(slot))
		if entry is Dictionary:
			set_style(slot, StringName(str(entry.get("style", ""))))
			set_color(slot, StringName(str(entry.get("color", ""))))
