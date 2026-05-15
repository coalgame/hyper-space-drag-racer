extends Node

const PORT = 7000
const MAX_CLIENTS = 8

const PRESET_COLORS = [
	Color.RED,
	Color.ORANGE,
	Color.YELLOW,
	Color.GREEN,
	Color.CYAN,
	Color.BLUE,
	Color.PURPLE,
	Color.MAGENTA,
	Color.WHITE,
	Color.LIME_GREEN
]

var players = {} # Store info like { peer_id: { "name": "Random Name" } }

func _ready():
	randomize()
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

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
	

func disconnect_from_game():
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

func _on_peer_connected(id):
	# When we see a new peer, tell them our info
	var my_id = multiplayer.get_unique_id()
	if players.has(my_id):
		_register_player.rpc_id(id, players[my_id])


func _on_peer_disconnected(id):
	players.erase(id)


@rpc("any_peer", "reliable")
func _register_player(info):
	var id = multiplayer.get_remote_sender_id()
	players[id] = info


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
