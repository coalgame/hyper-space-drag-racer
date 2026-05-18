extends CharacterBody3D

@export var base_speed := 45.0
@export var acceleration := 5.0
@export var steering_force := 4.0
@export var lookahead_distance := 20.0
@export var sensor_length := 15.0

func _physics_process(delta: float) -> void:
	if not Main.world or Main.world.safe_path.is_empty():
		return

	# 1. Steering: Calculate target velocity from path
	var target_pos = _get_path_target()
	var desired_velocity = (target_pos - global_position).normalized() * base_speed
	
	# 2. Steering Force: (Desired - Current) * Acceleration
	# This creates inertia, making the bot feel like it has mass
	var steer = (desired_velocity - velocity) * acceleration
	
	# 3. Avoidance Force: Accumulate "push" forces from sensors
	var avoidance = _calculate_avoidance()
	steer += avoidance * steering_force * base_speed

	# 4. Integration: Apply the force to velocity and move
	velocity += steer * delta
	move_and_slide()

	# Debug: Draw a line to the bot's current target
	DebugDraw3D.draw_line(global_position, target_pos, Color.YELLOW)

func _get_path_target() -> Vector3:
	var path = Main.world.safe_path
	var current_z = global_position.z
	
	# We look for a point on the pre-calculated safe path that is ahead of us
	for point in path:
		if point.z > current_z + lookahead_distance:
			return point
			
	# If we're near the end, target the last known point
	return path[-1]

func _calculate_avoidance() -> Vector3:
	var avoidance_vec = Vector3.ZERO
	var space_state = get_world_3d().direct_space_state
	
	# Directions to check: Center, Left, Right, Up, Down
	var forward = velocity.normalized()
	if forward.is_zero_approx(): forward = Vector3(0, 0, 1)
	
	# Since we aren't rotating, we calculate local directions based on velocity
	var temp_right = forward.cross(Vector3.UP).normalized()
	if temp_right.is_zero_approx(): temp_right = Vector3.RIGHT
	var temp_up = temp_right.cross(forward).normalized()
	
	var rays = [
		forward,
		(forward + temp_right * 0.5).normalized(),
		(forward - temp_right * 0.5).normalized(),
		(forward + temp_up * 0.5).normalized(),
		(forward - temp_up * 0.5).normalized()
	]
	
	for ray_dir in rays:
		var query = PhysicsRayQueryParameters3D.create(
			global_position,
			global_position + ray_dir * sensor_length,
			1 # Collision mask for geometry
		)
		query.exclude = [get_rid()]
		
		var result = space_state.intersect_ray(query)
		if result:
			# Use the collision normal to push away. This is much more stable than position.
			var dist = global_position.distance_to(result.position)
			var intensity = 1.0 - (dist / sensor_length)
			avoidance_vec += result.normal * intensity
			
	return avoidance_vec
