class_name LaserField
extends Node2D
## A vertical laser force field: two emitters joined by a red beam. While on it is a solid wall
## (the player cannot pass); switching it off removes the wall and fades the beam out.

# BEAM_WIDTH: width in pixels of the solid wall, centred on the field's column. It only has to be
# thick enough that the player cannot slip through at speed (one frame of movement is
# Player.SPEED / 60 pixels, so keep it above that).
# Higher: a fatter wall. Lower: the player's box can clip through it at high speed.
const BEAM_WIDTH := 24.0

# BEAM_PULSE_SPEED: radians per second of the beam's brightness shimmer.
# Higher: a jittery, nervous beam. Lower: a calm, steady one.
const BEAM_PULSE_SPEED := 9.0

# FADE_TIME: seconds the beam takes to fade out when switched off (and back in when switched on).
# Higher: a slow wind-down. Lower: it vanishes at once.
const FADE_TIME := 0.5

# EMITTER_SIZE: size in pixels of the emitter box at each end of the field.
const EMITTER_SIZE := Vector2(46, 22)

const BEAM_COLOR := Color(1.0, 0.18, 0.2)
const EMITTER_COLOR := Color(0.16, 0.18, 0.24)

var field_id := ""
var on := true

var _area := Rect2()    # the whole field in this node's coordinates: x centred, y from top to bottom
var _body: StaticBody2D
var _shape: CollisionShape2D
var _strength := 1.0     # 1 = fully on, 0 = fully off (animated)
var _clock := 0.0


## rect is the field's bounding box in world pixels (one tile wide, as tall as the field).
func setup(id: String, rect: Rect2) -> void:
	field_id = id
	position = Vector2(rect.get_center().x, rect.position.y)
	_area = Rect2(-rect.size.x / 2.0, 0.0, rect.size.x, rect.size.y)
	z_index = 1
	_body = StaticBody2D.new()
	_body.collision_layer = Player.LAYER_WORLD
	_shape = CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(BEAM_WIDTH, rect.size.y)
	_shape.shape = rs
	_shape.position = Vector2(0, rect.size.y / 2.0)
	_body.add_child(_shape)
	add_child(_body)


func set_on(value: bool) -> void:
	if value == on:
		return
	on = value
	_shape.set_deferred("disabled", not on)
	var tw := create_tween()
	tw.tween_property(self, "_strength", 1.0 if on else 0.0, FADE_TIME)


func _process(delta: float) -> void:
	_clock += delta
	queue_redraw()


func _draw() -> void:
	var h := _area.size.y
	var shimmer := 0.75 + 0.25 * sin(_clock * BEAM_PULSE_SPEED + _area.position.x)
	if _strength > 0.01:
		var core := Color(1.0, 0.85, 0.85, _strength * shimmer)
		var glow := Color(BEAM_COLOR, _strength * 0.35 * shimmer)
		draw_rect(Rect2(-BEAM_WIDTH / 2.0 - 6.0, 0.0, BEAM_WIDTH + 12.0, h), Color(glow, glow.a * 0.5))
		draw_rect(Rect2(-BEAM_WIDTH / 2.0, 0.0, BEAM_WIDTH, h), glow)
		draw_rect(Rect2(-3.0, 0.0, 6.0, h), core)
	# Emitters at both ends, with a status light: red = on, green = off.
	var status := BEAM_COLOR.lerp(Color(0.2, 1.0, 0.45), 1.0 - _strength)
	for top in [true, false]:
		var y: float = 0.0 if top else h - EMITTER_SIZE.y
		draw_rect(Rect2(-EMITTER_SIZE.x / 2.0, y, EMITTER_SIZE.x, EMITTER_SIZE.y), EMITTER_COLOR)
		draw_rect(Rect2(-6.0, y + 6.0, 12.0, EMITTER_SIZE.y - 12.0), status)
