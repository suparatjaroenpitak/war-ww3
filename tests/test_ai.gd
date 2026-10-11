extends "res://tests/test_case.gd"
## Unit tests for the deterministic AI controller.

var world: WorldData
var state: GameState


func _setup(seed: int = 7) -> void:
	if world == null:
		world = WorldData.load_default()
	state = GameState.new()
	state.setup(world, "vessaria", seed, "standard")


func _snapshot() -> Dictionary:
	var owners := {}
	var divisions := {}
	for tid in state.order:
		var t: Territory = state.territories[tid]
		owners[tid] = t.owner
		divisions[tid] = t.divisions
	return {
		"owners": owners,
		"divisions": divisions,
		"credits": state.faction("kadran").credits,
		"manpower": state.faction("kadran").manpower,
	}


func test_passive_faction_does_nothing() -> void:
	_setup()
	var before := _snapshot()
	AI_Controller.take_turn(state, "independent")
	var after := _snapshot()
	assert_eq(before, after, "independent faction is passive")


func test_active_ai_acts() -> void:
	_setup()
	var before := _snapshot()
	AI_Controller.take_turn(state, "kadran")
	var after := _snapshot()
	var acted := before["credits"] != after["credits"] or before["owners"] != after["owners"] or before["divisions"] != after["divisions"]
	assert_true(acted, "AI changed something (recruit or attack)")


func test_ai_recruits_keeps_economy_valid() -> void:
	_setup()
	# Kadran starts with 100 credits / 40 manpower: it can afford recruits.
	AI_Controller.take_turn(state, "kadran")
	var f: Faction = state.faction("kadran")
	assert_gte(f.credits, 0, "credits never negative")
	assert_gte(f.manpower, 0, "manpower never negative")


func test_ai_never_owns_more_than_map() -> void:
	_setup()
	for i in 5:
		AI_Controller.take_turn(state, "kadran")
	var owned: Array = state.territories_owned_by("kadran")
	assert_lte(owned.size(), state.territories.size(), "AI cannot own more than the map")


func test_ai_deterministic() -> void:
	_setup(11)
	AI_Controller.take_turn(state, "kadran")
	var a := state.to_dict()
	_setup(11)
	AI_Controller.take_turn(state, "kadran")
	var b := state.to_dict()
	assert_eq(a, b, "same seed produces identical AI behaviour")
