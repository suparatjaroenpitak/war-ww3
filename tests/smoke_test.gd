extends Node
## End-to-end smoke test. Run with a real (non-headless) or headless game:
##   godot --headless --path . --scene res://tests/smoke_test.tscn
##   godot --path . --scene res://tests/smoke_test.tscn
##
## Drives the real UI through: main menu -> new game -> strategic screen ->
## select -> recruit -> attack -> end turn -> save -> load -> verify.
## Prints SMOKE PASS/FAIL and exits with a matching code.

const STEP_INTERVAL := 5  # frames between actions

var step := 0
var frames := 0
var failures: Array[String] = []
var saved_turn := -1
var saved_credits := -1
var tactical_target := ""


func _ready() -> void:
	print("SMOKE: WAR WW3 end-to-end smoke test")
	print("SMOKE: locale=" + Settings.get_locale())
	# This node is launched as the current scene. Detach it from that role so
	# later change_scene_to_file() calls do not free the test driver, then boot
	# the real main menu as the actual start screen.
	get_tree().current_scene = null
	App.goto_main_menu()


func _process(_delta: float) -> void:
	frames += 1
	if frames % STEP_INTERVAL != 0:
		return
	_run_step()


func _fail(msg: String) -> void:
	failures.append(msg)
	print("SMOKE FAIL: " + msg)


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("SMOKE OK: " + msg)
	else:
		_fail(msg)


func _screen() -> Node:
	return get_tree().current_scene


func _run_step() -> void:
	step += 1
	match step:
		1:
			var scr := _screen()
			_check(scr != null and scr.name == "MainMenu", "main menu is the start scene")
			_check(Session.has_save(0) or not Session.has_save(0), "save slot query does not crash")
		2:
			var st := Session.start_new_game("vessaria", "tutorial", 1)
			_check(st != null, "new game started (tutorial scenario)")
			App.goto_strategic()
		3:
			var scr = _screen()
			_check(scr != null and scr.name == "StrategicScreen", "strategic screen loaded")
			_check(scr.state != null and scr.state.territories.size() == 15, "state has 15 territories")
			_check(scr._faction_label.text.length() > 0, "faction label populated")
			_check(scr._turn_label.text.length() > 0, "turn label populated")
			_check(scr._resources_label.text.length() > 0, "resources label populated")
			_check(scr._tutorial_label != null and scr._tutorial_label.text.length() > 0, "tutorial hint visible")
			# Select the capital.
			scr._map.select_territory("vess_capital")
			scr._on_territory_selected("vess_capital")
		4:
			var scr = _screen()
			_check(scr._terr_name.text.length() > 0, "territory panel shows name")
			_check(scr._terr_actions_box.visible, "action buttons visible")
			var before_div: int = scr.state.territory("vess_capital").divisions
			scr._on_recruit()
			_check(scr.state.territory("vess_capital").divisions == before_div + 1, "recruit added a division")
		5:
			# Attack a weak neighbour with overwhelming force.
			var scr = _screen()
			var pair := _find_attack_pair(scr.state)
			_check(pair.size() == 2, "found adjacent enemy pair")
			if pair.size() == 2:
				scr.state.territory(pair[0]).divisions = 10
				scr.state.territory(pair[1]).divisions = 1
				scr._map.select_territory(pair[0])
				scr._on_territory_selected(pair[0])
				scr._on_attack()
				scr._on_territory_selected(pair[1])
				_check(scr.state.territory(pair[1]).owner == "vessaria", "attack captured the territory")
		6:
			var scr = _screen()
			var turn_before: int = scr.state.turn_number
			scr._on_end_turn()
			_check(scr.state.turn_number == turn_before + 1, "end turn advanced the turn")
			_check(scr.state.is_human_turn(), "back to the human turn")
			# Save.
			scr._on_save()
			saved_turn = scr.state.turn_number
			saved_credits = scr.state.faction("vessaria").credits
			_check(Session.has_save(0), "save file created")
			_check(scr._log_view.get_parsed_text().length() > 0, "event log has content")
		7:
			# Leave and load back.
			App.goto_main_menu()
		8:
			_check(_screen().name == "MainMenu", "back at the main menu")
			var result: Dictionary = Session.load_slot(0)
			_check(result.get("ok", false), "save loaded from the menu")
			App.goto_strategic()
		9:
			var scr = _screen()
			_check(scr.name == "StrategicScreen" and scr.state != null, "strategic screen back after load")
			if scr.state != null:
				_check(scr.state.turn_number == saved_turn, "loaded turn matches")
				_check(scr.state.faction("vessaria").credits == saved_credits, "loaded credits match")
				_check(scr._resources_label.text.length() > 0, "top bar refreshed after load")
		10:
			# Launch a tactical battle from the campaign.
			var scr = _screen()
			var pair := _find_attack_pair(scr.state)
			_check(pair.size() == 2, "found adjacent enemy pair for tactical battle")
			if pair.size() == 2:
				scr.state.territory(pair[0]).divisions = 60
				scr.state.territory(pair[1]).divisions = 1
				tactical_target = pair[1]
				Session.pending_battle = {
					"from_id": pair[0],
					"to_id": pair[1],
					"attacker_divisions": 60,
					"defender_divisions": 1,
					"terrain_defense": scr.state.territory(pair[1]).defense_multiplier(),
					"seed": 12345,
				}
				App.goto_tactical()
		11:
			var scr = _screen()
			_check(scr.name == "TacticalScreen", "tactical screen loaded")
			_check(scr._field != null and scr.battle != null, "tactical battle initialised")
			# Resolve instantly instead of waiting for real-time ticks.
			scr.battle.run_to_completion()
			scr._on_finished()
			_check(scr.battle.over, "tactical battle resolved")
			_check(Session.pending_battle.is_empty(), "pending battle cleared after resolution")
			var st: GameState = Session.state
			_check(st.territory(tactical_target).owner == "vessaria", "winning tactical battle captured the territory")
		12:
			var scr = _screen()
			scr._on_return()
		13:
			_check(_screen().name == "StrategicScreen", "returned to the strategic screen after the battle")
			_finish()


func _find_attack_pair(st: GameState) -> Array:
	for tid in st.order:
		var t: Territory = st.territories[tid]
		if t.owner != "vessaria":
			continue
		for nb in t.neighbors:
			var n: Territory = st.territories[nb]
			if n.owner != "vessaria" and n.owner != "":
				return [tid, nb]
	return []


func _finish() -> void:
	print("")
	if failures.is_empty():
		print("SMOKE PASS: all steps succeeded")
		get_tree().quit(0)
	else:
		for f in failures:
			print("SMOKE FAILED STEP: " + f)
		print("SMOKE FAIL: %d step(s) failed" % failures.size())
		get_tree().quit(1)
