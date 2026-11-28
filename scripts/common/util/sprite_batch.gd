class_name SpriteBatch
extends RefCounted
## Draws a lot of still pictures with a handful of nodes. A level is made of thousands of tiles; a Sprite2D for each is thousands of nodes to make, keep and walk through. Here every
## picture is only noted down (add()), and flush() makes one MultiMeshInstance2D for all the pictures that share a texture, a depth (z_index) and a tint: the result looks exactly
## the same (the same pixels), made with a few dozen nodes. Pictures that must be nodes (they move, glow, have children) are Sprite2D as before.
##
##   var batch := SpriteBatch.new()
##   batch.add(texture, Vector2(70, 140), 0, Color.WHITE)
##   batch.flush(self)        # once, after the last add(): the nodes are made under `self`

var _groups := {}       # "texture id|z|tint" -> {"texture", "z", "tint", "positions": PackedVector2Array}
var _placed := {}       # Vector3i(x, y, z) of every picture added (kept after flush(), for drawn_at() and count_at())


## Note down a picture: `texture` with its top-left corner at `position` (a Sprite2D with centered = false), drawn at depth `z`, multiplied by `tint`.
func add(texture: Texture2D, position: Vector2, z: int, tint: Color) -> void:
	var key := "%d|%d|%s" % [texture.get_instance_id(), z, tint.to_html()]
	if not _groups.has(key):
		_groups[key] = {"texture": texture, "z": z, "tint": tint, "positions": PackedVector2Array()}
	var positions: PackedVector2Array = _groups[key]["positions"]
	positions.append(position)
	_groups[key]["positions"] = positions
	var spot := Vector3i(roundi(position.x), roundi(position.y), z)
	_placed[spot] = int(_placed.get(spot, 0)) + 1


## How many pictures are noted down.
func count() -> int:
	var total := 0
	for group: Dictionary in _groups.values():
		total += (group["positions"] as PackedVector2Array).size()
	return total


## True if a picture was added with its top-left corner at `position` and depth `z` (a batched picture is not a node to look for: this is how to ask).
func drawn_at(position: Vector2, z: int) -> bool:
	return _placed.has(Vector3i(roundi(position.x), roundi(position.y), z))


## How many pictures were added with their top-left corner at `position`, at any depth.
func count_at(position: Vector2) -> int:
	var total := 0
	for spot: Vector3i in _placed:
		if spot.x == roundi(position.x) and spot.y == roundi(position.y):
			total += int(_placed[spot])
	return total


## Make the nodes (one for every texture, depth and tint) under `parent` and forget the pictures. Returns them.
func flush(parent: Node) -> Array[MultiMeshInstance2D]:
	var made: Array[MultiMeshInstance2D] = []
	for group: Dictionary in _groups.values():
		var texture: Texture2D = group["texture"]
		var positions: PackedVector2Array = group["positions"]
		var size := texture.get_size()
		var quad := QuadMesh.new()
		quad.size = size
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_2D
		multimesh.mesh = quad
		multimesh.instance_count = positions.size()
		for i in positions.size():
			# (a quad is drawn upside down in 2D: the flip turns it over, and its middle is moved to where the picture's middle is)
			multimesh.set_instance_transform_2d(i, Transform2D(Vector2(1.0, 0.0), Vector2(0.0, -1.0), positions[i] + size / 2.0))
		var node := MultiMeshInstance2D.new()
		node.multimesh = multimesh
		node.texture = texture
		node.z_index = group["z"]
		node.modulate = group["tint"]
		parent.add_child(node)
		made.append(node)
	_groups.clear()
	return made
