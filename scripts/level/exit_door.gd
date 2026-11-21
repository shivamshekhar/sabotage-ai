class_name ExitDoor
extends Node2D
## The exit door of a level: a heavy data-center sliding door (pictures in assets/levels/common/door/, made by tools/art/generate_door.py). Its origin is the middle of
## its foot, on the floor. When the player comes near, the two leaves slide apart and the lamp over the door turns from red to green; when the player reaches the doorway
## they walk in by themselves (their controls are ignored), vanish into the dark corridor, and the door closes behind them. Then `entered` is emitted: that is how a level
## is finished (Level.goal_reached). `receive()` does the vanishing for any node, so the title screen's hero uses the same door (with `watch_player` off).
##
##   var door := ExitDoor.new()
##   door.position = Vector2(x, floor_y)
##   add_child(door)
##   door.entered.connect(on_level_done)

## Emitted when somebody has walked in and the door has closed behind them.
signal entered

## Emitted when somebody has vanished into the dark, just as the door starts to close (the title screen's flash starts here).
signal swallowed

# SIZE: the door's size in pixels (its pictures'): 2 tiles wide and 3 tall.
const SIZE := Vector2(140.0, 210.0)

# APPROACH_WIDTH: how wide (px) the zone round the door's middle is where a player makes the door open. Wider: it opens sooner as they run up to it.
# ENTER_WIDTH: how wide (px) the zone at its middle is that takes the player in: when their body touches it they walk the rest of the way to the middle by themselves.
# (Their body is wider than the zone, so it happens a little before they reach the middle.)
const APPROACH_WIDTH := 300.0
const ENTER_WIDTH := 40.0

# OPEN_TIME / CLOSE_TIME: seconds the leaves take to slide apart / together. LEAF_TRAVEL: how far (px) each slides: a little more than half the opening, so it is
# clear of it. FADE_TIME: seconds the one who walks in takes to fade into the dark.
const OPEN_TIME := 0.5
const CLOSE_TIME := 0.45
const LEAF_TRAVEL := 56.0
const FADE_TIME := 0.35

# LAMP_AT: where the lamp over the door is, from the door's origin. LAMP_SIZE: its glow's diameter in px. LAMP_SHUT / LAMP_OPEN: its colours while the door is shut / open.
const LAMP_AT := Vector2(0.0, -183.0)
const LAMP_SIZE := 34.0
const LAMP_SHUT := Color(1.0, 0.18, 0.12)
const LAMP_OPEN := Color(0.3, 1.0, 0.45)

# SPILL_AT / SPILL_SIZE / SPILL_COLOR / SPILL_ALPHA: the light that spills out of the open door onto the floor: where it is (from the origin), how big (px), its colour and
# how bright (0 to 1) at most.
const SPILL_AT := Vector2(0.0, -70.0)
const SPILL_SIZE := Vector2(260.0, 190.0)
const SPILL_COLOR := Color(0.35, 0.85, 1.0)
const SPILL_ALPHA := 0.45

# Z: the door is scenery, behind the player and the tiles in front of it.
const Z := -2

## Whether the door looks after the player itself (opens as they come near, takes them in). The title screen turns it off and calls open() and receive().
var watch_player := true

var _leaf_left: Sprite2D
var _leaf_right: Sprite2D
var _lamp: GlowPulse
var _spill: Sprite2D
var _open := false
var _taken := false
var _tween: Tween


func _ready() -> void:
	z_index = Z
	var inside := Sprite2D.new()
	inside.texture = AssetPaths.door("door_inside")
	inside.centered = false
	inside.position = Vector2(-SIZE.x / 2.0, -SIZE.y)
	inside.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW      # the leaves show only inside the opening: they slide out of sight behind the pillars
	add_child(inside)
	_leaf_left = _leaf(inside, false)
	_leaf_right = _leaf(inside, true)
	var frame := Sprite2D.new()
	frame.texture = AssetPaths.door("door_frame")
	frame.centered = false
	frame.position = inside.position
	add_child(frame)
	_spill = Sprite2D.new()
	_spill.texture = PitHazard.glow_texture()
	_spill.material = Blend.additive()
	_spill.position = SPILL_AT
	_spill.scale = SPILL_SIZE / float(_spill.texture.get_width())
	_spill.self_modulate = SPILL_COLOR
	_spill.modulate.a = 0.0
	add_child(_spill)
	_lamp = GlowPulse.make(LAMP_AT, LAMP_SHUT, LAMP_SIZE, 0.0)
	add_child(_lamp)
	if watch_player:
		_watch(APPROACH_WIDTH, func(body: Node) -> void: _approach(body), func(body: Node) -> void: _leave(body))
		_watch(ENTER_WIDTH, func(body: Node) -> void: _take(body), Callable())


func is_open() -> bool:
	return _open


## Slide the leaves apart (the lamp goes green and light spills out). Returns the tween, so a caller can `await door.open().finished`.
func open() -> Tween:
	return _slide(true)


## Slide the leaves together again.
func close() -> Tween:
	return _slide(false)


## Somebody who stands at the door's middle (a Node2D: the title screen's hero, a player) fades into the dark, the door closes behind them and `entered` is emitted.
## The door opens first if it is shut.
func receive(actor: Node2D) -> void:
	await _until_done(open())
	var fade := create_tween()
	fade.tween_property(actor, "modulate:a", 0.0, FADE_TIME).set_trans(Tween.TRANS_SINE)
	await fade.finished
	swallowed.emit()
	await _until_done(close())
	entered.emit()


## Wait for a tween of the door to finish (it may have finished already).
func _until_done(tween: Tween) -> void:
	if tween.is_running():
		await tween.finished


func _leaf(parent: Sprite2D, mirrored: bool) -> Sprite2D:
	var leaf := Sprite2D.new()
	leaf.texture = AssetPaths.door("door_leaf")
	leaf.centered = false
	leaf.flip_h = mirrored
	parent.add_child(leaf)
	return leaf


func _slide(opening: bool) -> Tween:
	if opening == _open and _tween != null:
		return _tween        # (it is already there, or on its way)
	_open = opening
	Sfx.play(get_tree(), Sfx.DOOR_OPEN if opening else Sfx.DOOR_CLOSE)
	if _tween != null:
		_tween.kill()
	var time := OPEN_TIME if opening else CLOSE_TIME
	var travel := LEAF_TRAVEL if opening else 0.0
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(_leaf_left, "position:x", -travel, time)
	_tween.tween_property(_leaf_right, "position:x", travel, time)
	_tween.tween_property(_lamp, "self_modulate", LAMP_OPEN if opening else LAMP_SHUT, time)
	_tween.tween_property(_spill, "modulate:a", SPILL_ALPHA if opening else 0.0, time)
	return _tween


## A zone `width` px wide round the door's middle, as tall as the door: calls `entered_call` when a body comes into it and `left_call` (if there is one) when it leaves.
func _watch(width: float, entered_call: Callable, left_call: Callable) -> void:
	var area := Area2D.new()
	area.position = Vector2(0.0, -SIZE.y / 2.0)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(width, SIZE.y)
	shape.shape = rect
	area.add_child(shape)
	area.body_entered.connect(entered_call)
	if left_call.is_valid():
		area.body_exited.connect(left_call)
	add_child(area)


func _approach(body: Node) -> void:
	if body is Player and not _open:
		open()


func _leave(body: Node) -> void:
	if body is Player and _open and not _taken:
		close()


## The player reached the doorway: they walk to its middle by themselves, then fade into the dark (see receive()).
func _take(body: Node) -> void:
	if not body is Player or _taken:
		return
	_taken = true
	var player := body as Player
	open()
	player.walk_to(global_position.x)
	await player.walk_finished
	player.freeze_for_pickup()
	await receive(player)
