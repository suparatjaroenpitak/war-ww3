class_name TacticalBattle
extends RefCounted
## Deterministic abstract tactical battle simulation.
##
## Battles are simulated as lightweight "unit groups" on a logical 2D field.
## Each group tracks strength, morale and supply; it moves toward uncaptured
## objectives, engages nearby enemies, and can rout when morale collapses.
## Everything is driven by a seeded RNG and a fixed iteration order, so the same
## inputs always produce the same outcome (important for save/replay and for
## headless tests). This class has no scene-tree dependency.

const SIDE_ATTACKER := 0
const SIDE_DEFENDER := 1

const DEFAULT_UNITS_PER_SIDE := 16
const DEFAULT_MAX_TICKS := 240
const FIELD_SIZE := Vector2(120.0, 70.0)
const MOVE_SPEED := 4.0
const ENGAGE_RANGE := 7.0
const OBJECTIVE_RANGE := 5.0
const SUPPLY_DRAIN_PER_TICK := 0.35

var field_size: Vector2 = FIELD_SIZE
var terrain_defense: float = 1.0
var max_ticks: int = DEFAULT_MAX_TICKS
var tick: int = 0
var over: bool = false
var winner: int = -1  # SIDE_* or -1 while undecided

var units: Array = []       # Array[Dictionary]
var objectives: Array = []  # Array[Dictionary]

var rng_seed: int = 0
var units_per_side: int = DEFAULT_UNITS_PER_SIDE

var _rng := RandomNumberGenerator.new()
var _next_id: int = 0
var _initial_strength := {SIDE_ATTACKER: 0, SIDE_DEFENDER: 0}


## Configure and spawn a new battle.
## attacker_strength / defender_strength: abstract power totals.
## units_per_side: how many unit groups each side fields (configurable for perf).
## objective_count: number of capture points along the front.
func setup(attacker_strength: int, defender_strength: int, terrain: float, seed: int, units_per_side_in: int = DEFAULT_UNITS_PER_SIDE, objective_count: int = 3, max_ticks_in: int = DEFAULT_MAX_TICKS) -> void:
	units_per_side = maxi(1, units_per_side_in)
	terrain_defense = maxf(0.5, terrain)
	max_ticks = maxi(10, max_ticks_in)
	rng_seed = seed
	_rng.seed = seed
	tick = 0
	over = false
	winner = -1
	_next_id = 0
	units.clear()
	objectives.clear()

	_spawn_side(SIDE_ATTACKER, maxi(1, attacker_strength))
	_spawn_side(SIDE_DEFENDER, maxi(1, defender_strength))
	_spawn_objectives(maxi(1, objective_count))

	_initial_strength[SIDE_ATTACKER] = strength(SIDE_ATTACKER)
	_initial_strength[SIDE_DEFENDER] = strength(SIDE_DEFENDER)


func _spawn_side(side: int, total_strength: int) -> void:
	var per_unit: int = maxi(1, int(ceil(float(total_strength) / float(units_per_side))))
	var spawn_x: float = field_size.x * (0.12 if side == SIDE_ATTACKER else 0.88)
	for i in units_per_side:
		var y := field_size.y * (float(i) + 0.5) / float(units_per_side)
		var jitter := _rng.randf_range(-2.0, 2.0)
		units.append({
			"id": _next_id,
			"side": side,
			"strength": float(per_unit),
			"morale": 100.0,
			"supply": 100.0,
			"pos": Vector2(spawn_x, clampf(y + jitter, 2.0, field_size.y - 2.0)),
			"alive": true,
		})
		_next_id += 1


func _spawn_objectives(count: int) -> void:
	for i in count:
		var t := (float(i) + 0.5) / float(count)
		var y := field_size.y * t
		objectives.append({
			"id": i,
			"pos": Vector2(field_size.x * 0.5, y),
			"owner": -1,  # -1 unclaimed, SIDE_ATTACKER, SIDE_DEFENDER
		})


# --------------------------------------------------------------------------
# Simulation
# --------------------------------------------------------------------------

## Advance one tick. Returns true while the battle is still running.
func step() -> bool:
	if over:
		return false
	tick += 1
	_move_units()
	_resolve_engagements()
	_update_morale_supply()
	_capture_objectives()
	_check_end()
	return not over


func run_to_completion() -> void:
	var guard := 0
	while not over and guard <= max_ticks + 1:
		step()
		guard += 1


func _move_units() -> void:
	for u in units:
		if not u["alive"]:
			continue
		var target := _unit_target(u)
		var to_target: Vector2 = target - u["pos"]
		if to_target.length() <= 1.0:
			continue
		# Morale and supply affect effective speed.
		var factor: float = 0.6 + 0.4 * (u["morale"] / 100.0) * (0.5 + 0.5 * (u["supply"] / 100.0))
		u["pos"] = u["pos"] + to_target.normalized() * MOVE_SPEED * factor
		u["pos"] = u["pos"].clamp(Vector2.ZERO, field_size)


## A unit prefers the nearest unclaimed/contested objective, else the nearest
## enemy, else holds its position.
func _unit_target(u: Dictionary) -> Vector2:
	var side: int = u["side"]
	var best_goal: Vector2 = u["pos"]
	var best_dist := INF
	for o in objectives:
		if o["owner"] == side:
			continue
		var d: float = u["pos"].distance_to(o["pos"])
		if d < best_dist:
			best_dist = d
			best_goal = o["pos"]
	if best_dist < INF and best_dist <= ENGAGE_RANGE * 3.0:
		return best_goal
	# Otherwise head for the nearest enemy.
	var enemy := _nearest_enemy(u)
	if not enemy.is_empty():
		return enemy["pos"]
	return best_goal


func _nearest_enemy(u: Dictionary) -> Dictionary:
	var best := {}
	var best_dist := INF
	for other in units:
		if other["side"] == u["side"] or not other["alive"]:
			continue
		var d: float = u["pos"].distance_to(other["pos"])
		if d < best_dist:
			best_dist = d
			best = other
	return best


func _resolve_engagements() -> void:
	# Iterate in a stable order so results are deterministic.
	for u in units:
		if not u["alive"]:
			continue
		for enemy in units:
			if enemy["side"] == u["side"] or not enemy["alive"]:
				continue
			if u["pos"].distance_to(enemy["pos"]) > ENGAGE_RANGE:
				continue
			_exchange_fire(u, enemy)


func _exchange_fire(a: Dictionary, b: Dictionary) -> void:
	var jitter := _rng.randf_range(0.9, 1.1)
	var a_power: float = a["strength"] * _effectiveness(a)
	var b_power: float = b["strength"] * _effectiveness(b)
	# The defender side benefits from terrain.
	if b["side"] == SIDE_DEFENDER:
		b_power *= terrain_defense
	if a["side"] == SIDE_DEFENDER:
		a_power *= terrain_defense
	var total: float = maxf(1.0, a_power + b_power)
	_apply_damage(b, a_power / total * 8.0 * jitter)
	_apply_damage(a, b_power / total * 8.0 * jitter)


func _effectiveness(u: Dictionary) -> float:
	return 0.5 + 0.5 * (u["morale"] / 100.0)


func _apply_damage(u: Dictionary, amount: float) -> void:
	u["strength"] = maxf(0.0, u["strength"] - amount)
	if u["strength"] <= 0.01:
		u["alive"] = false
		u["morale"] = 0.0
	else:
		u["morale"] = maxf(0.0, u["morale"] - amount * 1.5)


func _update_morale_supply() -> void:
	for u in units:
		if not u["alive"]:
			continue
		u["supply"] = maxf(0.0, u["supply"] - SUPPLY_DRAIN_PER_TICK)
		if u["supply"] <= 0.0:
			u["morale"] = maxf(0.0, u["morale"] - 1.5)
		elif u["morale"] < 100.0:
			# Recover a little in good order.
			u["morale"] = minf(100.0, u["morale"] + 0.4)
		if u["morale"] <= 0.0 and u["strength"] > 0.0:
			u["strength"] = maxf(0.0, u["strength"] - 2.0)
			if u["strength"] <= 0.01:
				u["alive"] = false


func _capture_objectives() -> void:
	for o in objectives:
		var present_attacker := false
		var present_defender := false
		for u in units:
			if not u["alive"]:
				continue
			if u["pos"].distance_to(o["pos"]) > OBJECTIVE_RANGE:
				continue
			if u["side"] == SIDE_ATTACKER:
				present_attacker = true
			else:
				present_defender = true
		if present_attacker and not present_defender:
			o["owner"] = SIDE_ATTACKER
		elif present_defender and not present_attacker:
			o["owner"] = SIDE_DEFENDER
		elif present_attacker and present_defender:
			o["owner"] = -1  # contested


func _check_end() -> void:
	if strength(SIDE_ATTACKER) <= 0.0:
		over = true
		winner = SIDE_DEFENDER
		return
	if strength(SIDE_DEFENDER) <= 0.0:
		over = true
		winner = SIDE_ATTACKER
		return
	if objectives_held(SIDE_ATTACKER) == objectives.size():
		over = true
		winner = SIDE_ATTACKER
		return
	if tick >= max_ticks:
		over = true
		winner = SIDE_ATTACKER if objectives_held(SIDE_ATTACKER) > objectives.size() / 2 else SIDE_DEFENDER


# --------------------------------------------------------------------------
# Queries / summary
# --------------------------------------------------------------------------

func strength(side: int) -> float:
	var total := 0.0
	for u in units:
		if u["side"] == side and u["alive"]:
			total += u["strength"]
	return total


func living_units(side: int) -> int:
	var n := 0
	for u in units:
		if u["side"] == side and u["alive"]:
			n += 1
	return n


func objectives_held(side: int) -> int:
	var n := 0
	for o in objectives:
		if o["owner"] == side:
			n += 1
	return n


func initial_strength(side: int) -> float:
	return float(_initial_strength.get(side, 0))


## Fraction of a side's starting strength that survived, in [0, 1].
func survival_ratio(side: int) -> float:
	var initial := initial_strength(side)
	if initial <= 0.0:
		return 0.0
	return clampf(strength(side) / initial, 0.0, 1.0)


func summary() -> Dictionary:
	return {
		"tick": tick,
		"over": over,
		"winner": winner,
		"attacker_survival": survival_ratio(SIDE_ATTACKER),
		"defender_survival": survival_ratio(SIDE_DEFENDER),
		"attacker_units": living_units(SIDE_ATTACKER),
		"defender_units": living_units(SIDE_DEFENDER),
		"attacker_objectives": objectives_held(SIDE_ATTACKER),
		"defender_objectives": objectives_held(SIDE_DEFENDER),
		"objective_count": objectives.size(),
	}
