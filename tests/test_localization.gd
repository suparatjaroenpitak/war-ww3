extends "res://tests/test_case.gd"
## Localization coverage tests. Reads the CSV directly (translations are not
## registered in --script mode) and cross-checks every translation key used in
## source code and data files.

const CSV_PATH := "res://localization/strings.csv"
const KEY_PREFIXES := ["APP", "MENU", "SETTINGS", "FACTION", "TERRAIN", "TERR", "GAME", "MSG", "EVENT", "COMMON", "CONFIRM", "MULTIPLAYER", "TUTORIAL", "TACTICAL", "WORLD", "LOG"]

var csv_rows: Array = []
var keys: Dictionary = {}


func _setup() -> void:
	if not csv_rows.is_empty():
		return
	var f := FileAccess.open(CSV_PATH, FileAccess.READ)
	assert_ne(f, null, "can open strings.csv")
	if f == null:
		return
	var text := f.get_as_text()
	f.close()
	for line in text.split("\n"):
		var l: String = line.strip_edges()
		if l == "" or l.begins_with("#"):
			continue
		csv_rows.append(_parse_line(l))


func _parse_line(line: String) -> PackedStringArray:
	var fields := PackedStringArray()
	var cur := ""
	var in_quotes := false
	var i := 0
	while i < line.length():
		var c := line[i]
		if in_quotes:
			if c == "\"":
				if i + 1 < line.length() and line[i + 1] == "\"":
					cur += "\""
					i += 1
				else:
					in_quotes = false
			else:
				cur += c
		else:
			if c == "\"":
				in_quotes = true
			elif c == ",":
				fields.append(cur)
				cur = ""
			else:
				cur += c
		i += 1
	fields.append(cur)
	return fields


func _build_key_map() -> void:
	if not keys.is_empty():
		return
	for row in csv_rows:
		var r: PackedStringArray = row
		if r.size() >= 3:
			keys[r[0]] = [r[1], r[2]]


func test_csv_structure_valid() -> void:
	_setup()
	assert_gt(csv_rows.size(), 50, "CSV has a substantial number of rows")
	var header: PackedStringArray = csv_rows[0]
	assert_eq(header[0], "keys", "first column is keys")
	assert_eq(header[1], "en", "second column is en")
	assert_eq(header[2], "th", "third column is th")


func test_no_duplicate_keys() -> void:
	_setup()
	var seen := {}
	for row in csv_rows:
		var r: PackedStringArray = row
		if r[0] == "keys":
			continue
		assert_false(seen.has(r[0]), "duplicate key: " + r[0])
		seen[r[0]] = true


func test_every_row_has_both_locales() -> void:
	_setup()
	for row in csv_rows:
		var r: PackedStringArray = row
		if r[0] == "keys":
			continue
		assert_eq(r.size(), 3, "row '%s' has exactly 3 columns" % r[0])
		assert_ne(r[1].strip_edges(), "", "english missing for " + r[0])
		assert_ne(r[2].strip_edges(), "", "thai missing for " + r[0])


func test_thai_rows_contain_thai_characters() -> void:
	_setup()
	var thai_count := 0
	for row in csv_rows:
		var r: PackedStringArray = row
		if r[0] == "keys":
			continue
		if _has_thai(r[2]):
			thai_count += 1
	assert_gt(thai_count, 40, "most rows contain real Thai text")


func _has_thai(s: String) -> bool:
	for i in s.length():
		var c := s.unicode_at(i)
		if c >= 0x0E01 and c <= 0x0E5B:
			return true
	return false


func _collect_gd_files(dir_path: String, out: Array) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		var full := dir_path.path_join(name)
		if dir.current_is_dir():
			if not name.begins_with("."):
				_collect_gd_files(full, out)
		elif name.ends_with(".gd"):
			out.append(full)
		name = dir.get_next()
	dir.list_dir_end()


func test_all_code_keys_exist_in_csv() -> void:
	_setup()
	_build_key_map()
	var files: Array = []
	_collect_gd_files("res://src", files)
	assert_gt(files.size(), 10, "found source files")
	var pattern := "\"((?:"
	for p in KEY_PREFIXES:
		pattern += p + "|"
	pattern = pattern.trim_suffix("|") + ")_[A-Z0-9_]+)\""
	var re := RegEx.new()
	re.compile(pattern)
	var missing: Array[String] = []
	for path in files:
		var f := FileAccess.open(path, FileAccess.READ)
		if f == null:
			continue
		var text := f.get_as_text()
		f.close()
		for m in re.search_all(text):
			var key: String = m.get_string(1)
			if not keys.has(key) and not missing.has(key):
				missing.append(key)
	assert_eq(missing.size(), 0, "missing keys: " + ", ".join(missing))


func test_dynamic_keys_exist() -> void:
	_setup()
	_build_key_map()
	for preset in ["low", "medium", "high"]:
		var key := "SETTINGS_PRESET_" + preset.to_upper()
		assert_true(keys.has(key), "preset key exists: " + key)
	for terrain_key in ["TERRAIN_PLAINS", "TERRAIN_FOREST", "TERRAIN_MOUNTAIN", "TERRAIN_DESERT", "TERRAIN_COAST", "TERRAIN_URBAN"]:
		assert_true(keys.has(terrain_key), "terrain key exists: " + terrain_key)


func test_world_json_keys_exist() -> void:
	_setup()
	_build_key_map()
	var world := WorldData.load_default()
	assert_ne(world, null, "world loads")
	if world == null:
		return
	assert_true(keys.has(world.name_key), "world name key exists: " + world.name_key)
	for fid in world.factions:
		var f: Faction = world.factions[fid]
		assert_true(keys.has(f.name_key), "faction name key exists: " + f.name_key)
		assert_true(keys.has(f.description_key), "faction description key exists: " + f.description_key)
	for tid in world.territories:
		var t: Territory = world.territories[tid]
		assert_true(keys.has(t.name_key), "territory name key exists: " + t.name_key)


func test_placeholders_consistent_between_locales() -> void:
	_setup()
	var re := RegEx.new()
	re.compile("%[sd]")
	var mismatches: Array[String] = []
	for row in csv_rows:
		var r: PackedStringArray = row
		if r[0] == "keys":
			continue
		var en := re.search_all(r[1]).size()
		var th := re.search_all(r[2]).size()
		if en != th:
			mismatches.append("%s (en=%d th=%d)" % [r[0], en, th])
	assert_eq(mismatches.size(), 0, "format placeholder mismatch: " + ", ".join(mismatches))
