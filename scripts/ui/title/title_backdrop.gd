class_name TitleBackdrop
extends Control
## The title screen's distant view: a stretch of a data center as the levels have it (the hall behind, a floor with racks and servers, bros pacing, deadly pits with their
## creatures leaping out of them), slowly drifting past, and put out of focus so it looks far away behind the title. The real level classes draw it (LevelBackground,
## PitHazard, SpriteLibrary), in a viewport of its own that is shown through the defocus shader (see defocus.gdshader).
##
##   var backdrop := TitleBackdrop.new()
##   layer.add_child(backdrop)

# FLOOR_Y: the world y of the floor's top, in the view. FLOOR_SCREEN_SHARE: how far down the screen (0 to 1) that floor is shown.
const FLOOR_Y := 520.0
const FLOOR_SCREEN_SHARE := 0.68

# ZOOM: how big the distant view is drawn (below 1: smaller than the levels, so it is far away).
const ZOOM := 0.85

# PAN_FROM / PAN_TO: the world x the view drifts between; PAN_TIME: seconds one way takes. It eases at each end, so the drift is never a jolt.
const PAN_FROM := 760.0
const PAN_TO := 2300.0
const PAN_TIME := 42.0

# BLUR_RADIUS / DIM: how out of focus (pixels) and how dark (0 to 1) the distance is (see defocus.gdshader).
const BLUR_RADIUS := 6.0
const DIM := 0.06

# TILE: the tile size in pixels (Level.T). PIT_DEPTH: how many tiles deep a pit is. FILL_ROWS: how many rows of buried ground there are under the floor.
const TILE := 70
const PIT_DEPTH := 3
const FILL_ROWS := 4

# LED_PERIOD: seconds one blink of a machine's lights takes.
const LED_PERIOD := 1.8

# BRO_MARGIN: how far (px) from the ends of its floor a bro turns round.
const BRO_MARGIN := 40.0

# STRIP: the floor, from left to right, in pieces. A piece is a stretch of floor ("ground": its width in tiles, "machines": [sprite name, tile it stands on], "bro": a bro
# paces on it) or a deadly pit ("pit": its kind, "width": in tiles).
const STRIP := [
	{"ground": 7, "machines": [["machine_gpu_rack", 1], ["machine_server_tower", 4]], "bro": true},
	{"pit": "lava", "width": 3},
	{"ground": 6, "machines": [["machine_supercomputer", 1]]},
	{"pit": "piranha_tank", "width": 4},
	{"ground": 8, "machines": [["machine_monitoring_station", 2]], "bro": true},
	{"pit": "nuclear_waste", "width": 3},
	{"ground": 6, "machines": [["machine_gpu_rack", 1], ["machine_gpu_rack", 3]]},
	{"pit": "toxic_waste", "width": 3},
	{"ground": 7, "machines": [["machine_server_tower", 2]], "bro": true},
]

# STRIP_START: the world x where the strip begins.
const STRIP_START := -280.0

var _viewport: SubViewport
var _camera: Camera2D
var _world: Node2D


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(get_viewport_rect().size)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.disable_3d = true
	add_child(_viewport)
	_world = Node2D.new()
	_viewport.add_child(_world)
	_camera = Camera2D.new()
	_camera.zoom = Vector2.ONE * ZOOM
	_camera.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS      # (as the game's camera: physics interpolation is on)
	_camera.position = Vector2(PAN_FROM, 0.0)
	_world.add_child(_camera)
	_build_hall()
	_build_strip()
	var view := TextureRect.new()
	view.texture = _viewport.get_texture()
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_SCALE
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = load(AssetPaths.DEFOCUS_SHADER)
	material.set_shader_parameter("radius", BLUR_RADIUS)
	material.set_shader_parameter("dim", DIM)
	view.material = material
	add_child(view)
	resized.connect(_fit)
	_fit()
	_camera.make_current()
	var pan := create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pan.tween_property(_camera, "position:x", PAN_TO, PAN_TIME)
	pan.tween_property(_camera, "position:x", PAN_FROM, PAN_TIME)


## Fit the view to the screen: the viewport is as big as the control, and the camera is set so the floor is shown FLOOR_SCREEN_SHARE of the way down.
func _fit() -> void:
	var screen := get_viewport_rect().size
	_viewport.size = Vector2i(screen)
	_camera.position.y = FLOOR_Y - (FLOOR_SCREEN_SHARE * screen.y - screen.y / 2.0) / ZOOM


## The hall behind: the parallax layers of one of the levels (a different one each time the game starts, so the colour changes).
func _build_hall() -> void:
	var hall := LevelBackground.new()
	var ids := LevelData.level_ids()
	if not ids.is_empty():
		hall.dir = LevelData.background_dir(ids[randi() % ids.size()])
	_world.add_child(hall)


func _build_strip() -> void:
	var x := STRIP_START
	for piece: Dictionary in STRIP:
		if piece.has("pit"):
			var width: float = float(piece["width"]) * TILE
			_build_pit(str(piece["pit"]), x, width)
			x += width
		else:
			var tiles: int = int(piece["ground"])
			_build_ground(x, tiles)
			for machine: Array in piece.get("machines", []):
				_build_machine(str(machine[0]), x + int(machine[1]) * TILE)
			if bool(piece.get("bro", false)):
				var bro := TitleBro.new()
				bro.setup(x + BRO_MARGIN, x + tiles * TILE - BRO_MARGIN, FLOOR_Y)
				bro.z_index = 1
				_world.add_child(bro)
			x += tiles * TILE


## A stretch of floor: the top row with its two ends, and the buried rows under it.
func _build_ground(x: float, tiles: int) -> void:
	for i in tiles:
		var top := "ground_middle"
		if i == 0:
			top = "ground_start"
		elif i == tiles - 1:
			top = "ground_end"
		_tile(top, x + i * TILE, FLOOR_Y)
		for row in range(1, FILL_ROWS + 1):
			_tile("ground_fill", x + i * TILE, FLOOR_Y + row * TILE)


## A deadly pit: buried ground under it, and the liquid with its creatures (the real PitHazard).
func _build_pit(kind: String, x: float, width: float) -> void:
	for i in int(width / TILE):
		for row in range(PIT_DEPTH, FILL_ROWS + 1):
			_tile("ground_fill", x + i * TILE, FLOOR_Y + row * TILE)
	_world.add_child(PitHazard.new(kind, Rect2(x, FLOOR_Y, width, PIT_DEPTH * TILE)))


## A machine standing on the floor with its lights blinking (like Level's).
func _build_machine(sprite_name: String, x: float) -> void:
	var texture := SpriteLibrary.machine(sprite_name)
	var at := Vector2(x, FLOOR_Y - texture.get_height())
	_sprite(texture, at)
	for i in 2:
		var leds := _sprite(SpriteLibrary.machine("%s_leds_%s" % [sprite_name, "a" if i == 0 else "b"]), at)
		var blink := leds.create_tween().set_loops()
		blink.tween_interval(LED_PERIOD * 0.5 * i)
		blink.tween_property(leds, "modulate:a", 0.25, LED_PERIOD * 0.5).set_trans(Tween.TRANS_SINE)
		blink.tween_property(leds, "modulate:a", 1.0, LED_PERIOD * 0.5).set_trans(Tween.TRANS_SINE)
		blink.tween_interval(LED_PERIOD * 0.5 * (1 - i))


func _tile(sprite_name: String, x: float, y: float) -> void:
	_sprite(SpriteLibrary.tile(sprite_name), Vector2(x, y))


func _sprite(texture: Texture2D, at: Vector2) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = false
	sprite.position = at
	_world.add_child(sprite)
	return sprite
