extends CharacterBody2D
## Crewmate-style player. Origin is at the feet. Art is drawn in code (placeholder).

const SPEED := 320.0
const ACCEL := 2600.0
const JUMP_VELOCITY := -640.0
const GRAVITY := 1600.0

const BODY_COLOR := Color("#c51111")
const BODY_SHADE := Color("#7a0838")
const OUTLINE := Color("#0b0d14")
const VISOR := Color("#9acad6")

var facing := 1
var walk_t := 0.0


func _ready() -> void:
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(44, 64)
	shape.shape = rect
	shape.position = Vector2(0, -32)
	add_child(shape)


func _physics_process(delta: float) -> void:
	var dir := Input.get_axis("move_left", "move_right")
	velocity.x = move_toward(velocity.x, dir * SPEED, ACCEL * delta)

	if not is_on_floor():
		velocity.y += GRAVITY * delta
	elif Input.is_action_just_pressed("jump"):
		velocity.y = JUMP_VELOCITY

	move_and_slide()

	if dir != 0.0:
		facing = 1 if dir > 0.0 else -1
		walk_t += delta * 14.0
	else:
		walk_t = 0.0
	queue_redraw()


func _draw() -> void:
	# Draw as if facing right, mirror when facing left.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(facing, 1))
	_draw_body(4.0, OUTLINE)
	_draw_body(0.0, BODY_COLOR)
	# Shading strip on the back/bottom for a bit of depth.
	draw_rect(Rect2(-22, -26, 44, 12), BODY_SHADE)
	# Visor
	draw_rect(Rect2(0, -57, 26, 16), OUTLINE)
	draw_rect(Rect2(3, -54, 20, 10), VISOR)
	draw_rect(Rect2(6, -52, 8, 3), Color.WHITE)


func _draw_body(g: float, col: Color) -> void:
	var airborne := not is_on_floor()
	var bob_a := 0.0 if airborne else maxf(0.0, sin(walk_t)) * 5.0
	var bob_b := 0.0 if airborne else maxf(0.0, -sin(walk_t)) * 5.0
	# Backpack
	draw_rect(Rect2(-31 - g, -44 - g, 11 + g, 28 + 2 * g), col)
	# Head dome + torso
	draw_circle(Vector2(0, -40), 22 + g, col)
	draw_rect(Rect2(-22 - g, -40, 44 + 2 * g, 26 + g), col)
	# Legs
	draw_rect(Rect2(-22 - g, -16 - bob_a, 19 + g, 16 + g - 0.0), col)
	draw_rect(Rect2(3, -16 - bob_b, 19 + g, 16 + g), col)
