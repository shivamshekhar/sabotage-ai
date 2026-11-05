extends Node2D
## A small data-center "ship" room. Solids get colliders; everything is drawn in code.

const WORLD_W := 2400
const FLOOR_Y := 600

# Walls, floor, ceiling.
const SHELL: Array[Rect2] = [
	Rect2(0, 600, 2400, 60),
	Rect2(0, -40, 2400, 40),
	Rect2(-40, -40, 40, 700),
	Rect2(2400, -40, 40, 700),
]

# Platforms. Max step is ~100px (jump apex is ~128px).
const PLATFORMS: Array[Rect2] = [
	Rect2(300, 500, 200, 24),
	Rect2(600, 400, 200, 24),
	Rect2(900, 300, 200, 24),
	Rect2(1250, 500, 300, 24),
	Rect2(1650, 420, 200, 24),
	Rect2(1950, 320, 260, 24),
]

const RACK_XS: Array[int] = [90, 560, 1120, 1560, 2060, 2260]

const STEEL := Color("#5a6577")
const STEEL_DARK := Color("#2a303d")
const OUTLINE := Color("#0b0d14")
const WALL := Color("#151a28")
const WALL_LINE := Color("#1d2436")
const HAZARD := Color("#f5c518")

var time := 0.0


func _ready() -> void:
	for r in SHELL:
		_add_solid(r)
	for r in PLATFORMS:
		_add_solid(r)


func _process(delta: float) -> void:
	time += delta
	queue_redraw()


func _add_solid(r: Rect2) -> void:
	var body := StaticBody2D.new()
	body.position = r.get_center()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = r.size
	shape.shape = rect
	body.add_child(shape)
	add_child(body)


func _draw() -> void:
	# Back wall
	draw_rect(Rect2(0, 0, WORLD_W, FLOOR_Y), WALL)
	for x in range(0, WORLD_W, 160):
		draw_line(Vector2(x, 0), Vector2(x, FLOOR_Y), WALL_LINE, 4.0)
	for y in range(100, FLOOR_Y, 150):
		draw_line(Vector2(0, y), Vector2(WORLD_W, y), WALL_LINE, 2.0)

	# Server racks (decor, no collision)
	for x in RACK_XS:
		_draw_rack(x)

	# Title
	draw_string(ThemeDB.fallback_font, Vector2(130, 70), "DATA CENTER 01",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Color(1, 1, 1, 0.35))

	# Solids
	for r in SHELL:
		_draw_solid(r, false)
	for r in PLATFORMS:
		_draw_solid(r, true)


func _draw_solid(r: Rect2, hazard_top: bool) -> void:
	draw_rect(r.grow(3), OUTLINE)
	draw_rect(r, STEEL)
	draw_rect(Rect2(r.position.x, r.end.y - 6, r.size.x, 6), STEEL_DARK)
	if hazard_top:
		var x := r.position.x
		while x < r.end.x:
			draw_rect(Rect2(x, r.position.y, minf(12.0, r.end.x - x), 5), HAZARD)
			x += 24.0


func _draw_rack(x: int) -> void:
	var rack := Rect2(x, FLOOR_Y - 170, 90, 170)
	draw_rect(rack.grow(3), OUTLINE)
	draw_rect(rack, STEEL_DARK)
	for i in 6:
		var y := rack.position.y + 12 + i * 26
		draw_rect(Rect2(x + 8, y, 74, 18), Color("#1b2030"))
		for j in 3:
			var on := sin(time * 3.0 + x * 0.01 + i * 1.7 + j * 2.3) > 0.2
			var c := Color("#2ee66b") if (i + j) % 3 != 0 else Color("#ff4d4d")
			if not on:
				c = c.darkened(0.7)
			draw_circle(Vector2(x + 18 + j * 14, y + 9), 3.5, c)
