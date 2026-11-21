class_name PauseMenu
extends CanvasLayer
## The pause menu of the game screen: the game stops, the screen dims and a window offers, from top to bottom as most games do, RESUME (the first and the one that has the focus),
## SETTINGS (the volumes and the controls: see SettingsPanel) and QUIT TO TITLE (last, in red; it asks "are you sure?" first, with CANCEL as the default). Esc resumes (or steps
## back out of the question). It is opened by the pause button (see PauseButton, Hud) or Esc.
##
##   PauseMenu.open(self)       # does nothing if the game is already paused (a puzzle window is open) or the menu is already there

# LAYER: the canvas layer of the menu: over the HUD, the touch controls and the banners, under the settings window (40) and the screen flash.
const LAYER := 32

# PANEL_WIDTH: the window's width in pixels (in the 1280x720 reference screen); BUTTON_SIZE: the size of each button; FONT_SIZE: their lettering. TITLE_SIZE / HINT_SIZE: the font sizes
# of the heading and of the line under the question. STRIP_HEIGHT: the hazard stripe along the top.
const PANEL_WIDTH := 460.0
const BUTTON_SIZE := Vector2(380.0, 64.0)
const FONT_SIZE := 28
const TITLE_SIZE := 40
const HINT_SIZE := 18
const STRIP_HEIGHT := 12.0

# RESUME_COLOR / SETTINGS_COLOR / QUIT_COLOR / CANCEL_COLOR: the buttons' colours.
const RESUME_COLOR := Color(0.18, 0.55, 0.36)
const SETTINGS_COLOR := Color(0.2, 0.42, 0.7)
const QUIT_COLOR := Color(0.62, 0.2, 0.24)
const CANCEL_COLOR := Color(0.2, 0.42, 0.7)

const TITLE_TEXT := "PAUSED"
const QUESTION_TEXT := "QUIT TO TITLE?"
const QUESTION_HINT := "YOUR PROGRESS AND SCORE WILL BE LOST."

static var _open_menu: PauseMenu

var _column: VBoxContainer
var _settings: SettingsPanel
var _asking := false
var _resume: Button
var _settings_button: Button
var _paused_by_me := false


## Open the menu under `parent` (the game stops). Returns it, or null if the game is already paused or the menu is already open.
static func open(parent: Node) -> PauseMenu:
	if parent.get_tree().paused or is_instance_valid(_open_menu):
		return null
	var menu := PauseMenu.new()
	parent.add_child(menu)
	return menu


func _init() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_open_menu = self
	get_tree().paused = true
	_paused_by_me = true
	Input.flush_buffered_events()
	for action in InputActions.ALL:             # whatever the player was holding must not carry on through the pause
		Input.action_release(action)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0.0)
	panel.add_theme_stylebox_override("panel", HackStyle.panel())
	center.add_child(panel)
	_column = VBoxContainer.new()
	_column.add_theme_constant_override("separation", 14)
	panel.add_child(_column)
	_show_menu()


func _exit_tree() -> void:
	if _open_menu == self:
		_open_menu = null
	if _paused_by_me and get_tree() != null:
		get_tree().paused = false


func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or int(event.physical_keycode) != KEY_ESCAPE:
		return
	if _settings != null:
		return                    # (the settings window takes the Esc)
	get_viewport().set_input_as_handled()
	if _asking:
		_show_menu()
	else:
		resume()


## Close the menu and carry on with the game.
func resume() -> void:
	Sfx.play(get_tree(), Sfx.CLICK)
	queue_free()


# ---------------------------------------------------------------------------------------------------------------------------
# the two views of the window
# ---------------------------------------------------------------------------------------------------------------------------
## The menu: PAUSED, then RESUME, SETTINGS, QUIT TO TITLE.
func _show_menu() -> void:
	_asking = false
	_clear()
	_column.add_child(HazardStrip.make(STRIP_HEIGHT))
	_column.add_child(_label(TITLE_TEXT, TITLE_SIZE, HackStyle.MINT))
	_resume = _button("RESUME", RESUME_COLOR, resume)
	_column.add_child(_resume)
	_settings_button = _button("SETTINGS", SETTINGS_COLOR, _open_settings)
	_column.add_child(_settings_button)
	_column.add_child(_button("QUIT TO TITLE", QUIT_COLOR, _show_question))
	_resume.grab_focus()


## "Quit to title?": CANCEL (the default) above QUIT.
func _show_question() -> void:
	_asking = true
	_clear()
	_column.add_child(HazardStrip.make(STRIP_HEIGHT))
	_column.add_child(_label(QUESTION_TEXT, TITLE_SIZE, HackStyle.ORANGE))
	var hint := _label(QUESTION_HINT, HINT_SIZE, Color(HackStyle.TEXT, 0.7))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(PANEL_WIDTH - 60.0, 0.0)
	_column.add_child(hint)
	var cancel := _button("CANCEL", CANCEL_COLOR, _show_menu)
	_column.add_child(cancel)
	_column.add_child(_button("QUIT", QUIT_COLOR, quit_to_title))
	cancel.grab_focus()


func _clear() -> void:
	for child in _column.get_children():
		_column.remove_child(child)
		child.queue_free()


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	HackStyle.style_text(label, color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func _button(text: String, color: Color, on_press: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = BUTTON_SIZE
	button.add_theme_font_size_override("font_size", FONT_SIZE)
	HackStyle.style_button(button, color)
	button.pressed.connect(func() -> void:
		if on_press != resume:
			Sfx.play(get_tree(), Sfx.CLICK)
		on_press.call())
	return button


# ---------------------------------------------------------------------------------------------------------------------------
# what the buttons do
# ---------------------------------------------------------------------------------------------------------------------------
func _open_settings() -> void:
	_settings = SettingsPanel.open(self, TouchControls.should_show())
	_settings.closed.connect(func() -> void:
		_settings = null
		if _settings_button != null and is_instance_valid(_settings_button):
			_settings_button.grab_focus())


## Leave the game for the title screen: the game is over (the score and what was carried start from nothing), and the game is not paused any more.
func quit_to_title() -> void:
	GameStats.reset()
	LevelData.selected_id = ""
	TitleScreen.requested = true          # (the title is shown even if a level was chosen in the environment)
	_paused_by_me = false
	get_tree().paused = false
	get_tree().change_scene_to_file(AssetPaths.TITLE_SCENE)
