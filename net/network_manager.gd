#network_manager.gd (autoload)
extends Node

const PORT = 7000
const MAX_CLIENTS = 8

const SAVE_PATH = "user://player_profile.cfg"
signal update_ui

const PRESET_COLORS = [
	Color.RED,
	Color.ORANGE,
	Color.YELLOW,
	Color.GREEN,
	Color.DODGER_BLUE,
	Color.MEDIUM_PURPLE,
	Color.HOT_PINK,
]

var players = {} # Store info like { peer_id: { "name": "Random Name" } }
var local_player_data = {"name": "", "color": Color.WHITE}

func _log(message: String, sender_id: int = -1):
	var time = Time.get_time_string_from_system()
	var local_id = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 0
	var sender_str = " [Sender:%d]" % sender_id if sender_id != -1 else ""
	print("[%s] [LocalID:%d]%s %s" % [time, local_id, sender_str, message])

func _ready():
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	load_settings()

func load_settings():
	var config = ConfigFile.new()
	var err = config.load(SAVE_PATH)
	
	var default_color =  PRESET_COLORS.pick_random()
	var default_name = "chud"+str(randi_range(0,9))
	if err == OK:
		local_player_data.name = config.get_value("profile", "name", default_name)
		local_player_data.color = config.get_value("profile", "color", default_color)
	else:
		# First time setup
		local_player_data.name = default_name
		local_player_data.color = default_color
		save_settings()

func save_settings():
	var config = ConfigFile.new()
	config.set_value("profile", "name", local_player_data.name)
	config.set_value("profile", "color", local_player_data.color)
	config.save(SAVE_PATH)

func set_player_name(new_name: String):
	local_player_data.name = new_name
	save_settings()
	
	# If we are currently in a lobby/game, sync the name change
	if has_connection():
		_register_player.rpc(local_player_data)

func set_player_color(new_color: Color):
	local_player_data.color = new_color
	save_settings()
	
	if has_connection():
		_register_player.rpc(local_player_data)

func create_game():
	# Ensure any previous peer is properly closed and nulled before creating a new one.
	disconnect_from_game()
	
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(PORT, MAX_CLIENTS)
	if error != OK:
		Notifications.notify("Cannot host: ", error_string(error), error) # todo real error window thingy
		_log("Failed to create server: " + error_string(error))
		return error
	
	multiplayer.multiplayer_peer = peer
	players[1] = local_player_data
	update_ui.emit()
	
	_log("Server started successfully on port %d" % PORT)
	Notifications.notify(1, "Server started on port ", PORT)
	return OK

func join_game(address = ""):
	if address.is_empty():
		address = "127.0.0.1"

	# Ensure any previous peer is properly closed and nulled before creating a new one.
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
		multiplayer.multiplayer_peer = null
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

func lock_lobby():
	print("Lobby locked. New connections will be denied.")

func _on_peer_connected(id):
	_log("Peer connected.", id)
	# When we see a new peer, tell them our info
	# We use the local_player_data which is always kept up to date
	_register_player.rpc_id(id, local_player_data)


func _on_peer_disconnected(id):
	_log("Peer disconnected.", id)
	players.erase(id)
	
	# If a race is in progress, find and remove the disconnected player's ship
	if is_instance_valid(Game.game):
		var player_node = Game.game.get_node_or_null(str(id))
		if player_node:
			player_node.queue_free()
			Notifications.notify("Player " + str(id) + " disconnected.")

	update_ui.emit()

func _on_server_disconnected():
	disconnect_from_game()
	Notifications.notify("Lost connection to host.")
	_log("Disconnected from server (Host closed connection).")
	get_tree().change_scene_to_file("res://main_menu.tscn")

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
	#if !is_host():
	#	DebugDraw2D.set_text("ping", str(NetworkManager.multiplayer_peer.get_peer(1).get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME))+"ms")
	DebugDraw2D.set_text("is host", is_host())
	DebugDraw2D.set_text("connected players", players.size())
#	DebugDraw2D.set_text("players", players)

	DebugDraw2D.end_text_group()
