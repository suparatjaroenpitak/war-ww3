class_name Economy
extends RefCounted
## Turn-based economy rules. All functions are pure given explicit inputs so
## they can be unit tested deterministically without a scene tree.

const UPKEEP_CREDITS_PER_DIVISION := 2
const RECRUIT_CREDITS := 10
const RECRUIT_MANPOWER := 5
const DEVELOP_BASE_COST := 40


## Sum of per-territory yields for the given list of territories.
static func gross_income(territories: Array) -> Dictionary:
	var credits := 0
	var manpower := 0
	for t in territories:
		credits += t.credits_yield()
		manpower += t.manpower_yield()
	return {"credits": credits, "manpower": manpower}


## Upkeep for a given total number of divisions.
static func upkeep(divisions_total: int) -> int:
	return divisions_total * UPKEEP_CREDITS_PER_DIVISION


## Resolve a faction's economy for one turn, mutating the faction object and
## returning a report dictionary.
static func resolve(faction: Faction, territories: Array) -> Dictionary:
	var income := gross_income(territories)
	var divisions := 0
	for t in territories:
		divisions += t.divisions
	var up := upkeep(divisions)
	var net := income["credits"] - up

	faction.credits = max(0, faction.credits + net)
	faction.manpower += income["manpower"]
	faction.income_credits = income["credits"]
	faction.income_manpower = income["manpower"]
	faction.upkeep_credits = up
	faction.divisions_total = divisions
	faction.territories_owned = territories.size()

	return {
		"income_credits": income["credits"],
		"income_manpower": income["manpower"],
		"upkeep_credits": up,
		"net_credits": net,
		"divisions_total": divisions,
		"territories_owned": territories.size(),
		"credits": faction.credits,
		"manpower": faction.manpower,
		"bankrupt": faction.credits <= 0 and net < 0,
	}


## Cost for one division and whether a faction can afford it.
static func can_recruit(faction: Faction) -> bool:
	return faction.credits >= RECRUIT_CREDITS and faction.manpower >= RECRUIT_MANPOWER


## Deduct the recruitment cost. Call only after can_recruit() returns true.
static func spend_recruit(faction: Faction) -> void:
	faction.credits -= RECRUIT_CREDITS
	faction.manpower -= RECRUIT_MANPOWER


## Cost to develop a territory by one level. Scales with current development.
static func develop_cost(development: int) -> int:
	return DEVELOP_BASE_COST * development
