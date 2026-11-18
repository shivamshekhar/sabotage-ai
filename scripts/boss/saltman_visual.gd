class_name SaltmanVisual
extends Node2D
## What RAM Saltman looks like: the layers of assets/bosses/saltman/ stacked in the order the art was drawn (made by
## tools/art/generate_boss_shaker.py), so the parts can move on their own:
##   back      the cap, collars and the back of the glass
##   pile      the hardware inside in three depths (back, middle, front), clipped to the inside of the glass (a clip mask, so it can be
##             thrown about and never pokes out). Each depth rattles on its own, so the hardware really moves about inside him
##   face      one picture per expression (idle, charge, attack, hurt, dead), cross-faded when the expression changes
##   front     the glass reflections and the metal in front of everything
##   cap_glow  the cap holes glowing hot (added on top while he sprays)
## Everything is centred on this node. Move, turn and scale the node to move the whole boss. Call step() every physics frame.

const FOLDER := "res://assets/bosses/saltman/"

# FACE_FADE: how fast one expression fades into the next, in alpha per second (10 = a tenth of a second).
const FACE_FADE := 10.0

# HOT_FADE: how fast the cap holes warm up and cool down, in alpha per second.
const HOT_FADE := 5.0

# SHAKE_X / SHAKE_UP: the most the pile is thrown about when shaken fully, in picture pixels: sideways either way, and upwards (it
# is never pushed down through the floor of the glass). SHAKE_SPEED: how fast it rattles, in radians per second.
const SHAKE_X := 12.0
const SHAKE_UP := 62.0
const SHAKE_SPEED := 38.0

# SHAKE_TURN: how far the depths of the pile tip while rattling, in radians.
const SHAKE_TURN := 0.09

# SLUMP: how far the whole pile slides towards the cap when he is upside down (the hardware falls to the cap end), in picture pixels.
const SLUMP := 130.0

# DEPTHS: for the back, middle and front of the pile: how strongly it is thrown about (1 = the numbers above), how fast it rattles
# compared with SHAKE_SPEED, and a phase offset so the depths do not move together.
const DEPTHS := [[0.7, 0.85, 0.0], [1.0, 1.0, 1.9], [1.3, 1.2, 3.7]]

var size := Vector2.ONE                 # the picture's size in pixels
var cap_holes: Array[Vector2] = []      # where the cap holes are, relative to the middle of the picture
var expression := "idle"

var _piles: Array[Sprite2D] = []
var _slump := 0.0
var _faces := {}                        # expression name -> Sprite2D
var _glow: Sprite2D
var _hot := 0.0
var _shake := 0.0
var _clock := 0.0


func _ready() -> void:
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FOLDER + "meta.json"))
	size = Vector2(float(meta["size"][0]), float(meta["size"][1]))
	for h in meta["cap_holes"]:
		cap_holes.append(Vector2(float(h[0]), float(h[1])) - size / 2.0)
	_add("back")
	var clip := Sprite2D.new()                       # the inside of the glass: everything under it is cut to its shape and it is not drawn
	clip.texture = load(FOLDER + "inner_mask.png")
	clip.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	add_child(clip)
	for depth in ["pile_back", "pile_mid", "pile_front"]:
		var layer := Sprite2D.new()
		layer.texture = load(FOLDER + depth + ".png")
		clip.add_child(layer)
		_piles.append(layer)
	for e in meta["expressions"]:
		var face := _add("face_" + e)
		face.modulate.a = 1.0 if e == expression else 0.0
		_faces[e] = face
	_add("front")
	_glow = _add("cap_glow")
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = add
	_glow.modulate.a = 0.0


func _add(file: String) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load(FOLDER + file + ".png")
	add_child(s)
	return s


## Switch to another expression (it fades in).
func set_expression(name: String) -> void:
	if _faces.has(name):
		expression = name


## How hard the hardware inside is being shaken: 0 = lying still, 1 = thrown about.
func set_shake(amount: float) -> void:
	_shake = clampf(amount, 0.0, 1.0)


## 0 = the hardware lies on the floor of the glass, 1 = it has slid to the cap end (he is upside down).
func set_slump(amount: float) -> void:
	_slump = clampf(amount, 0.0, 1.0)


## How hot the cap holes glow, 0 to 1.
func set_hot(amount: float) -> void:
	_hot = clampf(amount, 0.0, 1.0)


## Advance the little animations (call from _physics_process).
func step(delta: float) -> void:
	_clock += delta
	for e in _faces:
		var face: Sprite2D = _faces[e]
		face.modulate.a = move_toward(face.modulate.a, 1.0 if e == expression else 0.0, FACE_FADE * delta)
	_glow.modulate.a = move_toward(_glow.modulate.a, _hot, HOT_FADE * delta)
	# the hardware: thrown up and sideways in uneven beats (two rattles at different speeds, so it never looks like a loop). Each depth
	# of the pile has its own strength, speed and phase, and tips a little as it goes, so the pieces seem to tumble about inside.
	for i in _piles.size():
		var strength: float = DEPTHS[i][0]
		var speed: float = SHAKE_SPEED * float(DEPTHS[i][1])
		var phase: float = DEPTHS[i][2]
		var x := (sin(_clock * speed + phase) * 0.6 + sin(_clock * speed * 0.61 + 1.3 + phase) * 0.4) * SHAKE_X
		var up := (absf(sin(_clock * speed * 0.5 + phase)) * 0.7 + absf(sin(_clock * speed * 0.37 + 0.7 + phase)) * 0.3) * SHAKE_UP
		_piles[i].position = Vector2(x, -up) * _shake * strength + Vector2(0.0, -SLUMP * _slump * (0.8 + 0.2 * strength))
		_piles[i].rotation = sin(_clock * speed * 0.8 + phase * 1.7) * SHAKE_TURN * _shake * strength
