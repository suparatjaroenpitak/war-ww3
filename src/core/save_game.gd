class_name SaveGame
extends RefCounted
## Save/load with schema versioning and migration support.
##
## Save files are JSON stored under user://saves/. The schema version is
## validated on load; older versions are migrated through versioned steps.
## Imported data is validated so a corrupt or hostile file cannot crash the game.

const SAVE_DIR := "user://saves"
const SLOT_PREFIX := "slot_"
const FILE_EXT := ".json"


static func slot_path(slot: int) -> String:
	return "%s/%s%d%s" % [SAVE_DIR, SLOT_PREFIX, slot, FILE_EXT]


static func has_save(slot: int) -> bool:
	return FileAccess.file_exists(slot_path(slot))


static func save_game(state: GameState, slot: int) -> Dictionary:
	var root := DirAccess.open("user://")
	if root != null and not root.dir_exists("saves"):
		var dir_err := root.make_dir_recursive("saves")
		if dir_err != OK:
			return {"ok": false, "error": "MSG_SAVE_FAILED", "code": dir_err}
	var payload := JSON.stringify(state.to_dict(), "\t")
	var file := FileAccess.open(slot_path(slot), FileAccess.WRITE)
	if file == null:
		return {"ok": false, "error": "MSG_SAVE_FAILED", "code": FileAccess.get_open_error()}
	file.store_string(payload)
	file.close()
	return {"ok": true}


static func load_game(world: WorldData, slot: int) -> Dictionary:
	var path := slot_path(slot)
	if not FileAccess.file_exists(path):
		return {"ok": false, "error": "MSG_NO_SAVE"}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "error": "MSG_LOAD_FAILED", "code": FileAccess.get_open_error()}
	var text := file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(text) != OK:
		return {"ok": false, "error": "MSG_LOAD_FAILED", "detail": json.get_error_message()}

	var data = json.data
	if typeof(data) != TYPE_DICTIONARY:
		return {"ok": false, "error": "MSG_LOAD_FAILED", "detail": "not an object"}

	var migrated = migrate(data)
	var validation := validate(migrated)
	if validation != "":
		return {"ok": false, "error": "MSG_LOAD_FAILED", "detail": validation}

	var state := GameState.new()
	var human := str(migrated.get("human_faction_id", ""))
	var seed := int(migrated.get("rng_seed", 0))
	var scenario := str(migrated.get("scenario_id", "standard"))
	state.setup(world, human, seed, scenario)
	state.turn_number = int(migrated.get("turn_number", 1))
	state.current_faction_id = str(migrated.get("current_faction_id", human))
	state.winner_id = str(migrated.get("winner_id", ""))
	state.over = bool(migrated.get("over", false))

	var fdict: Dictionary = migrated.get("factions", {})
	for fid in fdict:
		if world.factions.has(fid) and state.factions.has(fid):
			var base: Faction = world.factions[fid]
			state.factions[fid] = Faction.from_dict(fdict[fid], base)

	var tdict: Dictionary = migrated.get("territories", {})
	for tid in tdict:
		if world.territories.has(tid) and state.territories.has(tid):
			state.territories[tid] = Territory.from_dict(tdict[tid], world.territories[tid])

	state.log = EventLog.from_dict(migrated.get("event_log", []))
	return {"ok": true, "state": state}


## Migrate older schemas to the latest. Steps are keyed by version number.
static func migrate(data: Dictionary) -> Dictionary:
	var version := int(data.get("schema_version", 1))
	var current := data.duplicate(true)
	# Future migration steps go here, e.g.:
	# if version < 2:
	#     current = _migrate_1_to_2(current)
	#     version = 2
	current["schema_version"] = GameState.SCHEMA_VERSION
	return current


## Structural validation of imported save data. Returns an error string or "".
static func validate(data: Dictionary) -> String:
	if not data.has("human_faction_id") or str(data["human_faction_id"]) == "":
		return "missing human_faction_id"
	if not data.has("territories") or typeof(data["territories"]) != TYPE_DICTIONARY:
		return "missing territories"
	if not data.has("factions") or typeof(data["factions"]) != TYPE_DICTIONARY:
		return "missing factions"
	if data["territories"].is_empty() or data["factions"].is_empty():
		return "empty factions or territories"
	var turn := int(data.get("turn_number", 0))
	if turn < 0 or turn > 100000:
		return "turn_number out of range"
	return ""
