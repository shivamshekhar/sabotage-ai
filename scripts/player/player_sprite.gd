class_name PlayerSprite
extends Sprite2D
## Visual for the player: picks a Kenney character pose from the movement state.
## Swap the hero by changing CHARACTER to "adventurer", "female", "soldier" or "zombie".

const CHARACTER := "player"
const SCALE := 1.2       # 80x110 source art -> ~96x132 px, matching Player.BODY_SIZE
const WALK_FRAME_TIME := 0.12
const CLIMB_FRAME_TIME := 0.15

const FLINCH_LEAN := 0.3        # radians the body tilts back on a hit
const FLINCH_TIME := 0.4
const FLINCH_TINT := Color(1.0, 0.3, 0.3)

const BLINK_HALF := 0.06        # seconds to fade out (and again to fade in)
const BLINK_LOW := 0.2          # alpha at the dim point of each blink

var _clock := 0.0
var _flinch_tween: Tween
var _blink_tween: Tween


func _init() -> void:
	scale = Vector2(SCALE, SCALE)
	# Origin of the Player node is at the feet; art is 110px tall with feet on the bottom edge.
	position = Vector2(0, -110.0 * SCALE / 2.0)


## state: idle | walk | jump | fall | climb | climb_idle | hurt
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
	texture = SpriteLibrary.character_pose(CHARACTER, pose)
