class_name WorldData
extends RefCounted
## Data-driven world definition. Loads factions and territory seed data from
## JSON and generates deterministic territory polygons with Voronoi.

const DEFAULT_PATH := "res://data/world.json"

var name_key: String = "WORLD_AURELIA"
var size: Vector2 = Vector2(1600, 900)
var factions: Dictionary = {}        # id -> Faction
var territories: Dictionary = {}     # id -> Territory (base definitions)
var order: PackedStringArray = PackedStringArray()  # territory ids in file order


static func load_default() -> WorldData:
	var w := WorldData.new()
	if w._load(DEFAULT_PATH):
		return w
	return null


func _load(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("WorldData: cannot open %s (%s)" % [path, FileAccess.get_open_error()])
		return false
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		push_error("WorldData: JSON parse error at line %d: %s" % [json.get_error_line(), json.get_error_message()])
		return false
	return build(json.data)


## Build the world from parsed JSON. Validates required fields and returns
## false on any structural problem so callers can fail loudly instead of
## running a broken game.
func build(data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		push_error("WorldData: root of world.json must be an object")
		return false

	var world: Dictionary = data.get("world", {})
	name_key = str(world.get("name_key", "WORLD_AURELIA"))
	size = Vector2(float(world.get("width", 1600)), float(world.get("height", 900)))

	# Factions.
	factions.clear()
	var faction_list: Array = data.get("factions", [])
	if faction_list.is_empty():
		push_error("WorldData: no factions defined")
		return false
	for fd in faction_list:
		if typeof(fd) != TYPE_DICTIONARY:
			continue
		var f := Faction.new()
		f.id = str(fd.get("id", ""))
		f.name_key = str(fd.get("name_key", ""))
		f.description_key = str(fd.get("description_key", ""))
		f.color = Color(str(fd.get("color", "#ffffff")))
		f.is_ai = bool(fd.get("is_ai", true))
		f.passive = bool(fd.get("passive", false))
		f.credits = int(fd.get("starting_credits", 0))
		f.manpower = int(fd.get("starting_manpower", 0))
		factions[f.id] = f

	# Territories: collect sites, then tessellate.
	var tlist: Array = data.get("territories", [])
	if tlist.is_empty():
		push_error("WorldData: no territories defined")
		return false

	var ids: PackedStringArray = PackedStringArray()
	var metas: Dictionary = {}
	var sites := PackedVector2Array()
	for td in tlist:
		if typeof(td) != TYPE_DICTIONARY:
			continue
		var id := str(td.get("id", ""))
		if id.is_empty():
			push_error("WorldData: territory missing id")
			return false
		if metas.has(id):
			push_error("WorldData: duplicate territory id '%s'" % id)
			return false
		var site: Array = td.get("site", [])
		if site.size() < 2:
			push_error("WorldData: territory '%s' missing site [x, y]" % id)
			return false
		ids.append(id)
		sites.append(Vector2(float(site[0]), float(site[1])))
		metas[id] = td

	var bounds := Rect2(0, 0, size.x, size.y)
	var polygons := Voronoi.build(sites, bounds)
	var adjacency := Voronoi.adjacency(polygons)

	territories.clear()
	order = ids
	for i in ids.size():
		var id := ids[i]
		var td: Dictionary = metas[id]
		var t := Territory.new()
		t.id = id
		t.name_key = str(td.get("name_key", ""))
		t.continent = str(td.get("continent", ""))
		t.terrain = str(td.get("terrain", Territory.TERRAIN_PLAINS))
		t.polygon = polygons[i]
		t.centroid = Voronoi.centroid(polygons[i])
		var nb: PackedStringArray = PackedStringArray()
		for j in adjacency[i]:
			nb.append(ids[j])
		t.neighbors = nb
		t.base_population = int(td.get("population", 0))
		t.base_credits = int(td.get("credits", 0))
		t.base_manpower = int(td.get("manpower", 0))
		t.owner = str(td.get("owner", ""))
		t.divisions = int(td.get("divisions", 0))
		t.development = int(td.get("development", 1))
		territories[id] = t

	return true
