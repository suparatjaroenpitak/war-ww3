class_name GameState
extends RefCounted
## Authoritative campaign state. Holds the world, faction/territory runtime
## objects, turn counter, and the deterministic RNG used for combat.
##
## This class intentionally has no scene-tree dependency so it can be run
## headless and unit tested. The GameSession autoload owns a single instance.

const SCHEMA_VERSION := 1

signal turn_changed(turn: int)
signal event_added(entry: Dictionary)
signal game_ended(winner_id: String)
signal state_changed

var world: WorldData = null
var factions: Dictionary = {}    # id -> Faction (runtime copies)
var territories: Dictionary = {}  # id -> Territory (runtime copies)
var order: PackedStringArray = PackedStringArray()

var scenario_id: String = "standard"
var turn_number: int = 1
var current_faction_id: String = ""
var human_faction_id: String = ""
var winner_id: String = ""
var over: bool = false

var rng_seed: int = 0
var _rng := RandomNumberGenerator.new()
var log := EventLog.new()

var _faction_order: PackedStringArray = PackedStringArray()


func setup(new_world: WorldData, human_faction: String, seed: int, scenario: String = "standard") -> void:
	world = new_world
	scenario_id = scenario
	human_faction_id = human_faction
	rng_seed = seed
	_rng.seed = seed

	# Runtime copies of factions.
	factions.clear()
	_faction_order = PackedStringArray()
	for fid in world.factions:
		var base: Faction = world.factions[fid]
		var f := Faction.new()
		f.id = base.id
		f.name_key = base.name_key
		f.description_key = base.description_key
		f.color = base.color
		f.is_ai = base.is_ai or base.id != human_faction
		f.passive = base.passive
		f.credits = base.credits
		f.manpower = base.manpower
		f.alive = true
		factions[fid] = f
		_faction_order.append(fid)

	# Runtime copies of territories.
	territories.clear()
	order = world.order
	for tid in order:
		territories[tid] = _copy_territory(world.territories[tid])

	current_faction_id = human_faction
	turn_number = 1
	winner_id = ""
	over = false
	log.clear()
	log.add_turn(turn_number, "EVENT_GAME_STARTED")
	log.add_turn(turn_number, "EVENT_TURN_START", [turn_number])


func _copy_territory(base: Territory) -> Territory:
	var t := Territory.new()
	t.id = base.id
	t.name_key = base.name_key
	t.continent = base.continent
	t.terrain = base.terrain
	t.polygon = base.polygon
	t.centroid = base.centroid
	t.neighbors = base.neighbors
	t.base_population = base.base_population
	t.base_credits = base.base_credits
	t.base_manpower = base.base_manpower
	t.owner = base.owner
	t.divisions = base.divisions
	t.development = base.development
	return t


func faction(id: String) -> Faction:
	return factions.get(id)


func territory(id: String) -> Territory:
	return territories.get(id)


func is_human_turn() -> bool:
	return current_faction_id == human_faction_id


func territories_owned_by(faction_id: String) -> Array:
	var result: Array = []
	for tid in order:
		var t: Territory = territories[tid]
		if t.owner == faction_id:
			result.append(t)
	return result


func total_divisions(faction_id: String) -> int:
	var n := 0
	for tid in order:
		var t: Territory = territories[tid]
		if t.owner == faction_id:
			n += t.divisions
	return n


## Recruitment. Validates ownership, turn, and affordability.
func recruit(territory_id: String) -> Dictionary:
	if over:
		return _fail("MSG_GAME_OVER")
	if territory_id not in territories:
		return _fail("MSG_INVALID_TERRITORY")
	var t: Territory = territories[territory_id]
	if t.owner != current_faction_id:
		return _fail("MSG_NOT_OWNER")
	var f: Faction = factions[current_faction_id]
	if not Economy.can_recruit(f):
		if f.credits < Economy.RECRUIT_CREDITS:
			return _fail("MSG_NOT_ENOUGH_CREDITS")
		return _fail("MSG_NOT_ENOUGH_MANPOWER")
	Economy.spend_recruit(f)
	t.divisions += 1
	log.add_turn(turn_number, "EVENT_RECRUITED", [f.name_key, t.name_key])
	state_changed.emit()
	return {"ok": true, "territory": territory_id, "divisions": t.divisions}


func develop(territory_id: String) -> Dictionary:
	if over:
		return _fail("MSG_GAME_OVER")
	if territory_id not in territories:
		return _fail("MSG_INVALID_TERRITORY")
	var t: Territory = territories[territory_id]
	if t.owner != current_faction_id:
		return _fail("MSG_NOT_OWNER")
	var f: Faction = factions[current_faction_id]
	var cost := Economy.develop_cost(t.development)
	if f.credits < cost:
		return _fail("MSG_NOT_ENOUGH_CREDITS")
	f.credits -= cost
	t.development += 1
	log.add_turn(turn_number, "EVENT_DEVELOPED", [f.name_key, t.name_key])
	state_changed.emit()
	return {"ok": true, "territory": territory_id, "development": t.development}


## Returns an error key (not ok) or an "ok" object for whether an attack is legal.
func can_attack(from_id: String, to_id: String) -> Dictionary:
	if from_id not in territories or to_id not in territories:
		return _fail("MSG_INVALID_TERRITORY")
	var from: Territory = territories[from_id]
	var to: Territory = territories[to_id]
	if from.owner != current_faction_id:
		return _fail("MSG_NOT_OWNER")
	if from.divisions <= 0:
		return _fail("MSG_NO_DIVISIONS")
	if to.owner == current_faction_id:
		return _fail("MSG_FRIENDLY")
	if to_id not in from.neighbors:
		return _fail("MSG_NOT_ADJACENT")
	return {"ok": true}


func attack(from_id: String, to_id: String) -> Dictionary:
	if over:
		return _fail("MSG_GAME_OVER")
	var legality := can_attack(from_id, to_id)
	if not legality.get("ok", false):
		return legality

	var from: Territory = territories[from_id]
	var to: Territory = territories[to_id]
	var atk_roll := _roll()
	var def_roll := _roll()
	var result := Combat.resolve(from.divisions, to.divisions, to.defense_multiplier(), atk_roll, def_roll)

	var prev_owner := to.owner
	from.divisions -= result["attacker_losses"]
	to.divisions -= result["defender_losses"]

	if result["captured"]:
		to.owner = current_faction_id
		to.divisions = result["survivors"]
		log.add_turn(turn_number, "EVENT_TERRITORY_CAPTURED", [factions[current_faction_id].name_key, to.name_key])
		if prev_owner == human_faction_id and prev_owner != current_faction_id:
			log.add_turn(turn_number, "EVENT_TERRITORY_LOST", [to.name_key])
	else:
		log.add_turn(turn_number, "EVENT_ATTACK_FAILED", [from.name_key, to.name_key])

	state_changed.emit()
	_check_victory()
	return {
		"ok": true,
		"captured": result["captured"],
		"attacker_losses": result["attacker_losses"],
		"defender_losses": result["defender_losses"],
		"from": from_id,
		"to": to_id,
	}


## End the current faction's turn and resolve the whole turn cycle.
## In single-player the AI factions act and resolve automatically between the
## human's turns.
func end_turn() -> void:
	if over:
		return
	_resolve_faction(current_faction_id)
	_advance()
	var guard := 0
	while not over and current_faction_id != human_faction_id:
		if guard > 100:
			push_error("GameState: turn cycle guard exceeded")
			break
		var fid := current_faction_id
		AI_Controller.take_turn(self, fid)
		_resolve_faction(fid)
		_advance()
		guard += 1
	check_defeat()
	if not over:
		turn_number += 1
		log.add_turn(turn_number, "EVENT_TURN_START", [turn_number])
	turn_changed.emit(turn_number)
	state_changed.emit()


func _resolve_faction(faction_id: String) -> void:
	var f: Faction = factions[faction_id]
	if not f.alive:
		return
	var owned := territories_owned_by(faction_id)
	var report := Economy.resolve(f, owned)
	log.add_turn(turn_number, "EVENT_ECONOMY_CALCULATED", [f.name_key])
	if report["bankrupt"]:
		log.add_turn(turn_number, "EVENT_BANKRUPT", [f.name_key])


func _advance() -> void:
	var idx := _faction_order.find(current_faction_id)
	if idx == -1:
		idx = 0
	current_faction_id = _faction_order[(idx + 1) % _faction_order.size()]


func _roll() -> float:
	return _rng.randf_range(0.85, 1.15)


func _check_victory() -> void:
	# Win: capture every non-unclaimed territory that is not your own; i.e. no
	# other living faction still owns territory.
	for fid in factions:
		if fid == human_faction_id:
			continue
		var f: Faction = factions[fid]
		if f.alive and territories_owned_by(fid).size() > 0:
			return
	winner_id = human_faction_id
	over = true
	log.add_turn(turn_number, "EVENT_VICTORY", [factions[human_faction_id].name_key])
	game_ended.emit(winner_id)


func check_defeat() -> void:
	if over:
		return
	if territories_owned_by(human_faction_id).is_empty():
		over = true
		winner_id = ""
		game_ended.emit("")
		log.add_turn(turn_number, "EVENT_DEFEAT", [])


func _fail(error_key: String) -> Dictionary:
	return {"ok": false, "error": error_key}


func to_dict() -> Dictionary:
	var fdict := {}
	for fid in factions:
		fdict[fid] = factions[fid].to_dict()
	var tdict := {}
	for tid in territories:
		tdict[tid] = territories[tid].to_dict()
	return {
		"schema_version": SCHEMA_VERSION,
		"scenario_id": scenario_id,
		"turn_number": turn_number,
		"current_faction_id": current_faction_id,
		"human_faction_id": human_faction_id,
		"winner_id": winner_id,
		"over": over,
		"rng_seed": rng_seed,
		"factions": fdict,
		"territories": tdict,
		"event_log": log.to_dict(),
	}
