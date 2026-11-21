class_name EditorCatalog
extends RefCounted
## The editor's view of tools/level_editor/catalog.json: every tile, object, player/terrain/meta value and minigame kind the
## editor can place or edit. The palette and the inspectors are built from this data, so a new entry needs no editor change.

# CATALOG_PATH: where the catalog file lives. Change it to point the editor at a different catalog.
const CATALOG_PATH := "res://tools/level_editor/catalog.json"

static var _instance: EditorCatalog

## Raw catalog sections.
var tiles: Array = []
var objects: Array = []
var player_props: Array = []
var terrain_props: Array = []
var meta_props: Array = []
var minigame_kinds: Array = []

# char -> palette entry (a Dictionary with an added "kind": "tile" or "object")
var _by_char: Dictionary = {}
var _items: Array[Dictionary] = []
var _by_type: Dictionary = {}


## The shared catalog (loaded once).
static func get_instance() -> EditorCatalog:
	if _instance == null:
		_instance = EditorCatalog.new()
		_instance.load_catalog(CATALOG_PATH)
	return _instance


## Read the catalog file. Returns true on success; on failure the catalog stays empty and an error is pushed.
func load_catalog(path: String) -> bool:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("EditorCatalog: cannot open %s" % path)
		return false
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("EditorCatalog: %s is not a JSON object" % path)
		return false
	var d: Dictionary = parsed
	tiles = d.get("tiles", [])
	objects = d.get("objects", [])
	player_props = d.get("player", [])
	terrain_props = d.get("terrain", [])
	meta_props = d.get("meta", [])
	minigame_kinds = d.get("minigames", [])
	_build_index()
	return true


func _build_index() -> void:
	_by_char.clear()
	_items.clear()
	_by_type.clear()
	tiles = []
	# Every tile and placeable object is a kind of the game's tile registry (levels/common/tile_registry.json): the palette lists
	# them all, however many there are. A kind marked `hidden` is drawn and named by the canvas but has no drawer item of its own
	# (the laser gate: one drawer item, `auto_id`, hands out the next free id; the other ids are hidden kinds).
	for k in TileRegistry.kinds():
		var e: Dictionary = (k as Dictionary).duplicate(true)
		var typed := str(e.get("type", ""))
		e["kind"] = "object" if typed != "" else "tile"
		if typed == "":
			e["type"] = "tile"
			tiles.append(e)
		_by_char[str(e["char"])] = e
		if not bool(e.get("hidden", false)):
			_items.append(e)
		if typed != "" and not _by_type.has(typed):
			_by_type[typed] = e
	# objects that are not tiles (the piranha tank settings) are edited through the thing they attach to and cannot be placed
	for o in objects:
		var e2: Dictionary = (o as Dictionary).duplicate(true)
		e2["kind"] = "object"
		_by_type[str(e2.get("type", ""))] = e2


## Every palette item (tiles, then objects; the laser gate is one item, its id is picked when it is placed).
func palette_items() -> Array[Dictionary]:
	return _items


## The palette group names in catalog order.
func groups() -> Array[String]:
	var out: Array[String] = []
	for e in _items:
		var g := str(e.get("group", ""))
		if not out.has(g):
			out.append(g)
	return out


## The entry for a map character, or {} if the catalog does not know it.
func entry_for_char(ch: String) -> Dictionary:
	return _by_char.get(ch, {})


## The entry of an object type ("ai_bro"...), or {}.
func entry_for_type(type: String) -> Dictionary:
	for e in _items:
		if str(e.get("type", "")) == type:
			return e
	return _by_type.get(type, {})


## True if this map character is an object marker (spawn, exit, bro, machine...) rather than a plain tile.
func is_object_char(ch: String) -> bool:
	return _by_char.has(ch) and str((_by_char[ch] as Dictionary).get("kind", "")) == "object"


## Footprint of a map character in tiles (width, height); 1 x 1 for ordinary tiles. A machine's letter is its bottom-left tile.
func footprint(ch: String) -> Vector2i:
	var e: Dictionary = _by_char.get(ch, {})
	if e.has("footprint"):
		var f: Array = e["footprint"]
		return Vector2i(int(f[0]), int(f[1]))
	return Vector2i(1, 1)


## True if the character is a machine letter (has a footprint bigger than one tile).
func is_machine(ch: String) -> bool:
	var f := footprint(ch)
	return f.x > 1 or f.y > 1


## True if this entry is placed with one click and not painted by dragging.
func is_single(entry: Dictionary) -> bool:
	if str(entry.get("kind", "")) != "object":
		return false
	return str(entry.get("type", "")) != "laser_gate"


## The editable props of an object type, or the empty array.
func props_for_type(type: String) -> Array:
	return entry_for_type(type).get("props", [])


## The catalog entry of a minigame kind, or {}.
func minigame_kind_entry(kind: String) -> Dictionary:
	for k in minigame_kinds:
		if str((k as Dictionary).get("kind", "")) == kind:
			return k
	return {}


## Names of every minigame kind.
func minigame_kind_names() -> Array[String]:
	var out: Array[String] = []
	for k in minigame_kinds:
		out.append(str((k as Dictionary)["kind"]))
	return out


## The default of a prop definition list entry by key (null if none).
static func default_of(props: Array, key: String) -> Variant:
	for p in props:
		if str((p as Dictionary).get("key", "")) == key:
			return (p as Dictionary).get("default")
	return null


## The selectable backgrounds: "background" (the level's own) and every level's background folder.
static func backgrounds() -> Array[String]:
	var out: Array[String] = [LevelData.BACKGROUND_FOLDER]
	for id in LevelData.level_ids():
		out.append(LevelData.art_dir(id) + LevelData.BACKGROUND_FOLDER)
	return out


## The sprite of a palette entry (null when it has none, e.g. the eraser or a laser gate).
func texture(entry: Dictionary) -> Texture2D:
	var s: Variant = entry.get("sprite")
	if typeof(s) != TYPE_DICTIONARY:
		return null
	var sd: Dictionary = s
	if sd.has("tile"):
		return SpriteLibrary.tile(str(sd["tile"]))
	if sd.has("machine"):
		return SpriteLibrary.machine(str(sd["machine"]))
	if sd.has("pit"):
		var a: Array = sd["pit"]
		return SpriteLibrary.pit(str(a[0]), str(a[1]))
	if sd.has("character"):
		var c: Array = sd["character"]
		return SpriteLibrary.character_pose(str(c[0]), str(c[1]))
	return null


## Coerce a JSON value to the type a prop definition says (JSON numbers are all floats).
static func coerce(def: Dictionary, value: Variant) -> Variant:
	match str(def.get("type", "string")):
		"int":
			return int(value)
		"float":
			return float(value)
		"bool":
			return bool(value)
		_:
			return str(value) if typeof(value) != TYPE_STRING else value
