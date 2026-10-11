extends SceneTree
## Automated project validation. Run headless:
##   godot --headless --path <project> --script res://tools/validate_project.gd
##
## Checks project structure, referenced files, script compilation, world data
## integrity, and localization files. Prints a PASS/FAIL summary and exits with
## a non-zero code on failure.

var errors: Array[String] = []
var warnings: Array[String] = []
var checks := 0


func _initialize() -> void:
	print("=== WAR WW3 project validation ===")
	_check_project_settings()
	_check_files()
	_check_scripts()
	_check_world_data()
	_check_localization()
	_check_scenes()
	_report()
	quit(1 if errors.size() > 0 else 0)


func _ok(cond: bool, message: String) -> void:
	checks += 1
	if cond:
		print("  [PASS] " + message)
	else:
		errors.append(message)
		print("  [FAIL] " + message)


func _warn(cond: bool, message: String) -> void:
	if not cond:
		warnings.append(message)
		print("  [WARN] " + message)


func _check_project_settings() -> void:
	print("-- project settings --")
	_ok(ProjectSettings.has_setting("application/config/name"), "game name configured")
	_ok(ProjectSettings.get_setting("application/config/name", "") == "WAR WW3", "game name is WAR WW3")
	var main_scene: String = ProjectSettings.get_setting("application/run/main_scene", "")
	_ok(main_scene != "", "main scene configured")
	_ok(ResourceLoader.exists(main_scene), "main scene exists: " + main_scene)
	var icon: String = ProjectSettings.get_setting("application/config/icon", "")
	_ok(icon != "" and ResourceLoader.exists(icon), "icon configured and exists")

	# Autoloads.
	var autoloads: Dictionary = ProjectSettings.get_setting("autoload", {})
	_ok(autoloads.size() >= 3, "autoloads configured: %d" % autoloads.size())
	for name in autoloads:
		var path: String = autoloads[name]
		var clean := path.trim_prefix("*")
		_ok(ResourceLoader.exists(clean), "autoload '%s' script exists: %s" % [name, clean])

	# Translations.
	var translations: Array = ProjectSettings.get_setting("internationalization/locale/translations", [])
	_ok(translations.size() >= 2, "translation resources configured: %d" % translations.size())
	for t in translations:
		_ok(ResourceLoader.exists(t), "translation exists: " + t)


func _check_files() -> void:
	print("-- key files --")
	for path in [
		"res://project.godot",
		"res://icon.svg",
		"res://data/world.json",
		"res://localization/strings.csv",
		"res://src/main/main_menu.tscn",
		"res://src/main/settings_screen.tscn",
		"res://src/main/faction_select.tscn",
		"res://src/strategic/strategic_screen.tscn",
		"res://src/tactical/tactical_screen.tscn",
	]:
		_ok(ResourceLoader.exists(path) or FileAccess.file_exists(path), "exists: " + path)


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


func _check_scripts() -> void:
	print("-- scripts --")
	var files: Array = []
	for d in ["res://src", "res://tests", "res://tools"]:
		_collect_gd_files(d, files)
	_ok(files.size() >= 20, "script files found: %d" % files.size())
	var broken: Array[String] = []
	for path in files:
		var script = load(path)
		if script == null:
			broken.append(path)
	_ok(broken.size() == 0, "all scripts compile" + ("" if broken.is_empty() else " (broken: " + ", ".join(broken) + ")"))


func _check_world_data() -> void:
	print("-- world data --")
	var world := WorldData.load_default()
	_ok(world != null, "world.json loads")
	if world != null:
		_ok(world.territories.size() >= 10, "territory count: %d" % world.territories.size())
		_ok(world.factions.size() >= 3, "faction count: %d" % world.factions.size())
		var bad_neighbor := false
		for tid in world.territories:
			var t: Territory = world.territories[tid]
			if t.polygon.size() < 3:
				bad_neighbor = true
			for nb in t.neighbors:
				if not world.territories.has(nb):
					bad_neighbor = true
		_ok(not bad_neighbor, "all territory polygons and neighbor links valid")


func _check_localization() -> void:
	print("-- localization --")
	var f := FileAccess.open("res://localization/strings.csv", FileAccess.READ)
	_ok(f != null, "strings.csv readable")
	if f != null:
		var text := f.get_as_text()
		f.close()
		var lines := text.split("\n")
		_ok(lines.size() > 50, "translation rows: %d" % lines.size())
		var header: PackedStringArray = lines[0].split(",")
		_ok(header.size() >= 3 and header[0] == "keys" and header[1] == "en" and header[2] == "th", "CSV header is keys,en,th")


func _check_scenes() -> void:
	print("-- scenes --")
	for path in [
		"res://src/main/main_menu.tscn",
		"res://src/main/settings_screen.tscn",
		"res://src/main/faction_select.tscn",
		"res://src/strategic/strategic_screen.tscn",
		"res://src/tactical/tactical_screen.tscn",
	]:
		var scene = load(path)
		_ok(scene != null and scene is PackedScene, "scene loads: " + path)


func _report() -> void:
	print("")
	print("=== validation summary ===")
	print("checks: %d  errors: %d  warnings: %d" % [checks, errors.size(), warnings.size()])
	for e in errors:
		print("  ERROR: " + e)
	for w in warnings:
		print("  WARNING: " + w)
	if errors.is_empty():
		print("PROJECT VALIDATION PASSED")
	else:
		print("PROJECT VALIDATION FAILED")
