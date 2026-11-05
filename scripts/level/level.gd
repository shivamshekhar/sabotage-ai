class_name Level
extends Node2D
## Builds a playable level (sprites, colliders, hazards, ladders, exit) from a
## LevelData ASCII map, using the individual Kenney sprites via SpriteLibrary.

signal goal_reached

const T := 70  # tile size in px
const SOLID := "#XO"

var world_w := 0
var world_h := 0
var spawn := Vector2.ZERO

var _map: Array[String] = []
var _goal_fired := false


func _ready() -> void:
	_map = LevelData.level_1()
	var cols := _map[0].length()
	for r in _map.size():
		if _map[r].length() != cols:
			push_error("Level row %d has length %d, expected %d" % [r, _map[r].length(), cols])
	world_w = cols * T
	world_h = _map.size() * T

	_build_backdrop()
	_build_tiles()
	_build_solid_colliders()
	_build_ledges()
	_build_ladders()


# ---------- map helpers ----------

func _cell(c: int, r: int) -> String:
	if r < 0 or r >= _map.size() or c < 0 or c >= _map[r].length():
		return "#"  # out of bounds counts as solid wall
	return _map[r][c]


func _is_solid(c: int, r: int) -> bool:
	return SOLID.contains(_cell(c, r))


func _place(sprite_name: String, c: int, r: int, z: int = 0) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = SpriteLibrary.tile(sprite_name)
	s.centered = false
	s.position = Vector2(c * T, r * T)
	s.z_index = z
	add_child(s)
	return s


func _decor(sprite_name: String, c: int, r: int, z: int = -5, tint: Color = Color(0.78, 0.82, 0.95)) -> Sprite2D:
	var s := _place(sprite_name, c, r, z)
	s.modulate = tint
	return s


## Pick <prefix>_start / _middle / _end (and _single when available) from neighbours.
func _run_name(prefix: String, ch: String, c: int, r: int, has_single: bool) -> String:
	var l := _cell(c - 1, r) == ch
	var rt := _cell(c + 1, r) == ch
	if l and rt:
		return prefix + "_middle"
	if rt:
		return prefix + "_start"
	if l:
		return prefix + "_end"
	return prefix + ("_single" if has_single else "_start")


func _ground_name(c: int, r: int) -> String:
	if _cell(c, r - 1) == "#":
		return "ground_fill"
	return _run_name("ground", "#", c, r, true)


# ---------- building ----------

func _build_tiles() -> void:
	for r in _map.size():
		for c in _map[r].length():
			match _map[r][c]:
				"#": _place(_ground_name(c, r), c, r)
				"X": _place("block_metal_x", c, r)
				"O": _place("block_metal_orange", c, r)
				"=": _place(_run_name("ledge", "=", c, r, true), c, r)
				"H": _place("ladder_top" if _cell(c, r - 1) != "H" else "ladder_middle", c, r, -2)
				"^":
					_place("spikes_up", c, r, 1)
					_add_hazard(Rect2(c * T + 10, r * T + 30, 50, 40))
				"v":
					_place("spikes_down", c, r, 1)
					_add_hazard(Rect2(c * T + 10, r * T, 50, 40))
				"k": _decor(_run_name("panel_controls", "k", c, r, false), c, r)
				"w": _decor(_run_name("panel_dark", "w", c, r, false), c, r)
				"r": _decor(_run_name("rail_thin", "r", c, r, false), c, r, -4, Color.WHITE)
				"m": _decor("monitor_text", c, r)
				"t": _decor("monitor_tv_text", c, r)
				"g": _decor("gear_full", c, r, -6)
				"i": _decor("siren_orange" if c % 2 == 0 else "siren_blue", c, r, -3, Color.WHITE)
				"l": _decor("lamp_pole_green", c, r, -3, Color.WHITE)
				"c": _decor("canister_blue_vertical" if c % 2 == 0 else "canister_yellow_vertical", c, r, -3)
				"~": _place(_run_name("slime_floor", "~", c, r, true), c, r, -1)
				"P": spawn = Vector2((c + 0.5) * T, (r + 1) * T)
				"E": _build_exit(c, r)


func _build_exit(c: int, r: int) -> void:
	var s := _decor("sign_power_green", c, r, -1, Color.WHITE)
	var tw := create_tween().set_loops()
	tw.tween_property(s, "modulate:a", 0.45, 0.6)
	tw.tween_property(s, "modulate:a", 1.0, 0.6)
	var area := _make_area(Rect2(c * T, r * T, T, T))
	area.body_entered.connect(_on_goal_body)


func _on_goal_body(body: Node) -> void:
	if body is Player and not _goal_fired:
		_goal_fired = true
		goal_reached.emit()


func _make_area(rect: Rect2) -> Area2D:
	var area := Area2D.new()
	area.position = rect.get_center()
	var shape := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = rect.size
	shape.shape = rs
	area.add_child(shape)
	add_child(area)
	return area


func _add_hazard(rect: Rect2) -> void:
	var area := _make_area(rect)
	area.body_entered.connect(func(body: Node) -> void:
		if body is Player:
			body.die())


func _add_solid(rect: Rect2, one_way: bool = false) -> void:
	var body := StaticBody2D.new()
	body.position = rect.get_center()
	var shape := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = rect.size
	shape.shape = rs
	shape.one_way_collision = one_way
	body.add_child(shape)
	add_child(body)


## Merge solid tiles into the fewest rectangles (greedy) to avoid seams.
func _build_solid_colliders() -> void:
	var used := {}
	var rows := _map.size()
	var cols := _map[0].length()
	for r in rows:
		for c in cols:
			if used.has(Vector2i(c, r)) or not _is_solid(c, r):
				continue
			var w := 1
			while c + w < cols and _is_solid(c + w, r) and not used.has(Vector2i(c + w, r)):
				w += 1
			var h := 1
			while r + h < rows and _row_free(c, r + h, w, used):
				h += 1
			for yy in h:
				for xx in w:
					used[Vector2i(c + xx, r + yy)] = true
			_add_solid(Rect2(c * T, r * T, w * T, h * T))


func _row_free(c: int, r: int, w: int, used: Dictionary) -> bool:
	for xx in w:
		if not _is_solid(c + xx, r) or used.has(Vector2i(c + xx, r)):
			return false
	return true


func _build_ledges() -> void:
	for r in _map.size():
		var c := 0
		while c < _map[r].length():
			if _map[r][c] == "=":
				var start := c
				while c < _map[r].length() and _map[r][c] == "=":
					c += 1
				_add_solid(Rect2(start * T, r * T, (c - start) * T, 14), true)
			else:
				c += 1


func _build_ladders() -> void:
	for c in _map[0].length():
		var r := 0
		while r < _map.size():
			if _cell(c, r) == "H":
				var top := r
				while _cell(c, r) == "H":
					r += 1
				var area := _make_area(Rect2(c * T + 15, top * T, 40, (r - top) * T))
				area.body_entered.connect(func(body: Node) -> void:
					if body is Player:
						body.ladder_count += 1)
				area.body_exited.connect(func(body: Node) -> void:
					if body is Player:
						body.ladder_count -= 1)
				# Stand on top of the ladder; climb up through it from below.
				_add_solid(Rect2(c * T, top * T, T, 12), true)
			else:
				r += 1


# ---------- backdrop ----------

func _build_backdrop() -> void:
	add_child(LevelBackground.new())

	# Light tint over the parallax art so gameplay tiles stay readable, plus the title.
	var bd := Node2D.new()
	bd.z_index = -20
	add_child(bd)
	bd.draw.connect(func() -> void:
		bd.draw_rect(Rect2(0, 0, world_w, world_h), Color(0.04, 0.06, 0.11, 0.30))
		bd.draw_string(ThemeDB.fallback_font, Vector2(150, 260), "DATA CENTER 01",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Color(1, 1, 1, 0.35)))
	bd.queue_redraw()
