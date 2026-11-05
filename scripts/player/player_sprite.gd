class_name PlayerSprite
extends Sprite2D
## Visual for the player: picks a Kenney character pose from the movement state.
## Swap the hero by changing CHARACTER to "adventurer", "female", "soldier" or "zombie".

const CHARACTER := "player"
const SCALE := 1.2       # 80x110 source art -> ~96x132 px, matching Player.BODY_SIZE
const WALK_FRAME_TIME := 0.12
const CLIMB_FRAME_TIME := 0.15

var _clock := 0.0


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


func _set_pose(pose: String) -> void:
	texture = SpriteLibrary.character_pose(CHARACTER, pose)
