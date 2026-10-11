class_name Territory
extends RefCounted
## A single territory on the strategic map. Pure data + small helpers.
## Serialization: to_dict()/from_dict() are used by SaveGame.

const TERRAIN_PLAINS := "plains"
const TERRAIN_FOREST := "forest"
const TERRAIN_MOUNTAIN := "mountain"
const TERRAIN_DESERT := "desert"
const TERRAIN_COAST := "coast"
const TERRAIN_URBAN := "urban"

const TERRAIN_DEFENSE := {
	TERRAIN_PLAINS: 1.0,
	TERRAIN_FOREST: 1.25,
	TERRAIN_MOUNTAIN: 1.5,
	TERRAIN_DESERT: 0.9,
	TERRAIN_COAST: 0.95,
	TERRAIN_URBAN: 1.75,
}

const TERRAIN_KEYS := {
	TERRAIN_PLAINS: "TERRAIN_PLAINS",
	TERRAIN_FOREST: "TERRAIN_FOREST",
	TERRAIN_MOUNTAIN: "TERRAIN_MOUNTAIN",
	TERRAIN_DESERT: "TERRAIN_DESERT",
	TERRAIN_COAST: "TERRAIN_COAST",
	TERRAIN_URBAN: "TERRAIN_URBAN",
}

var id: String = ""
var name_key: String = ""
var continent: String = ""
var terrain: String = TERRAIN_PLAINS
var polygon: PackedVector2Array = PackedVector2Array()
var centroid: Vector2 = Vector2.ZERO
var neighbors: PackedStringArray = PackedStringArray()
var base_population: int = 0
var base_credits: int = 0
var base_manpower: int = 0

var owner: String = ""  # faction id, or "" for unclaimed
var divisions: int = 0
var development: int = 1


func credits_yield() -> int:
	return base_credits + 2 * development


func manpower_yield() -> int:
	return int(float(base_population) / 1000.0) + development


func defense_multiplier() -> float:
	return TERRAIN_DEFENSE.get(terrain, 1.0)


func terrain_key() -> String:
	return TERRAIN_KEYS.get(terrain, "TERRAIN_PLAINS")


func is_owned_by(faction_id: String) -> bool:
	return owner == faction_id


func to_dict() -> Dictionary:
	return {
		"id": id,
		"owner": owner,
		"divisions": divisions,
		"development": development,
	}


static func from_dict(d: Dictionary, base: Territory) -> Territory:
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
	t.owner = str(d.get("owner", ""))
	t.divisions = int(d.get("divisions", 0))
	t.development = int(d.get("development", 1))
	return t
