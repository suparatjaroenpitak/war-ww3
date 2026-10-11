class_name StrategicScreen
extends Control
## Main campaign screen: strategic map, faction resources, territory actions,
## event log, turn controls, and the optional real-time simulation clock.

var state: GameState = null

var _faction_label: Label
var _turn_label: Label
var _resources_label: Label
var _day_label: Label
var _income_label: Label

var _map: WorldMapView
var _terr_name: Label
var _terr_owner: Label
var _terr_terrain: Label
var _terr_stats: Label
var _terr_actions_box: VBoxContainer
var _recruit_btn: Button
var _develop_btn: Button
var _attack_btn: Button
var _selection_hint: Label

var _log_view: RichTextLabel
var _log_search: LineEdit
var _clock: SimulationClock
var _pause_btn: Button
var _speed_btn: Button

var _attack_mode := false
var _attack_from := ""


func _ready() -> void:
	state = Session.state
	if state == null:
		# No active game (scene opened directly): bounce back to the menu.
		App.goto_main_menu()
		return
	_build()
	_connect_state()
	_refresh_all()


func _build() -> void:
	UI.bg(self, App.color_bg)

	var root := UI.vbox(self, 0)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# --- Top bar -------------------------------------------------------
	var top_panel := UI.panel(root)
	var top := UI.hbox(top_panel, 10)
	top.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_faction_label = UI.label("", 18)
	top.add_child(_faction_label)
	_turn_label = UI.label("", 15)
	top.add_child(_turn_label)
	_resources_label = UI.label("", 15)
	top.add_child(_resources_label)
	_income_label = UI.label("", 13)
	_income_label.modulate = App.color_text_dim
	top.add_child(_income_label)
	_day_label = UI.label("", 13)
	_day_label.modulate = App.color_text_dim
	top.add_child(_day_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)

	_pause_btn = UI.button(tr("GAME_PAUSE"))
	_pause_btn.pressed.connect(_on_pause)
	top.add_child(_pause_btn)
	_speed_btn = UI.button("1x")
	_speed_btn.pressed.connect(_on_speed)
	top.add_child(_speed_btn)

	var end_turn_btn := UI.button(tr("GAME_END_TURN"))
	end_turn_btn.pressed.connect(_on_end_turn)
	top.add_child(end_turn_btn)
	var save_btn := UI.button(tr("GAME_SAVE"))
	save_btn.pressed.connect(_on_save)
	top.add_child(save_btn)
	var menu_btn := UI.button(tr("GAME_MAIN_MENU"))
	menu_btn.pressed.connect(_on_main_menu)
	top.add_child(menu_btn)

	# --- Middle: map + right panel -------------------------------------
	var middle := UI.hbox(root, 8)
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL

	_map = WorldMapView.new()
	_map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_map.territory_selected.connect(_on_territory_selected)
	middle.add_child(_map)

	var side := UI.panel(middle)
	side.custom_minimum_size = Vector2(320, 0)
	var side_box := UI.vbox(side, 8)

	_selection_hint = UI.label(tr("GAME_NO_SELECTION"), 13)
	_selection_hint.modulate = App.color_text_dim
	_selection_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side_box.add_child(_selection_hint)

	_terr_name = UI.label("", 20)
	side_box.add_child(_terr_name)
	_terr_owner = UI.label("", 14)
	side_box.add_child(_terr_owner)
	_terr_terrain = UI.label("", 14)
	side_box.add_child(_terr_terrain)
	_terr_stats = UI.label("", 14)
	_terr_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side_box.add_child(_terr_stats)

	_terr_actions_box = UI.vbox(side_box, 6)
	_recruit_btn = UI.button(tr("GAME_RECRUIT"))
	_recruit_btn.pressed.connect(_on_recruit)
	_terr_actions_box.add_child(_recruit_btn)
	_develop_btn = UI.button(tr("GAME_DEVELOP"))
	_develop_btn.pressed.connect(_on_develop)
	_terr_actions_box.add_child(_develop_btn)
	_attack_btn = UI.button(tr("GAME_ATTACK"))
	_attack_btn.pressed.connect(_on_attack)
	_terr_actions_box.add_child(_attack_btn)
	side_box.add_child(_terr_actions_box)

	# --- Bottom: event log ---------------------------------------------
	var log_panel := UI.panel(root)
	log_panel.custom_minimum_size = Vector2(0, 150)
	var log_box := UI.vbox(log_panel, 4)
	var log_title := UI.label(tr("GAME_EVENT_LOG"), 14)
	log_title.modulate = App.color_text_dim
	log_box.add_child(log_title)
	_log_search = LineEdit.new()
	_log_search.placeholder_text = tr("GAME_EVENT_LOG")
	_log_search.text_changed.connect(_on_log_search)
	log_box.add_child(_log_search)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_box.add_child(scroll)
	_log_view = RichTextLabel.new()
	_log_view.scroll_following = true
	_log_view.bbcode_enabled = true
	_log_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_log_view)

	# --- Simulation clock ----------------------------------------------
	_clock = SimulationClock.new()
	_clock.tick.connect(_on_clock_tick)
	add_child(_clock)


func _connect_state() -> void:
	state.state_changed.connect(_on_state_changed)
	state.turn_changed.connect(_on_turn_changed)
	state.game_ended.connect(_on_game_ended)
	state.log.entry_added.connect(_on_entry_added)
	_map.set_state(state)
	_rebuild_log()


# --------------------------------------------------------------------------
# Refresh helpers
# --------------------------------------------------------------------------

func _refresh_all() -> void:
	_refresh_top_bar()
	_refresh_side_panel()
	_map.refresh()


func _refresh_top_bar() -> void:
	var f: Faction = state.faction(state.human_faction_id)
	if f == null:
		return
	_faction_label.text = f.display_name()
	_faction_label.modulate = f.color.lightened(0.25)
	_turn_label.text = tr("GAME_TURN") % state.turn_number

	var owned := state.territories_owned_by(f.id)
	var income := Economy.gross_income(owned)
	var divisions := 0
	for t in owned:
		divisions += t.divisions
	_upkeep_label_refresh(f, income, divisions, owned.size())

	if not state.is_human_turn():
		var cur: Faction = state.faction(state.current_faction_id)
		if cur != null:
			_selection_hint.text = tr("MSG_AI_TURN") % [cur.display_name()]
	else:
		_selection_hint.text = tr("MSG_HUMAN_TURN")
	_day_label.text = tr("GAME_DAY") % _clock.day


func _upkeep_label_refresh(f: Faction, income: Dictionary, divisions: int, territories_count: int) -> void:
	var upkeep := Economy.upkeep(divisions)
	_resources_label.text = "%s %d | %s %d | %s %d | %s %d" % [
		tr("GAME_CREDITS"), f.credits,
		tr("GAME_MANPOWER"), f.manpower,
		tr("GAME_DIVISIONS"), divisions,
		tr("GAME_TERRITORIES"), territories_count,
	]
	_income_label.text = "%s +%d | %s -%d | %s +%d" % [
		tr("GAME_INCOME"), income["credits"],
		tr("GAME_UPKEEP"), upkeep,
		tr("GAME_MANPOWER"), income["manpower"],
	]


func _refresh_side_panel() -> void:
	var id := _map.selected_id
	if id == "":
		_terr_name.text = ""
		_terr_owner.text = ""
		_terr_terrain.text = ""
		_terr_stats.text = ""
		_terr_actions_box.visible = false
		_attack_mode = false
		return
	var t: Territory = state.territory(id)
	if t == null:
		return
	_terr_name.text = tr(t.name_key)
	var owner_name := tr("GAME_UNOWNED")
	var owner_color := App.color_text_dim
	if t.owner != "" and state.factions.has(t.owner):
		var of: Faction = state.factions[t.owner]
		owner_name = of.display_name()
		owner_color = of.color.lightened(0.25)
	_terr_owner.text = "%s: %s" % [tr("GAME_OWNER"), owner_name]
	_terr_owner.modulate = owner_color
	_terr_terrain.text = "%s: %s (+%d%%)" % [
		tr("GAME_TERRAIN"), tr(t.terrain_key()),
		int((t.defense_multiplier() - 1.0) * 100.0),
	]
	var neighbors_text := ""
	for nb in t.neighbors:
		neighbors_text += tr(state.territory(nb).name_key) + ", "
	neighbors_text = neighbors_text.trim_suffix(", ")
	_terr_stats.text = "%s %d\n%s %d\n%s %d\n%s %d\n%s: %s" % [
		tr("GAME_POPULATION"), t.base_population,
		tr("GAME_DIVISIONS"), t.divisions,
		tr("GAME_CREDITS"), t.credits_yield(),
		tr("GAME_DEVELOPMENT"), t.development,
		tr("GAME_ADJACENT"), neighbors_text,
	]
	_terr_actions_box.visible = true
	_recruit_btn.disabled = not (t.owner == state.human_faction_id and state.is_human_turn())
	_develop_btn.disabled = _recruit_btn.disabled
	_attack_btn.disabled = t.owner != state.human_faction_id or t.divisions <= 0 or not state.is_human_turn()
	_attack_btn.text = tr("GAME_ATTACK") if not _attack_mode else tr("GAME_SELECT_TARGET")


# --------------------------------------------------------------------------
# Input handlers
# --------------------------------------------------------------------------

func _on_territory_selected(id: String) -> void:
	if _attack_mode:
		var from := _attack_from
		var result: Dictionary = state.attack(from, id)
		_attack_mode = false
		if result.get("ok", false):
			if result.get("captured", false):
				_show_toast(tr("MSG_TERRITORY_CAPTURED") % [tr(state.territory(id).name_key)])
			else:
				_show_toast(tr("MSG_ATTACK_FAILED"))
		else:
			_show_toast(tr(result.get("error", "MSG_CANNOT_ATTACK")))
		_refresh_all()
		return
	_refresh_side_panel()


func _on_recruit() -> void:
	var id := _map.selected_id
	if id == "":
		return
	var result: Dictionary = state.recruit(id)
	if not result.get("ok", false):
		_show_toast(tr(result.get("error", "MSG_NOT_ENOUGH_CREDITS")))
	_refresh_all()


func _on_develop() -> void:
	var id := _map.selected_id
	if id == "":
		return
	var result: Dictionary = state.develop(id)
	if not result.get("ok", false):
		_show_toast(tr(result.get("error", "MSG_NOT_ENOUGH_CREDITS")))
	_refresh_all()


func _on_attack() -> void:
	var id := _map.selected_id
	if id == "":
		return
	_attack_mode = true
	_attack_from = id
	_selection_hint.text = tr("GAME_SELECT_TARGET")
	_attack_btn.text = tr("GAME_SELECT_TARGET")


func _on_end_turn() -> void:
	state.end_turn()
	_refresh_all()


func _on_save() -> void:
	var result := Session.save_to_slot(0)
	_show_toast(tr("MSG_SAVE_SUCCESS") if result.get("ok", false) else tr("MSG_SAVE_FAILED"))


func _on_main_menu() -> void:
	App.goto_main_menu()


func _on_pause() -> void:
	_clock.toggle_pause()
	_pause_btn.text = tr("GAME_PAUSE") if not _clock.paused else tr("GAME_RESUME")


func _on_speed() -> void:
	var speeds := [1.0, 2.0, 4.0]
	var idx := speeds.find(_clock.speed)
	_clock.set_speed(speeds[(idx + 1) % speeds.size()])
	_speed_btn.text = "%dx" % int(_clock.speed)


func _on_clock_tick(day: int) -> void:
	_day_label.text = tr("GAME_DAY") % day


func _on_state_changed() -> void:
	_refresh_top_bar()
	_refresh_side_panel()
	_map.refresh()


func _on_turn_changed(_turn: int) -> void:
	_refresh_all()


func _on_game_ended(winner_id: String) -> void:
	var text := tr("MSG_DEFEAT")
	if winner_id == state.human_faction_id:
		text = tr("MSG_VICTORY")
	var d := AcceptDialog.new()
	d.title = tr("APP_TITLE")
	d.dialog_text = text
	d.ok_button_text = tr("COMMON_OK")
	d.confirmed.connect(_on_game_over_confirmed)
	add_child(d)
	d.popup_centered()


func _on_game_over_confirmed() -> void:
	Session.clear_state()
	App.goto_main_menu()


# --------------------------------------------------------------------------
# Event log
# --------------------------------------------------------------------------

func _rebuild_log() -> void:
	_log_view.clear()
	for e in state.log.entries():
		_append_log_entry(e)


func _on_entry_added(entry: Dictionary) -> void:
	_append_log_entry(entry)


func _append_log_entry(entry: Dictionary) -> void:
	var turn: int = entry.get("turn", -1)
	var args: Array = entry.get("args", [])
	var resolved: Array = []
	for a in args:
		if typeof(a) == TYPE_STRING and (a.begins_with("TERR_") or a.begins_with("FACTION_")):
			resolved.append(tr(a))
		else:
			resolved.append(a)
	var text := tr(entry.get("key", "")) % resolved
	var color := "#9fb0c8"
	if entry.get("key", "").contains("CAPTURED"):
		color = "#4aa36a"
	elif entry.get("key", "").contains("FAILED") or entry.get("key", "").contains("LOST") or entry.get("key", "").contains("BANKRUPT"):
		color = "#d0553f"
	_log_view.append_text("[color=#8a94a6][%d][/color] [color=%s]%s[/color]\n" % [turn, color, text])


func _on_log_search(term: String) -> void:
	_log_view.clear()
	for e in state.log.search(term):
		_append_log_entry(e)


# --------------------------------------------------------------------------
# Toasts
# --------------------------------------------------------------------------

func _show_toast(message: String) -> void:
	_selection_hint.text = message
	_selection_hint.modulate = App.color_accent
