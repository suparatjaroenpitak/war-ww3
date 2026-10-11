extends "res://tests/test_case.gd"
## Unit tests for abstract combat resolution.


func test_overwhelming_attack_captures() -> void:
	var r := Combat.resolve(10, 1, 1.0, 1.0, 1.0)
	assert_true(r["captured"], "captured")
	assert_eq(r["defender_losses"], 1, "defender wiped")
	assert_lte(r["attacker_losses"], 1, "minimal attacker losses")
	assert_eq(r["survivors"], 9, "nearly all attackers survive")


func test_defended_attack_fails() -> void:
	var r := Combat.resolve(1, 3, 1.5, 1.0, 1.0)
	assert_false(r["captured"], "not captured")
	assert_eq(r["defender_losses"], 1, "defender loses a portion")
	assert_gte(r["attacker_losses"], 1, "attacker loses units")
	assert_lte(r["survivors"], 0, "no survivors move in")


func test_no_attackers_no_battle() -> void:
	var r := Combat.resolve(0, 5, 1.0, 1.0, 1.0)
	assert_false(r["captured"], "cannot capture with zero attackers")
	assert_eq(r["attacker_losses"], 0, "no losses")
	assert_eq(r["defender_losses"], 0, "no defender losses")


func test_terrain_helps_defender() -> void:
	# 6 divisions attacking 4 defenders: enough on open ground (6 > 4),
	# not enough in mountains (4 * 1.5 = 6 defense power).
	var plains := Combat.resolve(6, 4, 1.0, 1.0, 1.0)
	var mountains := Combat.resolve(6, 4, 1.5, 1.0, 1.0)
	assert_true(plains["captured"], "stronger force captures on plains")
	assert_false(mountains["captured"], "same force fails in mountains")


func test_attacker_losses_bounded_when_capturing() -> void:
	for i in 20:
		var roll_a := 0.85 + 0.3 * (i / 20.0)
		var roll_d := 1.15 - 0.3 * (i / 20.0)
		var r := Combat.resolve(8, 2, 1.25, roll_a, roll_d)
		if r["captured"]:
			assert_lt(r["attacker_losses"], 8, "attacker keeps at least one division")
			assert_gte(r["survivors"], 1, "survivors positive")
		else:
			assert_gte(r["defender_losses"], 0, "defender losses non-negative")


func test_deterministic_for_same_inputs() -> void:
	var a := Combat.resolve(5, 2, 1.25, 1.0, 1.1)
	var b := Combat.resolve(5, 2, 1.25, 1.0, 1.1)
	assert_eq(a, b, "same inputs give identical results")
