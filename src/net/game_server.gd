class_name GameServer
extends RefCounted
## Authoritative multiplayer match logic.
##
## The server owns the single GameState. Clients may only send validated
## commands; the server checks that the sender is a known player, that it is
## their turn, that the command is well-formed, that it has not already been
## processed, and that the sender is not flooding. Nothing a client sends is
## trusted as state.
##
## This class is transport-agnostic: it takes a monotonic time value so it can
## be unit tested deterministically without real sockets.

signal lobby_changed
signal match_started

const MAX_PLAYERS := 4
const MAX_COMMANDS_PER_WINDOW := 25
const RATE_WINDOW_SEC := 1.0
const DEDUP_TTL_SEC := 8.0

var world: WorldData = null
var state: GameState = null
var seed: int = 0
var started: bool = false

var players: Dictionary = {}       # peer_id:int -> {name:String, faction_id:String, ready:bool}
var _by_faction: Dictionary = {}   # faction_id -> peer_id
var _seen := {}                    # command_id:int -> timestamp:float
var _rate := {}                    # peer_id:int -> Array[float]


func setup(new_world: WorldData, world_seed: int) -> void:
	world = new_world
	seed = world_seed
	state = null
	started = false
	players.clear()
	_by_faction.clear()
	_seen.clear()
	_rate.clear()


func playable_factions() -> Array:
	var out: Array = []
	if world == null:
		return out
	for fid in world.factions:
		out.append(fid)
	return out


# --------------------------------------------------------------------------
# Lobby
# --------------------------------------------------------------------------

func add_player(peer_id: int, faction_id: String, display_name: String) -> Dictionary:
	if world == null:
		return _fail("no_world")
	if players.has(peer_id):
		return _fail("already_joined")
	if players.size() >= MAX_PLAYERS:
		return _fail("server_full")
	if not world.factions.has(faction_id):
		return _fail("unknown_faction")
	if _by_faction.has(faction_id):
		return _fail("faction_taken")
	players[peer_id] = {
		"name": NetProtocol.sanitize_name(display_name),
		"faction_id": faction_id,
		"ready": false,
	}
	_by_faction[faction_id] = peer_id
	lobby_changed.emit()
	return {"ok": true, "peer_id": peer_id, "faction_id": faction_id}


func remove_player(peer_id: int) -> void:
	if not players.has(peer_id):
		return
	var faction_id: String = players[peer_id]["faction_id"]
	players.erase(peer_id)
	_by_faction.erase(faction_id)
	_rate.erase(peer_id)
	if started and state != null:
		# Hand the faction back to AI. If it was their turn, advance the match
		# so the remaining players are not blocked.
		var was_current := state.current_faction_id == faction_id
		state.unregister_human(faction_id)
		if was_current and not state.over:
			state.end_turn()
	lobby_changed.emit()


func set_ready(peer_id: int, ready: bool) -> Dictionary:
	if not players.has(peer_id):
		return _fail("not_a_player")
	players[peer_id]["ready"] = ready
	lobby_changed.emit()
	return {"ok": true}


func all_ready() -> bool:
	if players.size() < 2:
		return false
	for pid in players:
		if not bool(players[pid]["ready"]):
			return false
	return true


func start_match() -> Dictionary:
	if world == null:
		return _fail("no_world")
	if started:
		return _fail("already_started")
	if players.size() < 2:
		return _fail("need_players")
	if not all_ready():
		return _fail("not_ready")
	var ids := players.keys()
	ids.sort()
	var host_peer: int = ids[0]
	var host_faction: String = players[host_peer]["faction_id"]
	var extras: Array = []
	for pid in ids:
		if pid != host_peer:
			extras.append(players[pid]["faction_id"])
	state = GameState.new()
	state.setup(world, host_faction, seed, "multiplayer", extras)
	started = true
	match_started.emit()
	return {"ok": true}


func lobby_snapshot() -> Array:
	var out: Array = []
	for pid in players:
		out.append({
			"peer_id": pid,
			"name": players[pid]["name"],
			"faction_id": players[pid]["faction_id"],
			"ready": players[pid]["ready"],
		})
	return out


func faction_of(peer_id: int) -> String:
	if players.has(peer_id):
		return str(players[peer_id]["faction_id"])
	return ""


# --------------------------------------------------------------------------
# Commands
# --------------------------------------------------------------------------

## Validate and apply a client command. `now` is a monotonic seconds value.
func submit_command(peer_id: int, command, now: float) -> Dictionary:
	if not players.has(peer_id):
		return _fail("not_a_player")
	if not started or state == null:
		return _fail("not_started")
	if state.over:
		return _fail("game_over")
	if _rate_limited(peer_id, now):
		return _fail("rate_limited")

	var validated := NetValidation.validate_command(command)
	if not validated.get("ok", false):
		return validated

	var command_id: int = validated["id"]
	# Dedup key is per-peer so two clients using the same id never collide.
	var dedup_key := "%d:%d" % [peer_id, command_id]
	if _seen.has(dedup_key):
		return _fail("duplicate_command")

	var faction_id: String = players[peer_id]["faction_id"]
	if state.current_faction_id != faction_id:
		return _fail("not_your_turn")

	# Record before applying so a replayed id can never execute twice.
	_seen[dedup_key] = now
	_prune(now)

	var result := {}
	match validated["kind"]:
		"recruit":
			result = state.recruit(validated["territory"])
		"develop":
			result = state.develop(validated["territory"])
		"attack":
			result = state.attack(validated["from"], validated["to"])
		"end_turn":
			state.end_turn()
			result = {"ok": true}
	return {
		"ok": result.get("ok", false),
		"kind": validated["kind"],
		"command_id": command_id,
		"result": result,
		"state": state.to_dict(),
	}


## Serialised authoritative state for synchronising clients.
func state_snapshot() -> Dictionary:
	if state == null:
		return {}
	return state.to_dict()


# --------------------------------------------------------------------------
# Internals
# --------------------------------------------------------------------------

func _rate_limited(peer_id: int, now: float) -> bool:
	var window: Array = _rate.get(peer_id, [])
	var kept: Array = []
	for t in window:
		if now - float(t) < RATE_WINDOW_SEC:
			kept.append(t)
	if kept.size() >= MAX_COMMANDS_PER_WINDOW:
		_rate[peer_id] = kept
		return true
	kept.append(now)
	_rate[peer_id] = kept
	return false


func _prune(now: float) -> void:
	var stale: Array = []
	for cid in _seen:
		if now - float(_seen[cid]) > DEDUP_TTL_SEC:
			stale.append(cid)
	for cid in stale:
		_seen.erase(cid)


func _fail(reason: String) -> Dictionary:
	return {"ok": false, "error": reason}
