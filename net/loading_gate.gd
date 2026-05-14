class_name NetworkGate extends Node

signal all_players_ready

var ready_peers := []
var target_count := 0
var gate_name := ""

func _init(_gate_name: String):
	gate_name = _gate_name
	# Setting the name helps for network debugging
	name = "Gate_" + _gate_name 

func start_check():
	ready_peers.clear()
	# Server + all clients
	target_count = multiplayer.get_peers().size() + 1
	_send_ready.rpc_id(1, multiplayer.get_unique_id())

@rpc("any_peer", "call_local", "reliable")
func _send_ready(id: int):
	if not is_multiplayer_authority(): return
	
	if not ready_peers.has(id):
		ready_peers.append(id)
	
	if ready_peers.size() >= target_count:
		_open_gate.rpc()

@rpc("authority", "call_local", "reliable")
func _open_gate():
	all_players_ready.emit()
