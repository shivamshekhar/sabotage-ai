class_name PowerUpBox
extends Node2D
## A floating power-up box (the "powerup_box" tile): a flat slate cube with a "?" because what is inside is random. It hovers and
## bobs. Jump on it (come down on its top) and the player bounces off it, it breaks apart in a few frames (assets/powerups/box_break_*.png,
## made by tools/art/generate_powerup.py) and the power-up inside, picked at random (see PowerUps), is given to the player. Walking
## into it from the side or from below does nothing. A player who already has that vehicle gets it mended and refuelled, and 500 points.

signal opened(kind: String)

# SPRITE_SCALE: the pictures (a 560 px canvas around a 256 px box) are drawn at this scale: 0.25 makes the box about one tile (64 px) wide.
const SPRITE_SCALE := 0.25

# The "?" is a white picture of its own, tinted every frame so it glows in changing colours: its hue drifts slowly round the colour
# wheel (HUE_PERIOD seconds for a full turn), its brightness
# breathes (PULSE_PERIOD seconds) and now and then it blinks off for a moment (every BLINK_EVERY seconds, for BLINK_TIME).
const HUE_PERIOD := 7.0
const PULSE_PERIOD := 2.2
const PULSE_LOW := 0.55
const BLINK_EVERY := 3.4
const BLINK_TIME := 0.16
const QUESTION_SATURATION := 0.62

# HALF: half the box's side in pixels, as far as touching it is concerned.
const HALF := 32.0

# BOB_HEIGHT / BOB_SPEED: how far (px) and how fast (radians per second) the box floats up and down.
const BOB_HEIGHT := 4.0
const BOB_SPEED := 2.4

# STOMP_REACH: how far below the box's top edge (and how far above it) the player's feet may be and still count as landing on it.
const STOMP_REACH := 30.0

# BOUNCE_SPEED: the upward speed the player is given when they land on the box (a little hop, like a stomp).
const BOUNCE_SPEED := -460.0

# FRAME_TIME: seconds each break-apart frame is shown. GRANT_FRAME: the frame (0-based, of the break frames) at which the power-up
# is given, the moment of the flash.
const FRAME_TIME := 0.07
const GRANT_FRAME := 2

var kind := ""        # what is inside (picked when the box is created)
var _sprite: Sprite2D
var _question: Sprite2D
var _t := 0.0
var _breaking := false
var _home := Vector2.ZERO


func _ready() -> void:
	z_index = 1
	kind = PowerUps.random_kind()
	_home = position
	_t = _home.x * 0.013       # each box bobs at its own phase
	_sprite = Sprites.make(AssetPaths.powerup("box_base"), SPRITE_SCALE)
	add_child(_sprite)
	_question = Sprites.make(AssetPaths.powerup("box_question"), SPRITE_SCALE)
	add_child(_question)
	_glow_question()
	add_to_group(Groups.POWERUP_BOXES)


## The area that counts as the box (its collision rectangle in the world).
func rect() -> Rect2:
	return Rect2(_home - Vector2(HALF, HALF), Vector2(HALF, HALF) * 2.0)


## The colour and brightness of the "?" at the box's own time `t`: slowly changing colour, a breathing glow, and a blink now and then.
static func question_color(t: float) -> Color:
	var hue := fposmod(0.1 + t / HUE_PERIOD, 1.0)
	var pulse := PULSE_LOW + (1.0 - PULSE_LOW) * (0.5 + 0.5 * sin(t * TAU / PULSE_PERIOD))
	var blink := 0.12 if fposmod(t, BLINK_EVERY) < BLINK_TIME else 1.0
	var c := Color.from_hsv(hue, QUESTION_SATURATION, 1.0)
	c.a = pulse * blink
	return c


func _glow_question() -> void:
	_question.modulate = question_color(_t)


func _physics_process(delta: float) -> void:
	_t += delta
	if _breaking:
		return
	_glow_question()
	position = _home + Vector2(0.0, sin(_t * BOB_SPEED) * BOB_HEIGHT)
	for p in get_tree().get_nodes_in_group(Groups.PLAYER):
		var player := p as Player
		if player != null and _stomped_by(player):
			_open(player)
			return


func _stomped_by(player: Player) -> bool:
	if player.velocity.y < 0.0:
		return false
	var feet := player.global_position
	var top := position.y - HALF
	return absf(feet.x - position.x) < HALF + Player.BODY_SIZE.x * 0.5 - 8.0 and feet.y > top - STOMP_REACH and feet.y < top + STOMP_REACH


func _open(player: Player) -> void:
	_breaking = true
	player.velocity.y = BOUNCE_SPEED
	opened.emit(kind)
	_question.visible = false          # the break frames carry the (amber) "?" themselves
	for i in 6:
		_sprite.texture = AssetPaths.powerup("box_break_%d" % (i + 1))
		if i == GRANT_FRAME and is_instance_valid(player):
			PowerUps.grant(player, kind, position + Vector2(0.0, -50.0))
		await get_tree().create_timer(FRAME_TIME).timeout
	queue_free()
