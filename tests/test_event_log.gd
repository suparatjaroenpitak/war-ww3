extends "res://tests/test_case.gd"
## Unit tests for the event log.


func test_add_and_clear() -> void:
	var log := EventLog.new()
	log.add("EVENT_GAME_STARTED")
	log.add("EVENT_TURN_START", [1])
	assert_eq(log.entries().size(), 2, "two entries")
	log.clear()
	assert_eq(log.entries().size(), 0, "cleared")


func test_max_entries_capped() -> void:
	var log := EventLog.new()
	for i in EventLog.MAX_ENTRIES + 50:
		log.add("EVENT_TURN_START", [i])
	assert_lte(log.entries().size(), EventLog.MAX_ENTRIES, "log capped at MAX_ENTRIES")


func test_empty_search_returns_all() -> void:
	var log := EventLog.new()
	log.add("EVENT_GAME_STARTED")
	log.add("EVENT_BANKRUPT", ["FACTION_KADRAN"])
	assert_eq(log.search("").size(), 2, "empty term returns all")
	assert_eq(log.search("   ").size(), 2, "whitespace term returns all")


func test_search_matches_text() -> void:
	var log := EventLog.new()
	log.add("EVENT_TERRITORY_CAPTURED", ["FACTION_KADRAN", "TERR_VESS_CAPITAL"])
	log.add("EVENT_BANKRUPT", ["FACTION_ORINTH"])
	# Without translations loaded, keys pass through; match on the raw key text.
	var hits := log.search("CAPTURED")
	assert_eq(hits.size(), 1, "one capture entry")
	hits = log.search("nothing matches this")
	assert_eq(hits.size(), 0, "no false positives")


func test_roundtrip_serialization() -> void:
	var log := EventLog.new()
	log.add_turn(3, "EVENT_RECRUITED", ["FACTION_VESSARIA", "TERR_VESS_CAPITAL"])
	log.add_turn(4, "EVENT_BANKRUPT", ["FACTION_KADRAN"])
	var restored := EventLog.from_dict(log.to_dict())
	assert_eq(restored.entries().size(), 2, "entries restored")
	assert_eq(restored.entries()[0]["turn"], 3, "turn restored")
	assert_eq(restored.entries()[1]["key"], "EVENT_BANKRUPT", "key restored")
	assert_eq(restored.entries()[1]["args"], ["FACTION_KADRAN"], "args restored")


func test_from_dict_ignores_garbage() -> void:
	var log := EventLog.from_dict(["not a dict", 42, {"turn": 1, "key": "EVENT_X"}])
	assert_eq(log.entries().size(), 1, "garbage entries skipped")
