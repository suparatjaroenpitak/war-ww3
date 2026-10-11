class_name TacticalFieldView
extends Control
## Lightweight canvas renderer for a TacticalBattle. Draws objectives and unit
## groups directly with draw_* calls (no per-entity scene nodes), which keeps a
## battle with hundreds of abstract units cheap.

var battle: TacticalBattle = null

var _scale := 1.0
var _offset := Vector2.ZERO
const MARGIN := 12.0


func set_battle(value: TacticalBattle) -> void:
	battle = value
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_transform()
		queue_redraw()


func _update_transform() -> void:
	if battle == null:
		return
	_scale = 1.0
	_offset = Vector2.ZERO
	var avail := size - Vector2(MARGIN * 2, MARGIN * 2)
	if avail.x <= 0 or avail.y <= 0:
		return
	_scale = min(avail.x / battle.field_size.x, avail.y / battle.field_size.y)
	_offset = (size - battle.field_size * _scale) * 0.5


func _to_local(p: Vector2) -> Vector2:
	return p * _scale + _offset


func _draw() -> void:
	if battle == null:
		return
	_update_transform()
	draw_rect(Rect2(Vector2.ZERO, size), App.color_bg)
	draw_rect(Rect2(_offset, battle.field_size * _scale), Color("#141d2e"))
	draw_rect(Rect2(_offset, battle.field_size * _scale), App.color_border, false, 1.0)

	# Objectives: coloured disc shows the current holder.
	for o in battle.objectives:
		var pos := _to_local(o["pos"])
		var col: Color = App.color_text_dim
		if o["owner"] == TacticalBattle.SIDE_ATTACKER:
			col = App.color_accent
		elif o["owner"] == TacticalBattle.SIDE_DEFENDER:
			col = App.color_danger
		draw_circle(pos, 16.0, col)
		draw_arc(pos, 16.0, 0.0, TAU, 28, Color.WHITE, 2.0)

	# Unit groups: radius scales with remaining strength.
	for u in battle.units:
		if not u["alive"]:
			continue
		var col: Color = App.color_accent if u["side"] == TacticalBattle.SIDE_ATTACKER else App.color_danger
		var radius := clampf(3.0 + float(u["strength"]) * 0.15, 3.0, 13.0)
		draw_circle(_to_local(u["pos"]), radius, col)


func refresh() -> void:
	queue_redraw()
