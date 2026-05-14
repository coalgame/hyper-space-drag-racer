extends Node

const PORT = 7000
const MAX_CLIENTS = 8

var multiplayer_peer:ENetMultiplayerPeer

func create_game():
	multiplayer_peer = ENetMultiplayerPeer.new()
	var error = multiplayer_peer.create_server(PORT, MAX_CLIENTS)
	if error != OK:
		Notifications.notify("Cannot host: ", error)
		return error
	multiplayer.multiplayer_peer = multiplayer_peer
	
	#players[1] = player_info
	#player_connected.emit(1, player_info)
	
	Notifications.notify(multiplayer.get_unique_id(),"Server started on port ", PORT)
	
	return OK

func join_game(address = ""):
	if address.is_empty():
		address = "127.0.0.1"
	
	multiplayer_peer = ENetMultiplayerPeer.new()
	multiplayer_peer.create_client(address, PORT)
	multiplayer.multiplayer_peer = multiplayer_peer
	
	Notifications.notify(multiplayer.get_unique_id(),"Connecting to ", address, ":", PORT)

func is_host():
	return multiplayer.is_server()

func disconnect_from_game():
	if multiplayer_peer:
		multiplayer_peer.close()
	#players.clear()

func _process(delta: float) -> void:
	if not multiplayer_peer: return
	
	DebugDraw2D.begin_text_group("network", 10, Color.ANTIQUE_WHITE)
	#if !is_host():
	#	DebugDraw2D.set_text("ping", str(NetworkManager.multiplayer_peer.get_peer(1).get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME))+"ms")
	DebugDraw2D.set_text("is host", is_host())
	DebugDraw2D.set_text("connected players", len(multiplayer.get_peers())+1)

	DebugDraw2D.end_text_group()
