#network_manager.gd (autoload)
extends Node

const PORT = 7000
const MAX_CLIENTS = 8

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

func _ready():
	randomize()
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func create_game():
	# Ensure any previous peer is properly closed and nulled before creating a new one.
	disconnect_from_game()
	
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(PORT, MAX_CLIENTS)
	if error != OK:
		Notifications.notify("Cannot host: ", error)
		return error
	
	multiplayer.multiplayer_peer = peer
	players[1] = {"name": get_random_name(), "color": get_random_color()}
	update_ui.emit()
	
	Notifications.notify(multiplayer.get_unique_id(), "Server started on port ", PORT)
	
	return OK

func join_game(address = ""):
	if address.is_empty():
		address = "127.0.0.1"

	# Ensure any previous peer is properly closed and nulled before creating a new one.
	disconnect_from_game()
	Notifications.notify(multiplayer.get_unique_id(), "Connecting to ", address, ":", PORT)
	
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(address, PORT)
	if error == OK:
		multiplayer.multiplayer_peer = peer
		players[multiplayer.get_unique_id()] = {"name": get_random_name(), "color": get_random_color()}
		update_ui.emit()
	

func disconnect_from_game():
	if multiplayer.multiplayer_peer:
		# Reset the refusal flag if we were hosting
		if multiplayer.is_server():
			multiplayer.multiplayer_peer.refuse_new_connections = false
			
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	players.clear()

func has_connection() -> bool:
	var peer = multiplayer.multiplayer_peer
	# Ensure we have a peer and it's NOT the default offline peer
	if not multiplayer.has_multiplayer_peer() or peer is OfflineMultiplayerPeer:
		return false
	return peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED

func is_host() -> bool:
	return has_connection() and multiplayer.is_server()

func lock_lobby():
	if is_host() and multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.refuse_new_connections = true
		Notifications.notify("Lobby locked. No new players can join.")

func _on_peer_connected(id):
	# When we see a new peer, tell them our info
	var my_id = multiplayer.get_unique_id()
	if players.has(my_id):
		_register_player.rpc_id(id, players[my_id])


func _on_peer_disconnected(id):
	players.erase(id)
	
	# If a race is in progress, find and remove the disconnected player's ship
	if is_instance_valid(Game.game):
		var player_node = Game.game.get_node_or_null(str(id))
		if player_node:
			player_node.queue_free()
			Notifications.notify("Player " + str(id) + " disconnected.")

	update_ui.emit()

func _on_server_disconnected():
	Notifications.notify("Lost connection to host.")
	disconnect_from_game()
	get_tree().change_scene_to_file("res://main_menu.tscn")

@rpc("any_peer", "call_local", "reliable")
func _register_player(info):
	var id = multiplayer.get_remote_sender_id()
	if id == 0: # Handle local execution when calling via .rpc()
		id = multiplayer.get_unique_id()
	players[id] = info
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

func get_random_name():
	var name_combo = ["Epic", "Ugly", "Weird", "Jerkin", "Stupid", "Fat", "Turbo", "Wacky"]
	return str(name_combo.pick_random() + "Chud")

func get_random_color():
	return PRESET_COLORS.pick_random()
