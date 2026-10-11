class_name NetProtocol
extends RefCounted
## Versioned, size-bounded message protocol for WAR WW3 LAN multiplayer.
##
## Messages are small JSON objects carried in PackedByteArray UDP packets. The
## decoder never trusts the input: it enforces a hard byte limit, a version
## check, an integer message type, and returns a structured error instead of
## throwing. All free-form strings are sanitised and truncated before use.

const VERSION := 1
## Hard cap for any single packet. Command messages are tiny; state snapshots
## are trimmed to stay well under this bound.
const MAX_MESSAGE_BYTES := 16384
const MAX_STRING_LEN := 96
const MAX_NAME_LEN := 24
const MAX_ID_LEN := 64

## Message types.
enum Msg {
	HELLO = 1,     ## client -> server: nickname
	WELCOME = 2,   ## server -> client: assigned peer id + faction + lobby
	LOBBY = 3,     ## server -> clients: lobby snapshot
	READY = 4,     ## client -> server: ready toggle
	START = 5,     ## server -> clients: match started
	COMMAND = 6,   ## client -> server: player command
	RESULT = 7,    ## server -> clients: command result
	STATE = 8,     ## server -> clients: synchronised state delta
	PING = 9,      ## either way: keepalive
	ERROR = 10,    ## server -> client: rejection reason
	BYE = 11,      ## any -> any: leaving
}


## Build an outgoing message of the given type with optional fields.
static func make(type: int, fields: Dictionary = {}) -> Dictionary:
	var msg := fields.duplicate(true)
	msg["type"] = type
	return msg


static func encode(msg: Dictionary) -> PackedByteArray:
	if typeof(msg) != TYPE_DICTIONARY or not msg.has("type"):
		return PackedByteArray()
	var payload := msg.duplicate(true)
	payload["v"] = VERSION
	var bytes := JSON.stringify(payload).to_utf8_buffer()
	if bytes.size() > MAX_MESSAGE_BYTES:
		return PackedByteArray()
	return bytes


## Decode and validate an incoming packet.
## Returns {ok: true, msg: Dictionary} or {ok: false, error: String}.
static func decode(bytes: PackedByteArray) -> Dictionary:
	if bytes.size() == 0:
		return _err("empty")
	if bytes.size() > MAX_MESSAGE_BYTES:
		return _err("too_large")
	var text := bytes.get_string_from_utf8()
	var json := JSON.new()
	if json.parse(text) != OK:
		return _err("malformed")
	var data = json.data
	if typeof(data) != TYPE_DICTIONARY:
		return _err("not_object")
	if int(data.get("v", -1)) != VERSION:
		return _err("version")
	var t = data.get("type", null)
	if typeof(t) != TYPE_INT and typeof(t) != TYPE_FLOAT:
		return _err("no_type")
	var known := false
	for value in Msg.values():
		if int(t) == value:
			known = true
			break
	if not known:
		return _err("unknown_type")
	return {"ok": true, "msg": data}


static func type_of(msg: Dictionary) -> int:
	return int(msg.get("type", 0))


## Strip control characters and truncate. Used on every string received from a
## peer before it reaches UI, logs, or game logic.
static func sanitize_string(value, max_len: int = MAX_STRING_LEN) -> String:
	var s := str(value)
	var out := ""
	for i in s.length():
		var c := s.unicode_at(i)
		if c >= 32 and c != 127:
			out += String.chr(c)
		if out.length() >= max_len:
			break
	return out


static func sanitize_name(value) -> String:
	var s := sanitize_string(value, MAX_NAME_LEN).strip_edges()
	if s == "":
		s = "Commander"
	return s


## Safe integer coercion: rejects non-numeric/overflowing values.
static func sanitize_int(value, default: int = 0) -> int:
	var t := typeof(value)
	if t == TYPE_INT:
		return value
	if t == TYPE_FLOAT and is_finite(value):
		return int(value)
	return default


static func _err(reason: String) -> Dictionary:
	return {"ok": false, "error": reason}
