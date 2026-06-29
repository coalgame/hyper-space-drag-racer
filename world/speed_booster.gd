class_name SpeedBooster extends Area3D

@onready var mesh: MeshInstance3D = $MeshInstance3D

func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		if body.is_multiplayer_authority():
			request_pickup.rpc_id(1, body.name)

@rpc("any_peer", "call_local")
func request_pickup(player_node_name: String):
	if not multiplayer.is_server():
		return

	var player: Player = Main.world.get_node_or_null(player_node_name)
	if player:
		player.speed_boost.rpc_id(player.get_multiplayer_authority(), 10)
