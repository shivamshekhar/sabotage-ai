class_name PlayerSprite
extends Sprite2D
## Visual for the player: picks the picture of a character for the movement state (CharacterPoses says which pictures show which state).
## The hero is the "player" character (our own art, made from the Kenney hero by tools/art/generate_player.py); the AI Bro uses "zombie" (it sets `character`).

# CHARACTER: which character to use. It is the folder and file prefix of the poses:
# SpriteLibrary.character_pose(CHARACTER, pose) loads the picture (see SpriteLibrary.CHARACTER_STYLES for where).
# Available: player, zombie.
const CHARACTER := "player"

# SCALE: scale applied to the sprite: drawn size = source art size * SCALE, for art that is ART_HEIGHT pixels tall (the
# Kenney characters). Art of another height is scaled so it is drawn the same size, see
# base_scale(). The same scale sets the vertical offset that keeps the feet on the player's origin
# (position.y = -drawn height / 2). Visual only: the hitbox is Player.BODY_SIZE.
# If you change it, update BODY_SIZE, the PlayerShadow sizes and HEALTH_BAR_OFFSET too.
const SCALE := 1.2

# ART_HEIGHT: the height in pixels of the Kenney character art that SCALE is defined for.
const ART_HEIGHT := 110.0

# BLINK_TIME: seconds the eyes stay shut in a blink (the hero, while standing).
const BLINK_TIME := 0.13

# BLINK_GAP_MIN / BLINK_GAP_MAX: seconds between two idle expressions (a blink or a glance), a random time between the two. Larger: calmer.
const BLINK_GAP_MIN := 1.8
const BLINK_GAP_MAX := 4.5

# LOOK_CHANCE: the chance (0 to 1) that an idle expression is a glance up and aside instead of a blink, and LOOK_TIME: how many seconds the glance lasts.
const LOOK_CHANCE := 0.2
const LOOK_TIME := 0.9

# WALK_STRETCH: how much taller (a fraction of the figure's height) the figure grows in the middle of every step of a walk, and shrinks back as a foot lands: a bounce
# with the soles staying on the floor (it is stretched from the feet, not lifted). 0 = none. Larger: a springier, jauntier walk.
const WALK_STRETCH := 0.03

# RECOIL: how many px the whole figure is pushed back while the EMP gun fires, as it vibrates (between 0 and this), and RECOIL_RATE: how fast (radians a second;
# 2 PI = one vibration a second). 0 = none.
const RECOIL := 1.6
const RECOIL_RATE := 70.0

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

# The EMP gun is drawn into the hero's "shoot" picture (see EmpGun). GUN_FRAME: the size of that picture (px), GUN_MUZZLE: where the muzzle is in it (px from its
# top left corner; tools/art/generate_player.py prints it). The discharge leaves from there.
const GUN_FRAME := Vector2(128.0, 110.0)
const GUN_MUZZLE := Vector2(115.2, 71.7)

## Which character this sprite shows; defaults to CHARACTER. AIBro sets it to "zombie".
var character := CHARACTER

var _base_scale := SCALE   # the scale at rest for the current art (see base_scale())
var _pose_name := ""   # the pose currently shown, so an unchanged pose costs nothing
var _clock := 0.0
var _rest_y := 0.0         # the height of the sprite at rest (so the feet are on the ground), which the walk's bounce is measured from
var _gun_on := false       # the EMP gun is out (see set_gun())
var _gun_facing := 1       # the way it points (1 right, -1 left)
var _expression: StringName = &""   # the idle expression being shown now: &"blink", &"look", or &"" for none
var _expression_left := 0.0         # seconds until it ends
var _expression_gap := 0.0          # seconds until the next one starts
var _rng := RandomNumberGenerator.new()
var _flinch_tween: Tween
var _blink_tween: Tween


func _init() -> void:
	_rng.randomize()
	_expression_gap = _rng.randf_range(BLINK_GAP_MIN, BLINK_GAP_MAX)
	scale = Vector2(SCALE, SCALE)
	# Origin of the Player node is at the feet; art is 110px tall with feet on the bottom edge.
	_rest_y = -ART_HEIGHT * SCALE / 2.0
	position = Vector2(0, _rest_y)


## The scale at which art of this texture's height is drawn the same size as the 110 px Kenney art at SCALE.
static func base_scale(tex: Texture2D) -> float:
	return SCALE * ART_HEIGHT / float(tex.get_height()) if tex != null else SCALE


## state: idle | walk | jump | fall | climb | climb_idle | hurt | throw_windup | throw_release | shoot (the pictures of each: CharacterPoses). A standing hero
## breathes, blinks now and then and sometimes glances aside; a firing one vibrates a little with the recoil.
func update_pose(state: StringName, facing: int, delta: float) -> void:
	_clock += delta
	flip_h = facing < 0
	var table := CharacterPoses.table(character)
	var entry: Dictionary = table.get(state, table[&"idle"])
	var frames: Array = entry["frames"]
	var index := int(_clock / float(entry["time"])) % frames.size()
	var pose: String = frames[index]
	if state == &"idle" and table.has(&"blink"):
		pose = _idle_pose(table, index, delta)
	else:
		_expression = &""
	_set_pose(pose)
	position.x = -float(facing) * RECOIL * (0.5 + 0.5 * sin(_clock * RECOIL_RATE)) if state == &"shoot" else 0.0
	_stretch(WALK_STRETCH * absf(sin(_clock * PI / float(entry["time"]))) if state == &"walk" else 0.0)


## Stretches the figure taller by the fraction `amount` (and a little narrower), keeping its feet where they are. (Not while a flinch is playing: it moves the scale.)
func _stretch(amount: float) -> void:
	if _flinch_tween != null and _flinch_tween.is_running():
		return
	scale = Vector2(_base_scale * (1.0 - 0.5 * amount), _base_scale * (1.0 + amount))
	position.y = _rest_y - float(texture.get_height()) * _base_scale * 0.5 * amount


## The picture of a standing hero: the breathing one for the moment, or (now and then, for a short time) the same with the eyes shut, or a glance.
func _idle_pose(table: Dictionary, index: int, delta: float) -> String:
	if _expression == &"":
		_expression_gap -= delta
		if _expression_gap <= 0.0:
			_expression = &"look" if _rng.randf() < LOOK_CHANCE else &"blink"
			_expression_left = LOOK_TIME if _expression == &"look" else BLINK_TIME
	else:
		_expression_left -= delta
		if _expression_left <= 0.0:
			_expression = &""
			_expression_gap = _rng.randf_range(BLINK_GAP_MIN, BLINK_GAP_MAX)
	if _expression == &"":
		return table[&"idle"]["frames"][index]
	return table[_expression]["frames"][mini(index, table[_expression]["frames"].size() - 1)]


## Say whether the EMP gun is out (`on`) and which way it points (`facing` 1 right, -1 left). The gun is part of the "shoot" picture, which update_pose() shows.
func set_gun(on: bool, facing: int) -> void:
	_gun_on = on
	_gun_facing = facing


## True while the EMP gun is out.
func gun_shown() -> bool:
	return _gun_on


## Where the EMP gun's muzzle is in the world, as the gun points now (see set_gun()).
func gun_muzzle() -> Vector2:
	return to_global(Vector2(float(_gun_facing) * (GUN_MUZZLE.x - GUN_FRAME.x / 2.0), GUN_MUZZLE.y - GUN_FRAME.y / 2.0))


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
	scale = Vector2(_base_scale * 1.18, _base_scale * 0.82)
	self_modulate = FLINCH_TINT
	_flinch_tween = create_tween().set_parallel(true)
	_flinch_tween.tween_property(self, "rotation", 0.0, FLINCH_TIME) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_flinch_tween.tween_property(self, "scale", Vector2(_base_scale, _base_scale), FLINCH_TIME) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_flinch_tween.tween_property(self, "self_modulate", Color.WHITE, FLINCH_TIME * 0.75)


func _set_pose(pose: String) -> void:
	if pose == _pose_name:
		return
	_pose_name = pose
	texture = SpriteLibrary.character_pose(character, pose)
	var s := base_scale(texture)
	if not is_equal_approx(s, _base_scale):   # the first pose of art with another height than the Kenney art
		_base_scale = s
		scale = Vector2(s, s)

