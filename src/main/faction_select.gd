extends Control
## Faction selection screen. The player picks one of the major factions before
## starting a new campaign.

var _selected := ""
var _desc_label: Label
var _start_button: Button
var _buttons: Dictionary = {}


func _ready() -> void:
	_build()


func _build() -> void:
	UI.bg(self, App.color_bg)
	var center := UI.center(self)
	var panel := UI.panel(center)
	panel.custom_minimum_size = Vector2(720, 0)
	var box := UI.vbox(panel, 10)

	UI.title(box, tr("FACTION_SELECT_TITLE"), 30)
	var hint := UI.label(tr("FACTION_SELECT_HINT"), 14)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.modulate = App.color_text_dim
	box.add_child(hint)

	UI.spacer(box, 6)

	var list := UI.vbox(box, 8)
	var world := WorldData.load_default()
	if world == null:
		box.add_child(UI.label("Failed to load world data"))
		return
	for fid in world.factions:
		var f: Faction = world.factions[fid]
		if f.passive:
			continue  # neutral/independent is not player-selectable
		var btn := _faction_button(f)
		_buttons[fid] = btn
		list.add_child(btn)
	box.add_child(list)

	UI.spacer(box, 6)
	_desc_label = UI.label("", 14)
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc_label.custom_minimum_size = Vector2(0, 60)
	box.add_child(_desc_label)

	var actions := UI.hbox(box, 8)
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	var back := UI.button(tr("FACTION_SELECT_BACK"))
	back.pressed.connect(_on_back)
	actions.add_child(back)
	_start_button = UI.button(tr("FACTION_SELECT_START"))
	_start_button.disabled = true
	_start_button.pressed.connect(_on_start)
	actions.add_child(_start_button)
	box.add_child(actions)

	# Preselect the first faction.
	if _buttons.size() > 0:
		_select(_buttons.keys()[0])


func _faction_button(f: Faction) -> Button:
	var btn := UI.button(tr(f.name_key))
	btn.toggle_mode = true
	btn.custom_minimum_size = Vector2(0, 44)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.modulate = f.color.lightened(0.2)
	btn.pressed.connect(_select.bind(f.id))
	return btn


func _select(faction_id: String) -> void:
	_selected = faction_id
	_start_button.disabled = false
	for fid in _buttons:
		_buttons[fid].button_pressed = (fid == faction_id)
	var world := WorldData.load_default()
	if world != null and world.factions.has(faction_id):
		var f: Faction = world.factions[faction_id]
		_desc_label.text = tr(f.description_key)
		_desc_label.modulate = App.color_text_dim


func _on_start() -> void:
	if _selected == "":
		return
	var state := Session.start_new_game(_selected, "standard", 0)
	if state == null:
		return
	App.goto_scene("res://src/strategic/strategic_screen.tscn")


func _on_back() -> void:
	App.goto_main_menu()
