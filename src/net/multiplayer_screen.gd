extends Control
## LAN multiplayer lobby. Host or join a match, pick a faction, mark ready, and
## start when everyone is ready. The heavy lifting (authoritative commands,
## validation, state sync) lives in the Net autoload and GameServer.

var _nickname_edit: LineEdit
var _address_edit: LineEdit
var _port_spin: SpinBox
var _faction_select: OptionButton
var _status_label: Label
var _lobby_view: RichTextLabel
var _host_btn: Button
var _join_btn: Button
var _ready_btn: Button
var _start_btn: Button
var _back_btn: Button

var _is_ready := false
var _navigated := false


func _ready() -> void:
	_build()
	Net.lobby_changed.connect(_on_lobby_changed)
	Net.match_started.connect(_on_match_started)
	Net.state_updated.connect(_on_state_updated)
	Net.connection_failed.connect(_on_connection_failed)
	Net.disconnected.connect(_on_disconnected)
	_set_status(tr("MULTIPLAYER_NOTICE"))


func _build() -> void:
	UI.bg(self, App.color_bg)
	var center := UI.center(self)
	var panel := UI.panel(center)
	panel.custom_minimum_size = Vector2(640, 0)
	var box := UI.vbox(panel, 8)

	UI.title(box, tr("MULTIPLAYER_TITLE"), 30)

	# Connection fields.
	_nickname_edit = LineEdit.new()
	_nickname_edit.text = Net.nickname
	_nickname_edit.placeholder_text = tr("MULTIPLAYER_NICKNAME")
	box.add_child(_row(tr("MULTIPLAYER_NICKNAME"), _nickname_edit))

	_address_edit = LineEdit.new()
	_address_edit.text = "127.0.0.1"
	_address_edit.placeholder_text = tr("MULTIPLAYER_ADDRESS")
	box.add_child(_row(tr("MULTIPLAYER_ADDRESS"), _address_edit))

	_port_spin = SpinBox.new()
	_port_spin.min_value = 1024
	_port_spin.max_value = 65535
	_port_spin.step = 1
	_port_spin.value = Net.DEFAULT_PORT
	box.add_child(_row(tr("MULTIPLAYER_PORT"), _port_spin))

	_faction_select = OptionButton.new()
	var world := WorldData.load_default()
	if world != null:
		for fid in world.factions:
			_faction_select.add_item(tr(world.factions[fid].name_key), _faction_select.item_count)
			_faction_select.set_item_metadata(_faction_select.item_count - 1, fid)
	box.add_child(_row(tr("MULTIPLAYER_FACTION"), _faction_select))

	# Connection actions.
	var actions := UI.hbox(box, 8)
	_host_btn = UI.button(tr("MULTIPLAYER_HOST"))
	_host_btn.pressed.connect(_on_host)
	actions.add_child(_host_btn)
	_join_btn = UI.button(tr("MULTIPLAYER_JOIN"))
	_join_btn.pressed.connect(_on_join)
	actions.add_child(_join_btn)
	box.add_child(actions)

	_status_label = UI.label("", 14)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.modulate = App.color_accent
	box.add_child(_status_label)

	# Lobby.
	var lobby_title := UI.label(tr("MULTIPLAYER_LOBBY"), 18)
	lobby_title.modulate = App.color_text_dim
	box.add_child(lobby_title)
	_lobby_view = RichTextLabel.new()
	_lobby_view.bbcode_enabled = true
	_lobby_view.custom_minimum_size = Vector2(0, 90)
	box.add_child(_lobby_view)

	var lobby_actions := UI.hbox(box, 8)
	_ready_btn = UI.button(tr("MULTIPLAYER_NOT_READY"))
	_ready_btn.toggle_mode = true
	_ready_btn.pressed.connect(_on_ready)
	_ready_btn.disabled = true
	lobby_actions.add_child(_ready_btn)
	_start_btn = UI.button(tr("MULTIPLAYER_START_MATCH"))
	_start_btn.pressed.connect(_on_start)
	_start_btn.disabled = true
	lobby_actions.add_child(_start_btn)
	box.add_child(lobby_actions)

	UI.spacer(box, 4)
	_back_btn = UI.button(tr("MULTIPLAYER_BACK"))
	_back_btn.pressed.connect(_on_back)
	box.add_child(_back_btn)


func _row(label_text: String, control: Control) -> HBoxContainer:
	var row := UI.hbox(self, 8)
	var l := UI.label(label_text, 14)
	l.custom_minimum_size = Vector2(120, 0)
	row.add_child(l)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	# Detach from `self`; the caller adds the row to the box.
	remove_child(row)
	return row


func _selected_faction() -> String:
	if _faction_select.item_count == 0:
		return ""
	return str(_faction_select.get_item_metadata(_faction_select.selected))


func _set_status(text: String) -> void:
	_status_label.text = text


# --------------------------------------------------------------------------
# Actions
# --------------------------------------------------------------------------

func _on_host() -> void:
	var result := Net.host_game(int(_port_spin.value), _nickname_edit.text, _selected_faction())
	if not result.get("ok", false):
		_set_status(tr(str(result.get("error", "MULTIPLAYER_ERR_CREATE"))))
		return
	_set_status(tr("MULTIPLAYER_HOSTING") % int(_port_spin.value))
	_enter_lobby(true)


func _on_join() -> void:
	var result := Net.join_game(_address_edit.text.strip_edges(), int(_port_spin.value), _nickname_edit.text)
	if not result.get("ok", false):
		_set_status(tr(str(result.get("error", "MULTIPLAYER_ERR_CONNECT"))))
		return
	_set_status(tr("MULTIPLAYER_WAITING_HOST"))
	_enter_lobby(false)


func _enter_lobby(as_host: bool) -> void:
	_host_btn.disabled = true
	_join_btn.disabled = true
	_ready_btn.disabled = false
	_start_btn.visible = as_host
	_update_lobby()


func _on_ready() -> void:
	_is_ready = not _is_ready
	_ready_btn.text = tr("MULTIPLAYER_READY") if _is_ready else tr("MULTIPLAYER_NOT_READY")
	Net.set_ready_state(_is_ready)


func _on_start() -> void:
	var result := Net.host_start_match()
	if not result.get("ok", false):
		_set_status(tr(str(result.get("error", "not_ready"))))


func _on_back() -> void:
	Net.close()
	App.goto_main_menu()


# --------------------------------------------------------------------------
# Net signal handlers
# --------------------------------------------------------------------------

func _on_lobby_changed(players: Array) -> void:
	_update_lobby(players)


func _update_lobby(players: Array = []) -> void:
	if players.is_empty() and Net.server != null:
		players = Net.server.lobby_snapshot()
	_lobby_view.clear()
	if players.is_empty():
		return
	_lobby_view.append_text("%s: %d\n" % [tr("MULTIPLAYER_PLAYERS"), players.size()])
	for p in players:
		var is_me: bool = int(p.get("peer_id", -1)) == Net.peer_id
		var you := tr("MULTIPLAYER_YOU") if is_me else ""
		var state := tr("MULTIPLAYER_READY") if bool(p.get("ready", false)) else tr("MULTIPLAYER_NOT_READY")
		_lobby_view.append_text("%s (%s) — %s %s\n" % [
			NetProtocol.sanitize_name(p.get("name", "")),
			NetProtocol.sanitize_string(p.get("faction_id", ""), 32),
			state,
			you,
		])
	_start_btn.disabled = not (Net.is_host() and Net.server != null and Net.server.all_ready())


func _on_match_started() -> void:
	if Net.is_host():
		_go_strategic()


func _on_state_updated() -> void:
	# Clients navigate once the authoritative state has arrived.
	if not Net.is_host():
		_go_strategic()


func _go_strategic() -> void:
	if _navigated:
		return
	_navigated = true
	App.goto_strategic()


func _on_connection_failed(reason: String) -> void:
	_set_status(tr(str(reason)))


func _on_disconnected(reason: String) -> void:
	_set_status(tr("MULTIPLAYER_LEFT_THE_GAME"))
	Net.close()
	_host_btn.disabled = false
	_join_btn.disabled = false
	_ready_btn.disabled = true
	_start_btn.disabled = true
