class_name EditorTheme
extends RefCounted
## Colours and the Godot Theme of the level editor (a dark, compact look).

# BG: the window background colour. Lower values are darker.
const BG := Color(0.11, 0.12, 0.15)

# PANEL: the colour of the side panels (drawer, inspector, bottom bar).
const PANEL := Color(0.15, 0.16, 0.2)

# FIELD: the colour of text fields, list backgrounds and buttons at rest.
const FIELD := Color(0.2, 0.22, 0.27)

# ACCENT: the highlight colour (selected palette item, focus, selection outline).
const ACCENT := Color(0.3, 0.85, 0.55)

# TEXT: the normal text colour.
const TEXT := Color(0.88, 0.9, 0.95)

# DIM_TEXT: secondary text (hints, labels of unchanged values).
const DIM_TEXT := Color(0.6, 0.64, 0.72)

# ERROR: colour of validation errors and of the "cannot place here" text.
const ERROR := Color(1.0, 0.4, 0.4)

# WARN: colour of validation warnings and soft-rule hints.
const WARN := Color(1.0, 0.8, 0.3)

# FONT_SIZE: default text size in pixels for the whole editor. Raise it for a bigger, roomier interface.
const FONT_SIZE := 14


static func _box(color: Color, border: Color = Color(0, 0, 0, 0), radius: int = 4, margin: int = 6) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.border_color = border
	s.set_border_width_all(1 if border.a > 0.0 else 0)
	s.set_corner_radius_all(radius)
	s.content_margin_left = margin
	s.content_margin_right = margin
	s.content_margin_top = 3
	s.content_margin_bottom = 3
	return s


## A StyleBoxFlat panel in the editor's panel colour.
static func panel_box() -> StyleBoxFlat:
	var s := _box(PANEL, Color(0.25, 0.27, 0.33), 0, 6)
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	return s


## The Theme applied to the whole editor window.
static func build() -> Theme:
	var t := Theme.new()
	t.default_font_size = FONT_SIZE
	for type in ["Label", "CheckBox", "Button", "OptionButton", "LineEdit", "SpinBox", "ItemList", "RichTextLabel", "MenuButton", "TabContainer"]:
		t.set_color("font_color", type, TEXT)
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_color("font_placeholder_color", "LineEdit", DIM_TEXT)
	t.set_stylebox("panel", "PanelContainer", panel_box())
	t.set_stylebox("panel", "Panel", panel_box())
	for type in ["Button", "OptionButton", "MenuButton"]:
		t.set_stylebox("normal", type, _box(FIELD, Color(0.3, 0.32, 0.4)))
		t.set_stylebox("hover", type, _box(Color(0.27, 0.3, 0.38), Color(0.4, 0.42, 0.5)))
		t.set_stylebox("pressed", type, _box(Color(0.18, 0.4, 0.3), ACCENT))
		t.set_stylebox("focus", type, _box(Color(0, 0, 0, 0), ACCENT))
		t.set_stylebox("disabled", type, _box(Color(0.14, 0.15, 0.18), Color(0.2, 0.21, 0.25)))
	t.set_color("font_disabled_color", "Button", Color(0.45, 0.47, 0.52))
	t.set_stylebox("normal", "LineEdit", _box(FIELD, Color(0.3, 0.32, 0.4)))
	t.set_stylebox("focus", "LineEdit", _box(FIELD, ACCENT))
	t.set_stylebox("panel", "ItemList", _box(Color(0.12, 0.13, 0.16), Color(0.25, 0.27, 0.33), 2))
	t.set_stylebox("selected", "ItemList", _box(Color(0.18, 0.4, 0.3), ACCENT, 2))
	t.set_stylebox("selected_focus", "ItemList", _box(Color(0.18, 0.4, 0.3), ACCENT, 2))
	t.set_stylebox("panel", "TabContainer", _box(PANEL, Color(0.25, 0.27, 0.33), 0, 6))
	t.set_stylebox("tab_selected", "TabContainer", _box(PANEL, ACCENT, 0, 10))
	t.set_stylebox("tab_unselected", "TabContainer", _box(Color(0.12, 0.13, 0.16), Color(0.25, 0.27, 0.33), 0, 10))
	t.set_stylebox("tab_hovered", "TabContainer", _box(Color(0.2, 0.22, 0.28), Color(0.4, 0.42, 0.5), 0, 10))
	t.set_color("font_selected_color", "TabContainer", ACCENT)
	t.set_color("font_unselected_color", "TabContainer", DIM_TEXT)
	t.set_color("font_hovered_color", "TabContainer", TEXT)
	return t
