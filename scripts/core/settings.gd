class_name Settings
extends RefCounted
## The player's settings, kept between runs in a file (user://settings.cfg): how loud the music and the sound effects are, and which keys do what (see KeyBindings).
## Load them once at start-up with apply() (InputSetup.register() does), change them through the setters, and they are saved at once.
##
## A headless run (the automated tests) never reads or writes the player's own file, so a test always sees the default keys and volumes.

# DEFAULT_FILE: where the settings are kept. `file` is the one in use (a test points it somewhere else).
const DEFAULT_FILE := "user://settings.cfg"

# DEFAULT_VOLUME: how loud the music and the sound effects are before the player changes them (0 to 1).
const DEFAULT_VOLUME := 0.8

const SECTION_AUDIO := "audio"
const SECTION_KEYS := "keys"
const KEY_MUSIC := "music"
const KEY_SFX := "sfx"

static var file := DEFAULT_FILE
static var music_volume := DEFAULT_VOLUME
static var sfx_volume := DEFAULT_VOLUME

## The keys the player has set: action name -> the keys (KeyBindings.SLOTS of them, 0 = none) as keycodes. An action that is not in it has its default keys.
static var key_overrides := {}

static var _loaded := false


## Read the file (once) and put the settings to work: the volumes on the audio buses, the keys in the input map.
static func apply() -> void:
	ensure_loaded()
	AudioBuses.ensure()
	AudioBuses.set_volume(AudioBuses.MUSIC, music_volume)
	AudioBuses.set_volume(AudioBuses.SFX, sfx_volume)
	KeyBindings.apply()


## Read the settings file, if it has not been read yet.
static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	if file == DEFAULT_FILE and DisplayServer.get_name() == "headless":
		return
	var cfg := ConfigFile.new()
	if cfg.load(file) != OK:
		return
	music_volume = clampf(float(cfg.get_value(SECTION_AUDIO, KEY_MUSIC, DEFAULT_VOLUME)), 0.0, 1.0)
	sfx_volume = clampf(float(cfg.get_value(SECTION_AUDIO, KEY_SFX, DEFAULT_VOLUME)), 0.0, 1.0)
	for action in InputActions.ALL:
		if cfg.has_section_key(SECTION_KEYS, String(action)):
			key_overrides[String(action)] = Array(cfg.get_value(SECTION_KEYS, String(action)))


static func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	AudioBuses.set_volume(AudioBuses.MUSIC, music_volume)
	save()


static func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	AudioBuses.set_volume(AudioBuses.SFX, sfx_volume)
	save()


## Write the settings to the file.
static func save() -> void:
	if file == DEFAULT_FILE and DisplayServer.get_name() == "headless":
		return
	var cfg := ConfigFile.new()
	cfg.set_value(SECTION_AUDIO, KEY_MUSIC, music_volume)
	cfg.set_value(SECTION_AUDIO, KEY_SFX, sfx_volume)
	for action in key_overrides:
		cfg.set_value(SECTION_KEYS, action, key_overrides[action])
	cfg.save(file)


## Forget what was read and every change (the defaults again), without touching the file: for tests.
static func forget() -> void:
	_loaded = false
	music_volume = DEFAULT_VOLUME
	sfx_volume = DEFAULT_VOLUME
	key_overrides = {}
