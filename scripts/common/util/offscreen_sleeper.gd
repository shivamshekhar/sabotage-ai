class_name OffscreenSleeper
extends Node
## Puts things to sleep while they are far from the screen: a node that is asleep does not run its _process or _physics_process (a live screen, a pulsing light, a laser field that
## nobody can see need not be redrawn sixty times a second). Every CHECK_INTERVAL seconds it looks at what the camera shows, and wakes the things that are near it (with a margin, so they
## are awake before they are seen) and sends the others to sleep. Put one in a level and watch() what can sleep.
##
##   var sleeper := OffscreenSleeper.new()
##   add_child(sleeper)
##   sleeper.watch(screen, Rect2(screen.position, screen.size))      # its area in world pixels

# CHECK_INTERVAL: seconds between two looks at the screen. Larger: less work, but a thing wakes up later than it comes into view (the margin covers it). Smaller: more checks.
const CHECK_INTERVAL := 0.25

# MARGIN: how far (px) outside the screen a thing's area may be and still be awake. It must cover what the camera moves in a CHECK_INTERVAL.
const MARGIN := 320.0

var _watched: Array[Dictionary] = []     # {"node", "area", "awake"}
var _clock := 0.0


## Look after `node`: it sleeps while `area` (world pixels) is further than MARGIN from the screen. It starts awake.
func watch(node: Node, area: Rect2) -> void:
	_watched.append({"node": node, "area": area, "awake": true})


## How many of the watched things are asleep now.
func sleeping_count() -> int:
	var count := 0
	for entry in _watched:
		if not entry["awake"]:
			count += 1
	return count


## Wake everything and stop looking (for a test, or anything that needs all the watched things running whatever the camera shows).
func wake_all() -> void:
	set_process(false)
	for entry in _watched:
		entry["awake"] = true
		if is_instance_valid(entry["node"]):
			(entry["node"] as Node).process_mode = Node.PROCESS_MODE_INHERIT


## Do a look at the screen now (it is also done every CHECK_INTERVAL).
func check() -> void:
	var viewport := get_viewport()
	if viewport == null:
		return
	var screen: Rect2 = viewport.get_canvas_transform().affine_inverse() * viewport.get_visible_rect()
	screen = screen.grow(MARGIN)
	for entry in _watched:
		var node: Node = entry["node"]
		if not is_instance_valid(node):
			continue
		var awake := screen.intersects(entry["area"])
		if awake != entry["awake"]:
			entry["awake"] = awake
			node.process_mode = Node.PROCESS_MODE_INHERIT if awake else Node.PROCESS_MODE_DISABLED


func _process(delta: float) -> void:
	_clock += delta
	if _clock >= CHECK_INTERVAL:
		_clock = 0.0
		check()
