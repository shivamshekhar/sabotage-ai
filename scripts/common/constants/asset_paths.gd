class_name AssetPaths
extends RefCounted
## Where the game's pictures, sounds and data live, and one cached way to load them. No other script writes a "res://" path: add the folder or
## file here and load it through these helpers. (How the folders are organised: docs/project-layout.md.)

# ---- folders
#
# The pictures and sounds are all under ASSETS, grouped as  assets/<category>/<feature>/...  (the levels' data is not art: it is in LEVELS, below).
const ASSETS := "res://assets/"
const EFFECTS := ASSETS + "effects/"                    # generic effects any vehicle, enemy or boss can use: explosion, smoke, fire, sparks, glows
const POWERUP_BOX := ASSETS + "powerups/box/"           # the power-up box and its break frames
const MECH := ASSETS + "vehicles/mech/"                 # the mech's own parts, its damage layers and its missile
const BOSS_SALTMAN := ASSETS + "bosses/saltman/"        # the boss's layers
const BOSS_SPRAY := BOSS_SALTMAN + "spray/"             # what the boss shoots: RAM stick, CPU, chipset
const UI_ICONS := ASSETS + "ui/icons/"                  # icons of the puzzle window
const CAPTCHA := ASSETS + "ui/captcha/"                 # the captcha minigame's pictures, riddles and credits
const CHARACTERS := ASSETS + "characters/kenney_platformer/"
const PROJECTILES := ASSETS + "projectiles/pixel_art/"
const MUSIC := ASSETS + "audio/music/"
const SFX := ASSETS + "audio/sfx/"                      # the short sound effects (see Sfx)
const TITLE_LOGO := ASSETS + "ui/title/logo.png"        # the title screen's logo
const EMP_GUN := ASSETS + "weapons/emp_gun/emp_gun.png"    # the player's EMP gun (see EmpGun, PlayerSprite)

# Level art, shared by all levels (assets/levels/common/) and one background per level (assets/levels/<id>/background/).
const LEVEL_ART := ASSETS + "levels/"
const LEVEL_ART_COMMON := LEVEL_ART + "common/"
const TILES_BASE := LEVEL_ART_COMMON + "tiles/kenney_industrial/"      # the original tile art (the fallback)
const TILES_THEMED := LEVEL_ART_COMMON + "tiles/data_center/"          # the themed tile art (preferred when a tile has one)
const MACHINES := LEVEL_ART_COMMON + "machines/data_center/"
const PIT_HAZARDS := LEVEL_ART_COMMON + "pit_hazards/"
const DOOR := LEVEL_ART_COMMON + "door/"                                # the exit door's frame, corridor and leaf (see ExitDoor)

# Level data (not art): levels/<id>/level.sablevel.json, and the tile registry every level shares.
const LEVELS := "res://levels/"
const LEVELS_COMMON := LEVELS + "common/"

# ---- files
const TILE_REGISTRY := LEVELS_COMMON + "tile_registry.json"
const CAPTCHA_MANIFEST := CAPTCHA + "manifest.json"
const MUSIC_LEVEL := MUSIC + "the_mountain_retro_game.mp3"
const MUSIC_BOSS := MUSIC + "ihatetuesdays_boss_fight.mp3"
const MAIN_SCENE := "res://scenes/main.tscn"                      # the game itself: a level
const TITLE_SCENE := "res://scenes/title.tscn"                    # the title screen (what the game starts on)
const DEFOCUS_SHADER := "res://scripts/ui/title/defocus.gdshader"        # puts a picture out of focus (the title screen's distant backdrop)
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
	return texture(UI_ICONS + name + ".png")


## A picture of the exit door by name ("door_frame", "door_inside", "door_leaf").
static func door(name: String) -> Texture2D:
	return texture(DOOR + name + ".png")


## A picture from the power-up box's folder by name ("box_base", "box_break_3").
static func powerup(name: String) -> Texture2D:
	return texture(POWERUP_BOX + name + ".png")


## A picture of what the boss shoots, by name ("cpu", "ram_stick", "chipset").
static func boss_spray(name: String) -> Texture2D:
	return texture(BOSS_SPRAY + name + ".png")
