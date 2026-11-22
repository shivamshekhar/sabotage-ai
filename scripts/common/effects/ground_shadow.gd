class_name GroundShadow
extends Node2D
## A soft shadow on the floor below its parent (the parent's origin is its feet). It stays on the floor straight under the feet when the parent jumps or is carried
## up, and gets smaller and fainter the higher the parent is; over a pit, where there is no floor, it is not shown. A ray is cast straight down every physics step.

# MAX_DROP: how far down (px) the floor is looked for. If it is further than this (a pit, a long fall) there is no shadow. Larger: a shadow far below too.
const MAX_DROP := 700.0

# FADE_HEIGHT: the height above the floor (px) at which the shadow is at its smallest and faintest; it changes smoothly from the floor up to this.
const FADE_HEIGHT := 360.0

# SMALLEST: the shadow's width and height at FADE_HEIGHT and above, as a fraction of its size on the floor (1 = it does not shrink, 0 = it vanishes).
const SMALLEST := 0.45

# FAINTEST: the shadow's opacity at FADE_HEIGHT and above, as a fraction of its opacity on the floor (1 = it does not fade, 0 = it vanishes).
const FAINTEST := 0.25

# RAY_LIFT: how many px above the feet the ray starts, so a floor the feet have sunk into a little (or are standing on exactly) is still found.
const RAY_LIFT := 6.0

# SURFACE_LIFT: how many px above the floor line the middle of the shadow is. The floor tile is drawn over the lower half, so the shadow shows as a flat patch lying
# along the floor's edge. 0: only the part above the floor line seems half as big.
const SURFACE_LIFT := 3.0

# SHADOW_Z: the draw order: behind the figure, above the level.
const SHADOW_Z := -1

static var _blob: GradientTexture2D

## The shadow's width and height on the floor (px): a wide, flat ellipse.
var size := Vector2(100.0, 18.0)
## Its opacity on the floor (0 = none).
var alpha := 0.6

var _sprite: Sprite2D          # the blob (made when the shadow enters the scene)
var _owner_body: RID          # the body the shadow belongs to (an ancestor), which the ray must not hit (empty when there is none)


func _ready() -> void:
	top_level = true            # it does not follow the parent: it stays on the floor
	z_as_relative = false
	z_index = SHADOW_Z
	_sprite = Sprite2D.new()
	_sprite.texture = blob_texture()
	_sprite.modulate = Color(0.0, 0.0, 0.0, alpha)
	add_child(_sprite)
	var ancestor := get_parent()
	while ancestor != null and not ancestor is CollisionObject2D:
		ancestor = ancestor.get_parent()
	if ancestor != null:
		_owner_body = (ancestor as CollisionObject2D).get_rid()
	_follow()


func _physics_process(_delta: float) -> void:
	_follow()


## Puts the shadow on the floor under the parent, sized for its height; hides it if there is no floor within MAX_DROP.
func _follow() -> void:
	var feet := (get_parent() as Node2D).global_position
	var from := feet - Vector2(0.0, RAY_LIFT)
	var hit := Mech.world_ray(get_world_2d(), from, from + Vector2(0.0, MAX_DROP + RAY_LIFT), _owner_body)
	visible = not hit.is_empty()
	if not visible:
		return
	var floor_point: Vector2 = hit["position"]
	global_position = floor_point - Vector2(0.0, SURFACE_LIFT)
	var height := clampf((floor_point.y - feet.y) / FADE_HEIGHT, 0.0, 1.0)
	var grown := lerpf(1.0, SMALLEST, height)
	_sprite.scale = size * grown / float(blob_texture().width)
	_sprite.modulate.a = alpha * lerpf(1.0, FAINTEST, height)


## The soft round blob every shadow is made of: opaque in the middle, fading to nothing at the edge (white: tint it with modulate).
static func blob_texture() -> GradientTexture2D:
	if _blob == null:
		var grad := Gradient.new()
		grad.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
		grad.colors = PackedColorArray([Color(1, 1, 1, 1.0), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0.0)])
		_blob = GradientTexture2D.new()
		_blob.gradient = grad
		_blob.fill = GradientTexture2D.FILL_RADIAL
		_blob.fill_from = Vector2(0.5, 0.5)
		_blob.fill_to = Vector2(1.0, 0.5)
		_blob.width = 128
		_blob.height = 128
	return _blob
