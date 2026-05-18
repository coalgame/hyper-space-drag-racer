extends CharacterBody3D

@export var speed := 40.0

func _ready() -> void:
	# Only the server calculates AI movement
	if not multiplayer.is_server():
		set_physics_process(false)
		return
	
	add_to_group("player") # So get_first_place() counts the bot

func _physics_process(delta: float) -> void:
	# 1. Handle forward movement via physics
	velocity = Vector3(0, 0, speed)
	move_and_slide()

	# 2. Force the bot to follow the 1:1 safe path
	# We look at the safe point for our EXACT current Z position
	var safe_point = Main.world.get_safe_path_point(global_position.z)

	# 3. Snap X and Y to the safe path. 
	# We use a high-weight lerp just to smooth out the 2-meter steps of the voxel path.
	global_position.x =  safe_point.x
	global_position.y = safe_point.y
