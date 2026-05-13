class_name Gem extends CharacterBody3D

@onready var mesh: MeshInstance3D = $MeshInstance3D

var speed := 2.0

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
		
	
	var collision := move_and_collide(velocity * delta)

	if collision:
		# bounce using reflection
		velocity = velocity.bounce(collision.get_normal())

		# keep constant speed so it doesn't slow down over time
		velocity = velocity.normalized() * speed
	
func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		if not body.is_multiplayer_authority():
			return
		
		request_pickup.rpc_id(1)
		
@rpc("any_peer", "call_local")
func request_pickup():
	if not multiplayer.is_server():
		return
	
	# already collected?
	if is_queued_for_deletion():
		return
		
	var id = multiplayer.get_remote_sender_id()
	var player : Player = Game.game.get_node_or_null(str(id))
	if player:
		player.speed_boost.rpc_id(id, 3)
		# deletes for everyone (multiplayerspawner)
		queue_free()
