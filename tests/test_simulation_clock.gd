extends "res://tests/test_case.gd"
## Unit tests for the simulation clock (serialization and clamping; the
# _process() advance itself is exercised in the benchmark scene).


func test_speed_clamped() -> void:
	var clock := SimulationClock.new()
	clock.set_speed(99.0)
	assert_lte(clock.speed, 4.0, "speed clamped high")
	clock.set_speed(-5.0)
	assert_gte(clock.speed, 0.0, "speed clamped low")
	clock.free()


func test_pause_toggle() -> void:
	var clock := SimulationClock.new()
	assert_false(clock.paused, "starts unpaused")
	clock.toggle_pause()
	assert_true(clock.paused, "paused after toggle")
	clock.toggle_pause()
	assert_false(clock.paused, "unpaused after second toggle")
	clock.free()


func test_dict_roundtrip() -> void:
	var clock := SimulationClock.new()
	clock.day = 42
	clock.set_speed(2.0)
	clock.set_paused(true)
	var d := clock.to_dict()
	var other := SimulationClock.new()
	other.from_dict(d)
	assert_eq(other.day, 42, "day preserved")
	assert_eq(other.speed, 2.0, "speed preserved")
	assert_eq(other.paused, true, "paused preserved")
	clock.free()
	other.free()
