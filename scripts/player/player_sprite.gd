class_name PlayerSprite
extends Sprite2D
## Visual for the player: picks a Kenney character pose from the movement state.
## Swap the hero by changing CHARACTER to "adventurer", "female", "soldier" or "zombie".

# CHARACTER: which Kenney character to use. It is the folder and file prefix of the poses:
# SpriteLibrary.character_pose(CHARACTER, pose) loads
# assets/kenney/platformer-characters/<CHARACTER>/<CHARACTER>_<pose>.png.
# Available: player, adventurer, female, soldier, zombie.
const CHARACTER := "player"

# SCALE: scale applied to the sprite: drawn size = source art size * SCALE. It also sets the
# vertical offset that keeps the feet on the player's origin
# (position.y = -art height * SCALE / 2). Visual only: the hitbox is Player.BODY_SIZE.
# If you change it, update BODY_SIZE, the PlayerShadow sizes and HEALTH_BAR_OFFSET too.
const SCALE := 1.2

# WALK_FRAME_TIME: seconds each walk frame is shown. The walk alternates between two poses:
#     frame = int(clock / WALK_FRAME_TIME) % 2
#     steps per second = 1 / WALK_FRAME_TIME
# Smaller: legs move faster. Larger: a slow shuffle. Match it to SPEED so feet don't look
# like they slide.
const WALK_FRAME_TIME := 0.12

# CLIMB_FRAME_TIME: seconds each climbing frame is shown (two alternating poses, as with
# WALK_FRAME_TIME). Match it to CLIMB_SPEED.
const CLIMB_FRAME_TIME := 0.15

# FLINCH_LEAN: how far the body tilts back when hit, in radians. At the instant of the hit:
#     rotation = -facing * FLINCH_LEAN
# and it then springs back to upright. 0 = no tilt. Higher: a more dramatic recoil.
const FLINCH_LEAN := 0.3

# FLINCH_TIME: seconds for the flinch (rotation, squash and tint) to settle, using an
# elastic ease so it wobbles slightly. Higher: a longer, bouncier recoil. Lower: sharper.
const FLINCH_TIME := 0.4

# FLINCH_TINT: the colour flashed over the sprite at the moment of a hit, fading back to
# normal over most of FLINCH_TIME. (The squash amount is fixed inside flinch().)
const FLINCH_TINT := Color(1.0, 0.3, 0.3)

# BLINK_HALF: seconds for the sprite to fade down, and again to fade back up. One blink is
# twice this, and the number of blinks is the requested duration / (2 * BLINK_HALF), where
# the duration comes from the caller (for example Player.INVULN_TIME).
# Smaller: a faster flicker. Larger: slower pulses.
const BLINK_HALF := 0.06

# BLINK_LOW: opacity at the dimmest point of each blink. 0 = fully invisible, 1 = no
# visible blink.
const BLINK_LOW := 0.2

## Which Kenney character this sprite shows; defaults to CHARACTER. AIBro sets it to "zombie".
var character := CHARACTER

var _pose_name := ""   # the pose currently shown, so an unchanged pose costs nothing
var _clock := 0.0
var _flinch_tween: Tween
var _blink_tween: Tween


func _init() -> void:
	scale = Vector2(SCALE, SCALE)
	# Origin of the Player node is at the feet; art is 110px tall with feet on the bottom edge.
	position = Vector2(0, -110.0 * SCALE / 2.0)


## state: idle | walk | jump | fall | climb | climb_idle | hurt | throw_windup | throw_release
func update_pose(state: StringName, facing: int, delta: float) -> void:
	_clock += delta
	flip_h = facing < 0
	match state:
		&"walk":
			_set_pose("walk%d" % (int(_clock / WALK_FRAME_TIME) % 2 + 1))
		&"climb":
			_set_pose("climb%d" % (int(_clock / CLIMB_FRAME_TIME) % 2 + 1))
		&"climb_idle":
			_set_pose("climb1")
		&"throw_windup":
			_set_pose("action1")   # arm raised behind the head
		&"throw_release":
			_set_pose("action2")   # arm snapped forward
		_:
			_set_pose(String(state))


## Blink animation: pulse the sprite's alpha for `duration` seconds, then restore it.
func blink(duration: float) -> void:
	if _blink_tween:
		_blink_tween.kill()
	modulate.a = 1.0
	var cycles := maxi(1, int(duration / (BLINK_HALF * 2.0)))
	_blink_tween = create_tween().set_loops(cycles)
	_blink_tween.tween_property(self, "modulate:a", BLINK_LOW, BLINK_HALF)
	_blink_tween.tween_property(self, "modulate:a", 1.0, BLINK_HALF)


## Recoil on a hit: snap back (lean away from facing, squash) with a red flash,
## then spring back to normal. Pair with the "hurt" pose.
func flinch(facing: int) -> void:
	if _flinch_tween:
		_flinch_tween.kill()
	rotation = -facing * FLINCH_LEAN
	scale = Vector2(SCALE * 1.18, SCALE * 0.82)
	self_modulate = FLINCH_TINT
	_flinch_tween = create_tween().set_parallel(true)
	_flinch_tween.tween_property(self, "rotation", 0.0, FLINCH_TIME) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_flinch_tween.tween_property(self, "scale", Vector2(SCALE, SCALE), FLINCH_TIME) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_flinch_tween.tween_property(self, "self_modulate", Color.WHITE, FLINCH_TIME * 0.75)


func _set_pose(pose: String) -> void:
	if pose == _pose_name:
		return
	_pose_name = pose
	texture = SpriteLibrary.character_pose(character, pose)
