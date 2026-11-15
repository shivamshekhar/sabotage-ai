extends SceneTree
## The "I am not a robot" captcha (CaptchaGame): the stockpile of questions and pictures is complete and small, every round is six
## pictures with exactly ONE right one, a wrong answer is refused whichever way it is wrong, and the rounds vary. Exits non-zero on
## failure.
## Run: godot_console --headless --fixed-fps 60 --path . --script res://tools/tests/captcha_test.gd

# MAX_TOTAL_KB: the most the captcha pictures may weigh together. They are small cartoon pictures shown at their stored size; if this is
# exceeded something was saved bigger than it needs to be.
const MAX_TOTAL_KB := 300

# NEVER_WRONG: pairs [what the question asks about, groups that could also be right and so must never be among the wrong pictures]. For
# example a laptop can play a song, so "electronic" is never among the wrong pictures of "Which one can you play a song on?".
const NEVER_WRONG := {
	"play a song": ["electronic", "robot"],
	"draw with": ["electronic", "robot"],
	"NOT an instrument": ["electronic", "robot"],
}

var ok := true


func _check(name: String, cond: bool, detail := "") -> void:
	print(("PASS  " if cond else "FAIL  "), name, "  ", detail)
	if not cond:
		ok = false


func _initialize() -> void:
	_main()


func _wait(frames: int) -> void:
	for i in frames:
		await process_frame


func _groups_of(data: Dictionary) -> Array:
	var out := []
	for k in data:
		if k != "questions":
			out.append(k)
	return out


func _main() -> void:
	InputSetup.register()
	await _wait(2)
	var data := CaptchaGame.manifest()
	var questions: Array = data.get("questions", [])
	var groups := _groups_of(data)
	_check("there is a stockpile of questions", questions.size() >= 10, str(questions.size()))
	var problems := []
	var total := 0
	var pictures := 0
	var seen_files := {}
	for group in groups:
		var files: Array = data[group]
		pictures += files.size()
		if files.is_empty():
			problems.append("%s has no pictures" % group)
		for f in files:
			var path: String = CaptchaGame.PICTURE_DIR + "%s/%s" % [group, f]
			if seen_files.has(f):
				problems.append("%s is in two groups" % f)
			seen_files[f] = true
			var tex := load(path) as Texture2D
			if tex == null:
				problems.append("cannot load " + path)
				continue
			if tex.get_width() != CaptchaGame.TILE_SIZE or tex.get_height() != CaptchaGame.TILE_SIZE:
				problems.append("%s is %dx%d, not %d" % [path, tex.get_width(), tex.get_height(), CaptchaGame.TILE_SIZE])
			total += FileAccess.get_file_as_bytes(path).size()
	_check("every picture exists, is in one group only and is the size it is shown at (no wasted pixels)", problems.is_empty(), str(problems))
	_check("a stockpile of pictures (%d)" % pictures, pictures >= 36)
	_check("and together they are small (%d KB, at most %d)" % [total / 1024, MAX_TOTAL_KB], total / 1024 <= MAX_TOTAL_KB)
	var broken := []
	for q in questions:
		var target_groups: Array = CaptchaGame.target_groups_of(q)
		var others: Array = q["others"]
		var wrong_pool := 0
		for g in target_groups:
			if not data.has(g) or (data[g] as Array).is_empty():
				broken.append("%s: no pictures in the right group %s" % [q["text"], g])
		for g in others:
			if not data.has(g):
				broken.append("%s: unknown group %s" % [q["text"], g])
			elif target_groups.has(g):
				broken.append("%s: %s is both right and wrong" % [q["text"], g])
			else:
				wrong_pool += (data[g] as Array).size()
		if wrong_pool < CaptchaGame.PICTURES - 1:
			broken.append("%s: not enough wrong pictures (%d)" % [q["text"], wrong_pool])
		for key in NEVER_WRONG:
			if str(q["text"]).contains(key):
				for g in NEVER_WRONG[key]:
					if others.has(g):
						broken.append("%s: %s could also be right" % [q["text"], g])
	_check("each question has right pictures, enough wrong ones, and nothing that could also be right among them", broken.is_empty(), str(broken))
	_check("the picture credits are shipped", FileAccess.file_exists("res://assets/captcha/CREDITS.md"))

	# ---- the rounds
	var game := CaptchaGame.new()
	root.add_child(game)
	await _wait(3)
	var seen_questions := {}
	var seen_pictures := {}
	var bad_rounds := []
	for i in 80:
		game._new_round()
		seen_questions[str(game._question["text"])] = true
		var tiles: Array = game._tiles
		var right := 0
		var names := {}
		var allowed: Array = CaptchaGame.target_groups_of(game._question) + (game._question["others"] as Array)
		var wrong_group := false
		for t in tiles:
			if CaptchaGame.target_groups_of(game._question).has(t["group"]):
				right += 1
			if not allowed.has(t["group"]):
				wrong_group = true
			var icon: Texture2D = (t["button"] as Button).icon
			names[icon.resource_path] = true
			seen_pictures[icon.resource_path] = true
		if tiles.size() != 6 or right != 1 or names.size() != 6 or wrong_group:
			bad_rounds.append("%d tiles, %d right, %d different" % [tiles.size(), right, names.size()])
	_check("every round is six different pictures with exactly one right one", bad_rounds.is_empty(), str(bad_rounds.slice(0, 3)))
	_check("the rounds vary: many questions and pictures in 80 rounds", seen_questions.size() >= 9 and seen_pictures.size() >= 28, "%d questions, %d pictures" % [seen_questions.size(), seen_pictures.size()])

	# ---- answers
	game._new_round()
	var tiles2: Array = game._tiles
	var right_tile: Button = null
	var wrong_tiles: Array[Button] = []
	for t in tiles2:
		if CaptchaGame.target_groups_of(game._question).has(t["group"]):
			right_tile = t["button"]
		else:
			wrong_tiles.append(t["button"])
	_check("nothing chosen is refused", not game.is_answer_right())
	right_tile.button_pressed = true
	_check("the right picture is accepted", game.is_answer_right())
	wrong_tiles[0].button_pressed = true
	_check("choosing another picture replaces the choice (one at a time)", not right_tile.button_pressed and not game.is_answer_right())
	for w in wrong_tiles:
		w.button_pressed = true
		_check("a wrong picture is refused", not game.is_answer_right())
	var solved := [false]
	game.solved.connect(func() -> void: solved[0] = true)
	await game.auto_fail()
	await _wait(int(Minigame.RETRY_DELAY * 60.0) + 10)
	_check("a wrong answer does not solve it and a new round starts", not solved[0] and game._tiles.size() == 6)
	await game.auto_solve()
	await _wait(3)
	_check("the right answer solves it", solved[0])
	game.queue_free()
	await _wait(3)

	# ---- two rounds in a row
	var long_game := CaptchaGame.new()
	long_game.params = {"rounds": 2}
	root.add_child(long_game)
	await _wait(3)
	var done2 := [false]
	long_game.solved.connect(func() -> void: done2[0] = true)
	await long_game.auto_solve()
	await _wait(3)
	_check("with rounds = 2 it asks twice", done2[0])
	long_game.queue_free()
	await _wait(3)
	print("ALL PASS" if ok else "SOME FAILED")
	quit(0 if ok else 1)
