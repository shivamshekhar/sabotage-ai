class_name AssetPaths
extends RefCounted
## Where the game's pictures, sounds and data live, and one cached way to load them. No other script writes a "res://" path: add the folder or
## file here and load it through these helpers. (How the folders are organised: docs/project-layout.md.)

# ---- folders
const ASSETS := "res://assets/"
const EFFECTS := ASSETS + "effects/"                    # generic effects any vehicle, enemy or boss can use: explosion, smoke, fire, sparks, glows
const POWERUPS := ASSETS + "powerups/"                  # the power-up box and its break frames
const MECH := POWERUPS + "mech/"                        # the mech's own parts, its damage layers and its missile
const BOSSES := ASSETS + "bosses/"
const BOSS_SALTMAN := BOSSES + "saltman/"
const CAPTCHA := ASSETS + "captcha/"
const UI := ASSETS + "ui/"                                # icons of the puzzle window
const CHARACTERS := ASSETS + "characters/kenney_platformer/"
const PROJECTILES := ASSETS + "projectiles/pixel_art/"
const MUSIC := ASSETS + "audio/music/"

const LEVELS := "res://levels/"
const LEVELS_COMMON := LEVELS + "common/"
const TILES_BASE := LEVELS_COMMON + "tiles/kenney_industrial/"      # the original tile art (the fallback)
const TILES_THEMED := LEVELS_COMMON + "tiles/data_center/"          # the themed tile art (preferred when a tile has one)
const MACHINES := LEVELS_COMMON + "machines/data_center/"
const PIT_HAZARDS := LEVELS_COMMON + "pit_hazards/"

# ---- files
const TILE_REGISTRY := LEVELS_COMMON + "tile_registry.json"
const CAPTCHA_MANIFEST := CAPTCHA + "manifest.json"
const MUSIC_LEVEL := MUSIC + "the_mountain_retro_game.mp3"
const MUSIC_BOSS := MUSIC + "ihatetuesdays_boss_fight.mp3"
const MAIN_SCENE := "res://scenes/main.tscn"
const PART_FLASH_SHADER := "res://scripts/vehicle/part_flash.gdshader"       # turns a picture white (the mech parts at the flash)

static var _textures := {}


## A picture, loaded once and kept.
static func texture(path: String) -> Texture2D:
	if not _textures.has(path):
		_textures[path] = load(path)
	return _textures[path]


## A picture from assets/effects/ by name ("spark", "smoke_2").
static func effect(name: String) -> Texture2D:
	return texture(EFFECTS + name + ".png")


## The frame `index` (0-based) of an effect whose pictures are numbered from 1 ("explosion_1" ...).
static func effect_frame(name: String, index: int) -> Texture2D:
	return effect("%s_%d" % [name, index + 1])


## A picture from the mech's folder by name ("body", "link", "flame_2").
static func mech(name: String) -> Texture2D:
	return texture(MECH + name + ".png")


## An icon of the puzzle window by name ("icon_firewall", "icon_lock", "icon_unlocked").
static func ui(name: String) -> Texture2D:
	return texture(UI + name + ".png")


## A picture from the power-up folder by name ("box_base", "box_break_3").
static func powerup(name: String) -> Texture2D:
	return texture(POWERUPS + name + ".png")


## A picture from the boss folder by name ("cpu", "ram_stick").
static func boss(name: String) -> Texture2D:
	return texture(BOSSES + name + ".png")
