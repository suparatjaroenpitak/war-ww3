extends Node
## Net autoload. Owns the single ENet peer and, when hosting, the authoritative
## GameServer. It relays validated commands between clients and the server and
## synchronises compact state snapshots. In OFFLINE mode commands are applied
## directly to Session.state, so the campaign code path is identical.
##
## Design rules enforced here:
##  * the server is authoritative; clients only send commands,
##  * every inbound packet is size-checked and validated by NetProtocol,
##  * state snapshots are validated before replacing the local state,
##  * no privileged data is ever sent to clients.

enum Role { OFFLINE, HOST, CLIENT }

signal lobby_changed(players: Array)
signal match_started()
signal state_updated()
signal command_resolved(result: Dictionary)
signal connection_failed(reason: String)
signal disconnected(reason: String)

const DEFAULT_PORT := 27015
const STATE_LOG_TAIL := 40

var role: int = Role.OFFLINE
var peer_id: int = 0
var nickname: String = "Commander"
var server: GameServer = null
var local_faction: String = ""

var _next_command_id: int = 1


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	multiplayer.peer_packet.connect(_on_peer_packet)


func is_online() -> bool:
	return role != Role.OFFLINE


func is_host() -> bool:
	return role == Role.HOST


func _world() -> WorldData:
	return WorldData.load_default()


# --------------------------------------------------------------------------
# Hosting / joining
# --------------------------------------------------------------------------

func host_game(port: int, display_name: String, faction_id: String) -> Dictionary:
	var world := _world()
	if world == null:
		return _fail("MULTIPLAYER_ERR_CREATE")
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, GameServer.MAX_PLAYERS)
	if err != OK:
		return _fail("MULTIPLAYER_ERR_CREATE", err)
	multiplayer.multiplayer_peer = peer
	role = Role.HOST
	peer_id = 1
	nickname = NetProtocol.sanitize_name(display_name)
	local_faction = faction_id
	server = GameServer.new()
	server.setup(world, randi())
	var added := server.add_player(1, faction_id, nickname)
	if not added.get("ok", false):
		close()
		return _fail(str(added.get("error", "unknown_faction")))
	lobby_changed.emit(server.lobby_snapshot())
	return {"ok": true}


func join_game(address: String, port: int, display_name: String) -> Dictionary:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		return _fail("MULTIPLAYER_ERR_CONNECT", err)
	multiplayer.multiplayer_peer = peer
	role = Role.CLIENT
	nickname = NetProtocol.sanitize_name(display_name)
	return {"ok": true}


func close() -> void:
	if multiplayer.multiplayer_peer != null and role != Role.OFFLINE:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	role = Role.OFFLINE
	peer_id = 0
	server = null
	local_faction = ""


# --------------------------------------------------------------------------
# Lobby
# --------------------------------------------------------------------------

func host_start_match() -> Dictionary:
	if role != Role.HOST or server == null:
		return _fail("not_host")
	var result := server.start_match()
	if not result.get("ok", false):
		return result
	Session.state = server.state
	_broadcast(NetProtocol.make(NetProtocol.Msg.START, {}))
	_broadcast_state()
	match_started.emit()
	return {"ok": true}


func request_ready(ready: bool) -> Dictionary:
	match role:
		Role.HOST:
			var r := server.set_ready(1, ready)
			lobby_changed.emit(server.lobby_snapshot())
			return r
		Role.CLIENT:
			_send_to(1, NetProtocol.make(NetProtocol.Msg.READY, {"ready": ready}))
			return {"ok": true}
	return _fail("not_online")


# --------------------------------------------------------------------------
# Commands
# --------------------------------------------------------------------------

## Submit a gameplay command. In OFFLINE mode it is applied directly; when
## hosting it goes through the authoritative server; as a client it is sent to
## the server and the result arrives asynchronously via command_resolved().
func submit_command(command: Dictionary) -> Dictionary:
	match role:
		Role.OFFLINE:
			return apply_offline_command(command)
		Role.HOST:
			command = command.duplicate()
			command["id"] = _assign_id()
			var result := server.submit_command(peer_id, command, _now())
			if result.get("ok", false):
				_broadcast_state()
			return result
		Role.CLIENT:
			command = command.duplicate()
			command["id"] = _assign_id()
			_send_to(1, NetProtocol.make(NetProtocol.Msg.COMMAND, {"command": command}))
			return {"ok": true, "pending": true}
	return _fail("not_ready")


func apply_offline_command(command: Dictionary) -> Dictionary:
	var state: GameState = Session.state
	if state == null:
		return _fail("no_game")
	var kind := str(command.get("kind", ""))
	match kind:
		"recruit":
			return state.recruit(str(command.get("territory", "")))
		"develop":
			return state.develop(str(command.get("territory", "")))
		"attack":
			return state.attack(str(command.get("from", "")), str(command.get("to", "")))
		"end_turn":
			state.end_turn()
			return {"ok": true}
	return _fail("unknown_command")


# --------------------------------------------------------------------------
# Packet handling
# --------------------------------------------------------------------------

func _on_peer_packet(id: int, bytes: PackedByteArray) -> void:
	var decoded := NetProtocol.decode(bytes)
	if not decoded.get("ok", false):
		# A malformed packet is dropped; never trust it enough to reply.
		return
	var msg: Dictionary = decoded["msg"]
	match NetProtocol.type_of(msg):
		NetProtocol.Msg.HELLO:
			_handle_hello(id, msg)
		NetProtocol.Msg.WELCOME:
			_handle_welcome(msg)
		NetProtocol.Msg.LOBBY:
			_handle_lobby(msg)
		NetProtocol.Msg.READY:
			_handle_ready(id, msg)
		NetProtocol.Msg.START:
			_handle_start()
		NetProtocol.Msg.COMMAND:
			_handle_command(id, msg)
		NetProtocol.Msg.RESULT:
			_handle_result(msg)
		NetProtocol.Msg.STATE:
			_handle_state(msg)
		NetProtocol.Msg.PING:
			pass
		_:
			pass


func _handle_hello(id: int, msg: Dictionary) -> void:
	if role != Role.HOST or server == null:
		return
	var requested := NetProtocol.sanitize_string(msg.get("faction", ""), 32)
	var available := server.playable_factions()
	var faction := requested
	if faction == "" or not available.has(faction):
		faction = ""
	# Pick a free faction, preferring the requested one.
	var taken: Array = []
	for p in server.lobby_snapshot():
		taken.append(p["faction_id"])
	if taken.has(faction) or faction == "":
		faction = ""
		for f in available:
			if not taken.has(f):
				faction = f
				break
	if faction == "":
		_send_to(id, NetProtocol.make(NetProtocol.Msg.ERROR, {"reason": "server_full"}))
		return
	var added := server.add_player(id, faction, msg.get("name", "Commander"))
	if not added.get("ok", false):
		_send_to(id, NetProtocol.make(NetProtocol.Msg.ERROR, {"reason": added.get("error", "rejected")}))
		return
	_send_to(id, NetProtocol.make(NetProtocol.Msg.WELCOME, {
		"peer_id": id,
		"faction_id": faction,
	}))
	_broadcast_lobby()


func _handle_welcome(msg: Dictionary) -> void:
	if role != Role.CLIENT:
		return
	peer_id = NetProtocol.sanitize_int(msg.get("peer_id", 1), 1)
	local_faction = NetProtocol.sanitize_string(msg.get("faction_id", ""), 32)


func _handle_lobby(msg: Dictionary) -> void:
	if role != Role.CLIENT:
		return
	var players: Array = msg.get("players", [])
	lobby_changed.emit(players)


func _handle_ready(id: int, msg: Dictionary) -> void:
	if role != Role.HOST or server == null:
		return
	server.set_ready(id, bool(msg.get("ready", false)))
	_broadcast_lobby()


func _handle_start() -> void:
	if role == Role.CLIENT:
		# The authoritative state arrives in the following STATE packet.
		match_started.emit()


func _handle_command(id: int, msg: Dictionary) -> void:
	if role != Role.HOST or server == null:
		return
	var command = msg.get("command", {})
	var result := server.submit_command(id, command, _now())
	_send_to(id, NetProtocol.make(NetProtocol.Msg.RESULT, {
		"ok": result.get("ok", false),
		"error": result.get("error", ""),
		"kind": result.get("kind", ""),
		"command_id": result.get("command_id", 0),
	}))
	if result.get("ok", false):
		_broadcast_state()


func _handle_result(msg: Dictionary) -> void:
	if role != Role.CLIENT:
		return
	command_resolved.emit({
		"ok": bool(msg.get("ok", false)),
		"error": NetProtocol.sanitize_string(msg.get("error", ""), 32),
		"kind": NetProtocol.sanitize_string(msg.get("kind", ""), 24),
	})


func _handle_state(msg: Dictionary) -> void:
	if role != Role.CLIENT:
		return
	var snap = msg.get("state", null)
	if typeof(snap) != TYPE_DICTIONARY:
		return
	if SaveGame.validate(snap) != "":
		return
	var world := _world()
	if world == null:
		return
	Session.state = GameState.deserialize(world, snap)
	state_updated.emit()


# --------------------------------------------------------------------------
# Connection callbacks
# --------------------------------------------------------------------------

func _on_peer_connected(id: int) -> void:
	if role != Role.HOST:
		return
	# The client introduces itself with HELLO; nothing is trusted yet.
	_send_to(id, NetProtocol.make(NetProtocol.Msg.PING, {}))


func _on_peer_disconnected(id: int) -> void:
	if role == Role.HOST and server != null:
		server.remove_player(id)
		_broadcast_lobby()
		_broadcast_state()
	elif role == Role.CLIENT and id == 1:
		disconnected.emit("server_closed")
		close()


func _on_connected_to_server() -> void:
	if role != Role.CLIENT:
		return
	peer_id = multiplayer.get_unique_id()
	_send_to(1, NetProtocol.make(NetProtocol.Msg.HELLO, {
		"name": nickname,
		"faction": local_faction,
	}))


func _on_connection_failed() -> void:
	connection_failed.emit("MULTIPLAYER_ERR_CONNECT")
	if role == Role.CLIENT:
		close()


func _on_server_disconnected() -> void:
	disconnected.emit("server_closed")
	close()


# --------------------------------------------------------------------------
# Helpers
# --------------------------------------------------------------------------

func state_snapshot() -> Dictionary:
	if server == null or server.state == null:
		return {}
	var data := server.state.to_dict()
	var entries: Array = data.get("event_log", [])
	if entries.size() > STATE_LOG_TAIL:
		data["event_log"] = entries.slice(entries.size() - STATE_LOG_TAIL)
	return data


func _broadcast_state() -> void:
	if server == null or server.state == null:
		return
	_broadcast(NetProtocol.make(NetProtocol.Msg.STATE, {"state": state_snapshot()}))


func _broadcast_lobby() -> void:
	if server == null:
		return
	var players := server.lobby_snapshot()
	lobby_changed.emit(players)
	_broadcast(NetProtocol.make(NetProtocol.Msg.LOBBY, {"players": players}))


func _broadcast(msg: Dictionary) -> void:
	_send_bytes(NetProtocol.encode(msg), 0)


func _send_to(target: int, msg: Dictionary) -> void:
	_send_bytes(NetProtocol.encode(msg), target)


func _send_bytes(bytes: PackedByteArray, target: int) -> void:
	if bytes.is_empty():
		return
	if multiplayer.multiplayer_peer == null:
		return
	multiplayer.send_bytes(bytes, target, MultiplayerPeer.TRANSFER_MODE_RELIABLE)


func _assign_id() -> int:
	var id := _next_command_id
	_next_command_id += 1
	return id


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _fail(reason: String, code: int = 0) -> Dictionary:
	return {"ok": false, "error": reason, "code": code}
