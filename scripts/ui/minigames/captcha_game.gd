class_name CaptchaGame
extends Minigame
## The "I AM NOT A ROBOT" captcha: a riddle and six small cartoon pictures. The riddle is told by the thing itself ("I have 88 keys but
## cannot open a single door. What am I?") and never names its answer; exactly ONE picture fits. Tap it and press VERIFY. A wrong answer
## is met with a suspicious remark and a new riddle with new pictures. The riddles are easy to crack but need a moment's thought, and
## none of them is about the player.
##
## The riddles and pictures are a stockpile in assets/captcha/ (see manifest.json; tools/art/fetch_captcha_images.py makes it from cartoon
## emoji pictures downloaded from the web, a few KB each). A riddle names its right picture (`answer`) and the pictures that could also
## fit it (`exclude`), which are never shown with it. A round picks a riddle at random, then five other pictures at random, shuffled.
## Add riddles and pictures to the manifest and they are used.

# COLUMNS / PICTURES: the pictures are laid out in COLUMNS columns, PICTURES of them in all (one right, the rest wrong).
const COLUMNS := 3
const PICTURES := 6

# ROUNDS: how many riddles in a row must be answered right (a level file can change it with the "rounds" setting).
const ROUNDS := 2

# TILE_SIZE: the size in pixels a picture is shown at: the size of the stored pictures (no scaling, so they are sharp). It is not
# smaller than BUTTON_MIN, so a finger can always hit one.
const TILE_SIZE := 128
const TILE_GAP := 8

# RIDDLE_FONT_SIZE: the size of the riddle's text (it is a sentence or two, so it is smaller than the other puzzles' prompts).
const RIDDLE_FONT_SIZE := 26

# MANIFEST_PATH: the list of riddles and picture files, and PICTURE_DIR the folder of the pictures.
const MANIFEST_PATH := "res://assets/captcha/manifest.json"
const PICTURE_DIR := "res://assets/captcha/"

const REMARKS := [
	"A ROBOT WOULD SAY THAT. TRY AGAIN.",
	"HMM. NOT QUITE HUMAN ENOUGH.",
	"BEEP BOOP? NO. AGAIN.",
	"SUSPICIOUS. NEW CAPTCHA.",
	"THAT IS NOT HOW A HUMAN SEES IT.",
]

static var _manifest := {}

var _grid: GridContainer
var _verify: Button
var _tiles: Array[Dictionary] = []     # {"button": Button, "file": String}
var _choice := ButtonGroup.new()       # the pictures are a radio group: one chosen at a time
var _riddle := {}
var _round := 0

## Index of the riddle to always ask (negative = a random one each round). Used by tools/captcha_preview.tscn to go through them all.
var forced_question := -1


func _init() -> void:
	instructions = "Prove you are a human."


## The riddles and pictures (read once from the manifest file).
static func manifest() -> Dictionary:
	if _manifest.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
		if typeof(parsed) == TYPE_DICTIONARY:
			_manifest = parsed
	return _manifest


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 28)
	add_child(row)
	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", TILE_GAP)
	_grid.add_theme_constant_override("v_separation", TILE_GAP)
	_grid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_grid)
	var side := VBoxContainer.new()
	side.custom_minimum_size = Vector2(400, 0)
	side.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	side.add_theme_constant_override("separation", 14)
	row.add_child(side)
	_status = _make_label("", 24)
	_status.add_theme_color_override("font_color", Color(0.4, 1.0, 0.6))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(_status)
	_prompt = _make_label("", RIDDLE_FONT_SIZE)
	_prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(_prompt)
	_verify = _make_button("VERIFY", Color(0.2, 0.45, 0.3))
	_verify.custom_minimum_size = Vector2(0, 70)
	_verify.add_theme_font_size_override("font_size", 32)
	_verify.pressed.connect(_on_verify)
	side.add_child(_verify)
	begin()


func begin() -> void:
	_round = 0
	_new_round()


## A new riddle with new pictures.
func _new_round() -> void:
	_over = false
	var data := manifest()
	var riddles: Array = data.get("riddles", [])
	_riddle = riddles[forced_question if forced_question >= 0 else randi() % riddles.size()]
	_prompt.text = str(_riddle["text"])
	_status.text = "RIDDLE %d / %d" % [_round + 1, int(_p("rounds", ROUNDS))]
	var picks: Array[String] = [str(_riddle["answer"])]
	var others: Array = []
	for file in data["pictures"]:
		if file != _riddle["answer"] and not (_riddle["exclude"] as Array).has(file):
			others.append(file)
	others.shuffle()
	for file in others.slice(0, PICTURES - 1):
		picks.append(str(file))
	picks.shuffle()
	_choice = ButtonGroup.new()
	_clear(_grid)
	_tiles.clear()
	for file in picks:
		var b := _make_tile(file)
		_grid.add_child(b)
		_tiles.append({"button": b, "file": file})


func _make_tile(file: String) -> Button:
	var b := Button.new()
	b.toggle_mode = true
	b.button_group = _choice
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(TILE_SIZE, TILE_SIZE)
	b.icon = load(PICTURE_DIR + file)
	b.expand_icon = true
	b.add_theme_constant_override("icon_max_width", TILE_SIZE)
	var plain := StyleBoxFlat.new()
	plain.bg_color = Color(0.12, 0.14, 0.2)
	plain.set_border_width_all(3)
	plain.border_color = Color(0.3, 0.34, 0.46)
	plain.set_corner_radius_all(8)
	plain.set_content_margin_all(3)
	var chosen := plain.duplicate() as StyleBoxFlat
	chosen.border_color = Color(0.35, 1.0, 0.55)
	chosen.set_border_width_all(7)
	chosen.bg_color = Color(0.2, 0.5, 0.3)
	b.add_theme_stylebox_override("normal", plain)
	b.add_theme_stylebox_override("hover", plain)
	b.add_theme_stylebox_override("pressed", chosen)
	b.add_theme_stylebox_override("hover_pressed", chosen)
	return b


## True if the chosen picture is the answer of the riddle (nothing chosen is not right).
func is_answer_right() -> bool:
	for t in _tiles:
		if (t["button"] as Button).button_pressed:
			return t["file"] == _riddle["answer"]
	return false


func _on_verify() -> void:
	if _over:
		return
	if not is_answer_right():
		_lose(REMARKS[randi() % REMARKS.size()])
		return
	_round += 1
	if _round >= int(_p("rounds", ROUNDS)):
		_win()
	else:
		_status.text = "CORRECT. ONE MORE..."
		_new_round()


## Test hooks: choose the right picture (or a wrong one) and press VERIFY.
func auto_solve() -> void:
	for r in int(_p("rounds", ROUNDS)):
		for t in _tiles:
			if t["file"] == _riddle["answer"]:
				(t["button"] as Button).button_pressed = true
		await _wait_frames(1)
		_verify.pressed.emit()
		await _wait_frames(1)


func auto_fail() -> void:
	for t in _tiles:
		if t["file"] != _riddle["answer"]:
			(t["button"] as Button).button_pressed = true
			break
	await _wait_frames(1)
	_verify.pressed.emit()
