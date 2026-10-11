extends "res://tests/test_case.gd"
## Unit tests for save/load, schema versioning, and validation.

const TEST_SLOT := 99
const MISSING_SLOT := 98
const CORRUPT_SLOT := 97

var world: WorldData


func _setup() -> GameState:
	if world == null:
		world = WorldData.load_default()
	var s := GameState.new()
	s.setup(world, "vessaria", 7, "standard")
	return s


func _cleanup() -> void:
	var dir := DirAccess.open(SaveGame.SAVE_DIR)
	if dir != null:
		for slot in [TEST_SLOT, CORRUPT_SLOT]:
			var fname := "slot_%d.json" % slot
			if dir.file_exists(fname):
				dir.remove(fname)


func test_save_creates_file() -> void:
	_cleanup()
	var s := _setup()
	var result := SaveGame.save_game(s, TEST_SLOT)
	assert_true(result.get("ok", false), "save ok: %s" % str(result))
	assert_true(SaveGame.has_save(TEST_SLOT), "save file exists")


func test_roundtrip_preserves_state() -> void:
	_cleanup()
	var s := _setup()
	s.recruit("vess_capital")
	s.end_turn()
	var saved := SaveGame.save_game(s, TEST_SLOT)
	assert_true(saved.get("ok", false), "save ok")
	var loaded := SaveGame.load_game(world, TEST_SLOT)
	assert_true(loaded.get("ok", false), "load ok: %s" % str(loaded))
	if not loaded.get("ok", false):
		return
	var t: GameState = loaded["state"]
	assert_eq(t.turn_number, s.turn_number, "turn preserved")
	assert_eq(t.current_faction_id, s.current_faction_id, "current faction preserved")
	assert_eq(t.human_faction_id, s.human_faction_id, "human faction preserved")
	assert_eq(t.faction("vessaria").credits, s.faction("vessaria").credits, "credits preserved")
	assert_eq(t.territory("vess_capital").divisions, s.territory("vess_capital").divisions, "divisions preserved")
	assert_eq(t.territory("vess_capital").owner, s.territory("vess_capital").owner, "owner preserved")
	assert_eq(t.rng_seed, s.rng_seed, "rng seed preserved")
	assert_gt(t.log.entries().size(), 0, "event log preserved")
	_cleanup()


func test_load_missing_slot_fails_cleanly() -> void:
	var result := SaveGame.load_game(world, MISSING_SLOT)
	assert_false(result.get("ok", false), "missing slot rejected")
	assert_eq(result.get("error", ""), "MSG_NO_SAVE", "no-save error reported")


func test_corrupt_file_rejected() -> void:
	var dir := DirAccess.open("user://")
	if dir != null and not dir.dir_exists("saves"):
		dir.make_dir("saves")
	var file := FileAccess.open(SaveGame.slot_path(CORRUPT_SLOT), FileAccess.WRITE)
	file.store_string("{ this is not valid json !!!")
	file.close()
	var result := SaveGame.load_game(world, CORRUPT_SLOT)
	assert_false(result.get("ok", false), "corrupt file rejected")
	assert_eq(result.get("error", ""), "MSG_LOAD_FAILED", "load-failed error")
	assert_ne(result.get("detail", ""), "", "parse detail provided")


func test_tampered_save_rejected_by_validation() -> void:
	assert_ne(SaveGame.validate({}), "", "empty dict rejected")
	assert_ne(SaveGame.validate({"human_faction_id": ""}), "", "missing human rejected")
	assert_ne(SaveGame.validate({"human_faction_id": "vessaria"}), "", "missing territories rejected")
	assert_ne(SaveGame.validate({
		"human_faction_id": "vessaria",
		"territories": {},
		"factions": {},
	}), "", "missing factions rejected")
	assert_ne(SaveGame.validate({
		"human_faction_id": "vessaria",
		"territories": {},
		"factions": {},
		"turn_number": -5,
	}), "", "negative turn rejected")
	assert_eq(SaveGame.validate({
		"human_faction_id": "vessaria",
		"territories": {"a": {}},
		"factions": {"vessaria": {}},
		"turn_number": 3,
	}), "", "valid payload accepted")


func test_migrate_sets_current_version() -> void:
	var old := {"schema_version": 1, "human_faction_id": "vessaria"}
	var migrated := SaveGame.migrate(old)
	assert_eq(migrated["schema_version"], GameState.SCHEMA_VERSION, "migrated to current schema")
	assert_eq(migrated["human_faction_id"], "vessaria", "data preserved through migration")


func test_schema_version_is_positive() -> void:
	assert_gt(GameState.SCHEMA_VERSION, 0, "schema version defined")
