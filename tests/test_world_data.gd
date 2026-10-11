extends "res://tests/test_case.gd"
## Unit tests for world.json loading and integrity.

var world: WorldData


func _setup() -> void:
	if world == null:
		world = WorldData.load_default()


func test_loads_default_world() -> void:
	_setup()
	assert_ne(world, null, "WorldData.load_default() returns a world")


func test_territory_and_faction_counts() -> void:
	_setup()
	assert_eq(world.territories.size(), 15, "15 territories")
	assert_eq(world.factions.size(), 4, "4 factions")
	assert_eq(world.order.size(), 15, "order list matches territories")


func test_all_owners_are_valid_factions() -> void:
	_setup()
	for tid in world.territories:
		var t: Territory = world.territories[tid]
		assert_true(t.owner == "" or world.factions.has(t.owner), "territory %s owner '%s' valid" % [tid, t.owner])


func test_all_territories_have_polygons() -> void:
	_setup()
	for tid in world.territories:
		var t: Territory = world.territories[tid]
		assert_gte(t.polygon.size(), 3, "territory %s has polygon" % tid)
		assert_ne(t.centroid, Vector2.ZERO, "territory %s has centroid" % tid)
		assert_gt(t.neighbors.size(), 0, "territory %s has neighbors" % tid)


func test_neighbor_lists_reciprocal() -> void:
	_setup()
	for tid in world.territories:
		var t: Territory = world.territories[tid]
		for nb in t.neighbors:
			assert_true(world.territories.has(nb), "neighbor %s exists" % nb)
			var n: Territory = world.territories[nb]
			assert_true(n.neighbors.has(tid), "reciprocal: %s in %s" % [tid, nb])


func test_each_faction_owns_at_least_one_territory() -> void:
	_setup()
	for fid in world.factions:
		var count := 0
		for tid in world.territories:
			if world.territories[tid].owner == fid:
				count += 1
		assert_gt(count, 0, "faction %s owns territory" % fid)


func test_passive_flag_parsed_from_json() -> void:
	_setup()
	var independent: Faction = world.factions.get("independent")
	assert_ne(independent, null, "independent faction present")
	assert_true(independent.passive, "independent faction is passive (neutral militias)")
	for fid in world.factions:
		if fid == "independent":
			continue
		assert_false(world.factions[fid].passive, "major faction %s is not passive" % fid)


func test_territory_yields_sane() -> void:
	_setup()
	for tid in world.territories:
		var t: Territory = world.territories[tid]
		assert_gt(t.credits_yield(), 0, "territory %s yields credits" % tid)
		assert_gt(t.manpower_yield(), 0, "territory %s yields manpower" % tid)


func test_structural_validation_rejects_bad_data() -> void:
	var w := WorldData.new()
	assert_false(w.build("not a dictionary"), "string root rejected")
	assert_false(w.build({}), "empty object rejected")
	assert_false(w.build({"factions": [], "territories": []}), "empty lists rejected")
	assert_false(w.build({"factions": [{"id": "a"}], "territories": [{"id": "x"}]}), "missing site rejected")
	assert_false(w.build({"factions": [], "territories": [{"id": "x", "site": [1, 1]}]}), "no factions rejected")
	assert_true(w.build({
		"factions": [{"id": "a", "name_key": "FACTION_A", "color": "#ffffff"}],
		"territories": [{"id": "x", "name_key": "TERR_X", "site": [10, 10]}],
	}), "minimal valid world accepted")
