class_name LevelSolver
extends RefCounted
## Kinematic reachability solver for a level map. It simulates the player's movement (same
## constants and per-frame order as Player) from every standable spot, using a set of
## representative inputs, and builds a graph of where the player can get to.
## Used by tools/tests/level1_test.gd to prove a level can be finished, cannot trap the player,
## and that its big gaps cannot simply be jumped. It is a model, not the engine: it is
## deliberately a little pessimistic (hazards are full-size, takeoff speed is limited to
## what a run-up gives), and tools/tests/level1_test.gd also plays the route in the real engine.

# T: tile size in pixels; must match Level.T.
const T := 70

# NODE_STEP: horizontal resolution of the graph in pixels. Smaller is more precise but slower.
const NODE_STEP := 14

# MAX_FRAMES: a simulated jump or fall is abandoned after this many frames.
const MAX_FRAMES := 150

# HOLD_FRAMES: how long a direction is held before being released, in the input patterns tried.
const HOLD_FRAMES := [6, 16, 30]

const DT := 1.0 / 60.0

var rows: Array[String] = []
var cols := 0
var spawn := Vector2i(-1, -1)      # standing position (x px, feet y px)
var exit_rect := Rect2()
var ladders: Array[Rect2] = []
var nodes := {}                    # key -> Vector2 (x, feet y)
var edges := {}                    # key -> Array of keys
var start_key := -1
var sim_count := 0

var _hazards: Array[Rect2] = []


func _init(map: Array[String]) -> void:
	rows = map
	cols = rows[0].length()
	for r in rows.size():
		for c in cols:
			var ch := rows[r][c]
			match ch:
				"P":
					spawn = Vector2i(int((c + 0.5) * T), (r + 1) * T)
				"E":
					exit_rect = Rect2(c * T, (r - 1) * T, T, 2 * T)
				"^":
					_hazards.append(Rect2(c * T + 10, r * T + 30, 50, 40))
				"v":
					_hazards.append(Rect2(c * T + 10, r * T, 50, 40))
	# Ladders: contiguous H runs in a column.
	for c in cols:
		var r := 0
		while r < rows.size():
			if rows[r][c] == "H":
				var top := r
				while r < rows.size() and rows[r][c] == "H":
					r += 1
				ladders.append(Rect2(c * T, top * T, T, (r - top) * T))
			else:
				r += 1


# ---------- map queries ----------

func cell(c: int, r: int) -> String:
	if c < 0 or c >= cols or r < 0 or r >= rows.size():
		return "#"
	return rows[r][c]


func is_solid(ch: String) -> bool:
	return ch == "#" or ch == "X" or ch == "O"


## A one-way platform whose top is at the top of the cell: ledges, and the top tile of a ladder.
func is_oneway(c: int, r: int) -> bool:
	var ch := cell(c, r)
	if ch == "=":
		return true
	return ch == "H" and cell(c, r - 1) != "H"


func hits_solid(x: float, y: float) -> bool:
	# AABB of the player with feet at (x, y).
	var c0 := int(floorf((x - 29.99) / T))
	var c1 := int(floorf((x + 29.99) / T))
	var r0 := int(floorf((y - 127.99) / T))
	var r1 := int(floorf((y - 0.01) / T))
	for r in range(r0, r1 + 1):
		for c in range(c0, c1 + 1):
			if is_solid(cell(c, r)):
				return true
	return false


func in_hazard(x: float, y: float) -> bool:
	var box := Rect2(x - 30, y - 128, 60, 128)
	for h in _hazards:
		if box.intersects(h):
			return true
	return false


## Cell of a one-way platform top that the feet cross when moving from y0 down to y1, or -1.
func oneway_top_between(x: float, y0: float, y1: float) -> float:
	var c0 := int(floorf((x - 29.99) / T))
	var c1 := int(floorf((x + 29.99) / T))
	var r0 := int(ceilf(y0 / T - 0.0001))
	var r1 := int(floorf(y1 / T + 0.0001))
	for r in range(r0, r1 + 1):
		var top := float(r * T)
		if top < y0 - 0.01 or top > y1 + 0.01:
			continue
		for c in range(c0, c1 + 1):
			if is_oneway(c, r):
				return top
	return -1.0


func supported(x: float, y: float) -> bool:
	# Standing at feet y: is there floor right under the feet?
	if hits_solid(x, y + 1.0):
		return true
	return oneway_top_between(x, y, y + 1.0) >= 0.0 and absf(fmod(y, T)) < 0.5


func ladder_at(x: float, y_feet: float) -> int:
	for i in ladders.size():
		var l := ladders[i]
		var overlap := minf(x + 30.0, l.end.x) - maxf(x - 30.0, l.position.x)
		if overlap / 60.0 >= Player.LADDER_OVERLAP and y_feet >= l.position.y - 2.0 and y_feet <= l.end.y + 2.0:
			return i
	return -1


# ---------- graph ----------

func key_for(x: float, y: float) -> int:
	return int(roundf(x / NODE_STEP)) * 100000 + int(roundf(y))


func add_node(x: float, y: float) -> int:
	var qx := roundf(x / NODE_STEP) * NODE_STEP
	var k := key_for(qx, y)
	if not nodes.has(k):
		nodes[k] = Vector2(qx, y)
		edges[k] = []
	return k


func add_edge(a: int, b: int) -> void:
	if a != b and not edges[a].has(b):
		edges[a].append(b)


func solve() -> void:
	var start := Vector2(spawn.x, spawn.y)
	start_key = add_node(start.x, start.y)
	var queue: Array[int] = [start_key]
	var seen := {start_key: true}
	while not queue.is_empty():
		var k: int = queue.pop_front()
		for target in _expand(nodes[k]):
			var kt := add_node(target.x, target.y)
			add_edge(k, kt)
			if not seen.has(kt):
				seen[kt] = true
				queue.append(kt)


func _expand(p: Vector2) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var x := p.x
	var y := p.y
	# Step along the surface.
	for d in [-1, 1]:
		var nx: float = x + d * NODE_STEP
		if not hits_solid(nx, y) and supported(nx, y) and not in_hazard(nx, y):
			out.append(Vector2(nx, y))
	# Ladders.
	var li := ladder_at(x, y)
	if li >= 0:
		var l := ladders[li]
		var cx := l.get_center().x
		if absf(x - cx) <= 30.0 * (1.0 - Player.LADDER_OVERLAP) * 2.0 + 1.0:
			out.append(Vector2(cx, l.position.y))
			out.append(Vector2(cx, l.end.y))
	# Jumps and walk-offs.
	for d in [-1, 0, 1]:
		var v0s: Array = [0.0] if d == 0 else [0.0, d * Player.SPEED]
		for v0 in v0s:
			for jump in [true, false]:
				if not jump and d == 0:
					continue
				var patterns: Array = [[d, 9999, d]]
				if d != 0:
					for k in HOLD_FRAMES:
						patterns.append([d, k, 0])
				for pat in patterns:
					if not jump and v0 == 0.0 and pat[1] == 9999 and false:
						continue
					var res := _simulate(x, y, v0, jump, pat)
					out.append_array(res)
	return out


## Simulate one jump (or walk-off) and return where it can end: landing spots and any ladder caught.
func _simulate(x0: float, y0: float, vx0: float, jump: bool, pat: Array) -> Array[Vector2]:
	sim_count += 1
	var out: Array[Vector2] = []
	var x := x0
	var y := y0
	var vx := vx0
	var vy := 0.0
	var peak := y0
	var airborne := false
	var first := true
	for f in MAX_FRAMES:
		var dir: float = pat[0] if f < pat[1] else pat[2]
		vx = move_toward(vx, dir * Player.SPEED, Player.ACCEL * DT)
		if first and jump:
			vy = Player.JUMP_VELOCITY
		elif airborne or not supported(x, y):
			vy += Player.GRAVITY * DT
		first = false
		# Horizontal move.
		var nx := x + vx * DT
		if hits_solid(nx, y):
			vx = 0.0
			nx = x
		x = nx
		# Vertical move.
		var ny := y + vy * DT
		if vy < 0.0:
			if hits_solid(x, ny):
				vy = 0.0
				ny = y
			y = ny
			airborne = true
		else:
			if vy > 0.0 or not supported(x, y):
				var top := oneway_top_between(x, y, ny)
				var landed := false
				if top >= 0.0 and not hits_solid(x, top):
					ny = top
					landed = true
				if hits_solid(x, ny):
					ny = floorf(ny / T) * T  # rest on the top of the solid row we entered
					landed = true
				y = ny
				airborne = true
				if landed:
					if in_hazard(x, y) or y - peak > Player.FALL_DEATH_HEIGHT:
						return out
					out.append(Vector2(x, y))
					return out
			else:
				y = ny
		peak = minf(peak, y)
		if in_hazard(x, y):
			return out
		if y > rows.size() * T + 200:
			return out
		# Catching a ladder mid-air.
		var li := ladder_at(x, y)
		if li >= 0 and f > 2:
			var l := ladders[li]
			out.append(Vector2(l.get_center().x, l.position.y))
			out.append(Vector2(l.get_center().x, l.end.y))
		if x < 0 or x > cols * T:
			return out
	return out


# ---------- queries ----------

func reachable_keys() -> Array:
	return nodes.keys()


func near_exit(p: Vector2) -> bool:
	return Rect2(p.x - 30, p.y - 128, 60, 128).intersects(exit_rect)


func exit_keys() -> Array[int]:
	var out: Array[int] = []
	for k in nodes:
		if near_exit(nodes[k]):
			out.append(k)
	return out


## Nodes that can still reach the exit (walking the graph backwards from the exit nodes).
func coreachable() -> Dictionary:
	var rev := {}
	for k in edges:
		for t in edges[k]:
			if not rev.has(t):
				rev[t] = []
			rev[t].append(k)
	var seen := {}
	var queue: Array[int] = exit_keys()
	for k in queue:
		seen[k] = true
	while not queue.is_empty():
		var k: int = queue.pop_front()
		for p in rev.get(k, []):
			if not seen.has(p):
				seen[p] = true
				queue.append(p)
	return seen


## Nodes reachable from the start that can no longer get to the exit.
func stuck_nodes() -> Array[Vector2]:
	var ok := coreachable()
	var out: Array[Vector2] = []
	for k in nodes:
		if not ok.has(k):
			out.append(nodes[k])
	return out


## The list of node positions on a shortest route from start to the exit (empty if none).
func route() -> Array[Vector2]:
	var prev := {start_key: -1}
	var queue: Array[int] = [start_key]
	var goal := -1
	while not queue.is_empty():
		var k: int = queue.pop_front()
		if near_exit(nodes[k]):
			goal = k
			break
		for t in edges[k]:
			if not prev.has(t):
				prev[t] = k
				queue.append(t)
	var out: Array[Vector2] = []
	var k := goal
	while k != -1 and goal != -1:
		out.push_front(nodes[k])
		k = prev[k]
	return out
