class_name CaptchaGame
extends Minigame
## A silly captcha: tick "I AM NOT A ROBOT"... but the box keeps dodging and getting suspicious. After
## enough ticks you are declared human (probably). The small honest "I AM A ROBOT" button loses.

# TICKS_NEEDED: how many times the box must be ticked. Higher: a longer chase.
const TICKS_NEEDED := 3

const REMARKS := [
	"Hmm. That was suspiciously fast.",
	"Beep boop? ...No. Again.",
	"A human would hesitate more.",
	"Almost convincing. Once more.",
]

const FIELD_SIZE := Vector2(840, 150)
const BOX_SIZE := Vector2(330, 110)

var _field: Control
var _check: Button
var _robot: Button
var _ticks := 0


func _init() -> void:
	instructions = "Prove you are a human."


func _ready() -> void:
	_build_frame()
	_prompt.text = "CAPTCHA: PROVE YOU ARE NOT A ROBOT"
	_field = Control.new()
	_field.custom_minimum_size = FIELD_SIZE
	_field.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_box.add_child(_field)
	_check = _make_button("[ ] I AM NOT A ROBOT", Color(0.25, 0.3, 0.45))
	_check.size = BOX_SIZE
	_check.custom_minimum_size = BOX_SIZE
	_check.add_theme_font_size_override("font_size", 26)
	_check.pressed.connect(_on_tick)
	_field.add_child(_check)
	_robot = _make_button("I am a robot", Color(0.35, 0.2, 0.2))
	_robot.custom_minimum_size = Vector2(240, 60)
	_robot.add_theme_font_size_override("font_size", 22)
	_robot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_robot.pressed.connect(func() -> void: _lose("HONESTY IS NOT REWARDED."))
	_box.add_child(_robot)
	begin()


func begin() -> void:
	_ticks = 0
	_status.text = "0 / %d" % TICKS_NEEDED
	_check.text = "[ ] I AM NOT A ROBOT"
	_check.position = (FIELD_SIZE - BOX_SIZE) / 2.0


func _on_tick() -> void:
	if _over:
		return
	_ticks += 1
	if _ticks >= TICKS_NEEDED:
		_check.text = "[x] HUMAN (PROBABLY)"
		_win()
		return
	_status.text = REMARKS[randi() % REMARKS.size()]
	_check.position = Vector2(randf_range(0.0, FIELD_SIZE.x - BOX_SIZE.x), randf_range(0.0, FIELD_SIZE.y - BOX_SIZE.y))


func auto_solve() -> void:
	for i in TICKS_NEEDED:
		_check.pressed.emit()
		await _wait_frames(1)


func auto_fail() -> void:
	_robot.pressed.emit()
