extends "res://tests/test_case.gd"
## Unit tests for the deterministic TacticalBattle simulation.


func _battle(atk: int, dfn: int, terrain: float = 1.0, seed: int = 5, units: int = 16, obj: int = 3) -> TacticalBattle:
	var b := TacticalBattle.new()
	b.setup(atk, dfn, terrain, seed, units, obj)
	b.run_to_completion()
	return b


func test_setup_spawns_configured_entity_count() -> void:
	var b := TacticalBattle.new()
	b.setup(40, 40, 1.0, 1, 8, 3)
	assert_eq(b.units.size(), 16, "8 units per side yields 16 entities")
	assert_eq(b.objectives.size(), 3, "three objectives spawned")


func test_deterministic_same_seed() -> void:
	var a := _battle(60, 50, 1.25, 99)
	var b := _battle(60, 50, 1.25, 99)
	assert_eq(a.summary(), b.summary(), "identical seed produces identical outcome")
	assert_eq(a.tick, b.tick, "identical tick count")


func test_attacker_wins_with_overwhelming_force() -> void:
	var b := _battle(240, 8, 1.0, 3)
	assert_true(b.over, "battle resolves")
	assert_eq(b.winner, TacticalBattle.SIDE_ATTACKER, "overwhelming attacker wins")


func test_defender_wins_with_overwhelming_force() -> void:
	var b := _battle(8, 320, 1.0, 3)
	assert_true(b.over, "battle resolves")
	assert_eq(b.winner, TacticalBattle.SIDE_DEFENDER, "overwhelming defender wins")


func test_terminates_within_tick_cap() -> void:
	var b := _battle(40, 40, 1.0, 21)
	assert_true(b.over, "battle terminates")
	assert_lte(b.tick, b.max_ticks, "never runs past the tick cap")


func test_survival_ratios_bounded() -> void:
	var b := _battle(80, 70, 1.0, 17)
	var s := b.summary()
	assert_gte(s["attacker_survival"], 0.0, "attacker survival >= 0")
	assert_lte(s["attacker_survival"], 1.0, "attacker survival <= 1")
	assert_gte(s["defender_survival"], 0.0, "defender survival >= 0")
	assert_lte(s["defender_survival"], 1.0, "defender survival <= 1")


func test_living_units_never_negative() -> void:
	var b := _battle(50, 50, 1.0, 4)
	assert_gte(b.living_units(TacticalBattle.SIDE_ATTACKER), 0, "attacker units >= 0")
	assert_gte(b.living_units(TacticalBattle.SIDE_DEFENDER), 0, "defender units >= 0")


func test_terrain_helps_defender() -> void:
	var plain := _battle(60, 45, 0.9, 42)
	var fortified := _battle(60, 45, 2.5, 42)
	assert_gte(
		fortified.survival_ratio(TacticalBattle.SIDE_DEFENDER),
		plain.survival_ratio(TacticalBattle.SIDE_DEFENDER),
		"higher terrain never lowers defender survival"
	)


func test_no_units_after_wipe() -> void:
	var b := _battle(300, 6, 1.0, 8)
	if b.winner == TacticalBattle.SIDE_ATTACKER:
		assert_eq(b.living_units(TacticalBattle.SIDE_DEFENDER), 0, "losing side is wiped")
