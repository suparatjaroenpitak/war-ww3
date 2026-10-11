class_name NetValidation
extends RefCounted
## Validation for client-originated commands. The server runs every incoming
## command through here before it is allowed to touch authoritative state, so a
## hostile or buggy client cannot inject unknown command kinds, oversized
## strings, or malformed ids.

const COMMANDS := ["recruit", "develop", "attack", "end_turn"]
const MAX_TERRITORY_ID_LEN := 64


## Returns {ok:true, kind, id, ...} with sanitised fields, or
## {ok:false, error} describing the rejection.
static func validate_command(command) -> Dictionary:
	if typeof(command) != TYPE_DICTIONARY:
		return fail("bad_command")
	var kind := NetProtocol.sanitize_string(command.get("kind", ""), 24)
	if kind not in COMMANDS:
		return fail("unknown_command")
	var id := NetProtocol.sanitize_int(command.get("id", -1), -1)
	if id < 0:
		return fail("bad_command_id")
	match kind:
		"recruit", "develop":
			var tid := NetProtocol.sanitize_string(command.get("territory", ""), MAX_TERRITORY_ID_LEN)
			if tid == "":
				return fail("missing_territory")
			return {"ok": true, "kind": kind, "id": id, "territory": tid}
		"attack":
			var from_id := NetProtocol.sanitize_string(command.get("from", ""), MAX_TERRITORY_ID_LEN)
			var to_id := NetProtocol.sanitize_string(command.get("to", ""), MAX_TERRITORY_ID_LEN)
			if from_id == "" or to_id == "":
				return fail("missing_territory")
			if from_id == to_id:
				return fail("invalid_target")
			return {"ok": true, "kind": kind, "id": id, "from": from_id, "to": to_id}
		"end_turn":
			return {"ok": true, "kind": kind, "id": id}
	return fail("unknown_command")


static func fail(reason: String) -> Dictionary:
	return {"ok": false, "error": reason}
