extends SceneTree
## Headless test of the live monitor screens: the three monitors exist and sit on the machine's blank
## screens, the graph and oscilloscope keep moving, and the terminal runs its whole "AI job": funny
## quips, a progress bar that goes 0 to 100 (stalling at 99), the results page with the water
## figure, then starts again. Exits non-zero on failure.
## Run: godot_console --headless --fixed-fps 60 --path . --script res://tools/tests/screens_test.gd

var main: Node
var level: Level
var frames := 0
var ok := true


func _initialize() -> void:
	OS.set_environment("SABOTAGE_LEVEL", "test")
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _check(name: String, cond: bool, detail := "") -> void:
	print(("PASS  " if cond else "FAIL  "), name, "  ", detail)
	if not cond:
		ok = false


func _wait(n: int) -> void:
	for i in n:
		await process_frame


func _process(_d: float) -> bool:
	# _process must not contain `await` (a coroutine's return value makes Godot quit).
	frames += 1
	if frames == 5:
		_main()
	if frames > 900:
		print("FAIL  test timed out before finishing")
		quit(1)
	return false


func _screen(kind: MonitorScreen.Kind) -> MonitorScreen:
	for n in level.get_children():
		if n is MonitorScreen and n.kind == kind:
			return n
	return null


func _main() -> void:
	for n in main.get_children():
		if n is Level:
			level = n

	# ---- placement
	var all := []
	for n in level.get_children():
		if n is MonitorScreen:
			all.append(n)
	_check("the monitoring station has three live screens", all.size() == 3, "%d found" % all.size())
	var graph := _screen(MonitorScreen.Kind.GRAPH)
	var terminal := _screen(MonitorScreen.Kind.TERMINAL)
	var scope := _screen(MonitorScreen.Kind.SCOPE)
	_check("one of each kind (graph, terminal, scope)", graph != null and terminal != null and scope != null)
	var rects := MachineScreens.rects("machine_monitoring_station")
	_check("the generator wrote the three screen rectangles", rects.size() == 3 and rects.has("left") and rects.has("center") and rects.has("right"))
	var sizes_ok := true
	for key in rects:
		var kind: MonitorScreen.Kind = Level.SCREEN_KINDS[key]
		var s := _screen(kind)
		if s == null or not s.size.is_equal_approx((rects[key] as Rect2).size):
			sizes_ok = false
	_check("each screen is exactly the size of its blank monitor", sizes_ok)
	_check("a machine without monitors gets no screens", MachineScreens.rects("machine_gpu_rack").is_empty())

	# ---- everything sits inside the margin of its screen and nothing overlaps
	for s in all:
		var layout: Dictionary = s.layout_rects()
		var inner := Rect2(MonitorScreen.PADDING, MonitorScreen.PADDING, s.size.x - 2.0 * MonitorScreen.PADDING, s.size.y - 2.0 * MonitorScreen.PADDING).grow(0.01)
		var inside := true
		for key in layout:
			if not inner.encloses(layout[key]):
				inside = false
		var overlap := false
		var keys := layout.keys()
		for i in keys.size():
			for j in range(i + 1, keys.size()):
				if (layout[keys[i]] as Rect2).intersects(layout[keys[j]]):
					overlap = true
		_check("%s screen: all content is inside the margin" % MonitorScreen.Kind.keys()[s.kind], inside, str(layout))
		_check("%s screen: nothing overlaps" % MonitorScreen.Kind.keys()[s.kind], not overlap)

	# ---- every string fits at the full font size (no shrinking needed, so none gets cut off)
	var status: Rect2 = terminal.layout_rects()["status"]
	var too_big := []
	var messages: Array[String] = [MonitorScreen.STALL_TEXT, MonitorScreen.DONE_TEXT]
	messages.append_array(MonitorScreen.QUIPS)
	messages.append_array(MonitorScreen.STATS)
	for m in messages:
		if terminal.fitted_font_size(m, MonitorScreen.FONT_BODY, status.size.x, status.size.y) != MonitorScreen.FONT_BODY:
			too_big.append(m.replace("\n", " / "))
	_check("terminal: every message fits its slot at the full text size", too_big.is_empty(), str(too_big))
	var long_captions := []
	var caption_rect: Rect2 = graph.layout_rects()["caption"]
	var captions: Array[String] = ["16999 t/s"]   # the widest the oscilloscope's number can get
	captions.append_array(MonitorScreen.GRAPH_CAPTIONS)
	for c in captions:
		if graph.fitted_font_size(c, MonitorScreen.FONT_SMALL, caption_rect.size.x, caption_rect.size.y) != MonitorScreen.FONT_SMALL:
			long_captions.append(c)
	_check("graph and oscilloscope: every caption fits on one line at the full text size", long_captions.is_empty(), str(long_captions))
	var bar: Rect2 = terminal.layout_rects()["bar"]
	var label_w := ThemeDB.fallback_font.get_string_size("100%", HORIZONTAL_ALIGNMENT_LEFT, -1, MonitorScreen.FONT_SMALL).x
	_check("terminal: the percentage fits inside the progress bar", label_w < bar.size.x and ThemeDB.fallback_font.get_height(MonitorScreen.FONT_SMALL) * 0.72 < bar.size.y)

	# ---- the graph and the oscilloscope keep moving
	var before_graph := graph.graph_samples().duplicate()
	var before_phase := scope.scope_phase()
	await _wait(40)
	_check("the graph scrolls (its samples change)", graph.graph_samples() != before_graph)
	_check("the oscilloscope wave keeps moving", scope.scope_phase() > before_phase + 0.5, "phase %.2f -> %.2f" % [before_phase, scope.scope_phase()])
	var lo := 1.0
	var hi := 0.0
	await _wait(30)
	for v in graph.graph_samples():
		lo = minf(lo, v)
		hi = maxf(hi, v)
	_check("graph values stay inside the screen (0..1)", lo >= 0.0 and hi <= 1.0, "range %.2f..%.2f" % [lo, hi])

	# ---- the AI job, run on fast-forward by stepping the screen's own clock
	var quips_seen := {}
	var last_progress := -1.0
	var monotonic := true
	var stalled_seen := false
	var started_loading := terminal.job_state() == MonitorScreen.Job.LOADING
	var guard := 0
	while terminal.job_state() != MonitorScreen.Job.DONE and guard < 4000:
		terminal._process(0.05)
		guard += 1
		quips_seen[terminal.status_text()] = true
		if terminal.progress() < last_progress - 0.001 and terminal.job_state() != MonitorScreen.Job.DONE:
			monotonic = false
		last_progress = terminal.progress()
		if terminal.job_state() == MonitorScreen.Job.STALLED:
			stalled_seen = true
			_check("while stalled the bar is stuck at the stall point", is_equal_approx(terminal.progress(), MonitorScreen.JOB_STALL_AT)) if not quips_seen.has("__stall_checked") else null
			quips_seen["__stall_checked"] = true
	_check("the job starts in the loading state", started_loading)
	_check("the first message is 'Loading...'", MonitorScreen.QUIPS[0] == "Loading...")
	_check("the job reaches the finished state", terminal.job_state() == MonitorScreen.Job.DONE, "%d steps" % guard)
	_check("the progress bar never goes backwards", monotonic)
	_check("it stalls near the end before finishing", stalled_seen)
	_check("several different funny messages appear while loading", quips_seen.size() >= 4, "%d distinct" % (quips_seen.size() - 1))
	_check("the bar ends at 100", is_equal_approx(terminal.progress(), 100.0))
	_check("the finished message is the AI slop poster one", (terminal.status_text() == MonitorScreen.DONE_TEXT) and ("slop poster" in terminal.status_text().replace("\n", " ")), terminal.status_text().replace("\n", " "))

	# ---- the results, then it starts over
	var pages := []
	guard = 0
	while terminal.job_state() == MonitorScreen.Job.DONE and guard < 400:
		pages.append(terminal.status_text())
		terminal._process(0.05)
		guard += 1
	var joined := "\n".join(pages)
	_check("the results include the water used (69,000 gallons)", "69,000" in joined and "gallons" in joined)
	_check("the results show several lines", pages.size() > 0 and joined.count("\n") >= 4)
	_check("after the results it starts a new job", terminal.job_state() == MonitorScreen.Job.LOADING and terminal.progress() < 5.0,
		"state %d, progress %.1f" % [terminal.job_state(), terminal.progress()])

	print("ALL PASS" if ok else "SOME FAILED")
	quit(0 if ok else 1)
