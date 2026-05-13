class_name Gem extends CharacterBody3D

var speed := 6.0

func _ready() -> void:
	if multiplayer.is_server():
		# random initial direction
		velocity = Vector3(
			randf_range(-1, 1),
			randf_range(-1, 1),
			-1
		).normalized() * speed
		
func _physics_process(delta: float) -> void:
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
		body.speed_boost(3)
	
	if multiplayer.is_server():
		queue_free()
