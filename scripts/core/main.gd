extends Node2D
## Entry point: wires input, level, player, camera, touch controls and the win banner.
## Set env var SABOTAGE_PREVIEW=1 to render a zoomed-out view of the whole level.

# TOUCH_SIDE_PADDING: on phones only, how far in pixels the camera may scroll past each end
# of the level. The level draws that much decorative wall beyond its edges
# (Level.side_padding) and the camera limits are widened by the same amount:
#     limit_left = -padding,   limit_right = world width + padding
# Without it the camera stops at the level edge, which can leave the player hidden behind
# the D-pad at the start or the buttons at the end. It must be at least the D-pad's right
# edge plus its grab padding plus half the player's width (see TouchControls: MARGIN,
# DPAD_RADIUS, DPAD_GRAB_PADDING and Player.BODY_SIZE).
# Higher: more empty wall visible at the level's ends. Lower: the player can disappear
# behind the controls. tools/tests/hud_clearance_test.gd checks this.
const TOUCH_SIDE_PADDING := 400


var _level_id := ""

# fight: the boss fight, in a level that has a boss (null otherwise).
var fight: BossFight

# _player: the player of this level (what is carried to the next level is read from it, see GameStats.save_player()).
var _player: Player


func _ready() -> void:
	InputSetup.register()
	_level_id = _chosen_level_id()
	var boss_name := BossFight.boss_of(_level_id)
	MusicPlayer.ensure_playing(get_tree(), MusicPlayer.BOSS_TRACK if boss_name != "" else MusicPlayer.TRACK)

	var level := Level.new()
	level.level_id = _level_id
	if TouchControls.should_show():
		# Let the camera scroll a little past each end so the player isn't hidden behind the
		# D-pad (left) or the buttons (right) near the level's edges.
		level.side_padding = TOUCH_SIDE_PADDING
	add_child(level)
	Hud.add_to(self, LevelData.stage_label(_level_id))

	var player := Player.new()
	_player = player
	player.apply_tuning(level.player_tuning, level.terrain_tuning)
	player.spawn = level.spawn
	player.ladders = level.ladders
	player.position = level.spawn
	# Debug aid: SABOTAGE_START="column,row" starts the player standing on that map tile (row = the tile the
	# feet are in), e.g. to look at a part of a big level. It also becomes the respawn point.
	var start_at := OS.get_environment("SABOTAGE_START").split(",")
	if start_at.size() == 2:
		player.position = Vector2((float(start_at[0]) + 0.5) * Level.T, (float(start_at[1]) + 1.0) * Level.T)
		player.spawn = player.position
	add_child(player)
	GameStats.apply_to(player)    # the health and the vehicle (in the state it was in) from the last level; nothing in a new game

	if boss_name != "":
		# A boss level: the fight has its own camera; beating the boss finishes the level.
		fight = BossFight.new()
		add_child(fight)
		fight.setup(level, player)
		fight.defeated.connect(_on_boss_defeated)
		add_child(Vignette.new())
		if TouchControls.should_show():
			add_child(TouchControls.new())
	else:
		_setup_camera(level, player)
	level.goal_reached.connect(_on_goal_reached)

	player.died.connect(_on_player_died)

	# Using a computer opens its puzzle; solving it switches the laser off.
	player.interacted.connect(func() -> void: level.try_interact(player.global_position))
	level.hack_requested.connect(func(laser_id: String, game: String) -> void:
		var popup := HackPopup.open(self, laser_id, game)
		popup.solved.connect(func(id: String) -> void: level.set_laser(id, false)))


## Which level to load, in this order: a level file given on the command line (`-- --level-file=path`) or in the environment
## variable SABOTAGE_LEVEL_FILE; the level chosen by finishing the previous one (LevelData.selected_id); the environment
## variable SABOTAGE_LEVEL (a folder name in levels/, such as "level_02", or "test" for the test level);
## otherwise the default level. An unknown value warns and falls back to the default.
func _chosen_level_id() -> String:
	var path := _level_file_path()
	if path != "":
		var loaded := LevelFile.load_file(path)
		if (loaded["data"] as Dictionary).is_empty():
			push_warning("Cannot play level file %s: %s" % [path, loaded["errors"]])
		else:
			for problem in loaded["errors"]:
				push_warning("Level file %s: %s" % [path, problem])
			LevelData.use_file(loaded["data"], path.get_base_dir())
			return LevelData.FILE_ID
	if LevelData.selected_id != "" and LevelData.has_level(LevelData.selected_id):
		return LevelData.selected_id
	var wanted := OS.get_environment("SABOTAGE_LEVEL")
	if wanted == "":
		return LevelData.DEFAULT_ID
	if not LevelData.has_level(wanted):
		push_warning("Unknown SABOTAGE_LEVEL '%s'; using level %s" % [wanted, LevelData.DEFAULT_ID])
		return LevelData.DEFAULT_ID
	return wanted


## The level file to play, if any: `--level-file=path` after `--` on the command line, or SABOTAGE_LEVEL_FILE.
func _level_file_path() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--level-file="):
			return arg.trim_prefix("--level-file=")
	return OS.get_environment("SABOTAGE_LEVEL_FILE")


func _setup_camera(level: Level, player: Player) -> void:
	var cam := Camera2D.new()
	if OS.get_environment("SABOTAGE_PREVIEW") != "":
		cam.position = Vector2(level.world_w, level.world_h) / 2.0
		# Fit the whole level in the window (with a small margin).
		var view := Vector2(get_viewport().get_visible_rect().size)
		var fit := minf(view.x / level.world_w, view.y / level.world_h) * 0.95
		cam.zoom = Vector2(fit, fit)
		add_child(cam)
	else:
		cam.position_smoothing_enabled = true
		# Follow in the physics step, like the player it is attached to, so the two never drift apart by a
		# fraction of a pixel (the player's movement is interpolated; see project.godot, physics_interpolation).
		cam.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
		cam.limit_left = -level.side_padding
		cam.limit_top = 0
		cam.limit_right = level.world_w + level.side_padding
		cam.limit_bottom = level.world_h
		player.add_child(cam)
		add_child(Vignette.new())
		if TouchControls.should_show():  # phones only; hidden on PC
			add_child(TouchControls.new())
	cam.make_current()


# GAME_OVER_TIME: seconds the "GAME OVER" banner stays up after the player dies, while they
# respawn at the last checkpoint. Higher: a longer pause to take it in. Lower: back in the action sooner.
const GAME_OVER_TIME := 1.6

func _on_player_died(cause: String) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 19
	var label := Label.new()
	label.text = "GAME OVER" + "\n" + {"pit": "fell into a deadly pit", "fall": "fell too far", "health": "out of health"}.get(cause, "")
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.add_theme_font_size_override("font_size", 56)
	label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 12)
	layer.add_child(label)
	add_child(layer)
	get_tree().create_timer(GAME_OVER_TIME).timeout.connect(layer.queue_free)
	if fight != null:
		# Losing to a boss starts the fight again from the beginning (the boss gets all its health back).
		await get_tree().create_timer(GAME_OVER_TIME).timeout
		LevelData.selected_id = _level_id
		get_tree().reload_current_scene()


# BOSS_DOWN_TIME: seconds the "boss defeated" message shows before the level is finished.
const BOSS_DOWN_TIME := 2.5

func _on_boss_defeated() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 19
	var label := Label.new()
	label.text = "BOSS DEFEATED\nRAM SALTMAN IS DOWN"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.add_theme_font_size_override("font_size", 56)
	label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.6))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 12)
	layer.add_child(label)
	add_child(layer)
	await get_tree().create_timer(BOSS_DOWN_TIME).timeout
	layer.queue_free()
	_on_goal_reached()


func _on_goal_reached() -> void:
	# Finishing a level loads the next one; after the last (or a level with no next) it starts again.
	var next := LevelData.next_id(_level_id)
	var again := next == ""
	if again:
		next = LevelData.DEFAULT_ID if LevelData.is_campaign(_level_id) else _level_id
		GameStats.reset()   # the game starts over: the score, the health and the vehicle too
	elif _player != null and is_instance_valid(_player):
		GameStats.save_player(_player)   # the health and the vehicle (with its damage and fuel) go with the player into the next level
	var layer := CanvasLayer.new()
	layer.layer = 20
	var label := Label.new()
	label.text = "DATA CENTER OFFLINE\nLEVEL COMPLETE" if not again else "ALL DATA CENTERS OFFLINE\nTHE END (for now)"
	if not again:
		label.text += "\nNext: %s" % LevelData.title(next)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.add_theme_font_size_override("font_size", 56)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 12)
	layer.add_child(label)
	add_child(layer)
	await get_tree().create_timer(3.0).timeout
	LevelData.selected_id = next
	get_tree().reload_current_scene()
