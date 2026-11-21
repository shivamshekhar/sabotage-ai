class_name ScreenFlash
extends RefCounted
## A white flash over the whole screen, and the way a flash carries from one scene into the next: the title screen covers itself in white and starts the game, and the game's
## first frame then clears away from white (see Main). Everything is on a layer above all the game's windows.
##
##   await ScreenFlash.cover(get_tree(), 0.3).finished       # the screen goes white
##   ScreenFlash.arriving = true                            # (the next scene calls reveal_if_arriving() as it starts)

# LAYER: the canvas layer of the flash: above every window and banner.
const LAYER := 100

# COLOR: the flash's colour: white.
const COLOR := Color.WHITE

## True when the scene that is starting should clear away from white (the one before it ended in a flash).
static var arriving := false

static var _layer: CanvasLayer        # the flash on screen now (it lives on the root, so it survives a change of scene)


## The screen goes from clear to white in `seconds`. Returns the tween (the white stays until the scene is changed).
static func cover(tree: SceneTree, seconds: float) -> Tween:
	var rect := _make(tree)
	rect.color.a = 0.0
	var tw := rect.create_tween()
	tw.tween_property(rect, "color:a", 1.0, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	return tw


## The screen starts white and clears over `seconds`.
static func reveal(tree: SceneTree, seconds: float) -> Tween:
	var rect := _make(tree)
	var tw := rect.create_tween()
	tw.tween_property(rect, "color:a", 0.0, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(rect.get_parent().queue_free)
	return tw


## Clear away from white if the scene before ended in a flash (cover() then `arriving = true`); otherwise nothing.
static func reveal_if_arriving(tree: SceneTree, seconds: float) -> void:
	if arriving:
		arriving = false
		reveal(tree, seconds)


static func _make(tree: SceneTree) -> ColorRect:
	if is_instance_valid(_layer):
		_layer.queue_free()          # (a new flash takes over from the old one without a flicker: both are white)
	var layer := CanvasLayer.new()
	_layer = layer
	layer.layer = LAYER
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	var rect := ColorRect.new()
	rect.color = COLOR
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(rect)
	tree.root.add_child(layer)
	return rect
