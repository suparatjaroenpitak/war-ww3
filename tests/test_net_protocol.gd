extends "res://tests/test_case.gd"
## Unit tests for NetProtocol: encode/decode round-trip, size limits, malformed
## input rejection, and string sanitisation.


func test_roundtrip_preserves_fields() -> void:
	var msg := NetProtocol.make(NetProtocol.Msg.COMMAND, {"kind": "recruit", "territory": "vess_capital"})
	var bytes := NetProtocol.encode(msg)
	assert_gt(bytes.size(), 0, "message encodes")
	var decoded := NetProtocol.decode(bytes)
	assert_true(decoded.get("ok", false), "message decodes")
	assert_eq(NetProtocol.type_of(decoded["msg"]), NetProtocol.Msg.COMMAND, "type preserved")
	assert_eq(decoded["msg"]["kind"], "recruit", "field preserved")


func test_empty_rejected() -> void:
	var r := NetProtocol.decode(PackedByteArray())
	assert_false(r.get("ok", false), "empty packet rejected")
	assert_eq(r.get("error", ""), "empty", "empty error reason")


func test_oversize_rejected() -> void:
	var big := PackedByteArray()
	big.resize(NetProtocol.MAX_MESSAGE_BYTES + 1)
	var r := NetProtocol.decode(big)
	assert_false(r.get("ok", false), "oversize packet rejected")
	assert_eq(r.get("error", ""), "too_large", "too_large reason")


func test_oversize_encode_returns_empty() -> void:
	var payload := {"type": NetProtocol.Msg.PING, "blob": "x".repeat(NetProtocol.MAX_MESSAGE_BYTES)}
	var bytes := NetProtocol.encode(payload)
	assert_eq(bytes.size(), 0, "oversize outbound message is dropped")


func test_malformed_rejected() -> void:
	var r := NetProtocol.decode("not json at all".to_utf8_buffer())
	assert_false(r.get("ok", false), "malformed json rejected")
	assert_eq(r.get("error", ""), "malformed", "malformed reason")


func test_non_object_rejected() -> void:
	var r := NetProtocol.decode("[1,2,3]".to_utf8_buffer())
	assert_false(r.get("ok", false), "array root rejected")
	assert_eq(r.get("error", ""), "not_object", "not_object reason")


func test_wrong_version_rejected() -> void:
	var bytes := JSON.stringify({"v": 999, "type": NetProtocol.Msg.PING}).to_utf8_buffer()
	var r := NetProtocol.decode(bytes)
	assert_false(r.get("ok", false), "wrong version rejected")
	assert_eq(r.get("error", ""), "version", "version reason")


func test_missing_type_rejected() -> void:
	var bytes := JSON.stringify({"v": NetProtocol.VERSION}).to_utf8_buffer()
	var r := NetProtocol.decode(bytes)
	assert_false(r.get("ok", false), "missing type rejected")
	assert_eq(r.get("error", ""), "no_type", "no_type reason")


func test_unknown_type_rejected() -> void:
	var bytes := JSON.stringify({"v": NetProtocol.VERSION, "type": 4242}).to_utf8_buffer()
	var r := NetProtocol.decode(bytes)
	assert_false(r.get("ok", false), "unknown type rejected")
	assert_eq(r.get("error", ""), "unknown_type", "unknown_type reason")


func test_sanitize_strips_control_characters() -> void:
	var dirty := "ab" + String.chr(7) + "cd" + String.chr(10) + "ef" + String.chr(27) + "gh" + String.chr(127) + "ij"
	var clean := NetProtocol.sanitize_string(dirty)
	assert_false(clean.contains(String.chr(7)), "bell removed")
	assert_false(clean.contains(String.chr(10)), "newline removed")
	assert_false(clean.contains(String.chr(27)), "escape removed")
	assert_false(clean.contains(String.chr(127)), "delete removed")
	assert_eq(clean, "abcdefghij", "visible characters preserved")


func test_sanitize_truncates() -> void:
	var long := "a".repeat(500)
	assert_eq(NetProtocol.sanitize_string(long, 10).length(), 10, "string truncated to limit")


func test_sanitize_name_defaults() -> void:
	assert_eq(NetProtocol.sanitize_name("   "), "Commander", "blank name gets a default")
	assert_eq(NetProtocol.sanitize_name("Red" + String.chr(7) + "Baron"), "RedBaron", "control chars stripped from name")


func test_sanitize_int_rejects_non_numeric() -> void:
	assert_eq(NetProtocol.sanitize_int("5", -1), -1, "string is not a number")
	assert_eq(NetProtocol.sanitize_int(7), 7, "int passes through")
	assert_eq(NetProtocol.sanitize_int(3.9), 3, "float truncated")
	assert_eq(NetProtocol.sanitize_int(null, -1), -1, "null uses default")
