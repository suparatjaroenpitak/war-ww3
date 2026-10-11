extends Control
## Tactical battle screen. Runs a TacticalBattle either from a pending campaign
## engagement (Session.pending_battle) or as a standalone demo, with pause,
## speed control, a configurable entity count, and a result summary.
##
## When the battle comes from the campaign, the outcome is fed back into the
## authoritative GameState through GameState.apply_tactical_result().

const DEMO_ATTACK_STRENGTH := 48
const DEMO_DEFENSE_STRENGTH := 40
const TICKS_PER_SECOND := 3.0
const UNITS_MIN := 4
const UNITS_MAX := 64

var battle: TacticalBattle = null
var _pending: Dictionary = {}
var _running := false
var _speed := 1.0
var _accum := 0.0
var _applied := false

var _field: TacticalFieldView
var _tick_label: Label
var _attacker_label: Label
var _defender_label: Label
var _obj_label: Label
var _units_label: Label
var _result_label: Label
var _pause_btn: Button
var _return_btn: Button
var _units_spin: SpinBox


func _ready() -> void:
	_pending = Session.pending_battle.duplicate()
	_build()
	_start_battle(TacticalBattle.DEFAULT_UNITS_PER_SIDE)


func _build() -> void:
	UI.bg(self, App.color_bg)
	var root := UI.vbox(self, 6)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	UI.title(root, tr("TACTICAL_TITLE"), 26)

	# Top status bar.
	var top := UI.panel(root)
	var top_box := UI.hbox(top, 14)
	_tick_label = UI.label("", 14)
	_attacker_label = UI.label("", 14)
	_attacker_label.modulate = App.color_accent
	_defender_label = UI.label("", 14)
	_defender_label.modulate = App.color_danger
	_obj_label = UI.label("", 14)
	_units_label = UI.label("", 14)
	for l in [_tick_label, _attacker_label, _defender_label, _obj_label, _units_label]:
		top_box.add_child(l)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_box.add_child(spacer)

	_units_spin = SpinBox.new()
	_units_spin.min_value = UNITS_MIN
	_units_spin.max_value = UNITS_MAX
	_units_spin.step = 1
	_units_spin.value = TacticalBattle.DEFAULT_UNITS_PER_SIDE
	_units_spin.value_changed.connect(_on_units_changed)
	if not _pending.is_empty():
		_units_spin.visible = false
	top_box.add_child(_units_spin)

	# Field.
	_field = TacticalFieldView.new()
	_field.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(_field)

	# Result line.
	_result_label = UI.label("", 16)
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_result_label)

	# Controls.
	var controls := UI.hbox(root, 8)
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	_pause_btn = UI.button(tr("GAME_PAUSE"))
	_pause_btn.pressed.connect(_on_pause)
	controls.add_child(_pause_btn)
	var speed_btn := UI.button("1x")
	speed_btn.pressed.connect(_on_speed.bind(speed_btn))
	controls.add_child(speed_btn)
	var restart := UI.button(tr("TACTICAL_RESTART"))
	restart.pressed.connect(_on_restart)
	controls.add_child(restart)
	_return_btn = UI.button(tr("TACTICAL_RETURN"))
	_return_btn.pressed.connect(_on_return)
	controls.add_child(_return_btn)


func _start_battle(units_per_side: int) -> void:
	battle = TacticalBattle.new()
	var seed := 1234
	var atk := DEMO_ATTACK_STRENGTH
	var dfn := DEMO_DEFENSE_STRENGTH
	var terrain := 1.0
	if not _pending.is_empty():
		atk = maxi(1, int(_pending.get("attacker_divisions", 1)) * 10)
		dfn = maxi(1, int(_pending.get("defender_divisions", 1)) * 10)
		terrain = float(_pending.get("terrain_defense", 1.0))
		seed = int(_pending.get("seed", 1234))
	battle.setup(atk, dfn, terrain, seed, units_per_side)
	_field.set_battle(battle)
	_applied = false
	_running = true
	_accum = 0.0
	_result_label.text = ""
	_pause_btn.disabled = false
	_pause_btn.text = tr("GAME_PAUSE")
	_return_btn.text = tr("TACTICAL_RETURN")
	_refresh_hud()


func _process(delta: float) -> void:
	if battle == null or not _running or battle.over:
		return
	_accum += delta * TICKS_PER_SECOND * _speed
	while _accum >= 1.0 and not battle.over:
		_accum -= 1.0
		battle.step()
	_refresh_hud()
	_field.refresh()
	if battle.over:
		_on_finished()


func _refresh_hud() -> void:
	if battle == null:
		return
	var s := battle.summary()
	_tick_label.text = "%s %d" % [tr("TACTICAL_TICK"), s["tick"]]
	_attacker_label.text = "%s %d" % [tr("TACTICAL_ATTACKER_STRENGTH"), int(battle.strength(TacticalBattle.SIDE_ATTACKER))]
	_defender_label.text = "%s %d" % [tr("TACTICAL_DEFENDER_STRENGTH"), int(battle.strength(TacticalBattle.SIDE_DEFENDER))]
	_obj_label.text = "%s %d/%d" % [tr("TACTICAL_OBJECTIVES"), s["attacker_objectives"], s["objective_count"]]
	_units_label.text = "%s %d/%d" % [tr("TACTICAL_UNITS"), s["attacker_units"], s["defender_units"]]


func _on_finished() -> void:
	_running = false
	_pause_btn.disabled = true
	if battle.winner == TacticalBattle.SIDE_ATTACKER:
		_result_label.text = tr("TACTICAL_RESULT_ATTACKER_WINS")
		_result_label.modulate = App.color_success
	else:
		_result_label.text = tr("TACTICAL_RESULT_DEFENDER_WINS")
		_result_label.modulate = App.color_danger
	if not _pending.is_empty():
		_apply_campaign_result()
		_return_btn.text = tr("TACTICAL_RETURN")


## Feed the simulated outcome back into the authoritative campaign state exactly
## once. GameState re-validates the attack, so a stale/illegal battle is refused.
func _apply_campaign_result() -> void:
	if _applied or battle == null or _pending.is_empty():
		return
	_applied = true
	var st: GameState = Session.state
	if st == null:
		return
	var from_id := str(_pending.get("from_id", ""))
	var to_id := str(_pending.get("to_id", ""))
	var a_divs := int(_pending.get("attacker_divisions", 0))
	var d_divs := int(_pending.get("defender_divisions", 0))
	var captured := battle.winner == TacticalBattle.SIDE_ATTACKER
	var a_remaining := int(round(float(a_divs) * battle.survival_ratio(TacticalBattle.SIDE_ATTACKER)))
	var d_remaining := int(round(float(d_divs) * battle.survival_ratio(TacticalBattle.SIDE_DEFENDER)))
	if captured:
		a_remaining = clampi(a_remaining, 1, maxi(1, a_divs))
	var a_losses := clampi(a_divs - a_remaining, 0, a_divs)
	var d_losses := clampi(d_divs - d_remaining, 0, d_divs)
	st.apply_tactical_result(from_id, to_id, captured, a_losses, d_losses, a_remaining)
	Session.pending_battle = {}


func _on_pause() -> void:
	if battle == null or battle.over:
		return
	_running = not _running
	_pause_btn.text = tr("GAME_PAUSE") if _running else tr("TACTICAL_RESUME")


func _on_speed(button: Button) -> void:
	var speeds := [1.0, 2.0, 4.0]
	var idx := speeds.find(_speed)
	_speed = speeds[(idx + 1) % speeds.size()]
	button.text = "%dx" % int(_speed)


func _on_restart() -> void:
	_start_battle(int(_units_spin.value))


func _on_units_changed(value: float) -> void:
	if _pending.is_empty():
		_start_battle(int(value))


func _on_return() -> void:
	if _pending.is_empty() and _applied:
		App.goto_main_menu()
		return
	# If we came from a campaign, go back to it; otherwise to the main menu.
	if Session.state != null and Session.pending_battle.is_empty() and _was_campaign():
		App.goto_strategic()
	else:
		App.goto_main_menu()


func _was_campaign() -> bool:
	# A battle started from the campaign clears _pending after applying, so we
	# track that we applied a result this session.
	return _applied
