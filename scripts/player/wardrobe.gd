class_name Wardrobe
extends RefCounted
## The outfit the hero wears, kept between runs in a file (user://outfit.cfg). Everything that draws the hero asks for it (SpriteLibrary.character_pose); change it through
## change() / reset() and it is saved at once and every PlayerSprite notices (`version` goes up).
##
## A headless run (the automated tests) never reads or writes the player's own file, so a test always starts with the original look.

# DEFAULT_FILE: where the outfit is kept. `file` is the one in use (a test points it somewhere else).
const DEFAULT_FILE := "user://outfit.cfg"

const SECTION := "outfit"

static var file := DEFAULT_FILE

## Goes up every time the outfit changes: a sprite that sees another number than it has drawn redraws itself.
static var version := 0

static var _outfit: Outfit
static var _loaded := false


## The outfit being worn (read from the file the first time).
static func outfit() -> Outfit:
	_ensure_loaded()
	return _outfit


## Change one slot: its style and/or its colour (an empty id leaves it as it is). The outfit is saved and `version` goes up. False if the catalog has no such style or colour.
static func change(slot: StringName, style_id: StringName = &"", color_id: StringName = &"") -> bool:
	_ensure_loaded()
	var done := true
	if style_id != &"":
		done = _outfit.set_style(slot, style_id) and done
	if color_id != &"":
		done = _outfit.set_color(slot, color_id) and done
	_changed()
	return done


## The next or previous style of a slot (see Outfit.step_style()).
static func step_style(slot: StringName, step: int) -> void:
	_ensure_loaded()
	_outfit.step_style(slot, step)
	_changed()


## Put on the original look.
static func reset() -> void:
	_ensure_loaded()
	_outfit.reset()
	_changed()


## Put on an outfit made up at random.
static func shuffle(rng: RandomNumberGenerator) -> void:
	_ensure_loaded()
	_outfit.shuffle(rng)
	_changed()


## Forget what was read and every change (the original look again), without touching the file: for tests.
static func forget() -> void:
	_loaded = false
	_outfit = Outfit.new()
	version += 1


static func _changed() -> void:
	version += 1
	save()


## Read the file, if it has not been read yet.
static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_outfit = Outfit.new()
	if file == DEFAULT_FILE and DisplayServer.get_name() == "headless":
		return
	var cfg := ConfigFile.new()
	if cfg.load(file) != OK:
		return
	var data := {}
	for key in cfg.get_section_keys(SECTION):
		data[key] = cfg.get_value(SECTION, key)
	_outfit.load_dict(data)


## Write the outfit to the file.
static func save() -> void:
	if file == DEFAULT_FILE and DisplayServer.get_name() == "headless":
		return
	var cfg := ConfigFile.new()
	var data := _outfit.to_dict()
	for slot in data:
		cfg.set_value(SECTION, slot, data[slot])
	cfg.save(file)
