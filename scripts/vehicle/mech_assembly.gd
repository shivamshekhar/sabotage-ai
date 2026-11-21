class_name MechAssembly
extends Node2D
## The pickup of the mech, like a vehicle power-up in Jetpack Joyride: the player stops where they are, held in the air, and the parts of the mech (the body, the cab
## glass, both turrets, four legs with their joints and claws) fly in from all round and snap together on them. As the last part begins to attach a big white glow
## (three times the size of the player) swells round them, and inside it the mech takes the place of the parts and the player is in it. The whole thing takes a good moment, which is the time to see where you are and get ready for the landing (the boxes hang over pits).
## The player cannot move, be hurt or be pushed while it lasts (Player.freeze_for_pickup()).
##
##   MechAssembly.start(player)       # the player gets into the mech when it is done

# FLY_TIME: seconds a part takes to fly in. STAGGER: the delay (seconds) between the starts of two parts, so they arrive one after another.
# THE FLASH. It starts when the last part begins to attach (FLASH_AT, a share of that part's flight): the glow swells round the mech and every part whitens (it takes
# FLASH_SWAP seconds to go white). At that peak the real mech takes the player's place under the parts, and the white parts fade away over PARTS_FADE seconds, so
# the mech melts into view instead of popping in. FLASH_HEIGHT: how high above the player's feet (px) the middle of the glow is (the middle of the mech).
const FLY_TIME := 0.7
const STAGGER := 0.05
const FLASH_AT := 0.6
const FLASH_SWAP := 0.14
const PARTS_FADE := 0.3
const FLASH_HEIGHT := 100.0

# START_DISTANCE: how far (px) from its place a part starts, from the first to the second number. START_SPIN: how far (radians) it turns on the way.
const START_DISTANCE := Vector2(260.0, 440.0)
const START_SPIN := 5.0

# KNEE_LIFT / KNEE_OUT: how a leg is shaped for the assembly: its knee is this far (px) above the middle between the hip and the foot, and this share of the
# leg's length further out. LEG_SEGMENTS: the links in a leg here (the real mech's are finer; it replaces these at the end).
const KNEE_LIFT := 34.0
const KNEE_OUT := 0.15

# Z_FAR / Z_NEAR / Z_BODY / Z_TURRET: the drawing order (the legs behind the body, the legs in front).
const Z_FAR := -3
const Z_NEAR := 3
const Z_BODY := 0
const Z_TURRET := 2

# LINK_SIZE: the size in pixels of the leg link's picture (it is stretched to the length of the segment), LINK_STRETCH: how much longer than the segment it is drawn
# (so the links overlap at the joints, as in MechVisual).
const LINK_SIZE := Vector2(52.0, 40.0)
const LINK_STRETCH := 1.14

var player: Player
var _parts: Array[Sprite2D] = []
var _whiten: ShaderMaterial        # shared by all the parts: its `flash` turns them white
var _total_time := 0.0


## Freeze `player` and build the mech round them.
static func start(for_player: Player) -> MechAssembly:
	var a := MechAssembly.new()
	a.player = for_player
	a.position = for_player.global_position
	for_player.freeze_for_pickup()
	for_player.get_parent().add_child(a)
	return a


func _ready() -> void:
	z_index = 5
	_build()
	var count := _parts.size()
	var rng := RandomNumberGenerator.new()
	rng.seed = int(position.x) * 31 + int(position.y)
	for i in count:
		var part := _parts[i]
		var final_position := part.position
		var final_rotation := part.rotation
		var final_scale := part.scale
		var angle := rng.randf() * TAU
		part.position = final_position + Vector2.from_angle(angle) * rng.randf_range(START_DISTANCE.x, START_DISTANCE.y)
		part.rotation = final_rotation + rng.randf_range(-START_SPIN, START_SPIN)
		part.scale = final_scale * 0.35
		part.modulate.a = 0.0
		var delay := float(i) * STAGGER
		var tw := part.create_tween().set_parallel(true)
		tw.tween_property(part, "position", final_position, FLY_TIME).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(part, "rotation", final_rotation, FLY_TIME).set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(part, "scale", final_scale, FLY_TIME).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(part, "modulate:a", 1.0, FLY_TIME * 0.35).set_delay(delay)
	_total_time = duration(count)
	await get_tree().create_timer(_total_time - FLASH_SWAP).timeout
	_flash()
	await get_tree().create_timer(FLASH_SWAP).timeout
	_swap()


## How long the assembly takes, in seconds, for `part_count` parts: until the last one begins to attach, then the glow and the whitening up to the moment the real mech
## is there.
static func duration(part_count: int) -> float:
	return float(part_count - 1) * STAGGER + FLY_TIME * FLASH_AT + FLASH_SWAP


## The parts, each already at its place in the finished mech (relative to the player's feet).
func _build() -> void:
	_whiten = ShaderMaterial.new()
	_whiten.shader = load(AssetPaths.PART_FLASH_SHADER)
	var facing := float(player.facing())
	var tex := MechVisual.TEX
	# the legs: a link from the hip to a knee and one from the knee to the foot, a joint between, the open claw standing on the floor
	for i in 4:
		var hip := Vector2(MechVisual.ROOTS[i] * facing, -MechVisual.BELLY - 8.0)
		var foot := Vector2(MechVisual.STANCE[i] * facing, 0.0)
		var middle := (hip + foot) / 2.0
		var knee := middle + Vector2(signf(MechVisual.ROOTS[i] * facing) * hip.distance_to(foot) * KNEE_OUT, -KNEE_LIFT)
		var z := Z_NEAR if MechVisual.NEAR[i] else Z_FAR
		var shade := 1.0 if MechVisual.NEAR[i] else MechVisual.FAR_SHADE
		_link(hip, knee, z, shade)
		_link(knee, foot - Vector2(0.0, MechVisual.CLAW_OPEN_REACH), z, shade)
		_part(AssetPaths.mech("joint"), knee, z + 1, tex * 0.9, shade)
		var claw := AssetPaths.mech("claw_open")
		var sprite := _part(claw, foot, z + 1, tex, shade)
		sprite.centered = false
		sprite.offset = Vector2(-claw.get_width() / 2.0, -claw.get_height() + MechVisual.CLAW_OPEN_PAD)
		sprite.position = foot
	# the body, the cab glass, the turrets
	var body_at := MechVisual.BODY_MIDDLE
	_part(AssetPaths.mech("body"), body_at, Z_BODY, tex).scale.x = tex * facing
	_part(AssetPaths.mech("canopy"), body_at, Z_BODY + 1, tex).scale.x = tex * facing
	_turret("missile_turret", MechVisual.MISSILE_PIVOT, MechVisual.MISSILE_MOUNT, facing)
	_turret("laser_turret", MechVisual.LASER_PIVOT, MechVisual.LASER_MOUNT, facing)


func _part(texture: Texture2D, at: Vector2, z: int, scale_value: float, shade := 1.0) -> Sprite2D:
	var s := Sprites.make(texture, scale_value, z)
	s.position = at
	s.modulate = Color(shade, shade, shade, 1.0)
	s.material = _whiten
	add_child(s)
	_parts.append(s)
	return s


## A leg link stretched from `a` to `b`.
func _link(a: Vector2, b: Vector2, z: int, shade: float) -> void:
	var seg := b - a
	var s := _part(AssetPaths.mech("link"), (a + b) / 2.0, z, 1.0, shade)
	s.rotation = seg.angle()
	s.scale = Vector2(seg.length() * LINK_STRETCH / LINK_SIZE.x, MechVisual.LINK_THICKNESS * 0.8 / LINK_SIZE.y)
	if seg.x < 0.0:
		s.scale.y = -s.scale.y


func _turret(name: String, pivot: Vector2, mount: Vector2, facing: float) -> void:
	var s := _part(AssetPaths.mech(name), MechVisual.BODY_MIDDLE + Vector2(mount.x * facing, mount.y), Z_TURRET, MechVisual.TEX)
	s.centered = false
	s.offset = -pivot
	s.scale.x = MechVisual.TEX * facing          # (flipped about its pivot when the mech faces left)


## The last part begins to attach: the glow, three times the size of the player, swells round the middle of the mech, and every part goes white.
func _flash() -> void:
	if is_instance_valid(player):
		WhiteFlash.burst(get_parent(), player.global_position + Vector2(0.0, -FLASH_HEIGHT), Player.BODY_SIZE.y * WhiteFlash.PLAYER_SIZES)
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void: _whiten.set_shader_parameter("flash", v), 0.0, 1.0, FLASH_SWAP).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## The parts are white and the glow is at its peak: the real mech takes the player's place under them, and the parts fade away over it.
func _swap() -> void:
	if is_instance_valid(player):
		player.board_mech()
		player.end_pickup_freeze()
	var tw := create_tween().set_parallel(true)
	for part in _parts:
		tw.tween_property(part, "modulate:a", 0.0, PARTS_FADE).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(queue_free)
