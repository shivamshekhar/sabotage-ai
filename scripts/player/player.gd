class_name Player
extends CharacterBody2D
## Platformer controller: run, jump, climb ladders, respawn on hazards.
## Origin is at the feet. Visuals live in PlayerSprite.

const SPEED := 320.0
const ACCEL := 2600.0
const JUMP_VELOCITY := -640.0
const GRAVITY := 1600.0
const CLIMB_SPEED := 190.0
const HURT_TIME := 0.4

var spawn := Vector2.ZERO
var ladder_count := 0  # how many ladder areas currently overlap the player
var climbing := false

var _facing := 1
var _hurt_timer := 0.0
var _visuals: PlayerSprite


func _ready() -> void:
	z_index = 2
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(44, 64)
	shape.shape = rect
	shape.position = Vector2(0, -32)
	add_child(shape)

	_visuals = PlayerSprite.new()
	add_child(_visuals)


func die() -> void:
	global_position = spawn
	velocity = Vector2.ZERO
	climbing = false
	_hurt_timer = HURT_TIME


func _physics_process(delta: float) -> void:
	var dir := Input.get_axis("move_left", "move_right")
	var vdir := Input.get_axis("move_up", "move_down")  # negative = up
	_hurt_timer = maxf(0.0, _hurt_timer - delta)

	if ladder_count > 0:
		if vdir != 0.0:
			climbing = true
	else:
		climbing = false

	if climbing:
		velocity.x = dir * SPEED * 0.5
		velocity.y = vdir * CLIMB_SPEED
		if Input.is_action_just_pressed("jump"):
			climbing = false
			velocity.y = JUMP_VELOCITY
	else:
		velocity.x = move_toward(velocity.x, dir * SPEED, ACCEL * delta)
		if not is_on_floor():
			velocity.y += GRAVITY * delta
		elif Input.is_action_just_pressed("jump"):
			velocity.y = JUMP_VELOCITY

	move_and_slide()

	if dir != 0.0:
		_facing = 1 if dir > 0.0 else -1
	_visuals.update_pose(_pose_state(vdir), _facing, delta)


func _pose_state(vdir: float) -> StringName:
	if _hurt_timer > 0.0:
		return &"hurt"
	if climbing:
		return &"climb" if vdir != 0.0 else &"climb_idle"
	if not is_on_floor():
		return &"jump" if velocity.y < 0.0 else &"fall"
	if absf(velocity.x) > 20.0:
		return &"walk"
	return &"idle"
