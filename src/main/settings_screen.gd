extends Control
## Settings screen: language, audio, graphics. Changes apply immediately and
## are persisted through the Settings autoload.

var _locale_selector: OptionButton
var _preset_selector: OptionButton
var _master_slider: HSlider
var _music_slider: HSlider
var _sfx_slider: HSlider
var _fullscreen_check: CheckBox
var _ui_scale_slider: HSlider
var _scale_label: Label


func _ready() -> void:
	_build()


func _build() -> void:
	UI.bg(self, App.color_bg)
	var center := UI.center(self)
	var panel := UI.panel(center)
	panel.custom_minimum_size = Vector2(560, 0)
	var box := UI.vbox(panel, 10)

	UI.title(box, tr("SETTINGS_TITLE"), 32)
	UI.spacer(box, 4)

	# Language.
	box.add_child(_section(tr("SETTINGS_LANGUAGE")))
	_locale_selector = OptionButton.new()
	_locale_selector.add_item(tr("SETTINGS_LANGUAGE_EN"), 0)
	_locale_selector.set_item_metadata(0, "en")
	_locale_selector.add_item(tr("SETTINGS_LANGUAGE_TH"), 1)
	_locale_selector.set_item_metadata(1, "th")
	_locale_selector.select(0 if Settings.get_locale() == "en" else 1)
	_locale_selector.item_selected.connect(_on_locale_selected)
	box.add_child(_locale_selector)

	UI.spacer(box, 6)

	# Audio.
	box.add_child(_section(tr("SETTINGS_AUDIO")))
	_master_slider = _slider(Settings.get_value("master_volume", 0.8))
	_master_slider.value_changed.connect(_on_master)
	box.add_child(_slider_row(tr("SETTINGS_MASTER_VOLUME"), _master_slider))
	_music_slider = _slider(Settings.get_value("music_volume", 0.6))
	_music_slider.value_changed.connect(_on_music)
	box.add_child(_slider_row(tr("SETTINGS_MUSIC_VOLUME"), _music_slider))
	_sfx_slider = _slider(Settings.get_value("sfx_volume", 0.8))
	_sfx_slider.value_changed.connect(_on_sfx)
	box.add_child(_slider_row(tr("SETTINGS_SFX_VOLUME"), _sfx_slider))

	UI.spacer(box, 6)

	# Graphics.
	box.add_child(_section(tr("SETTINGS_GRAPHICS")))
	_preset_selector = OptionButton.new()
	for p in Settings.GRAPHICS_PRESETS:
		_preset_selector.add_item(tr("SETTINGS_PRESET_" + p.to_upper()), _preset_selector.item_count)
	_preset_selector.select(Settings.GRAPHICS_PRESETS.find(Settings.get_value("graphics_preset", "medium")))
	_preset_selector.item_selected.connect(_on_preset_selected)
	var preset_row := UI.hbox(box, 8)
	var preset_label := UI.label(tr("SETTINGS_GRAPHICS_PRESET"))
	preset_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preset_row.add_child(preset_label)
	preset_row.add_child(_preset_selector)
	box.add_child(preset_row)

	_fullscreen_check = CheckBox.new()
	_fullscreen_check.text = tr("SETTINGS_FULLSCREEN")
	_fullscreen_check.button_pressed = bool(Settings.get_value("fullscreen", false))
	_fullscreen_check.toggled.connect(_on_fullscreen)
	box.add_child(_fullscreen_check)

	_ui_scale_slider = _slider(Settings.get_value("ui_scale", 1.0))
	_ui_scale_slider.min_value = 0.75
	_ui_scale_slider.max_value = 1.5
	_ui_scale_slider.step = 0.05
	_ui_scale_slider.value_changed.connect(_on_ui_scale)
	var scale_row := UI.hbox(box, 8)
	scale_row.add_child(UI.label(tr("SETTINGS_UI_SCALE")))
	_scale_label = UI.label(_fmt_pct(_ui_scale_slider.value))
	scale_row.add_child(_ui_scale_slider)
	scale_row.add_child(_scale_label)
	box.add_child(scale_row)

	UI.spacer(box, 10)

	# Actions.
	var actions := UI.hbox(box, 8)
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	var reset := UI.button(tr("SETTINGS_RESET"))
	reset.pressed.connect(_on_reset)
	actions.add_child(reset)
	var back := UI.button(tr("SETTINGS_BACK"))
	back.pressed.connect(_on_back)
	actions.add_child(back)
	box.add_child(actions)


func _section(text: String) -> Label:
	var l := UI.label(text, 18)
	l.modulate = App.color_text_dim
	return l


func _slider(value: float) -> HSlider:
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = value
	s.custom_minimum_size = Vector2(160, 0)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return s


func _slider_row(text: String, slider: HSlider) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(UI.label(text))
	row.add_child(slider)
	return row


func _fmt_pct(v: float) -> String:
	return "%d%%" % int(v * 100)


func _on_locale_selected(index: int) -> void:
	var locale: String = _locale_selector.get_item_metadata(index)
	Settings.set_locale(locale)
	_rebuild()


func _on_master(v: float) -> void:
	Settings.set_value("master_volume", v)
	Settings.save_settings()


func _on_music(v: float) -> void:
	Settings.set_value("music_volume", v)
	Settings.save_settings()


func _on_sfx(v: float) -> void:
	Settings.set_value("sfx_volume", v)
	Settings.save_settings()


func _on_preset_selected(index: int) -> void:
	Settings.set_value("graphics_preset", Settings.GRAPHICS_PRESETS[index])
	Settings.save_settings()


func _on_fullscreen(checked: bool) -> void:
	Settings.set_value("fullscreen", checked)
	Settings.save_settings()


func _on_ui_scale(v: float) -> void:
	Settings.set_value("ui_scale", v)
	_scale_label.text = _fmt_pct(v)
	Settings.save_settings()


func _on_reset() -> void:
	Settings.reset_defaults()
	_rebuild()


func _on_back() -> void:
	App.goto_main_menu()


func _rebuild() -> void:
	# Rebuild the screen so labels reflect the newly selected language.
	for child in get_children():
		child.queue_free()
	_build()
