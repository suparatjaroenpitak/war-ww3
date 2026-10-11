extends Node
## GameSession autoload. Owns the active GameState and orchestrates
## new game / save / load. It is the single source of truth for the current
## match, and is serialized/deserialized through SaveGame.

signal game_started(state: GameState)
signal game_loaded(state: GameState)

var state: GameState = null
var default_seed: int = 20261011

## Set by the strategic screen when the player chooses to fight an attack
## tactically. The tactical screen reads it, simulates the battle, feeds the
## result back into `state`, and clears it.
var pending_battle: Dictionary = {}


func start_new_game(faction_id: String, scenario: String = "standard", seed: int = 0) -> GameState:
	var world := WorldData.load_default()
	if world == null:
		push_error("GameSession: failed to load world data")
		return null
	if seed == 0:
		seed = default_seed
	var s := GameState.new()
	s.setup(world, faction_id, seed, scenario)
	state = s
	game_started.emit(s)
	return s


func load_slot(slot: int) -> Dictionary:
	var world := WorldData.load_default()
	if world == null:
		return {"ok": false, "error": "MSG_LOAD_FAILED", "detail": "world data missing"}
	var result := SaveGame.load_game(world, slot)
	if result.get("ok", false):
		state = result["state"]
		game_loaded.emit(state)
	return result


func save_to_slot(slot: int) -> Dictionary:
	if state == null:
		return {"ok": false, "error": "MSG_SAVE_FAILED"}
	return SaveGame.save_game(state, slot)


func has_save(slot: int) -> bool:
	return SaveGame.has_save(slot)


func clear_state() -> void:
	state = null
