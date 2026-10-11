class_name EventLog
extends RefCounted
## In-memory event log for the campaign. Entries are keyed dictionaries so the
## UI can translate them. The full log lives in the GameState and is serialized
## with it.

const MAX_ENTRIES := 500

var _entries: Array = []  # Array[Dictionary]

signal entry_added(entry: Dictionary)


func add(key: String, args: Array = []) -> void:
	var entry := {"turn": -1, "key": key, "args": args}
	_entries.append(entry)
	if _entries.size() > MAX_ENTRIES:
		_entries.pop_front()
	entry_added.emit(entry)


func add_turn(turn: int, key: String, args: Array = []) -> void:
	var entry := {"turn": turn, "key": key, "args": args}
	_entries.append(entry)
	if _entries.size() > MAX_ENTRIES:
		_entries.pop_front()
	entry_added.emit(entry)


func entries() -> Array:
	return _entries


func search(term: String) -> Array:
	## Search the log by matching the localized text of each entry, or the raw
	## event key (so searching works in any locale).
	var results: Array = []
	var t := term.strip_edges().to_lower()
	if t.is_empty():
		return _entries.duplicate()
	for e in _entries:
		var text := _localize(e).to_lower()
		var key := str(e.get("key", "")).to_lower()
		if text.contains(t) or key.contains(t):
			results.append(e)
	return results


func _localize(entry: Dictionary) -> String:
	var key: String = entry.get("key", "")
	var args: Array = entry.get("args", [])
	# Translate known placeholders, otherwise pass through.
	var resolved: Array = []
	for a in args:
		if typeof(a) == TYPE_STRING and a.begins_with("TERR_"):
			resolved.append(tr(a))
		elif typeof(a) == TYPE_STRING and a.begins_with("FACTION_"):
			resolved.append(tr(a))
		else:
			resolved.append(a)
	return tr(key) % resolved


func clear() -> void:
	_entries.clear()


func to_dict() -> Array:
	var out := []
	for e in _entries:
		out.append({"turn": e.get("turn", -1), "key": e.get("key", ""), "args": e.get("args", [])})
	return out


static func from_dict(list: Array) -> EventLog:
	var log := EventLog.new()
	for item in list:
		if typeof(item) == TYPE_DICTIONARY:
			log._entries.append({
				"turn": int(item.get("turn", -1)),
				"key": str(item.get("key", "")),
				"args": item.get("args", []),
			})
	return log
