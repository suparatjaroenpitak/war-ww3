extends "res://tests/test_case.gd"
## Unit tests for the deterministic Voronoi map generator.

const BOUNDS := Rect2(0, 0, 1600, 900)


func _sites() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(200, 300), Vector2(120, 560), Vector2(330, 170), Vector2(150, 170), Vector2(330, 520),
		Vector2(700, 330), Vector2(760, 620), Vector2(560, 430), Vector2(560, 700), Vector2(900, 250), Vector2(860, 760),
		Vector2(1230, 400), Vector2(1150, 190), Vector2(1360, 620), Vector2(1250, 760),
	])


func _area(poly: PackedVector2Array) -> float:
	var a := 0.0
	for k in poly.size():
		var p := poly[k]
		var q := poly[(k + 1) % poly.size()]
		a += p.x * q.y - q.x * p.y
	return absf(a * 0.5)


func test_all_sites_get_valid_polygons() -> void:
	var polys = Voronoi.build(_sites(), BOUNDS)
	assert_eq(polys.size(), 15, "one polygon per site")
	for i in polys.size():
		var p: PackedVector2Array = polys[i]
		assert_gte(p.size(), 3, "site %d polygon has >= 3 vertices" % i)
		assert_gt(_area(p), 100.0, "site %d polygon has positive area" % i)


func test_polygons_cover_bounds_without_overlap() -> void:
	var polys = Voronoi.build(_sites(), BOUNDS)
	var total := 0.0
	for p in polys:
		total += _area(p)
	var expected := BOUNDS.size.x * BOUNDS.size.y
	assert_lte(absf(total - expected) / expected, 0.01, "total area within 1% of bounds")


func test_each_site_inside_own_polygon() -> void:
	var sites := _sites()
	var polys = Voronoi.build(sites, BOUNDS)
	for i in sites.size():
		assert_true(Geometry2D.is_point_in_polygon(sites[i], polys[i]), "site %d inside own cell" % i)


func test_adjacency_symmetric_and_undirected() -> void:
	var polys = Voronoi.build(_sites(), BOUNDS)
	var adj = Voronoi.adjacency(polys)
	for i in adj.size():
		assert_false(adj[i].has(i), "no self adjacency for %d" % i)
		for j in adj[i]:
			assert_true(adj[j].has(i), "adjacency symmetric %d<->%d" % [i, j])


func test_adjacency_connects_map() -> void:
	var polys = Voronoi.build(_sites(), BOUNDS)
	var adj = Voronoi.adjacency(polys)
	assert_gt(adj[0].size(), 0, "first cell has at least one neighbor")
	# Flood fill must reach every cell.
	var visited := {0: true}
	var stack: Array = [0]
	while not stack.is_empty():
		var cur: int = stack.pop_back()
		for nb in adj[cur]:
			if not visited.has(nb):
				visited[nb] = true
				stack.append(nb)
	assert_eq(visited.size(), polys.size(), "map is fully connected")


func test_deterministic_output() -> void:
	var a = Voronoi.build(_sites(), BOUNDS)
	var b = Voronoi.build(_sites(), BOUNDS)
	assert_eq(a.size(), b.size(), "same count")
	for i in a.size():
		var pa: PackedVector2Array = a[i]
		var pb: PackedVector2Array = b[i]
		assert_eq(pa.size(), pb.size(), "same vertex count for cell %d" % i)
		for k in pa.size():
			assert_lte(pa[k].distance_to(pb[k]), 0.001, "same vertices for cell %d" % i)


func test_centroid_inside_polygon() -> void:
	var sites := _sites()
	var polys = Voronoi.build(sites, BOUNDS)
	for i in polys.size():
		var c := Voronoi.centroid(polys[i])
		assert_true(Geometry2D.is_point_in_polygon(c, polys[i]), "centroid of cell %d inside it" % i)
