class_name HackPopup
extends CanvasLayer
## The in-game window shown when the player uses a computer: a dimmed screen with a panel holding
## one puzzle (see Minigame). The game is paused while it is open. Beating the puzzle emits
## solved(laser_id); the small X in the corner or the Escape key leaves without solving it.

signal solved(laser_id: String)
signal closed

# PANEL_SIZE: size in pixels of the window, in the game's 1280x720 reference screen. It must be big
# enough for the biggest puzzle plus the title and close button.
const PANEL_SIZE := Vector2(940, 540)

# CLOSE_SIZE: size in pixels of the small X button in the window's top-right corner. Keep it big enough for
# a finger but small compared with the puzzle. Higher: easier to tap, but it takes more of the title row.
const CLOSE_SIZE := Vector2(64, 64)

## Every puzzle, by the name a terminal can ask for (the "game" value in LevelData.terminals()). The special
## name "random" (what the level terminals use) picks one at random each time the computer is used, never
## the same one twice in a row.
const GAME_NAMES := [
	"sequence", "timing", "dont_press", "color_word", "captcha",
	"wrong_only", "jokes", "dot_count", "mash", "simon_says",
]

## For tests: when not empty, this puzzle is used instead of a random one.
static var force_game := ""

static var _last_game := ""

var laser_id := ""
var game: Minigame
var game_name := ""


static func has_game(game_id: String) -> bool:
	return game_id == "random" or GAME_NAMES.has(game_id)


## A random puzzle name, different from the one used last time.
static func random_game_name() -> String:
	var pick: String = GAME_NAMES[randi() % GAME_NAMES.size()]
	while pick == _last_game and GAME_NAMES.size() > 1:
		pick = GAME_NAMES[randi() % GAME_NAMES.size()]
	return pick


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
		"jokes":
			return JokeGame.new()
		"dot_count":
			return DotCountGame.new()
		"mash":
			return MashGame.new()
		"simon_says":
			return SimonSaysGame.new()
	return SequenceGame.new()


## Show the popup for a laser and puzzle name. Returns the popup (already added under `parent`).
static func open(parent: Node, laser: String, requested: String) -> HackPopup:
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


func _init() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS


func _build(chosen_name: String) -> void:
	get_tree().paused = true
	# Anything the player was holding must not carry on through the pause.
	Input.flush_buffered_events()
	for a in ["move_left", "move_right", "move_up", "move_down", "jump", "interact", "attack_light", "attack_heavy"]:
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
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.09, 0.14)
	style.border_color = Color(0.3, 0.9, 0.5)
	style.set_border_width_all(4)
	style.set_corner_radius_all(18)
	style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	panel.add_child(col)

	# Title row: the title in the middle, a small X in the top-right corner (a blank spacer of the same
	# width on the left keeps the title centred). Nothing else shares this row, so the X can't overlap a puzzle.
	var top := HBoxContainer.new()
	col.add_child(top)
	var spacer := Control.new()
	spacer.custom_minimum_size = CLOSE_SIZE
	top.add_child(spacer)
	var title := Label.new()
	title.text = "FIREWALL TERMINAL"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Color(0.4, 1.0, 0.6))
	top.add_child(title)
	var close := Button.new()
	close.text = "X"
	close.focus_mode = Control.FOCUS_NONE
	close.custom_minimum_size = CLOSE_SIZE
	close.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	close.add_theme_font_size_override("font_size", 30)
	close.pressed.connect(close_popup)
	top.add_child(close)

	game = _make_game(chosen_name)
	var hint := Label.new()
	hint.text = game.instructions
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 28)
	col.add_child(hint)

	var area := Control.new()
	area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	area.custom_minimum_size = Vector2(0, 300)
	col.add_child(area)
	area.add_child(game)
	game.solved.connect(_on_solved)


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		close_popup()
		get_viewport().set_input_as_handled()


func _on_solved() -> void:
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
