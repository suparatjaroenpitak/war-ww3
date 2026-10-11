extends "res://tests/test_case.gd"
## Unit tests for the economy rules.


func _territory(base_credits: int, population: int, development: int, divisions: int) -> Territory:
	var t := Territory.new()
	t.id = "t_%d" % (randi() % 100000)
	t.base_credits = base_credits
	t.base_population = population
	t.development = development
	t.divisions = divisions
	return t


func _faction(credits: int, manpower: int) -> Faction:
	var f := Faction.new()
	f.id = "f"
	f.credits = credits
	f.manpower = manpower
	return f


func test_gross_income_sums_yields() -> void:
	var list: Array = [
		_territory(10, 2000, 1, 0),
		_territory(20, 4000, 2, 0),
	]
	var income := Economy.gross_income(list)
	# credits: (10 + 2*1) + (20 + 2*2) = 12 + 24 = 36
	assert_eq(income["credits"], 36, "credits income")
	# manpower: (2 + 1) + (4 + 2) = 3 + 6 = 9
	assert_eq(income["manpower"], 9, "manpower income")


func test_upkeep_scales_with_divisions() -> void:
	assert_eq(Economy.upkeep(0), 0, "no divisions, no upkeep")
	assert_eq(Economy.upkeep(3), 6, "3 divisions cost 6 credits")
	assert_eq(Economy.upkeep(10), 20, "10 divisions cost 20 credits")


func test_resolve_accumulates_positive_net() -> void:
	var f := _faction(50, 10)
	var list: Array = [_territory(10, 2000, 1, 2)]  # income 12, upkeep 4
	var report := Economy.resolve(f, list)
	assert_eq(f.credits, 58, "credits after resolve")
	assert_eq(f.manpower, 13, "manpower after resolve")
	assert_eq(report["net_credits"], 8, "net reported")
	assert_false(report["bankrupt"], "not bankrupt")


func test_resolve_clamps_credits_at_zero() -> void:
	var f := _faction(0, 0)
	var list: Array = [_territory(0, 0, 1, 10)]  # income 2, upkeep 20
	var report := Economy.resolve(f, list)
	assert_eq(f.credits, 0, "credits clamped at zero")
	assert_eq(report["net_credits"], -18, "negative net reported")
	assert_true(report["bankrupt"], "bankrupt flagged")


func test_can_recruit_checks_both_resources() -> void:
	var rich := _faction(100, 100)
	assert_true(Economy.can_recruit(rich), "rich faction can recruit")
	var no_credits := _faction(5, 100)
	assert_false(Economy.can_recruit(no_credits), "cannot recruit without credits")
	var no_manpower := _faction(100, 1)
	assert_false(Economy.can_recruit(no_manpower), "cannot recruit without manpower")


func test_spend_recruit_deducts_cost() -> void:
	var f := _faction(50, 50)
	Economy.spend_recruit(f)
	assert_eq(f.credits, 40, "credits deducted")
	assert_eq(f.manpower, 45, "manpower deducted")


func test_develop_cost_scales() -> void:
	assert_eq(Economy.develop_cost(1), 40, "level 1 cost")
	assert_eq(Economy.develop_cost(3), 120, "level 3 cost")
	assert_gt(Economy.develop_cost(4), Economy.develop_cost(2), "cost grows with level")
