class_name WorldMapView
extends Control
## Renders the strategic map by drawing territory polygons and handles
## click-based territory selection. Uses lightweight canvas drawing (no
## per-territory scene nodes) for efficiency.

signal territory_selected(territory_id: String)

var state: GameState = null
var selected_id: String = ""

var _scale := 1.0
var _offset := Vector2.ZERO

const MARGIN := 24.0
const NEUTRAL_COLOR := Color("#2a3550")


func set_state(value: GameState) -> void:
	state = value
	selected_id = ""
	queue_redraw()


func select_territory(id: String) -> void:
	selected_id = id
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_transform()
		queue_redraw()


func _update_transform() -> void:
	if state == null or state.world == null:
		return
	var ws := state.world.size
	var avail := size - Vector2(MARGIN * 2, MARGIN * 2)
	if avail.x <= 0 or avail.y <= 0:
		return
	_scale = min(avail.x / ws.x, avail.y / ws.y)
	var scaled := ws * _scale
	_offset = (size - scaled) * 0.5


func _to_local(world_pos: Vector2) -> Vector2:
	return world_pos * _scale + _offset


func _draw() -> void:
	if state == null or state.world == null:
		return
	_update_transform()
	# Background water/void.
	draw_rect(Rect2(Vector2.ZERO, size), App.color_bg)

	for tid in state.order:
		var t: Territory = state.territories[tid]
		var fill := _owner_color(t.owner)
		if selected_id == tid:
			fill = fill.lightened(0.25)
		var pts := PackedVector2Array()
		for p in t.polygon:
			pts.append(_to_local(p))
		draw_colored_polygon(pts, fill)
		# Border.
		var border := App.color_border
		var width := 1.0
		if selected_id == tid:
			border = Color.WHITE
			width = 2.5
		draw_polyline(PackedVector2Array(pts + PackedVector2Array([pts[0]])), border, width, true)
		# Name label.
		var font := ThemeDB.fallback_font
		var pos := _to_local(t.centroid)
		draw_string(font, pos + Vector2(0, 5), tr(t.name_key), HORIZONTAL_ALIGNMENT_CENTER, -1, 14, App.color_text)


func _owner_color(owner: String) -> Color:
	if owner == "":
		return NEUTRAL_COLOR
	if state.factions.has(owner):
		var f: Faction = state.factions[owner]
		return f.color.darkened(0.35)
	return NEUTRAL_COLOR


func _gui_input(event: InputEvent) -> void:
	if state == null:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			var world_pos: Vector2 = (mb.position - _offset) / _scale
			var found := _territory_at(world_pos)
			if found != "":
				selected_id = found
				queue_redraw()
				territory_selected.emit(found)


func _territory_at(world_pos: Vector2) -> String:
	for tid in state.order:
		var t: Territory = state.territories[tid]
		if Geometry2D.is_point_in_polygon(world_pos, t.polygon):
			return tid
	return ""


func refresh() -> void:
	queue_redraw()
