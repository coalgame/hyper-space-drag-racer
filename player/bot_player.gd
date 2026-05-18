extends CharacterBody3D

@export var speed := 40.0
@export var steering_sensitivity := 45.0
@export var look_ahead_z := 20 # How many meters ahead to find a path
@export var search_radius := 6 # How far left/right to look for a hole

var target_velocity := Vector3.ZERO
var current_urgency := 1.0

func _ready() -> void:
	# Only the server calculates AI movement
	if not multiplayer.is_server():
		set_physics_process(false)
		return
	
	add_to_group("player") # So get_first_place() counts the bot

func _physics_process(delta: float) -> void:
	var target_xy = _get_best_voxel_target()
	
	# Calculate direction to the target voxel in 2D space
	var current_xy = Vector2(global_position.x, global_position.y)
	var desired_dir = (target_xy - current_xy).normalized()
	var dist_to_target = current_xy.distance_to(target_xy)
	
	# If we are already close to the center of the hole, don't over-steer
	var strength = clamp(dist_to_target * 0.5, 0.0, 1.0)

	velocity.x = lerp(velocity.x, desired_dir.x * steering_sensitivity * strength * current_urgency, delta * 15.0)
	velocity.y = lerp(velocity.y, desired_dir.y * steering_sensitivity * strength * current_urgency, delta * 15.0)
	
	# Constant forward speed
	velocity.z = speed
	
	move_and_slide()

	# physically cannot go out of bounds
	global_position.x = clamp(global_position.x, -World.X_SIZE, World.X_SIZE)
	global_position.y = clamp(global_position.y, -World.Y_SIZE, World.Y_SIZE)

func _get_best_voxel_target() -> Vector2:
	var v_size = Main.world.VOXEL_SIZE
	# Convert current world position to the nearest voxel grid coordinate
	var current_v_pos = (global_position / float(v_size)).round()
	
	var current_ix = int(current_v_pos.x)
	var current_iy = int(current_v_pos.y)

	# 1. Find the NEAREST obstructed Z-slice instead of always looking at the max distance.
	# This prevents "turning too early" when the immediate path is clear.
	var v_look_ahead = int(look_ahead_z / float(v_size))
	var effective_v_z = v_look_ahead
	
	for z_off in range(1, v_look_ahead + 1):
		var check_z = int(current_v_pos.z) + z_off
		if Main.world.is_voxel_occupied(Vector3i(current_ix, current_iy, check_z)):
			effective_v_z = z_off
			break
	
	# 2. Calculate urgency based on how close the obstruction is (0.2 to 1.0)
	current_urgency = clamp(1.0 - (float(effective_v_z) / v_look_ahead), 0.2, 1.0)
	
	var target_iz = int(current_v_pos.z) + effective_v_z
	var best_pos = Vector2(current_ix, current_iy) # Default to staying straight
	var min_dist = INF
	
	var v_search_radius = floor(search_radius / float(v_size))
	
	# If we found an obstruction closer than our max look-ahead, 
	# we search that specific slice for the best opening.
	# Search a window (in voxel units) around our current position in the future Z-slice
	for dx in range(-v_search_radius, v_search_radius + 1):
		for dy in range(-v_search_radius, v_search_radius + 1):
			var test_v = Vector3i(current_ix + dx, current_iy + dy, target_iz)
			var occupied = Main.world.is_voxel_occupied(test_v)
			
			# Visualization for the search grid
			var debug_color = Color.RED if occupied else Color.GREEN
			DebugDraw3D.draw_square(Vector3(test_v) * v_size, 0.1 * v_size, debug_color)
			
			if not occupied:
				# Calculate a "Safety Cost" by checking neighbors.
				# If a neighboring voxel is blocked, this path is "risky".
				var safety_cost = 0.0
				for ox in range(-1, 2):
					for oy in range(-1, 2):
						if Main.world.is_voxel_occupied(test_v + Vector3i(ox, oy, 0)):
							safety_cost += 5.0 # Higher cost for voxels touching walls
				
				# Score = distance from current path + risk of hitting a wall
				var score = Vector2(dx, dy).length() + safety_cost
				
				if score < min_dist:
					min_dist = score
					best_pos = Vector2(test_v.x, test_v.y)
	
	# Debug the target path
	var target_world_pos = Vector3(best_pos.x, best_pos.y, target_iz) * v_size
	DebugDraw3D.draw_sphere(target_world_pos, 0.5 * v_size, Color.CYAN)
	DebugDraw3D.draw_line(global_position, target_world_pos, Color.CYAN)
	
	return Vector2(target_world_pos.x, target_world_pos.y)
