extends SceneTree
## The "I am not a robot" captcha (CaptchaGame): the stockpile of riddles and pictures is complete and small, no riddle gives away its
## answer or is about the player, every round is six pictures with exactly ONE right one, a wrong answer is refused whichever way it is
## wrong, and the rounds vary. Exits non-zero on failure.
## Run: godot_console --headless --fixed-fps 60 --path . --script res://tools/tests/captcha_test.gd

# MAX_TOTAL_KB: the most the captcha pictures may weigh together. They are small cartoon pictures shown at their stored size; if this is
# exceeded something was saved bigger than it needs to be.
const MAX_TOTAL_KB := 300

# PERSONAL_WORDS: words that would make a riddle about the player or a matter of opinion; none may appear in a riddle.
const PERSONAL_WORDS := ["would you", "do you", "your ", " you like", "favourite", "favorite", "prefer", "which one would"]

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


func _main() -> void:
	InputSetup.register()
	await _wait(2)
	var data := CaptchaGame.manifest()
	var riddles: Array = data.get("riddles", [])
	var pictures: Array = data.get("pictures", [])
	_check("there is a stockpile of riddles", riddles.size() >= 20, str(riddles.size()))
	_check("and of pictures", pictures.size() >= 40, str(pictures.size()))
	var problems := []
	var total := 0
	for f in pictures:
		var path: String = CaptchaGame.PICTURE_DIR + str(f)
		var tex := load(path) as Texture2D
		if tex == null:
			problems.append("cannot load " + path)
			continue
		if tex.get_width() != CaptchaGame.TILE_SIZE or tex.get_height() != CaptchaGame.TILE_SIZE:
			problems.append("%s is %dx%d, not %d" % [path, tex.get_width(), tex.get_height(), CaptchaGame.TILE_SIZE])
		total += FileAccess.get_file_as_bytes(path).size()
	_check("every picture exists and is the size it is shown at (no wasted pixels)", problems.is_empty(), str(problems))
	_check("and together they are small (%d KB, at most %d)" % [total / 1024, MAX_TOTAL_KB], total / 1024 <= MAX_TOTAL_KB)
	_check("the picture credits are shipped", FileAccess.file_exists("res://assets/ui/captcha/CREDITS.md"))

	var broken := []
	var answers := {}
	for r in riddles:
		var text := str(r["text"])
		var answer := str(r["answer"])
		if not pictures.has(answer):
			broken.append("%s: answer %s is not a picture" % [text, answer])
		answers[answer] = true
		for f in r["exclude"]:
			if not pictures.has(f) or f == answer:
				broken.append("%s: bad exclude %s" % [text, f])
		if pictures.size() - 1 - (r["exclude"] as Array).size() < CaptchaGame.PICTURES - 1:
			broken.append("%s: not enough wrong pictures" % text)
		# a riddle must not give its answer away by naming it
		var name := answer.get_basename().replace("_", " ")
		if text.to_lower().contains(name):
			broken.append("%s: names its answer (%s)" % [text, name])
		for w in PERSONAL_WORDS:
			if text.to_lower().contains(w):
				broken.append("%s: personal or opinion word '%s'" % [text, w])
		if not text.ends_with("What am I?"):
			broken.append("%s: not a riddle" % text)
	_check("every riddle has a picture as its answer, does not name it, is not personal, and has enough wrong pictures", broken.is_empty(), str(broken))
	_check("every riddle has its own answer", answers.size() == riddles.size())

	# ---- the rounds
	var game := CaptchaGame.new()
	root.add_child(game)
	await _wait(3)
	var seen_riddles := {}
	var seen_pictures := {}
	var bad_rounds := []
	for i in 100:
		game._new_round()
		seen_riddles[str(game._riddle["text"])] = true
		var tiles: Array = game._tiles
		var right := 0
		var names := {}
		var clash := false
		for t in tiles:
			if t["file"] == game._riddle["answer"]:
				right += 1
			elif (game._riddle["exclude"] as Array).has(t["file"]):
				clash = true
			names[t["file"]] = true
			seen_pictures[t["file"]] = true
		if tiles.size() != 6 or right != 1 or names.size() != 6 or clash:
			bad_rounds.append("%d tiles, %d right, %d different, clash %s" % [tiles.size(), right, names.size(), clash])
	_check("every round is six different pictures with exactly one right one, never one the riddle excludes", bad_rounds.is_empty(), str(bad_rounds.slice(0, 3)))
	_check("the rounds vary: many riddles and pictures in 100 rounds", seen_riddles.size() >= 20 and seen_pictures.size() >= 38, "%d riddles, %d pictures" % [seen_riddles.size(), seen_pictures.size()])

	# ---- answers
	game._new_round()
	var tiles2: Array = game._tiles
	var right_tile: Button = null
	var wrong_tiles: Array[Button] = []
	for t in tiles2:
		if t["file"] == game._riddle["answer"]:
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
	_check("a wrong answer does not solve it and a new riddle starts", not solved[0] and game._tiles.size() == 6)
	await game.auto_solve()
	await _wait(3)
	_check("the right answers solve it (it asks %d riddles by default)" % CaptchaGame.ROUNDS, solved[0] and CaptchaGame.ROUNDS >= 2)
	game.queue_free()
	await _wait(3)

	# ---- one riddle only
	var short_game := CaptchaGame.new()
	short_game.params = {"rounds": 1}
	root.add_child(short_game)
	await _wait(3)
	var done1 := [false]
	short_game.solved.connect(func() -> void: done1[0] = true)
	await short_game.auto_solve()
	await _wait(3)
	_check("with rounds = 1 it asks once", done1[0])
	short_game.queue_free()
	await _wait(3)
	print("ALL PASS" if ok else "SOME FAILED")
	quit(0 if ok else 1)
