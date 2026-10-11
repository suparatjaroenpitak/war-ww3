class_name Faction
extends RefCounted
## A playable or AI faction. Pure data + small helpers.

var id: String = ""
var name_key: String = ""
var description_key: String = ""
var color: Color = Color.WHITE
var is_ai: bool = true
var passive: bool = false
var credits: int = 0
var manpower: int = 0
var alive: bool = true

var income_credits: int = 0
var income_manpower: int = 0
var upkeep_credits: int = 0
var divisions_total: int = 0
var territories_owned: int = 0


func display_name() -> String:
	return tr(name_key)


func to_dict() -> Dictionary:
	return {
		"id": id,
		"credits": credits,
		"manpower": manpower,
		"alive": alive,
	}


static func from_dict(d: Dictionary, base: Faction) -> Faction:
	var f := Faction.new()
	f.id = base.id
	f.name_key = base.name_key
	f.description_key = base.description_key
	f.color = base.color
	f.is_ai = base.is_ai
	f.passive = base.passive
	f.credits = int(d.get("credits", 0))
	f.manpower = int(d.get("manpower", 0))
	f.alive = bool(d.get("alive", true))
	return f
