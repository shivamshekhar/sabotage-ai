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


func _ready() -> void:
	InputSetup.register()

	var level := Level.new()
	level.level_id = _chosen_level_id()
	if TouchControls.should_show():
		# Let the camera scroll a little past each end so the player isn't hidden behind the
		# D-pad (left) or the buttons (right) near the level's edges.
		level.side_padding = TOUCH_SIDE_PADDING
	add_child(level)

	var player := Player.new()
	player.spawn = level.spawn
	player.ladders = level.ladders
	player.position = level.spawn
	add_child(player)

	_setup_camera(level, player)
	level.goal_reached.connect(_on_goal_reached)


## Which level to load: the environment variable SABOTAGE_LEVEL ("test" for the test level),
## otherwise the default level. An unknown value warns and falls back to the default.
func _chosen_level_id() -> String:
	var wanted := OS.get_environment("SABOTAGE_LEVEL")
	if wanted == "":
		return LevelData.DEFAULT_ID
	if not LevelData.has_level(wanted):
		push_warning("Unknown SABOTAGE_LEVEL '%s'; using level %s" % [wanted, LevelData.DEFAULT_ID])
		return LevelData.DEFAULT_ID
	return wanted


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
		cam.limit_left = -level.side_padding
		cam.limit_top = 0
		cam.limit_right = level.world_w + level.side_padding
		cam.limit_bottom = level.world_h
		player.add_child(cam)
		add_child(Vignette.new())
		if TouchControls.should_show():  # phones only; hidden on PC
			add_child(TouchControls.new())
	cam.make_current()


func _on_goal_reached() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	var label := Label.new()
	label.text = "DATA CENTER OFFLINE\nLEVEL COMPLETE"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.add_theme_font_size_override("font_size", 56)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 12)
	layer.add_child(label)
	add_child(layer)
	await get_tree().create_timer(3.0).timeout
	get_tree().reload_current_scene()
