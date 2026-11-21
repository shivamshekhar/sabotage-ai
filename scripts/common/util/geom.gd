class_name Geom
extends RefCounted
## Small geometry helpers shared by everything that moves along a line (thrown objects, missiles, the laser).


## Where along the segment a-b (0 at a, 1 at b) it first enters the rectangle, or -1 if it never does. A segment that starts inside gives 0.
static func segment_entry(a: Vector2, b: Vector2, r: Rect2) -> float:
	var t0 := 0.0
	var t1 := 1.0
	var d := b - a
	for axis in 2:
		if absf(d[axis]) < 0.00001:
			if a[axis] < r.position[axis] or a[axis] > r.end[axis]:
				return -1.0
		else:
			var ta: float = (r.position[axis] - a[axis]) / d[axis]
			var tb: float = (r.end[axis] - a[axis]) / d[axis]
			t0 = maxf(t0, minf(ta, tb))
			t1 = minf(t1, maxf(ta, tb))
			if t0 > t1:
				return -1.0
	return t0


## True if the segment a-b touches the rectangle.
static func segment_hits_rect(a: Vector2, b: Vector2, r: Rect2) -> bool:
	return segment_entry(a, b, r) >= 0.0
