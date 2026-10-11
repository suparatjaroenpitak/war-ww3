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
	load_settings()
	# Detect the OS locale on first run.
	if not _loaded_locale:
		var os_locale := OS.get_locale_language()
		if os_locale in SUPPORTED_LOCALES:
			set_value("locale", os_locale)
	apply_locale()


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
			if key == "fullscreen":
				pass  # applied on next window setup


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
