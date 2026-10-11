class_name Voronoi
extends RefCounted
## Deterministic Voronoi tessellation of a rectangle from seed sites.
## Used to generate fictional territory polygons from data-driven seed points.

const EPS := 0.5


## Build one convex polygon per site, clipped to the rectangle.
## sites: PackedVector2Array of seed positions (world units).
## bounds: Rect2 in world units.
## Returns Array[PackedVector2Array] in the same order as sites.
static func build(sites: PackedVector2Array, bounds: Rect2) -> Array:
	var rect := PackedVector2Array([
		bounds.position,
		bounds.position + Vector2(bounds.size.x, 0),
		bounds.position + bounds.size,
		bounds.position + Vector2(0, bounds.size.y),
	])
	var result: Array = []
	for i in sites.size():
		var poly := rect
		for j in sites.size():
			if i == j:
				continue
			poly = _clip_half_plane(poly, sites[i], sites[j])
			if poly.size() < 3:
				break
		result.append(poly)
	return result


## Adjacency lists (Array of Array[int]) where two cells are adjacent if they
## share at least two distinct vertices (i.e. an edge, not just a corner).
static func adjacency(polygons: Array) -> Array:
	var n := polygons.size()
	var adj: Array = []
	for i in n:
		adj.append([])
	for i in n:
		for j in range(i + 1, n):
			if _share_edge(polygons[i], polygons[j]):
				adj[i].append(j)
				adj[j].append(i)
	return adj


static func _share_edge(a: PackedVector2Array, b: PackedVector2Array) -> bool:
	var shared: Array[Vector2] = []
	for pa in a:
		for pb in b:
			if pa.distance_to(pb) <= EPS:
				if shared.is_empty() or shared[shared.size() - 1].distance_to(pa) > 1.0:
					shared.append(pa)
				break
	return shared.size() >= 2


static func _clip_half_plane(poly: PackedVector2Array, a: Vector2, b: Vector2) -> PackedVector2Array:
	# Keep the half-plane closer to 'a'. The plane boundary is the
	# perpendicular bisector of the segment a..b.
	var mid := (a + b) * 0.5
	var n := b - a
	var out := PackedVector2Array()
	var count := poly.size()
	for k in count:
		var cur := poly[k]
		var nxt := poly[(k + 1) % count]
		var d_cur := (cur - mid).dot(n)
		var d_nxt := (nxt - mid).dot(n)
		if d_cur <= 0.0:
			out.append(cur)
			if d_nxt > 0.0:
				out.append(_intersect(cur, nxt, mid, n))
		elif d_nxt <= 0.0:
			out.append(_intersect(cur, nxt, mid, n))
	return out


static func _intersect(p1: Vector2, p2: Vector2, mid: Vector2, n: Vector2) -> Vector2:
	var d1 := (p1 - mid).dot(n)
	var d2 := (p2 - mid).dot(n)
	if is_equal_approx(d1, d2):
		return p1
	var t := d1 / (d1 - d2)
	return p1.lerp(p2, t)


## Centroid of a polygon (area centroid), used for label placement.
static func centroid(poly: PackedVector2Array) -> Vector2:
	if poly.is_empty():
		return Vector2.ZERO
	var a := 0.0
	var cx := 0.0
	var cy := 0.0
	var count := poly.size()
	for k in count:
		var p := poly[k]
		var q := poly[(k + 1) % count]
		var cross := p.x * q.y - q.x * p.y
		a += cross
		cx += (p.x + q.x) * cross
		cy += (p.y + q.y) * cross
	if is_zero_approx(a):
		var sum := Vector2.ZERO
		for p in poly:
			sum += p
		return sum / float(count)
	a *= 0.5
	return Vector2(cx / (6.0 * a), cy / (6.0 * a))
