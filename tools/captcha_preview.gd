extends Control
## A preview of the "I am not a robot" captcha for looking at every question: it shows each question of the stockpile in turn, with new
## pictures each time you ask. Run it with  tools/captcha_preview.sh  (or: godot --path . res://tools/captcha_preview.tscn).
##   Right / Left arrow, or the buttons: next / previous question      Space: new pictures for the same question
##   A (or the button): show the right answer (marks the right picture in gold; hold it up while you decide)
## You can also just play it: tap a picture and press VERIFY. A right answer moves on to the next question.

var _index := 0
var _game: CaptchaGame
var _title: Label
var _holder: Control
var _show_answer := false


func _ready() -> void:
	InputSetup.register()
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.04, 0.07)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_title = Label.new()
	_title.position = Vector2(40, 18)
	_title.add_theme_font_size_override("font_size", 26)
	_title.add_theme_color_override("font_color", Color(0.6, 1.0, 0.75))
	add_child(_title)
	_holder = Control.new()
	_holder.position = Vector2(170, 90)
	_holder.size = Vector2(940, 440)
	add_child(_holder)
	var bar := HBoxContainer.new()
	bar.position = Vector2(170, 560)
	bar.size = Vector2(940, 70)
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 20)
	add_child(bar)
	for spec in [["< Previous", -1], ["Same question, new pictures", 0], ["Show the answer (A)", 99], ["Next >", 1]]:
		var b := Button.new()
		b.text = spec[0]
		b.custom_minimum_size = Vector2(210, 60)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_act.bind(int(spec[1])))
		bar.add_child(b)
	_load()


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match (event as InputEventKey).keycode:
		KEY_RIGHT:
			_act(1)
		KEY_LEFT:
			_act(-1)
		KEY_SPACE:
			_act(0)
		KEY_A:
			_act(99)


func _act(what: int) -> void:
	var count: int = (CaptchaGame.manifest()["questions"] as Array).size()
	match what:
		1:
			_index = (_index + 1) % count
		-1:
			_index = (_index - 1 + count) % count
		99:
			_show_answer = not _show_answer
			_mark_answer()
			return
	_show_answer = false
	_load()


func _load() -> void:
	if _game != null:
		_game.queue_free()
	_game = CaptchaGame.new()
	_game.forced_question = _index
	_game.custom_minimum_size = _holder.size
	_game.size = _holder.size
	_holder.add_child(_game)
	_game.solved.connect(func() -> void:
		await get_tree().create_timer(0.8).timeout
		_act(1))
	var questions: Array = CaptchaGame.manifest()["questions"]
	var q: Dictionary = questions[_index]
	_title.text = "Question %d of %d" % [_index + 1, questions.size()]


## Mark the right picture with a gold border (or clear it).
func _mark_answer() -> void:
	for t in _game._tiles:
		var b: Button = t["button"]
		var right: bool = CaptchaGame.target_groups_of(_game._question).has(t["group"])
		b.modulate = Color(1.0, 0.9, 0.35) if (_show_answer and right) else (Color(1, 1, 1, 0.45) if _show_answer else Color.WHITE)
