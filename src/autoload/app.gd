extends Node
## App autoload. Builds the global visual theme (with Thai-capable font
## fallback), applies user settings, and provides scene navigation helpers.

const MAIN_MENU_SCENE := "res://src/main/main_menu.tscn"
const STRATEGIC_SCENE := "res://src/strategic/strategic_screen.tscn"
const TACTICAL_SCENE := "res://src/tactical/tactical_screen.tscn"

var theme: Theme = null

# Accent palette (original).
var color_bg := Color("#0e141f")
var color_panel := Color("#1b2740")
var color_panel_alt := Color("#222f4d")
var color_border := Color("#3f7fd0")
var color_text := Color("#e8edf5")
var color_text_dim := Color("#9fb0c8")
var color_accent := Color("#3f7fd0")
var color_danger := Color("#d0553f")
var color_success := Color("#4aa36a")


func _ready() -> void:
	_setup_fonts()
	theme = _build_theme()
	get_tree().root.theme = theme
	Settings.locale_changed.connect(_on_locale_changed)


func _setup_fonts() -> void:
	# Prefer a bundled font if the project ships one; otherwise fall back to
	# system fonts. Thai glyphs are covered by the fallback list.
	var font: Font = null
	if ResourceLoader.exists("res://assets/fonts/ui_font.tres"):
		var res = ResourceLoader.load("res://assets/fonts/ui_font.tres")
		if res is Font:
			font = res
	if font == null:
		var sys := SystemFont.new()
		sys.font_names = PackedStringArray(["Noto Sans", "Segoe UI", "Leelawadee UI", "Tahoma", "Arial"])
		font = sys

	var thai := SystemFont.new()
	thai.font_names = PackedStringArray(["Leelawadee UI", "Noto Sans Thai", "Tahoma", "Segoe UI"])
	if font is FontFile:
		font.fallbacks = [thai]
	elif font is SystemFont:
		font.fallbacks = [thai]

	ThemeDB.fallback_font = font
	ThemeDB.fallback_font_size = 16


func _build_theme() -> Theme:
	var t := Theme.new()
	var font := ThemeDB.fallback_font

	t.default_font = font
	t.default_font_size = 16

	# Buttons.
	var btn := StyleBoxFlat.new()
	btn.bg_color = color_panel
	btn.border_color = color_border
	btn.set_border_width_all(1)
	btn.set_corner_radius_all(6)
	btn.content_margin_left = 14
	btn.content_margin_right = 14
	btn.content_margin_top = 8
	btn.content_margin_bottom = 8
	var btn_hover := btn.duplicate()
	btn_hover.bg_color = color_panel_alt
	var btn_pressed := btn.duplicate()
	btn_pressed.bg_color = color_border
	t.set_stylebox("normal", "Button", btn)
	t.set_stylebox("hover", "Button", btn_hover)
	t.set_stylebox("pressed", "Button", btn_pressed)
	t.set_stylebox("focus", "Button", btn_hover)
	t.set_color("font_color", "Button", color_text)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color.WHITE)

	# Panels.
	var panel := StyleBoxFlat.new()
	panel.bg_color = color_panel
	panel.border_color = color_border
	panel.set_border_width_all(1)
	panel.set_corner_radius_all(8)
	panel.content_margin_left = 12
	panel.content_margin_right = 12
	panel.content_margin_top = 12
	panel.content_margin_bottom = 12
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("panel", "Panel", panel)

	# Labels.
	t.set_color("font_color", "Label", color_text)

	# LineEdit.
	var le := StyleBoxFlat.new()
	le.bg_color = color_bg
	le.border_color = color_border
	le.set_border_width_all(1)
	le.set_corner_radius_all(4)
	le.content_margin_left = 8
	le.content_margin_right = 8
	le.content_margin_top = 6
	le.content_margin_bottom = 6
	t.set_stylebox("normal", "LineEdit", le)
	t.set_stylebox("focus", "LineEdit", le)
	t.set_color("font_color", "LineEdit", color_text)

	# HSlider.
	var grabber := StyleBoxFlat.new()
	grabber.bg_color = color_accent
	grabber.set_corner_radius_all(8)
	t.set_stylebox("grabber_area", "HSlider", grabber)
	var slider := StyleBoxFlat.new()
	slider.bg_color = color_panel_alt
	slider.set_corner_radius_all(4)
	slider.content_margin_top = 6
	slider.content_margin_bottom = 6
	t.set_stylebox("slider", "HSlider", slider)

	return t


func _on_locale_changed(_locale: String) -> void:
	pass


func goto_scene(path: String) -> void:
	get_tree().change_scene_to_file(path)


func goto_main_menu() -> void:
	goto_scene(MAIN_MENU_SCENE)


func goto_strategic() -> void:
	goto_scene(STRATEGIC_SCENE)


func goto_tactical() -> void:
	goto_scene(TACTICAL_SCENE)
