class_name SpriteLibrary
extends RefCounted
## Central place that knows where art lives on disk. Everything else asks for
## sprites by name, so moving or swapping art only touches this file.

const TILE_DIR := "res://assets/kenney/platformer-pack-industrial/sprites/"
const CHARACTER_DIR := "res://assets/kenney/platformer-characters/"

static var _cache := {}


## Level tile / prop sprite by name, e.g. "ground_start" (see sprites/NAMES.md).
static func tile(sprite_name: String) -> Texture2D:
	return _load(TILE_DIR + sprite_name + ".png")


## Character pose, e.g. character_pose("player", "walk1").
static func character_pose(character: String, pose: String) -> Texture2D:
	return _load("%s%s/%s_%s.png" % [CHARACTER_DIR, character, character, pose])


static func _load(path: String) -> Texture2D:
	if not _cache.has(path):
		_cache[path] = load(path)
	return _cache[path]
