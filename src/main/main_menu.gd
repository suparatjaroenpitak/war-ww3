extends Control
## Main menu. The entry point of the game.

func _ready() -> void:
	_build()


func _build() -> void:
	UI.bg(self, App.color_bg)

	var center := UI.center(self)
	var box := UI.vbox(center, 12)
	box.custom_minimum_size = Vector2(420, 0)
	box.alignment = BoxContainer.ALIGNMENT_CENTER

	var logo := TextureRect.new()
	if ResourceLoader.exists("res://icon.svg"):
		logo.texture = load("res://icon.svg")
		logo.custom_minimum_size = Vector2(96, 96)
		logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		logo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		box.add_child(logo)

	UI.title(box, tr("APP_TITLE"), 46)
	var subtitle := UI.label(tr("APP_SUBTITLE"), 15)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.modulate = App.color_text_dim
	box.add_child(subtitle)

	UI.spacer(box, 16)

	box.add_child(_menu_button(tr("MENU_NEW_GAME"), _on_new_game))
	box.add_child(_menu_button(tr("MENU_TUTORIAL"), _on_tutorial))

	var continue_btn := _menu_button(tr("MENU_CONTINUE"), _on_continue)
	continue_btn.disabled = not Session.has_save(0)
	box.add_child(continue_btn)

	box.add_child(_menu_button(tr("MENU_MULTIPLAYER"), _on_multiplayer))
	box.add_child(_menu_button(tr("MENU_SETTINGS"), _on_settings))
	box.add_child(_menu_button(tr("MENU_QUIT"), _on_quit))

	var version := UI.label(tr("APP_VERSION") + " " + ProjectSettings.get_setting("application/config/version", "0.0.0"), 12)
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	version.modulate = App.color_text_dim
	UI.spacer(box, 8)
	box.add_child(version)


func _menu_button(text: String, handler: Callable) -> Button:
	var b := UI.button(text)
	b.custom_minimum_size = Vector2(280, 46)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(handler)
	return b


func _on_new_game() -> void:
	App.goto_scene("res://src/main/faction_select.tscn")


func _on_tutorial() -> void:
	var state := Session.start_new_game("vessaria", "tutorial", 1)
	if state == null:
		return
	App.goto_scene("res://src/strategic/strategic_screen.tscn")


func _on_continue() -> void:
	var result := Session.load_slot(0)
	if result.get("ok", false):
		App.goto_scene("res://src/strategic/strategic_screen.tscn")
	else:
		_show_notice(tr("MSG_NO_SAVE"))


func _on_multiplayer() -> void:
	_show_notice(tr("MULTIPLAYER_COMING_SOON"))


func _on_settings() -> void:
	App.goto_scene("res://src/main/settings_screen.tscn")


func _on_quit() -> void:
	get_tree().quit()


func _show_notice(message: String) -> void:
	var d := AcceptDialog.new()
	d.title = tr("APP_TITLE")
	d.dialog_text = message
	d.ok_button_text = tr("COMMON_OK")
	add_child(d)
	d.popup_centered()
