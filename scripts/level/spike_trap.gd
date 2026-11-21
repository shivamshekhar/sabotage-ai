class_name SpikeTrap
extends Node2D
## Ordinary spikes (map characters ^ on the floor and v hanging from a ceiling). They HURT: standing
## in them costs Player.hazard_damage() health every Player.INVULN_TIME seconds, they never kill outright,
## and enemies are immune to them. Deadly pits are a different thing: see PitHazard.

# TILE: tile size in pixels; must match Level.T.
const TILE := 70

# FLOOR_BOX / CEILING_BOX: the part of the tile, in pixels from its top-left, that actually hurts: just
# the points of the spikes, a bit narrower than the tile so grazing the sides is safe. Bigger: harsher.
const FLOOR_BOX := Rect2(10, 30, 50, 40)
const CEILING_BOX := Rect2(10, 0, 50, 40)

var _column := 0
var _row := 0
var _on_floor := true


## Spikes in map cell (column, row); `on_floor` false hangs them from the ceiling.
func _init(column: int = 0, row: int = 0, on_floor: bool = true) -> void:
	_column = column
	_row = row
	_on_floor = on_floor


func _ready() -> void:
	position = Vector2(_column * TILE, _row * TILE)
	z_index = 1
	var sprite := Sprite2D.new()
	sprite.texture = SpriteLibrary.tile("spikes_up" if _on_floor else "spikes_down")
	sprite.centered = false
	add_child(sprite)
	var box := FLOOR_BOX if _on_floor else CEILING_BOX
	var area := Area2D.new()
	area.position = box.get_center()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = box.size
	shape.shape = rect
	area.add_child(shape)
	add_child(area)
	# The player counts how many spike areas it is inside and takes damage while it is in at least one.
	area.body_entered.connect(func(body: Node) -> void:
		if body is Player:
			body.hazard_count += 1)
	area.body_exited.connect(func(body: Node) -> void:
		if body is Player:
			body.hazard_count -= 1)


## The world-space rectangle that hurts (used by the level solver and tests).
func hurt_rect() -> Rect2:
	var box := FLOOR_BOX if _on_floor else CEILING_BOX
	return Rect2(position + box.position, box.size)
