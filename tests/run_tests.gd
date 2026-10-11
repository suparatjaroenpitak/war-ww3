extends SceneTree
## Headless test runner entry point.
## Usage: godot --headless --path <project> --script res://tests/run_tests.gd

func _initialize() -> void:
	var info: Dictionary = Engine.get_version_info()
	print("WAR WW3 test suite")
	print("Godot %s (%s)" % [info.get("string", "?"), info.get("build", "?")])
	print("")
	var fw := preload("res://tests/framework.gd").new()
	var suites := [
		"res://tests/test_voronoi.gd",
		"res://tests/test_world_data.gd",
		"res://tests/test_economy.gd",
		"res://tests/test_combat.gd",
		"res://tests/test_tactical.gd",
		"res://tests/test_game_state.gd",
		"res://tests/test_ai.gd",
		"res://tests/test_save_game.gd",
		"res://tests/test_event_log.gd",
		"res://tests/test_simulation_clock.gd",
		"res://tests/test_localization.gd",
		"res://tests/test_net_protocol.gd",
		"res://tests/test_game_server.gd",
	]
	for path in suites:
		var script := load(path)
		if script == null:
			print("  ERROR  cannot load suite: " + path)
			fw.failed += 1
			fw.failures.append("missing suite " + path)
			continue
		fw.run_suite(script.new())
	fw.summary()
	quit(fw.exit_code())
