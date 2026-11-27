class_name TitleScreen
extends Node
## The title screen, the first thing the game shows. A distant, out-of-focus data center drifts behind (TitleBackdrop); the menu is down the left (TitleMenu); the logo is in the
## middle with "PRESS ENTER TO START" ("TAP ANYWHERE TO START" on a phone) under it; and the hero stands on the floor in front of an exit door. Start, and the hero walks
## to the door by himself and goes in, the screen flashes white and the first level begins (it clears away from white, see ScreenFlash and Main): the hero is entering the
## data center. The level's music is already playing, and carries on into the game.
##
## Running the game with a level chosen (SABOTAGE_LEVEL, SABOTAGE_LEVEL_FILE, `-- --level-file=path`) or SABOTAGE_NO_TITLE set skips the title and plays that level (should_skip()).

## True when the player has just come back to the title from the game (the pause menu's QUIT TO TITLE): the title is shown even if a level was chosen in the environment.
static var requested := false

## Emitted when the screen is white and the game is about to start (the scene changes right after, unless `launch_game` is off).
signal game_starting

# STAGE_SCALE: how much bigger than in the levels the hero, the floor and the door are drawn (they are in front, the backdrop far behind).
const STAGE_SCALE := 1.5

# FLOOR_SHARE: how far down the screen (0 to 1) the floor's top is. The floor is drawn in front of everything but the menu and the lettering.
const FLOOR_SHARE := 0.8

# FLOOR_ROWS: how many rows of ground are under the floor's top.
const FLOOR_ROWS := 3

# LOGO_WIDTH: how wide (px, in the 1280x720 reference screen) the logo is drawn. LOGO_CENTER_SHIFT: how far (px) its middle is right of the screen's middle, to balance the menu
# on the left. LOGO_TOP: the y of its top.
const LOGO_WIDTH := 640.0
const LOGO_CENTER_SHIFT := 70.0
const LOGO_TOP := 36.0

# MENU_MARGIN: the menu's distance from the left and top edges of the screen.
const MENU_MARGIN := Vector2(30.0, 90.0)

# HERO_SHARE: how far across the screen (0 to 1) the hero stands at first. DOOR_MARGIN: the distance (px) from the right edge to the middle of the door.
const HERO_SHARE := 0.46
const DOOR_MARGIN := 165.0

# WALK_SPEED: how fast the hero walks to the door, in stage pixels per second. ARRIVE: how close (stage px) to the door's middle he stops.
const WALK_SPEED := 190.0
const ARRIVE := 3.0

# PROMPT_FONT / PROMPT_PERIOD / PROMPT_LOW: the "press to start" line: its font size, the seconds of one pulse, and its dimmest opacity. PROMPT_GAP: the distance (px) under the logo.
const PROMPT_FONT := 22
const PROMPT_PERIOD := 1.1
const PROMPT_LOW := 0.35
const PROMPT_GAP := 18.0
const PROMPT_KEYBOARD := "PRESS %s TO START"
const PROMPT_TOUCH := "TAP ANYWHERE TO START"

# SOON_FONT / SOON_TEXT / SOON_TIME: the "coming soon" note a menu button that does not work yet shows (above the menu), and the seconds it stays.
const SOON_FONT := 16
const SOON_TEXT := "COMING SOON"
const SOON_TIME := 1.4

# FADE_TIME: seconds the menu, the prompt and the logo take to fade away when the game starts. FLASH_TIME: seconds the screen takes to go white after the hero is inside.
const FADE_TIME := 0.4
const FLASH_TIME := 0.32
const LOGO_FADE_TIME := 0.7

# Layers: the backdrop is behind everything, then the stage (floor, door, hero), then the vignette (Vignette's own layer), then the lettering and menu.
const BACKDROP_LAYER := -5
const STAGE_LAYER := 1
const UI_LAYER := 8

# BURST_SIZE: how big (stage px) the glow at the door is when the hero has gone in.
const BURST_SIZE := 520.0

## Whether the game really starts (the scene changes to the level) once the screen is white. A test or a screenshot tool turns it off to look at the title only.
var launch_game := true

var _stage: Node2D
var _floor: Node2D
var _door: ExitDoor
var _hero: Node2D
var _hero_sprite: PlayerSprite
var _logo: TextureRect
var _prompt: Label
var _prompt_pulse: Tween
var _menu: TitleMenu
var _soon: Label
var _soon_tween: Tween
var _settings: SettingsPanel
var _wardrobe: WardrobePanel
var _started := false
var _walking := false
var _clock := 0.0
var _touch := false


## True if the game should skip the title and go straight to a level: one was asked for on the command line or in the environment (or the title is switched off).
static func should_skip() -> bool:
	if requested:
		return false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--level-file="):
			return true
	for variable in ["SABOTAGE_LEVEL", "SABOTAGE_LEVEL_FILE", "SABOTAGE_NO_TITLE", "SABOTAGE_PREVIEW"]:
		if OS.get_environment(variable) != "":
			return true
	return false


func _ready() -> void:
	if should_skip():
		get_tree().change_scene_to_file.call_deferred(AssetPaths.MAIN_SCENE)
		return
	requested = false
	InputSetup.register()
	_touch = TouchControls.should_show()
	MusicPlayer.ensure_playing(get_tree())
	var backdrop_layer := CanvasLayer.new()
	backdrop_layer.layer = BACKDROP_LAYER
	backdrop_layer.add_child(TitleBackdrop.new())
	add_child(backdrop_layer)
	_build_stage()
	add_child(Vignette.new())
	_build_ui()
	get_viewport().size_changed.connect(_layout)
	_layout()


func _process(delta: float) -> void:
	if _stage == null:
		return
	_clock += delta
	if _walking:
		_hero.position.x += WALK_SPEED * delta
		_hero_sprite.update_pose(&"walk", 1, delta)
		if _hero.position.x >= _door.position.x - ARRIVE:
			_walking = false
			_door.receive(_hero)
	else:
		_hero_sprite.update_pose(&"idle", 1, delta)


func _unhandled_input(event: InputEvent) -> void:
	if _started or _settings != null or _wardrobe != null:
		return
	var key_start: bool = event is InputEventKey and event.pressed and not event.echo and KeyBindings.START_KEYS.has(int(event.keycode))
	var tap_start: bool = _touch and ((event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT))
	if key_start or tap_start:
		get_viewport().set_input_as_handled()
		_start()


# ---------------------------------------------------------------------------------------------------------------------------
# building the screen
# ---------------------------------------------------------------------------------------------------------------------------
## The floor, the door and the hero, drawn bigger than in the levels, in their own layer.
func _build_stage() -> void:
	var layer := CanvasLayer.new()
	layer.layer = STAGE_LAYER
	add_child(layer)
	_stage = Node2D.new()
	_stage.scale = Vector2.ONE * STAGE_SCALE
	layer.add_child(_stage)
	_floor = Node2D.new()
	_stage.add_child(_floor)
	_door = ExitDoor.new()
	_door.watch_player = false
	_door.swallowed.connect(_on_swallowed)
	_stage.add_child(_door)
	_hero = Node2D.new()
	_hero.z_index = 1
	_hero_sprite = PlayerSprite.new()
	_hero.add_child(_hero_sprite)
	_stage.add_child(_hero)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = UI_LAYER
	add_child(layer)
	_logo = TextureRect.new()
	_logo.texture = load(AssetPaths.TITLE_LOGO)
	_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_logo)
	_prompt = Label.new()
	_prompt.text = PROMPT_TOUCH if _touch else PROMPT_KEYBOARD % KeyBindings.label(KeyBindings.START_KEYS[0])
	_prompt.add_theme_font_size_override("font_size", PROMPT_FONT)
	HackStyle.style_text(_prompt)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_prompt)
	_prompt_pulse = _prompt.create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	_prompt_pulse.tween_property(_prompt, "modulate:a", PROMPT_LOW, PROMPT_PERIOD / 2.0)
	_prompt_pulse.tween_property(_prompt, "modulate:a", 1.0, PROMPT_PERIOD / 2.0)
	_menu = TitleMenu.new()
	_menu.chosen.connect(_on_menu)
	layer.add_child(_menu)
	_soon = Label.new()
	_soon.text = SOON_TEXT
	_soon.add_theme_font_size_override("font_size", SOON_FONT)
	HackStyle.style_text(_soon, HackStyle.ORANGE)
	_soon.modulate.a = 0.0
	_soon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_soon)


## Put everything where it goes for the screen's size (the screen can be wider than 1280x720 on a phone, or change shape).
func _layout() -> void:
	var screen := get_viewport().get_visible_rect().size
	var floor_y := screen.y * FLOOR_SHARE
	_stage.position = Vector2(0.0, floor_y)
	for child in _floor.get_children():
		child.queue_free()
	var tile := float(Level.T)
	for i in int(screen.x / (tile * STAGE_SCALE)) + 2:
		_floor_tile("ground_middle", i * tile, 0.0)
		for row in range(1, FLOOR_ROWS + 1):
			_floor_tile("ground_fill", i * tile, row * tile)
	_door.position = Vector2((screen.x - DOOR_MARGIN) / STAGE_SCALE, 0.0)
	if not _started:
		_hero.position = Vector2(screen.x * HERO_SHARE / STAGE_SCALE, 0.0)
	var logo_height := LOGO_WIDTH * float(_logo.texture.get_height()) / float(_logo.texture.get_width())
	var logo_x := screen.x / 2.0 + LOGO_CENTER_SHIFT - LOGO_WIDTH / 2.0
	_logo.position = Vector2(logo_x, LOGO_TOP)
	_logo.size = Vector2(LOGO_WIDTH, logo_height)
	_prompt.size = Vector2(LOGO_WIDTH, float(PROMPT_FONT) * 1.6)
	_prompt.position = Vector2(logo_x, LOGO_TOP + logo_height + PROMPT_GAP)
	_menu.position = MENU_MARGIN
	_soon.position = Vector2(MENU_MARGIN.x + 4.0, MENU_MARGIN.y - SOON_FONT * 1.6)


func _floor_tile(sprite_name: String, x: float, y: float) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = SpriteLibrary.tile(sprite_name)
	sprite.centered = false
	sprite.position = Vector2(x, y)
	_floor.add_child(sprite)


# ---------------------------------------------------------------------------------------------------------------------------
# what the player does
# ---------------------------------------------------------------------------------------------------------------------------
func _on_menu(id: StringName) -> void:
	if _started:
		return
	if id == &"settings":
		_settings = SettingsPanel.open(self, _touch)
		_settings.closed.connect(func() -> void: _settings = null)
		return
	if id == &"wardrobe":
		_wardrobe = WardrobePanel.open(self)
		_wardrobe.closed.connect(func() -> void: _wardrobe = null)
		return
	_show_soon()


## "Coming soon", under the menu for a moment.
func _show_soon() -> void:
	if _soon_tween != null:
		_soon_tween.kill()
	_soon.modulate.a = 1.0
	_soon_tween = create_tween()
	_soon_tween.tween_interval(SOON_TIME)
	_soon_tween.tween_property(_soon, "modulate:a", 0.0, FADE_TIME)


## The player starts the game: the lettering and menu fade, the door opens and the hero walks to it.
func _start() -> void:
	_started = true
	Sfx.play(get_tree(), Sfx.CONFIRM)
	_prompt_pulse.kill()
	var fade := create_tween().set_parallel(true)
	fade.tween_property(_menu, "modulate:a", 0.0, FADE_TIME)
	fade.tween_property(_prompt, "modulate:a", 0.0, FADE_TIME)
	fade.tween_property(_logo, "modulate:a", 0.0, LOGO_FADE_TIME).set_delay(FADE_TIME)
	_menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_door.open()
	_walking = true


## The hero is inside: the door glows, the screen goes white, and the first level starts from that white.
func _on_swallowed() -> void:
	WhiteFlash.burst(_stage, _door.position + Vector2(0.0, -ExitDoor.SIZE.y / 2.0), BURST_SIZE)
	await ScreenFlash.cover(get_tree(), FLASH_TIME).finished
	ScreenFlash.arriving = true
	game_starting.emit()
	if launch_game:
		get_tree().change_scene_to_file(AssetPaths.MAIN_SCENE)
