class_name Player extends Node3D

@export var move_speed := 8.0
@export var forward_speed := 10.0

# Optional movement bounds so the ship stays inside the obstacle field.
@export var x_limit := 5.0
@export var y_limit := 5.0

var slowdown = 1.


func _enter_tree() -> void:
	set_multiplayer_authority(str(name).to_int())
	if is_multiplayer_authority():
		Global.local_player=self
		
func _ready() -> void:
	if !is_multiplayer_authority():
		$Camera3D.queue_free()
		$Area3D.queue_free()
		$ScoreLabel.queue_free()

func _physics_process(delta: float) -> void:
	if !is_multiplayer_authority(): 
		return
	
	slowdown = move_toward(slowdown, 1, delta * .1)
	
	$ScoreLabel.text = str(int(-global_position.z))

	var input := Vector2.ZERO

	# Using action strengths avoids weird diagonal speed differences.
	input.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	input.y = Input.get_action_strength("move_up") - Input.get_action_strength("move_down")

	input = input.normalized()

	# Move forward constantly.
	global_position.z -= (forward_speed * slowdown) * delta

	# Move sideways and vertically.
	global_position.x += input.x * move_speed * delta
	global_position.y += input.y * move_speed * delta

	# Prevent the ship from leaving the playable area.
	global_position.x = clamp(global_position.x, -x_limit, x_limit)
	global_position.y = clamp(global_position.y, -y_limit, y_limit)


func _on_area_3d_body_entered(body: Node3D) -> void:
	slowdown = 0.5
