class_name SimulationClock
extends Node
## Optional real-time clock for time-based events (construction, supply trickle,
## research). The strategic layer is turn-based; this clock is additive and is
## fully pausable with configurable speed.

signal tick(day: int)
signal speed_changed(speed: float)
signal paused_changed(paused: bool)

const BASE_TICKS_PER_SECOND := 1.0

var day: int = 0
var speed: float = 1.0
var paused: bool = false

var _accum := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	if paused or speed <= 0.0:
		return
	_accum += delta * BASE_TICKS_PER_SECOND * speed
	while _accum >= 1.0:
		_accum -= 1.0
		day += 1
		tick.emit(day)


func set_speed(value: float) -> void:
	speed = clampf(value, 0.0, 4.0)
	speed_changed.emit(speed)


func set_paused(value: bool) -> void:
	paused = value
	paused_changed.emit(paused)


func toggle_pause() -> void:
	set_paused(not paused)


func to_dict() -> Dictionary:
	return {"day": day, "speed": speed, "paused": paused}


func from_dict(d: Dictionary) -> void:
	day = int(d.get("day", 0))
	speed = float(d.get("speed", 1.0))
	paused = bool(d.get("paused", false))
