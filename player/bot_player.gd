extends CharacterBody3D

@export var starting_speed := 20.0
var top_speed := starting_speed
var speed := 0.0
var acceleration := 145.0
var top_acceleration := 145.0

@export var steering_force := 250.0 # Maximum physical force for turning
@export var bot_radius := 1.5 # How wide the bot "feels" it is
@export var cone_angle_degrees := 150.0 # How wide the steering cone is
@export var cone_resolution := 0.2 # Slightly coarser for performance with wider cone

var num_rays := 0 # Will be calculated based on cone_angle_degrees and cone_resolution
var ray_directions: Array[Vector3] = []

func _ready() -> void:
	speed = 0.0
	_generate_ray_directions()

func _generate_ray_directions() -> void:
	ray_directions.clear()
	var cone_angle_rad = deg_to_rad(cone_angle_degrees)
	var current_angle_x = - cone_angle_rad / 2.0
	
	# Generate rays in a cone around the local Z-axis (forward)
	while current_angle_x <= cone_angle_rad / 2.0:
		var current_angle_y = - cone_angle_rad / 2.0
		while current_angle_y <= cone_angle_rad / 2.0:
			# dir = Vector3(x_deviation, y_deviation, forward_component)
			var dir = Vector3(sin(current_angle_x), sin(current_angle_y), cos(current_angle_x) * cos(current_angle_y)).normalized()
			ray_directions.append(dir)
			current_angle_y += cone_resolution
		current_angle_x += cone_resolution
	
	# Also add a straight forward ray if not already present
	if not ray_directions.has(Vector3(0, 0, 1)):
		ray_directions.append(Vector3(0, 0, 1))
	
	num_rays = ray_directions.size()
	print("Generated ", num_rays, " ray directions.")

func _physics_process(delta: float) -> void:
	if not Main.world:
		return

	# 1. Steering Goal: Move forward (+Z) while staying inside tunnel bounds
	var world_goal_direction = Vector3(0, 0, 1)
	
	# Calculate attraction to center if approaching or outside tunnel bounds.
	# This acts like a 'lane-centering' force that pulls the bot back to the middle.
	var tunnel_x = Main.world.X_SIZE
	var tunnel_y = Main.world.Y_SIZE
	
	if abs(global_position.x) > tunnel_x * 0.7: # Start centering earlier, but with less force
		world_goal_direction.x = - sign(global_position.x) * 0.5 # Reduced centering force
	if abs(global_position.y) > tunnel_y * 0.7: # Start centering earlier, but with less force
		world_goal_direction.y = - sign(global_position.y) * 0.5 # Reduced centering force

	world_goal_direction = world_goal_direction.normalized()

	# 1. Update speed over time to match player.gd mechanics
	var speed_damp_strength = -0.008
	var speed_damp = ((speed_damp_strength * top_speed) + 1) - (20 * speed_damp_strength)
	top_speed += delta * 0.5 * speed_damp
	
	# Match player's acceleration and top speed tracking
	speed = move_toward(speed, top_speed, delta * (10 + (top_speed * 0.4)))
	acceleration = move_toward(acceleration, top_acceleration, delta * (10 + (top_speed * 0.4)))

	# 2. Context Steering: Evaluate all directions and pick the best one
	var chosen_dir = _get_context_direction(world_goal_direction)
	
	# 3. Apply physics
	var desired_velocity = chosen_dir * speed
	var steer = (desired_velocity - velocity) * acceleration
	steer = steer.limit_length(steering_force)
	
	velocity += steer * delta
	move_and_slide()

func _get_context_direction(world_goal_direction: Vector3) -> Vector3:
	var interests = []
	var dangers = []
	interests.resize(num_rays)
	dangers.resize(num_rays)
	
	var space_state = get_world_3d().direct_space_state
	var current_speed = velocity.length()
	var sensor_dist = max(bot_radius * 6.0, current_speed * 1.5) # Increased minimum lookahead and speed scaling
	
	var current_heading = velocity.normalized()
	if current_heading.is_zero_approx():
		# If not moving, aim directly at the world goal direction
		current_heading = world_goal_direction
	
	# Create a basis that aligns Vector3.FORWARD with current_heading
	# This basis will transform our local ray_directions into world space,
	# making them relative to the bot's current movement direction.
	# Note: Basis.looking_at aligns -Z to target. We want local +Z to align with heading.
	var steering_basis: Basis
	if abs(current_heading.dot(Vector3.UP)) > 0.99:
		steering_basis = Basis.looking_at(-current_heading, Vector3.FORWARD)
	else:
		steering_basis = Basis.looking_at(-current_heading, Vector3.UP)
	
	# Calculate Interest (How much does this ray point toward our goal?)
	for i in range(num_rays):
		# Transform the local ray_direction into world space
		var world_ray_dir = steering_basis * ray_directions[i]
		interests[i] = max(0.0, world_ray_dir.dot(world_goal_direction))
	
	# Calculate Danger (Is there an obstacle in this ray?)
	var shape = SphereShape3D.new()
	shape.radius = bot_radius
	
	for i in range(num_rays):
		var world_ray_dir = steering_basis * ray_directions[i]
		var params = PhysicsShapeQueryParameters3D.new()
		params.shape = shape
		params.collision_mask = 1
		params.exclude = [get_rid()]
		
		# Cast the sphere forward in this ray's direction
		params.transform = Transform3D(Basis(), global_position)
		params.motion = world_ray_dir * sensor_dist
		
		var motion_result = space_state.cast_motion(params)
		if motion_result.is_empty():
			dangers[i] = 1.0 # Immediate collision or stuck
		elif motion_result[0] < 1.0:
			# The smaller the safe fraction, the higher the danger
			dangers[i] = 1.0 - motion_result[0]
		else:
			# Virtual Boundary Danger: Keep the bot from steering out of the "Swiss Cheese" tunnel
			# by treating the X/Y bounds as invisible obstacles.
			var ray_end = global_position + world_ray_dir * sensor_dist
			if abs(ray_end.x) > Main.world.X_SIZE or abs(ray_end.y) > Main.world.Y_SIZE:
				dangers[i] = 0.9 # High danger, slightly lower than physical walls
			else:
				dangers[i] = 0.0
	# Choose best direction: High interest, low danger
	var result_dir = Vector3.ZERO
	for i in range(num_rays):
		var world_ray_dir = steering_basis * ray_directions[i]
		
		# Score this direction: combination of how much we want to go there vs how dangerous it is
		# We square the safety factor (1.0 - danger) to make the bot avoid obstacles 
		# much more aggressively as they get closer.
		var score = interests[i] * pow(1.0 - dangers[i], 2.0)
		result_dir += world_ray_dir * score

		# Debug visualization
		if dangers[i] > 0.0: # If there's any danger, draw it
			DebugDraw3D.draw_ray(global_position, world_ray_dir, sensor_dist * dangers[i], Color.RED)
		else: # Otherwise, draw interest
			DebugDraw3D.draw_ray(global_position, world_ray_dir, sensor_dist * interests[i] * 0.5, Color.GREEN) # Green for clear paths, scaled by interest
	
	if result_dir.is_zero_approx():
		return world_goal_direction
		
	var final_dir = result_dir.normalized()
	DebugDraw3D.draw_ray(global_position, final_dir, 10.0, Color.CYAN)
	return final_dir
