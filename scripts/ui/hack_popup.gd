class_name HackPopup
extends CanvasLayer
## The in-game window shown when the player uses a computer: a dimmed screen with a panel holding
## one puzzle (see Minigame). The game is paused while it is open. Beating the puzzle emits
## solved(laser_id); the small X in the corner or the Escape key leaves without solving it.

signal solved(laser_id: String)
signal closed

# PANEL_SIZE: size in pixels of the window, in the game's 1280x720 reference screen. It must be big
# enough for the biggest puzzle plus the title and close button.
const PANEL_SIZE := Vector2(940, 610)

# CLOSE_SIZE: size in pixels of the small X button in the window's top-right corner. Keep it big enough for
# a finger but small compared with the puzzle. Higher: easier to tap, but it takes more of the title row. CLOSE_COLOR: its colour (a dull red).
const CLOSE_SIZE := Vector2(64, 64)
const CLOSE_COLOR := Color(0.62, 0.18, 0.22)

# The look: STRIP_HEIGHT is the hazard stripe along the top (the one along the bottom is 60% of it); HEADER_ICON the size of the firewall icon and HINT_ICON
# of the padlock beside the instructions; TITLE_SIZE / SUBTITLE_SIZE the font sizes of the title and the line under it.
const STRIP_HEIGHT := 12.0
const HEADER_ICON := Vector2(68, 68)
const HINT_ICON := Vector2(44, 44)
const TITLE_SIZE := 25
const SUBTITLE_SIZE := 12

# HINT_SIZE: the font size of the instructions strip. TITLE_GAP: pixels between the title and the line under it.
const HINT_SIZE := 16
const TITLE_GAP := 8

# GRANTED_TEXT: the line under the title once the puzzle is solved.
const GRANTED_TEXT := "ACCESS GRANTED  //  GATE %s OPEN"

## Every puzzle, by the name a terminal can ask for (the "game" value in LevelData.terminals()). The special
## name "random" (what the level terminals use) picks one at random each time the computer is used, never
## the same one twice in a row.
const GAME_NAMES := [
	"sequence", "timing", "dont_press", "color_word", "captcha",
	"wrong_only", "mash", "ring_lock", "safe_cracker", "stacker",
]

## Puzzles kept in the game but left out of the "random" choice for now (they can still be asked for by name, e.g. from a level file).
## The captcha's riddles are being reworked.
const RESTING := ["captcha"]

## For tests: when not empty, this puzzle is used instead of a random one.
static var force_game := ""

static var _last_game := ""

var laser_id := ""
var game: Minigame
var game_name := ""
var definition := {}      # settings for the puzzle (see open_definition())

var _lock_icon: TextureRect
var _subtitle: Label


static func has_game(game_id: String) -> bool:
	return game_id == "random" or GAME_NAMES.has(game_id)


## A random puzzle name, different from the one used last time.
static func random_game_name() -> String:
	var pool: Array = random_pool()
	var pick: String = pool[randi() % pool.size()]
	while pick == _last_game and pool.size() > 1:
		pick = pool[randi() % pool.size()]
	return pick


## The puzzles "random" chooses from: all of them except the resting ones.
static func random_pool() -> Array:
	return GAME_NAMES.filter(func(n: String) -> bool: return not RESTING.has(n))


static func _make_game(game_id: String) -> Minigame:
	match game_id:
		"timing":
			return TimingGame.new()
		"dont_press":
			return DontPressGame.new()
		"color_word":
			return ColorWordGame.new()
		"captcha":
			return CaptchaGame.new()
		"wrong_only":
			return WrongOnlyGame.new()
		"mash":
			return MashGame.new()
		"ring_lock":
			return RingLockGame.new()
		"safe_cracker":
			return SafeCrackerGame.new()
		"stacker":
			return StackerGame.new()
	return SequenceGame.new()


## Show the popup for a laser and puzzle name. Returns the popup (already added under `parent`). `requested` is a built-in
## puzzle name, "random", or the id of a puzzle defined by the level file being played.
static func open(parent: Node, laser: String, requested: String) -> HackPopup:
	if force_game == "" and requested != "random" and not GAME_NAMES.has(requested):
		var definition := LevelFile.minigame(LevelData.data_for(LevelData.current_id), requested)
		if not definition.is_empty():
			return open_definition(parent, laser, definition)
	var chosen := requested
	if force_game != "":
		chosen = force_game
	elif requested == "random" or not GAME_NAMES.has(requested):
		chosen = random_game_name()
	_last_game = chosen
	var popup := HackPopup.new()
	popup.laser_id = laser
	popup.game_name = chosen
	parent.add_child(popup)
	popup._build(chosen)
	return popup


## Show a puzzle from a definition: {"kind": a built-in puzzle name, "params": {...settings...}, "questions": [...]}, the shape
## used by level files (see tools/level_editor/FORMAT.md) and by the level editor's preview.
static func open_definition(parent: Node, laser: String, definition: Dictionary) -> HackPopup:
	var kind := str(definition.get("kind", ""))
	if not GAME_NAMES.has(kind):
		kind = random_game_name()
	_last_game = kind
	var popup := HackPopup.new()
	popup.laser_id = laser
	popup.game_name = kind
	popup.definition = definition
	parent.add_child(popup)
	popup._build(kind)
	return popup


func _init() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS


func _build(chosen_name: String) -> void:
	get_tree().paused = true
	# Anything the player was holding must not carry on through the pause.
	Input.flush_buffered_events()
	for a in InputActions.ALL:
		Input.action_release(a)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = PANEL_SIZE
	panel.add_theme_stylebox_override("panel", HackStyle.panel())
	center.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	panel.add_child(col)
	col.add_child(HazardStrip.make(STRIP_HEIGHT))

	# Header: the firewall icon, the title with a line under it, and a small X in the top-right corner. Nothing else shares this row, so the X can't overlap a puzzle.
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	col.add_child(top)
	top.add_child(_icon("icon_firewall", HEADER_ICON))
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.alignment = BoxContainer.ALIGNMENT_CENTER
	titles.add_theme_constant_override("separation", TITLE_GAP)
	top.add_child(titles)
	var title := Label.new()
	title.text = "FIREWALL TERMINAL"
	title.add_theme_font_size_override("font_size", TITLE_SIZE)
	HackStyle.style_text(title, HackStyle.MINT)
	titles.add_child(title)
	_subtitle = Label.new()
	_subtitle.text = "LASER GATE %s  //  SECURITY OVERRIDE" % laser_id
	_subtitle.add_theme_font_size_override("font_size", SUBTITLE_SIZE)
	_subtitle.add_theme_color_override("font_color", HackStyle.CYAN)
	titles.add_child(_subtitle)
	var close := Button.new()
	close.text = "X"
	close.focus_mode = Control.FOCUS_NONE
	close.custom_minimum_size = CLOSE_SIZE
	close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close.add_theme_font_size_override("font_size", 20)
	HackStyle.style_button(close, CLOSE_COLOR)
	close.pressed.connect(close_popup)
	top.add_child(close)

	game = _make_game(chosen_name)
	var settings: Dictionary = (definition.get("params", {}) as Dictionary).duplicate()
	if definition.has("questions"):
		settings["questions"] = definition["questions"]
	game.params = settings
	# The instructions, in a strip of their own with a padlock beside them (it opens when the puzzle is solved).
	var strip := PanelContainer.new()
	strip.add_theme_stylebox_override("panel", HackStyle.inset(HackStyle.CYAN_DIM, 8))
	col.add_child(strip)
	var strip_row := HBoxContainer.new()
	strip_row.add_theme_constant_override("separation", 14)
	strip.add_child(strip_row)
	_lock_icon = _icon("icon_lock", HINT_ICON)
	strip_row.add_child(_lock_icon)
	var hint := Label.new()
	hint.text = game.instructions
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.add_theme_font_size_override("font_size", HINT_SIZE)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART        # (a long instruction wraps instead of widening the window)
	hint.add_theme_constant_override("line_spacing", Minigame.LINE_SPACING)
	HackStyle.style_text(hint)
	strip_row.add_child(hint)

	# The puzzle itself on a dark screen with faint scanlines.
	var screen := PanelContainer.new()
	screen.size_flags_vertical = Control.SIZE_EXPAND_FILL
	screen.add_theme_stylebox_override("panel", HackStyle.inset(HackStyle.CYAN_DIM, 4))
	col.add_child(screen)
	var area := Control.new()
	area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	area.custom_minimum_size = Vector2(0, 280)
	screen.add_child(area)
	area.add_child(game)
	screen.add_child(Scanlines.make())
	game.solved.connect(_on_solved)
	col.add_child(HazardStrip.make(STRIP_HEIGHT * 0.6))


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		close_popup()
		get_viewport().set_input_as_handled()


## A picture of the window (see AssetPaths.ui()) at `size`.
func _icon(name: String, size: Vector2) -> TextureRect:
	var t := TextureRect.new()
	t.texture = AssetPaths.ui(name)
	t.custom_minimum_size = size
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


func _on_solved() -> void:
	_lock_icon.texture = AssetPaths.ui("icon_unlocked")      # the padlock opens
	_subtitle.text = GRANTED_TEXT % laser_id
	_subtitle.add_theme_color_override("font_color", HackStyle.MINT)
	# Let the "ACCESS GRANTED" message be read for a moment, then hand control back.
	await get_tree().create_timer(0.9, true, false, true).timeout
	solved.emit(laser_id)
	close_popup()


func close_popup() -> void:
	if not is_inside_tree():
		return
	get_tree().paused = false
	closed.emit()
	queue_free()
