class_name TitleMenu
extends PanelContainer
## The title screen's menu, down the left side: one big button per entry, its name on the left and its icon on the right. Only the settings work so far; the rest are
## places for what the game will have later (a level list, upgrades, vehicles, gadgets) and say "coming soon" on a tap. Pressing a button emits `chosen` with the entry's id.
##
##   var menu := TitleMenu.new()
##   menu.chosen.connect(func(id: StringName) -> void: print(id))

signal chosen(id: StringName)

# ENTRIES: the menu from top to bottom: the id it reports, its name, its icon (a picture in assets/ui/icons/, see AssetPaths.ui) and whether it works yet.
const ENTRIES := [
	{"id": &"levels", "label": "LEVELS", "icon": "icon_levels", "ready": false},
	{"id": &"upgrades", "label": "UPGRADES", "icon": "icon_upgrades", "ready": false},
	{"id": &"vehicles", "label": "VEHICLES", "icon": "icon_vehicles", "ready": false},
	{"id": &"gadgets", "label": "GADGETS", "icon": "icon_gadgets", "ready": false},
	{"id": &"settings", "label": "SETTINGS", "icon": "icon_settings", "ready": true},
]

# BUTTON_SIZE: the size of a button in pixels; ICON_SIZE: the width of its icon; FONT_SIZE: its lettering; SEPARATION: the space between two buttons.
const BUTTON_SIZE := Vector2(268.0, 70.0)
const ICON_SIZE := 46
const FONT_SIZE := 27
const SEPARATION := 12

# READY_COLOR / SOON_COLOR: the colour of a button that works / of one that is only a place for something to come (dimmer).
const READY_COLOR := Color(0.2, 0.42, 0.7)
const SOON_COLOR := Color(0.15, 0.23, 0.36)

# SOON_TEXT / SOON_SIZE / SOON_TAG_COLOR: the small "soon" tag in the corner of a button that does not work yet.
const SOON_TEXT := "SOON"
const SOON_SIZE := 13
const SOON_TAG_COLOR := Color(1.0, 0.72, 0.25)
const SOON_TAG_WIDTH := 60.0

# STRIP_HEIGHT: the hazard stripe above and below the buttons. PANEL_ALPHA: how solid the menu's panel is (0 to 1).
const STRIP_HEIGHT := 10.0
const PANEL_ALPHA := 0.86


func _ready() -> void:
	var box := HackStyle.panel()
	box.bg_color = Color(HackStyle.NAVY_DARK, PANEL_ALPHA)
	box.set_content_margin_all(14)
	add_theme_stylebox_override("panel", box)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", SEPARATION)
	add_child(column)
	column.add_child(HazardStrip.make(STRIP_HEIGHT))
	for entry: Dictionary in ENTRIES:
		column.add_child(_button(entry))
	column.add_child(HazardStrip.make(STRIP_HEIGHT))


func _button(entry: Dictionary) -> Button:
	var ready: bool = entry["ready"]
	var button := Button.new()
	button.text = str(entry["label"])
	button.icon = AssetPaths.ui(str(entry["icon"]))
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = BUTTON_SIZE
	button.add_theme_font_size_override("font_size", FONT_SIZE)
	button.add_theme_constant_override("icon_max_width", ICON_SIZE)
	button.add_theme_constant_override("h_separation", 10)
	HackStyle.style_button(button, READY_COLOR if ready else SOON_COLOR)
	if not ready:
		button.add_child(_soon_tag())
	button.pressed.connect(func() -> void:
		button.release_focus()          # (so Enter, afterwards, starts the game instead of pressing this button again)
		Sfx.play(get_tree(), Sfx.CLICK)
		chosen.emit(entry["id"]))
	return button


func _soon_tag() -> Label:
	var tag := Label.new()
	tag.text = SOON_TEXT
	tag.add_theme_font_size_override("font_size", SOON_SIZE)
	HackStyle.style_text(tag, SOON_TAG_COLOR)
	tag.add_theme_constant_override("outline_size", 3)
	tag.offset_left = 14.0
	tag.offset_right = 14.0 + SOON_TAG_WIDTH
	tag.offset_top = 2.0
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tag
