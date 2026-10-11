extends SceneTree

var host: ENetMultiplayerPeer
var client: ENetMultiplayerPeer
var frames := 0

func _initialize() -> void:
	host = ENetMultiplayerPeer.new()
	print("host err=", host.create_server(27999, 4))
	client = ENetMultiplayerPeer.new()
	print("client err=", client.create_client("127.0.0.1", 27999))

func _process(_delta: float) -> bool:
	frames += 1
	host.poll()
	client.poll()
	if frames % 20 == 0:
		print("f=%d host=%d client=%d cid=%d hid=%d" % [
			frames, host.get_connection_status(), client.get_connection_status(),
			client.get_unique_id(), host.get_unique_id()])
	if frames > 200:
		quit()
	return false
