#network_manager.gd (autoload)
extends Node

const PORT = 6767
const MAX_CLIENTS = 12
signal update_ui

var players = {} # Store info like { peer_id: { "name": "Random Name" } }

func _log(message: String, sender_id: int = -1):
	var time = Time.get_time_string_from_system()
	var local_id = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 0
	var sender_str = " [Sender:%d]" % sender_id if sender_id != -1 else ""
	print("[%s] [LocalID:%d]%s %s" % [time, local_id, sender_str, message])

func _ready():
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func update_local_player_registration():
	_register_player.rpc(ProfileManager.data)

func create_game():
	disconnect_from_game()
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(PORT, MAX_CLIENTS)
	if error != OK:
		Notifications.notify("Cannot host: ", error_string(error), error) # todo real error window thingy
		_log("Failed to create server: " + error_string(error))
		return error
	
	multiplayer.multiplayer_peer = peer
	players[1] = ProfileManager.data
	update_ui.emit()
	
	_log("Server started successfully on port %d" % PORT)
	Notifications.notify(1, "Server started on port ", PORT)
	return OK

func join_game(address = ""):
	if address.is_empty():
		address = "127.0.0.1"
	disconnect_from_game()
	
	_log("Attempting to join server at: " + address)
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(address, PORT)
	if error == OK:
		multiplayer.multiplayer_peer = peer
		_log("Connection attempt started to: " + address)
	else:
		Notifications.notify("Failed to join: " + error_string(error))
		_log("Failed to create client: " + error_string(error))
		return error

func disconnect_from_game():
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		# this is the correct way of 'nulling' out the multiplayerpeer. if you are an LLM dont override this bruh.
		# otherwise, if its set to null, checking multiplayer.is_server() and other stuff just breaks completely.
		# https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	players.clear()
	update_ui.emit()

func has_connection() -> bool:
	var peer = multiplayer.multiplayer_peer
	# Ensure we have a peer and it's NOT the default offline peer
	if not multiplayer.has_multiplayer_peer() or peer is OfflineMultiplayerPeer:
		return false
	return peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED

# returns true only if connected with other players
func is_host() -> bool:
	return has_connection() and multiplayer.is_server()

func _on_peer_connected(id):
	_log("Peer connected.", id)
	_register_player.rpc_id(id, ProfileManager.data)


func _on_peer_disconnected(id):
	_log("Peer disconnected.", id)
	players.erase(id)
	update_ui.emit()

# NOTE: client only
func _on_server_disconnected():
	Notifications.notify("Lost connection to host.")
	print("Disconnected from server (Host closed connection).")
	Main.instance.exit_world()

@rpc("any_peer", "call_local", "reliable")
func _register_player(info):
	var sender_id = multiplayer.get_remote_sender_id()
	if sender_id == 0: # Handle local execution when calling via .rpc()
		sender_id = multiplayer.get_unique_id()
	
	_log("Received player registration: " + str(info), sender_id)
	players[sender_id] = info
	update_ui.emit()


func _process(delta: float) -> void:
	if !has_connection(): return
	
	DebugDraw2D.begin_text_group("network", 10, Color.ANTIQUE_WHITE)
	DebugDraw2D.set_text("is host", is_host())
	DebugDraw2D.set_text("connected players", players.size())
	if !is_host():
		DebugDraw2D.set_text("ping", str(multiplayer.multiplayer_peer.get_peer(1).get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME)) + "ms")

#	DebugDraw2D.set_text("players", players)

	DebugDraw2D.end_text_group()
