extends Control
## Placeholder for the Phase 3 tactical simulation screen.
## The strategic layer is playable now; tactical battles are resolved
## abstractly in GameState.attack() until this screen is implemented.


func _ready() -> void:
	UI.bg(self, App.color_bg)
	var center := UI.center(self)
	var panel := UI.panel(center)
	panel.custom_minimum_size = Vector2(480, 0)
	var box := UI.vbox(panel, 10)
	UI.title(box, tr("TACTICAL_TITLE"), 28)
	var note := UI.label(tr("TACTICAL_PLACEHOLDER"), 14)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(420, 0)
	note.modulate = App.color_text_dim
	box.add_child(note)
	UI.spacer(box, 8)
	var back := UI.button(tr("GAME_MAIN_MENU"))
	back.pressed.connect(_on_back)
	box.add_child(back)


func _on_back() -> void:
	App.goto_main_menu()
