extends Node2D
## Data-center level built from Kenney's "Platformer Pack: Industrial" tilesheet (CC0).
## Tilesheet is a 70px grid. Solids get colliders; art is drawn from the sheet.

const TILESHEET: Texture2D = preload("res://assets/kenney/platformer-pack-industrial/tilesheet.png")

const T := 70
const COLS := 36
const FLOOR_Y := 630
const WORLD_W := COLS * T

# Platforms as Vector3i(first_tile_x, top_y_px, length_in_tiles).
# Max step is ~100px (jump apex is ~128px).
const PLATFORMS: Array[Vector3i] = [
	Vector3i(4, 530, 3),
	Vector3i(9, 430, 3),
	Vector3i(13, 330, 3),
	Vector3i(18, 530, 4),
	Vector3i(24, 440, 3),
	Vector3i(28, 340, 4),
]

# Background machine panels (3x2 tiles) standing on the floor, by tile x.
const MACHINE_XS: Array[int] = [1, 7, 16, 22, 31]

const WALL := Color("#151a28")
const WALL_LINE := Color("#1d2436")


func _ready() -> void:
	# Floor, ceiling and side walls (invisible colliders).
	_add_solid(Rect2(0, FLOOR_Y, WORLD_W, T))
	_add_solid(Rect2(0, -40, WORLD_W, 40))
	_add_solid(Rect2(-40, -40, 40, FLOOR_Y + T + 40))
	_add_solid(Rect2(WORLD_W, -40, 40, FLOOR_Y + T + 40))
	# One-way platforms: jump up through them from below.
	for p in PLATFORMS:
		_add_solid(Rect2(p.x * T, p.y, p.z * T, 20), true)


func _add_solid(r: Rect2, one_way: bool = false) -> void:
	var body := StaticBody2D.new()
	body.position = r.get_center()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = r.size
	shape.shape = rect
	shape.one_way_collision = one_way
	body.add_child(shape)
	add_child(body)


func _tile(col: int, row: int, w: int = T, h: int = T) -> Rect2:
	return Rect2(col * T, row * T, w, h)


func _blit(dest: Rect2, src: Rect2) -> void:
	draw_texture_rect_region(TILESHEET, dest, src)


func _draw() -> void:
	# Back wall
	draw_rect(Rect2(-200, -100, WORLD_W + 400, FLOOR_Y + 100), WALL)
	for x in range(0, WORLD_W, 140):
		draw_line(Vector2(x, 0), Vector2(x, FLOOR_Y), WALL_LINE, 4.0)
	for y in range(70, FLOOR_Y, 140):
		draw_line(Vector2(0, y), Vector2(WORLD_W, y), WALL_LINE, 2.0)

	# Title
	draw_string(ThemeDB.fallback_font, Vector2(130, 70), "DATA CENTER 01",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Color(1, 1, 1, 0.35))

	# Machine panels (decor)
	for mx in MACHINE_XS:
		_blit(Rect2(mx * T, FLOOR_Y - 2 * T, 3 * T, 2 * T), Rect2(2 * T, 4 * T, 3 * T, 2 * T))

	# Floor: top tile row
	for i in COLS:
		_blit(Rect2(i * T, FLOOR_Y, T, T), _tile(2, 0))

	# Platforms: thin ledge tiles (40px tall)
	for p in PLATFORMS:
		for i in p.z:
			var col := 7 if i % 2 == 0 else 8
			_blit(Rect2((p.x + i) * T, p.y, T, 40), _tile(col, 0, T, 40))
