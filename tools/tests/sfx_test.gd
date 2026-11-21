extends SceneTree
## The sound effects: every name in Sfx is a sound file that loads (so no sound is silently missing in the game), the booster's sound is set to loop, and a SfxLoop follows set_on() (it fades out and then stops). Exits non-zero on failure.
## Run: godot_console --headless --fixed-fps 60 --path . --script res://tools/tests/sfx_test.gd

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


## Every sound name that Sfx has: its single names and the takes of each array.
func _all_names() -> Array[StringName]:
	var names: Array[StringName] = []
	var script: Script = Sfx
	var constants := script.get_script_constant_map()
	for constant_name in constants:
		var value: Variant = constants[constant_name]
		if value is StringName:
			names.append(value)
		elif value is Array:
			for take: StringName in value:
				names.append(take)
	return names


func _main() -> void:
	var names := _all_names()
	_check("Sfx lists the sounds", not names.is_empty(), "%d names" % names.size())
	var missing: Array[String] = []
	for sfx_name in names:
		if Sfx.stream(sfx_name) == null:
			missing.append(String(sfx_name))
	_check("every sound in Sfx is a file that loads", missing.is_empty(), str(missing))

	var booster := Sfx.stream(Sfx.MECH_BOOSTER) as AudioStreamWAV
	_check("the booster's sound loops", booster != null and booster.loop_mode == AudioStreamWAV.LOOP_FORWARD)

	var holder := Node.new()
	root.add_child(holder)
	var loop := SfxLoop.attach(holder, Sfx.MECH_BOOSTER)
	_check("a loop starts off", not loop.is_on())
	loop.set_on(true)
	_check("set_on(true) turns it on at full volume", loop.is_on() and is_equal_approx(loop.volume_db, 0.0))
	loop.set_on(false)
	_check("set_on(false) turns it off", not loop.is_on())
	var waited := 0
	while loop.volume_db > AudioBuses.MUTE_DB + 0.5 and waited < 120:
		await process_frame
		waited += 1
	_check("it fades out to silence", loop.volume_db <= AudioBuses.MUTE_DB + 0.5, "%d frames" % waited)
	holder.queue_free()

	print("ALL PASS" if ok else "SOME FAILED")
	quit(0 if ok else 1)
