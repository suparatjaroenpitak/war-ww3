extends Node
## Settings autoload. Persists user preferences to user://settings.cfg and
## applies localization + graphics/audio settings.

const CONFIG_PATH := "user://settings.cfg"
const CONFIG_VERSION := 1

const SUPPORTED_LOCALES := ["en", "th"]
const GRAPHICS_PRESETS := ["low", "medium", "high"]

signal settings_changed(key: String, value: Variant)
signal locale_changed(locale: String)

var _values := {
	"locale": "en",
	"master_volume": 0.8,
	"music_volume": 0.6,
	"sfx_volume": 0.8,
	"graphics_preset": "medium",
	"fullscreen": false,
	"ui_scale": 1.0,
}


func _ready() -> void:
	_ensure_audio_buses()
	load_settings()
	# Detect the OS locale on first run.
	if not _loaded_locale:
		var os_locale := OS.get_locale_language()
		if os_locale in SUPPORTED_LOCALES:
			_values["locale"] = os_locale
	apply_locale()
	# Apply every persisted value on startup so the stored preset, volumes,
	# fullscreen mode and UI scale take effect immediately.
	for key in _values:
		_apply(key, _values[key])


var _loaded_locale := false


func load_settings() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(CONFIG_PATH)
	if err != OK:
		return
	_loaded_locale = cfg.has_section_key("general", "locale")
	for key in _values:
		if cfg.has_section_key("general", key):
			_values[key] = cfg.get_value("general", key)
	var v := int(cfg.get_value("general", "config_version", 1))
	if v < CONFIG_VERSION:
		pass  # future migrations go here


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("general", "config_version", CONFIG_VERSION)
	for key in _values:
		cfg.set_value("general", key, _values[key])
	cfg.save(CONFIG_PATH)


func get_value(key: String, default = null):
	return _values.get(key, default)


func set_value(key: String, value) -> void:
	if _values.has(key):
		_values[key] = value
	settings_changed.emit(key, value)
	_apply(key, value)


func _apply(key: String, value) -> void:
	match key:
		"locale":
			apply_locale()
		"fullscreen":
			apply_fullscreen()
		"graphics_preset":
			apply_graphics_preset()
		"ui_scale":
			apply_ui_scale()
		"master_volume", "music_volume", "sfx_volume":
			apply_audio()


## Create the Music and SFX buses if the project has not defined them yet, so
## volume settings can be applied without shipping a bus layout file.
func _ensure_audio_buses() -> void:
	if AudioServer.get_bus_index("Music") == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "Music")
		AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	if AudioServer.get_bus_index("SFX") == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "SFX")
		AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")


func apply_audio() -> void:
	_set_bus_volume("Master", _values["master_volume"])
	_set_bus_volume("Music", _values["music_volume"] * _values["master_volume"])
	_set_bus_volume("SFX", _values["sfx_volume"] * _values["master_volume"])


func _set_bus_volume(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	AudioServer.set_bus_mute(idx, linear <= 0.001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(clampf(linear, 0.0, 1.0)))


func apply_fullscreen() -> void:
	if not is_inside_tree():
		return
	var mode := DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN if bool(_values["fullscreen"]) else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)


func apply_ui_scale() -> void:
	if not is_inside_tree():
		return
	get_window().content_scale_factor = clampf(float(_values["ui_scale"]), 0.75, 1.5)


## Graphics presets tune 2D antialiasing. The strategic map is lightweight 2D
## canvas drawing, so these are the levers that actually affect cost here.
func apply_graphics_preset() -> void:
	var preset: String = _values["graphics_preset"]
	var vp := get_viewport()
	if vp == null:
		return
	match preset:
		"low":
			vp.msaa_2d = Viewport.MSAA_DISABLED
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
		"high":
			vp.msaa_2d = Viewport.MSAA_4X
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
		_:
			vp.msaa_2d = Viewport.MSAA_2X
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED


func set_locale(locale: String) -> void:
	if locale not in SUPPORTED_LOCALES:
		return
	if _values["locale"] == locale:
		return
	_values["locale"] = locale
	settings_changed.emit("locale", locale)
	apply_locale()
	save_settings()


func apply_locale() -> void:
	var locale: String = _values["locale"]
	TranslationServer.set_locale(locale)
	locale_changed.emit(locale)


func get_locale() -> String:
	return _values["locale"]


func reset_defaults() -> void:
	_values["locale"] = "en"
	_values["master_volume"] = 0.8
	_values["music_volume"] = 0.6
	_values["sfx_volume"] = 0.8
	_values["graphics_preset"] = "medium"
	_values["fullscreen"] = false
	_values["ui_scale"] = 1.0
	apply_locale()
	settings_changed.emit("reset", null)
	save_settings()
