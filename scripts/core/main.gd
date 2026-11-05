extends Node2D
## Entry point: wires input, level, player, camera, touch controls and the win banner.
## Set env var SABOTAGE_PREVIEW=1 to render a zoomed-out view of the whole level.


func _ready() -> void:
	InputSetup.register()

	var level := Level.new()
	add_child(level)

	var player := Player.new()
	player.spawn = level.spawn
	player.position = level.spawn
	add_child(player)

	_setup_camera(level, player)
	level.goal_reached.connect(_on_goal_reached)


func _setup_camera(level: Level, player: Player) -> void:
	var cam := Camera2D.new()
	if OS.get_environment("SABOTAGE_PREVIEW") != "":
		cam.position = Vector2(level.world_w, level.world_h) / 2.0
		cam.zoom = Vector2(0.3, 0.3)
		add_child(cam)
	else:
		cam.position_smoothing_enabled = true
		cam.limit_left = 0
		cam.limit_top = 0
		cam.limit_right = level.world_w
		cam.limit_bottom = level.world_h
		player.add_child(cam)
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
