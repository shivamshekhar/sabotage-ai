class_name TitleBro
extends Node2D
## An AI Bro that only paces: it walks back and forth along a stretch of floor, turning at each end, as the bros of the levels do. For the title screen's backdrop (a real
## AIBro needs a floor to collide with and a player to watch). Its origin is at its feet.
##
##   var bro := TitleBro.new()
##   bro.setup(x_left, x_right, floor_y)
##   world.add_child(bro)

# SPEED: how fast it walks, in pixels per second. PAUSE: seconds it stands still at each end of its stretch before turning round.
const SPEED := 70.0
const PAUSE := 0.8

var _sprite: PlayerSprite
var _x_min := 0.0
var _x_max := 0.0
var _direction := 1
var _pause_left := 0.0
var _clock := 0.0


## Pace between the x positions `left` and `right` on the floor at `floor_y`, starting at a random spot and direction (seeded by the stretch, so a run always looks the same).
func setup(left: float, right: float, floor_y: float) -> void:
	_x_min = left
	_x_max = right
	var rng := RandomNumberGenerator.new()
	rng.seed = int(left)
	position = Vector2(rng.randf_range(left, right), floor_y)
	_direction = 1 if rng.randf() < 0.5 else -1


func _ready() -> void:
	_sprite = PlayerSprite.new()
	_sprite.character = "zombie"
	add_child(_sprite)


func _process(delta: float) -> void:
	_clock += delta
	if _pause_left > 0.0:
		_pause_left -= delta
		_sprite.update_pose(&"idle", _direction, delta)
		return
	position.x += _direction * SPEED * delta
	if position.x >= _x_max or position.x <= _x_min:
		position.x = clampf(position.x, _x_min, _x_max)
		_direction = -_direction
		_pause_left = PAUSE
	_sprite.update_pose(&"walk", _direction, delta)
