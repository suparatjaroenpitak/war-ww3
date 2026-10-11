extends "res://tests/test_case.gd"
## Unit tests for GameServer: lobby membership, authoritative turn enforcement,
## command validation, duplicate suppression, and rate limiting.


func _server() -> GameServer:
	var s := GameServer.new()
	s.setup(WorldData.load_default(), 4242)
	return s


func _ready_server() -> GameServer:
	var s := _server()
	s.add_player(1, "vessaria", "Host")
	s.add_player(2, "kadran", "Guest")
	s.set_ready(1, true)
	s.set_ready(2, true)
	s.start_match()
	return s


func _cmd(kind: String, id: int, extra: Dictionary = {}) -> Dictionary:
	var c := extra.duplicate()
	c["kind"] = kind
	c["id"] = id
	return c


func test_player_gets_assigned_faction() -> void:
	var s := _server()
	var r := s.add_player(1, "vessaria", "Host")
	assert_true(r.get("ok", false), "player added")
	assert_eq(s.faction_of(1), "vessaria", "faction assigned")


func test_duplicate_faction_rejected() -> void:
	var s := _server()
	s.add_player(1, "vessaria", "Host")
	var r := s.add_player(2, "vessaria", "Copycat")
	assert_false(r.get("ok", false), "second player on same faction rejected")
	assert_eq(r.get("error", ""), "faction_taken", "faction_taken reason")


func test_server_full_rejected() -> void:
	var s := _server()
	var fids := s.playable_factions()
	var added := 0
	for i in fids.size():
		var r := s.add_player(i + 1, fids[i], "P%d" % i)
		if r.get("ok", false):
			added += 1
	var overflow := s.add_player(99, fids[0], "Late")
	assert_false(overflow.get("ok", false), "extra player rejected")
	assert_lte(added, GameServer.MAX_PLAYERS, "never exceeds the player cap")


func test_unknown_faction_rejected() -> void:
	var s := _server()
	var r := s.add_player(1, "atlantis", "Nope")
	assert_false(r.get("ok", false), "unknown faction rejected")
	assert_eq(r.get("error", ""), "unknown_faction", "unknown_faction reason")


func test_start_requires_two_players() -> void:
	var s := _server()
	s.add_player(1, "vessaria", "Solo")
	s.set_ready(1, true)
	var r := s.start_match()
	assert_false(r.get("ok", false), "cannot start alone")
	assert_eq(r.get("error", ""), "need_players", "need_players reason")


func test_start_requires_all_ready() -> void:
	var s := _server()
	s.add_player(1, "vessaria", "Host")
	s.add_player(2, "kadran", "Guest")
	s.set_ready(1, true)
	var r := s.start_match()
	assert_false(r.get("ok", false), "cannot start while unready")
	assert_eq(r.get("error", ""), "not_ready", "not_ready reason")


func test_commands_rejected_before_start() -> void:
	var s := _server()
	s.add_player(1, "vessaria", "Host")
	var r := s.submit_command(1, _cmd("recruit", 1, {"territory": "vess_capital"}), 0.0)
	assert_false(r.get("ok", false), "command rejected before start")
	assert_eq(r.get("error", ""), "not_started", "not_started reason")


func test_unknown_player_rejected() -> void:
	var s := _ready_server()
	var r := s.submit_command(77, _cmd("recruit", 1, {"territory": "vess_capital"}), 0.0)
	assert_false(r.get("ok", false), "unknown peer rejected")
	assert_eq(r.get("error", ""), "not_a_player", "not_a_player reason")


func test_command_from_non_current_player_rejected() -> void:
	var s := _ready_server()
	# Player 2 (kadran) is not the starting player.
	var r := s.submit_command(2, _cmd("recruit", 1, {"territory": "kad_capital"}), 0.0)
	assert_false(r.get("ok", false), "out-of-turn command rejected")
	assert_eq(r.get("error", ""), "not_your_turn", "not_your_turn reason")


func test_unknown_command_rejected() -> void:
	var s := _ready_server()
	var r := s.submit_command(1, _cmd("teleport", 1, {"territory": "kad_capital"}), 0.0)
	assert_false(r.get("ok", false), "unknown command rejected")
	assert_eq(r.get("error", ""), "unknown_command", "unknown_command reason")


func test_malformed_command_rejected() -> void:
	var s := _ready_server()
	var r := s.submit_command(1, {"kind": "recruit", "id": 1}, 0.0)
	assert_false(r.get("ok", false), "missing territory rejected")
	assert_eq(r.get("error", ""), "missing_territory", "missing_territory reason")
	var bad_id := s.submit_command(1, {"kind": "recruit", "id": -1, "territory": "vess_capital"}, 0.0)
	assert_false(bad_id.get("ok", false), "negative command id rejected")
	assert_eq(bad_id.get("error", ""), "bad_command_id", "bad_command_id reason")


func test_valid_recruit_applies() -> void:
	var s := _ready_server()
	var before: int = s.state.territory("vess_capital").divisions
	var r := s.submit_command(1, _cmd("recruit", 1, {"territory": "vess_capital"}), 0.0)
	assert_true(r.get("ok", false), "recruit accepted")
	assert_eq(s.state.territory("vess_capital").divisions, before + 1, "division added on the server")


func test_duplicate_command_not_applied_twice() -> void:
	var s := _ready_server()
	var before: int = s.state.territory("vess_capital").divisions
	s.submit_command(1, _cmd("recruit", 7, {"territory": "vess_capital"}), 0.0)
	var again := s.submit_command(1, _cmd("recruit", 7, {"territory": "vess_capital"}), 0.01)
	assert_false(again.get("ok", false), "duplicate command rejected")
	assert_eq(again.get("error", ""), "duplicate_command", "duplicate_command reason")
	assert_eq(s.state.territory("vess_capital").divisions, before + 1, "only applied once")


func test_rate_limit_triggers() -> void:
	var s := _ready_server()
	var limited := false
	for i in range(GameServer.MAX_COMMANDS_PER_WINDOW + 3):
		var r := s.submit_command(1, _cmd("recruit", 100 + i, {"territory": "vess_capital"}), 0.0)
		if r.get("error", "") == "rate_limited":
			limited = true
			break
	assert_true(limited, "flooding triggers the rate limit")


func test_end_turn_advances_to_next_human() -> void:
	var s := _ready_server()
	var r := s.submit_command(1, _cmd("end_turn", 1), 0.0)
	assert_true(r.get("ok", false), "end turn accepted")
	assert_eq(s.state.current_faction_id, "kadran", "turn passed to the other human player")


func test_disconnect_handover_ends_current_turn() -> void:
	var s := _ready_server()
	assert_eq(s.state.current_faction_id, "vessaria", "host starts")
	s.remove_player(1)
	assert_eq(s.faction_of(1), "", "removed player has no faction")
	# vessaria is no longer human; the match continues with kadran.
	assert_eq(s.state.current_faction_id, "kadran", "turn handed to the remaining player")
	assert_true(s.state.factions["vessaria"].is_ai, "abandoned faction reverts to AI")
