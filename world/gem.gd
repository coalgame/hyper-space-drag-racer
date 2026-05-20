class_name Gem extends CharacterBody3D

@onready var mesh: MeshInstance3D = $MeshInstance3D

var speed := 1.0

func _ready() -> void:
	if multiplayer.is_server():
		# random initial direction
		velocity = Vector3(
			randf_range(-1, 1),
			randf_range(-1, 1),
			-1
		).normalized() * speed
		
func _physics_process(delta: float) -> void:
	mesh.rotate_x(delta)
	mesh.rotate_y(delta)
	mesh.rotate_z(delta)

	if !multiplayer.is_server():
		return

	# var collision := move_and_collide(velocity * delta)

	# if collision:
	# 	# reflect off physical colliders
	# 	velocity = velocity.bounce(collision.get_normal()).normalized() * speed

	# # bounce off world bounds
	# if global_position.x < -World.X_SIZE:
	# 	global_position.x = -World.X_SIZE
	# 	velocity.x *= -1

	# elif global_position.x > World.X_SIZE:
	# 	global_position.x = World.X_SIZE
	# 	velocity.x *= -1

	# if global_position.y < -World.Y_SIZE:
	# 	global_position.y = -World.Y_SIZE
	# 	velocity.y *= -1

	# elif global_position.y > World.Y_SIZE:
	# 	global_position.y = World.Y_SIZE
	# 	velocity.y *= -1

	# # keep movement speed consistent after reflections
	# velocity = velocity.normalized() * speed
	
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
			var distance = abs(first_place_player.global_position.z - player.global_position.z)
			var gemboost = (0.002 * distance) + 1
			
	 		# FIX: dont use multiplayer.get_remote_sender_id() because a bot could pick it up and bots dont have a network id, instead pass the player node name and look it up in the world
			# Apply boost specifically to the authority of this ship instance
			player.speed_boost.rpc_id(player.get_multiplayer_authority(), 3 * gemboost)
			
			# deletes for everyone (multiplayerspawner)
			queue_free()
