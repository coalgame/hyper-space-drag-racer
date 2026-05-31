class_name Gem extends Area3D

@onready var mesh: MeshInstance3D = $MeshInstance3D

@export var is_golden := false

func _ready() -> void:
	if is_golden:
		var mat = mesh.get_surface_override_material(0)
		if !mat:
			mat = mesh.mesh.material
		
		if mat:
			var gold_mat = mat.duplicate()
			gold_mat.set_shader_parameter("albedo", Color(1.0, 0.84, 0.0))
			gold_mat.set_shader_parameter("emission", Color(1.0, 0.84, 0.0))
			mesh.set_surface_override_material(0, gold_mat)
			mesh.scale *= 1.4

func _process(delta: float) -> void:
	mesh.rotation += Vector3.ONE * delta
	
func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		if body.is_multiplayer_authority():
			hide() # show pick it up immediately
			request_pickup.rpc_id(1, body.name)

@rpc("any_peer", "call_local")
func request_pickup(player_node_name: String):
	if not multiplayer.is_server():
		return
	
	# already collected?
	if is_queued_for_deletion():
		return
	
	var player: Player = Main.world.get_node_or_null(player_node_name)
	if player:
		var first_place_player = Main.world.get_first_place()
		if is_instance_valid(first_place_player):
			var distance = abs(first_place_player.get_total_distance() - player.get_total_distance())
			var gemboost = (0.002 * distance) + 1
			gemboost = clamp(gemboost, 1, 3.0)
			
			
	 		# FIX: dont use multiplayer.get_remote_sender_id() because a bot could pick it up and bots dont have a network id, instead pass the player node name and look it up in the world
			# Apply boost specifically to the authority of this ship instance
			player.speed_boost.rpc_id(player.get_multiplayer_authority(), 3 * gemboost)
			player.race_stats.add_score.rpc_id(player.get_multiplayer_authority(), player.race_stats.score_gem)
			
			if is_golden:
				player.activate_boost_rpc.rpc_id(player.get_multiplayer_authority())

			# deletes for everyone (multiplayerspawner)
			queue_free()
