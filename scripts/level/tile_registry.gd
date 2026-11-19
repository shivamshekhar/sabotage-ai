class_name TileRegistry
extends RefCounted
## The list of every kind of tile a level can contain: levels/common/tile_registry.json. It is data, so the game, the level editor and
## the command-line tool all know the same tiles, and a new kind of tile is one new entry in that file, with no limit on how many
## there can be (the numbers in level files are plain integers, not characters).
##
## Each kind has a permanent number (`id`, what level files store), a readable `key`, and inside the game a one-character code
## (`char`): the kinds the game has always had keep their old map character ('#' ground, 'B' AI Bro...), every other kind gets the
## character chr(PRIVATE_BASE + id), from a private-use range of Unicode, so a map is still a list of strings with one character per
## tile and there is room for over a million kinds. Kinds without a built-in character have a `behavior`:
##   "solid"  a block the player stands on and is stopped by, drawn with its `sprite`
##   "decor"  a picture behind the player, drawn with its `sprite`
##   "barrier"  an invisible wall: only the player is stopped by it (enemies walk through), nothing is drawn in the game (the level
##              editor shows its `sprite`)
##   "powerup"  a floating power-up box (see PowerUpBox): jump on it and it breaks open and gives the player a vehicle; not solid
## The solver, the AI Bro checks and the physics only care about what a tile DOES, so physics_rows() turns a map into the
## handful of physical classes (solid, empty, ...) first.

# PATH: the registry file.
const PATH := AssetPaths.TILE_REGISTRY

# PRIVATE_BASE: the first code point used for kinds without a built-in character (the start of Unicode's plane 15, a private-use
# range with 65,534 code points; the id is added to it).
const PRIVATE_BASE := 0xF0000

# SOLID_CHAR: what physics_rows() puts for a generic solid block: solid like ground, but not drawn as ground by the older
# tile code (Level draws it from its own sprite).
const SOLID_CHAR := "@"

# BARRIER_CHAR: what physics_rows() puts for an invisible wall: not solid for anyone but the player (Level builds its colliders on
# PhysicsLayers.BARRIER), so the solver and the enemies treat it as empty air.
const BARRIER_CHAR := "|"

static var _loaded := false
static var _kinds: Array[Dictionary] = []
static var _by_id := {}
static var _by_char := {}
static var _by_key := {}


## Read the registry file again (after it changed).
static func reload() -> void:
	_loaded = false
	_ensure()


static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	_kinds.clear()
	_by_id.clear()
	_by_char.clear()
	_by_key.clear()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("TileRegistry: cannot read %s" % PATH)
		return
	add_kinds((parsed as Dictionary).get("kinds", []))


## Add kinds to the registry (the file's own, or more made in code, for example by a test). Each is a dictionary with at least
## `id` and `key`; the `char` is filled in. Duplicates of an id, key or character are reported and skipped.
static func add_kinds(list: Array) -> void:
	for k in list:
		var kind: Dictionary = (k as Dictionary).duplicate(true)
		var id := int(kind["id"])
		if not kind.has("char") or str(kind["char"]) == "":
			kind["char"] = String.chr(PRIVATE_BASE + id)
		var key := str(kind["key"])
		var ch := str(kind["char"])
		if _by_id.has(id) or _by_key.has(key) or _by_char.has(ch):
			push_error("TileRegistry: duplicate tile id %d, key '%s' or character" % [id, key])
			continue
		_kinds.append(kind)
		_by_id[id] = kind
		_by_key[key] = kind
		_by_char[ch] = kind


## Every kind, in the order of the file.
static func kinds() -> Array[Dictionary]:
	_ensure()
	return _kinds


static func kind_for_id(id: int) -> Dictionary:
	_ensure()
	return _by_id.get(id, {})


static func kind_for_key(key: String) -> Dictionary:
	_ensure()
	return _by_key.get(key, {})


## The kind a map character stands for, or {}.
static func kind_for_char(ch: String) -> Dictionary:
	_ensure()
	return _by_char.get(ch, {})


## The map character of a tile number, or "" if no kind has that number.
static func char_for_id(id: int) -> String:
	return str(kind_for_id(id).get("char", ""))


## The tile number of a map character, or -1.
static func id_for_char(ch: String) -> int:
	var kind := kind_for_char(ch)
	return int(kind["id"]) if not kind.is_empty() else -1


## True for a kind without a built-in character: Level draws and handles it from its registry entry.
static func is_generic(ch: String) -> bool:
	return ch.unicode_at(0) >= PRIVATE_BASE if ch != "" else false


## What the tile does, as one of the game's own map characters: itself if the game has always known it, SOLID_CHAR for a generic
## solid block, "." (nothing) for decor and anything unknown.
static func physics_char(ch: String) -> String:
	if not is_generic(ch):
		return ch
	match str(kind_for_char(ch).get("behavior", "")):
		"solid":
			return SOLID_CHAR
		"barrier":
			return BARRIER_CHAR
	return "."


## The rows of a map with every generic kind replaced by its physics_char() (what the solver, the AI Bro checks and the physics
## need). Rows without generic kinds are returned as they are.
static func physics_rows(rows: Array[String]) -> Array[String]:
	var out: Array[String] = []
	for row in rows:
		var plain := true
		for i in row.length():
			if row.unicode_at(i) >= PRIVATE_BASE:
				plain = false
				break
		if plain:
			out.append(row)
			continue
		var s := ""
		for i in row.length():
			s += physics_char(row[i])
		out.append(s)
	return out
