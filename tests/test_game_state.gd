extends "res://tests/test_case.gd"
## Unit tests for GameState: setup, recruit, attack, end-turn, determinism,
## and victory/defeat detection.

var world: WorldData
var state: GameState


func _setup(seed: int = 7) -> void:
	if world == null:
		world = WorldData.load_default()
	state = GameState.new()
	state.setup(world, "vessaria", seed, "standard")


func _find_attack_pair() -> Array:
	## Returns [from_id, to_id] for a vessaria territory adjacent to a
	## non-vessaria territory, or [] if none exists.
	for tid in state.order:
		var t: Territory = state.territories[tid]
		if t.owner != "vessaria":
			continue
		for nb in t.neighbors:
			var n: Territory = state.territories[nb]
			if n.owner != "vessaria" and n.owner != "":
				return [tid, nb]
	return []


func test_setup_initializes_state() -> void:
	_setup()
	assert_eq(state.territories.size(), 15, "all territories present")
	assert_eq(state.factions.size(), 4, "all factions present")
	assert_eq(state.turn_number, 1, "starts at turn 1")
	assert_eq(state.current_faction_id, "vessaria", "human moves first")
	assert_true(state.is_human_turn(), "human turn at start")
	assert_false(state.over, "game not over")


func test_recruit_in_own_territory() -> void:
	_setup()
	var before_credits: int = state.faction("vessaria").credits
	var before_manpower: int = state.faction("vessaria").manpower
	var result: Dictionary = state.recruit("vess_capital")
	assert_true(result.get("ok", false), "recruit succeeds")
	assert_eq(state.territory("vess_capital").divisions, 4, "division added")
	assert_eq(state.faction("vessaria").credits, before_credits - 10, "credits deducted")
	assert_eq(state.faction("vessaria").manpower, before_manpower - 5, "manpower deducted")


func test_recruit_rejects_enemy_territory() -> void:
	_setup()
	var result: Dictionary = state.recruit("kad_capital")
	assert_false(result.get("ok", false), "recruit rejected")
	assert_eq(result.get("error", ""), "MSG_NOT_OWNER", "owner error")


func test_recruit_rejects_when_broke() -> void:
	_setup()
	state.faction("vessaria").credits = 0
	var result: Dictionary = state.recruit("vess_capital")
	assert_false(result.get("ok", false), "recruit rejected when broke")
	assert_eq(result.get("error", ""), "MSG_NOT_ENOUGH_CREDITS", "credits error")


func test_attack_requires_adjacency() -> void:
	_setup()
	var result: Dictionary = state.can_attack("vess_capital", "ori_capital")
	assert_false(result.get("ok", false), "distant attack rejected")
	assert_eq(result.get("error", ""), "MSG_NOT_ADJACENT", "adjacency error")


func test_attack_rejects_friendly_target() -> void:
	_setup()
	var pair := _find_attack_pair()
	assert_ne(pair.size(), 0, "an enemy adjacency exists")
	var result: Dictionary = state.can_attack(pair[0], pair[0])
	assert_false(result.get("ok", false), "attacking itself rejected")


func test_attack_captures_with_superior_force() -> void:
	_setup()
	var pair := _find_attack_pair()
	assert_ne(pair.size(), 0, "an enemy adjacency exists")
	var from: Territory = state.territory(pair[0])
	var to: Territory = state.territory(pair[1])
	# Force a guaranteed capture: overwhelming attack on flat ground.
	from.divisions = 10
	to.divisions = 1
	to.terrain = Territory.TERRAIN_PLAINS
	var result: Dictionary = state.attack(pair[0], pair[1])
	assert_true(result.get("ok", false), "attack executes")
	assert_true(result.get("captured", false), "territory captured")
	assert_eq(to.owner, "vessaria", "ownership transferred")
	assert_gte(to.divisions, 1, "survivors garrison the territory")


func test_attack_without_divisions_rejected() -> void:
	_setup()
	var pair := _find_attack_pair()
	assert_ne(pair.size(), 0, "an enemy adjacency exists")
	state.territory(pair[0]).divisions = 0
	var result: Dictionary = state.can_attack(pair[0], pair[1])
	assert_false(result.get("ok", false), "no divisions means no attack")
	assert_eq(result.get("error", ""), "MSG_NO_DIVISIONS", "divisions error")


func test_end_turn_advances_and_resolves() -> void:
	_setup()
	var credits_before: int = state.faction("vessaria").credits
	var owned: Array = state.territories_owned_by("vessaria")
	var income := Economy.gross_income(owned)
	var divisions := 0
	for t in owned:
		divisions += t.divisions
	var expected_net: int = income["credits"] - Economy.upkeep(divisions)
	state.end_turn()
	assert_eq(state.turn_number, 2, "turn advanced")
	assert_eq(state.current_faction_id, "vessaria", "back to human")
	assert_eq(state.faction("vessaria").credits, credits_before + expected_net, "economy resolved")


func test_end_turn_is_deterministic() -> void:
	_setup(7)
	var a := state
	a.recruit("vess_capital")
	a.end_turn()
	var b := GameState.new()
	b.setup(world, "vessaria", 7, "standard")
	b.recruit("vess_capital")
	b.end_turn()
	assert_eq(a.to_dict(), b.to_dict(), "same seed + actions = same state")


func test_victory_when_no_enemies_own_land() -> void:
	_setup()
	for tid in state.order:
		state.territories[tid].owner = "vessaria"
	state._check_victory()
	assert_true(state.over, "game over")
	assert_eq(state.winner_id, "vessaria", "human wins")


func test_defeat_when_human_loses_all_land() -> void:
	_setup()
	for tid in state.order:
		var t: Territory = state.territories[tid]
		if t.owner == "vessaria":
			t.owner = "kadran"
	state.check_defeat()
	assert_true(state.over, "game over on defeat")
	assert_ne(state.winner_id, "vessaria", "human did not win")


func test_commands_blocked_after_game_over() -> void:
	_setup()
	for tid in state.order:
		state.territories[tid].owner = "vessaria"
	state._check_victory()
	var result: Dictionary = state.recruit("vess_capital")
	assert_false(result.get("ok", false), "recruit blocked after victory")


func test_territories_owned_by_filters_correctly() -> void:
	_setup()
	var owned: Array = state.territories_owned_by("vessaria")
	assert_eq(owned.size(), 4, "vessaria owns 4 at start")
	for t in owned:
		assert_eq(t.owner, "vessaria", "owned territory reported")
	var none: Array = state.territories_owned_by("does_not_exist")
	assert_eq(none.size(), 0, "unknown faction owns nothing")
