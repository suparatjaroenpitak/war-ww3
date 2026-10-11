class_name AI_Controller
extends RefCounted
## Deterministic AI faction turn logic. No scene-tree dependency, no external
## RNG: it uses the state's seeded RNG so the whole campaign is reproducible.
##
## Decision rules (in priority order):
## 1. Recruit in the richest owned territory if affordable and below a cap.
## 2. Attack the weakest adjacent enemy territory when local strength allows.

const MAX_DIVISIONS_PER_TERRITORY := 8
const ATTACK_STRENGTH_RATIO := 1.5


static func take_turn(state: GameState, faction_id: String) -> void:
	var f: Faction = state.factions.get(faction_id)
	if f == null or not f.alive or f.passive:
		return

	_recruit(state, f)
	_attack(state, f)


static func _recruit(state: GameState, f: Faction) -> void:
	if not Economy.can_recruit(f):
		return
	var owned := state.territories_owned_by(f.id)
	if owned.is_empty():
		return
	# Prefer the territory with the fewest divisions (spread defense) that is
	# still under the cap.
	var best: Territory = null
	for t in owned:
		if t.divisions < MAX_DIVISIONS_PER_TERRITORY:
			if best == null or t.divisions < best.divisions:
				best = t
	if best == null:
		return
	state.recruit(best.id)


static func _attack(state: GameState, f: Faction) -> void:
	var owned := state.territories_owned_by(f.id)
	if owned.is_empty():
		return
	for t in owned:
		if t.divisions < 2:
			continue
		var targets: Array = []
		for nb in t.neighbors:
			var n: Territory = state.territories.get(nb)
			if n != null and n.owner != f.id and n.owner != "":
				targets.append(n)
		if targets.is_empty():
			continue
		var weakest: Territory = null
		for n in targets:
			if weakest == null or n.divisions < weakest.divisions:
				weakest = n
		if weakest == null:
			continue
		# Attack when we have a decisive local advantage.
		if float(t.divisions) >= float(weakest.divisions) * ATTACK_STRENGTH_RATIO:
			state.attack(t.id, weakest.id)
			return
