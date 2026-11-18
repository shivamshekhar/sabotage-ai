class_name StackerGame
extends Minigame
## "Stacker": a block slides left and right above a tower. Press DROP to let it fall onto the tower. Whatever hangs over the
## edge is cut off, so the tower gets narrower; drop it too far off and it misses completely. Build the tower to the top.

# LEVELS: how many blocks to stack on top of the base. Higher: longer.
const LEVELS := 3

# SPEED: how fast the first block slides, in pixels per second. Higher: harder. Each block after it is SPEED_UP times faster.
const SPEED := 300.0
const SPEED_UP := 1.25

# MIN_OVERLAP: the share of the block's width that must rest on the tower for a drop to count (the rest is cut off).
# Higher: needs more exact drops. Lower: more forgiving.
const MIN_OVERLAP := 0.45

# FIELD_WIDTH / BLOCK_HEIGHT / BLOCK_GAP: the size in pixels of the area the blocks slide in, and of each block row.
const FIELD_WIDTH := 560.0
const BLOCK_HEIGHT := 40.0
const BLOCK_GAP := 4.0

# BASE_WIDTH: the width in pixels of the first block (the base) and of the first sliding block.
const BASE_WIDTH := 200.0

const COLORS := [Color(0.25, 0.5, 0.95), Color(0.95, 0.8, 0.15), Color(0.7, 0.35, 0.9), Color(0.95, 0.55, 0.15), Color(0.3, 0.85, 0.4)]

var _field: Control
var _tower: Array[Rect2] = []     # the placed blocks, the base first (x, y, width, height in field pixels)
var _x := 0.0                     # the sliding block's left edge
var _width := BASE_WIDTH
var _dir := 1.0


func _init() -> void:
	instructions = "Press DROP to stack the block. Build the tower!"


func _ready() -> void:
	_build_frame()
	_prompt.visible = false
	_field = Control.new()
	_field.custom_minimum_size = Vector2(FIELD_WIDTH, (float(_p("levels", LEVELS)) + 1.0) * (BLOCK_HEIGHT + BLOCK_GAP))
	_field.draw.connect(_draw_field)
	var row := _make_row()
	row.add_child(_field)
	var drop := _make_button("DROP", Color(0.2, 0.55, 0.9))
	drop.custom_minimum_size = Vector2(220, _field.custom_minimum_size.y)
	drop.pressed.connect(press)
	row.add_child(drop)
	begin()


func begin() -> void:
	_tower.clear()
	_width = BASE_WIDTH
	_tower.append(_block_rect((FIELD_WIDTH - BASE_WIDTH) / 2.0, 0, BASE_WIDTH))
	_x = 0.0
	_dir = 1.0
	_update_status()


## The rectangle of the block in row `row` (0 = the base, at the bottom of the field).
func _block_rect(x: float, row: int, width: float) -> Rect2:
	var top := _field_height() - float(row + 1) * (BLOCK_HEIGHT + BLOCK_GAP) + BLOCK_GAP
	return Rect2(x, top, width, BLOCK_HEIGHT)


func _field_height() -> float:
	return (float(_p("levels", LEVELS)) + 1.0) * (BLOCK_HEIGHT + BLOCK_GAP)


func _update_status() -> void:
	_status.text = "STACKED  %d / %d" % [_tower.size() - 1, int(_p("levels", LEVELS))]


func _speed() -> float:
	return float(_p("speed", SPEED)) * pow(SPEED_UP, _tower.size() - 1)


func _process(delta: float) -> void:
	if _over or _field == null:
		return
	_x += _dir * _speed() * delta
	if _x + _width >= FIELD_WIDTH:
		_x = FIELD_WIDTH - _width
		_dir = -1.0
	elif _x <= 0.0:
		_x = 0.0
		_dir = 1.0
	_field.queue_redraw()


func _draw_field() -> void:
	_field.draw_rect(Rect2(Vector2.ZERO, _field.size), Color(0.08, 0.1, 0.15))
	for i in _tower.size():
		_field.draw_rect(_tower[i], COLORS[i % COLORS.size()])
	if not _over:
		_field.draw_rect(_block_rect(_x, _tower.size(), _width), Color(1, 1, 1))


## The DROP button (also callable from tests).
func press() -> void:
	if _over:
		return
	var below: Rect2 = _tower[_tower.size() - 1]
	var left: float = maxf(_x, below.position.x)
	var right: float = minf(_x + _width, below.position.x + below.size.x)
	var overlap := right - left
	if overlap < _width * float(_p("min_overlap", MIN_OVERLAP)):
		_lose("IT FELL OFF! RETRY")
		return
	_width = overlap
	_tower.append(_block_rect(left, _tower.size(), overlap))
	_update_status()
	if _tower.size() - 1 >= int(_p("levels", LEVELS)):
		_win()
		_field.queue_redraw()


## For tests: put the sliding block exactly over the tower.
func aim() -> void:
	var below: Rect2 = _tower[_tower.size() - 1]
	_x = below.position.x


func auto_solve() -> void:
	for i in int(_p("levels", LEVELS)):
		while _over:
			await _wait_frames(1)
		aim()
		press()
		await _wait_frames(1)


func auto_fail() -> void:
	while _over:
		await _wait_frames(1)
	var below: Rect2 = _tower[_tower.size() - 1]
	_x = 0.0 if below.position.x > _width else FIELD_WIDTH - _width
	press()
