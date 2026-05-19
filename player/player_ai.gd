class_name PlayerAI extends Node

var testing_mode := false

var difficulty := 8.0 # 0 to 10
var knockback_multiplier := 1.0
var speed_multiplier := 1.0

var bot_radius := 0.5
var cone_angle_degrees := 80.0
var cone_resolution := 0.15
var num_rays := 0
var ray_directions: Array[Vector3] = []

static var all_test_results: Array = []

@onready var player: Player = get_parent()

func _ready() -> void:
	# Use a local RNG seeded by name so each bot has a unique, persistent personality
	var rng = RandomNumberGenerator.new()
	rng.seed = player.name.hash()
	
	var global_diff = Global.get("difficulty")
	if global_diff != null:
		difficulty = global_diff

	knockback_multiplier = (-0.12 * difficulty) + 1.2
	speed_multiplier = (0.42 * difficulty) + 0.8
	#printt(knockback_multiplier, speed_multiplier)
	# Adjust personality based on difficulty
#	cone_angle_degrees += rng.randf_range(-25.0, 25.0) * (1.0 / max(0.1, difficulty)) # Harder AI has less random cone angle
#	cone_resolution = clamp(cone_resolution + rng.randf_range(-0.1, 0.1) * (1.0 / max(0.1, difficulty)), 0.15, 0.5) # Harder AI has more precise rays

	_generate_ray_directions(rng)
	
	# Initialize bot identity and visuals
	player.player_color = ProfileManager.PRESET_COLORS[rng.randi() % ProfileManager.PRESET_COLORS.size()]
	player.player_name = player.name

func _generate_ray_directions(rng: RandomNumberGenerator = null) -> void:
	ray_directions.clear()
	var cone_angle_rad = deg_to_rad(cone_angle_degrees)
	var current_angle_x = - cone_angle_rad / 2.0
	var jitter := 0.1
	while current_angle_x <= cone_angle_rad / 2.0:
		var current_angle_y = - cone_angle_rad / 2.0
		while current_angle_y <= cone_angle_rad / 2.0:
			var j_x = current_angle_x + (rng.randf_range(-jitter, jitter) if rng else 0.0)
			var j_y = current_angle_y + (rng.randf_range(-jitter, jitter) if rng else 0.0)
			
			var dir = Vector3(sin(j_x), sin(j_y), cos(j_x) * cos(j_y)).normalized()
			ray_directions.append(dir)
			current_angle_y += cone_resolution
		current_angle_x += cone_resolution
	num_rays = ray_directions.size()

func get_input() -> Vector2:
	var world_goal_direction = Vector3(0, 0, 1)
	var space_state = player.get_world_3d().direct_space_state
	
	var closest_gem: Node3D = null
	var min_gem_dist := 20.0
	for gem in get_tree().get_nodes_in_group("gem"):
		var dist = player.global_position.distance_to(gem.global_position)
		if dist < min_gem_dist and gem.global_position.z > player.global_position.z:
			var ray_params = PhysicsRayQueryParameters3D.create(player.global_position, gem.global_position)
			ray_params.collision_mask = 1
			ray_params.exclude = [player.get_rid()]
			var result = space_state.intersect_ray(ray_params)
			if result.is_empty():
				min_gem_dist = dist
				closest_gem = gem
	
	if closest_gem:
		world_goal_direction = (closest_gem.global_position - player.global_position).normalized()

	if abs(player.global_position.x) > World.X_SIZE * 0.7:
		world_goal_direction.x = - sign(player.global_position.x) * 0.5
	if abs(player.global_position.y) > World.Y_SIZE * 0.7:
		world_goal_direction.y = - sign(player.global_position.y) * 0.5
	
	var interests = []
	var dangers = []
	interests.resize(num_rays)
	dangers.resize(num_rays)
	
	var sensor_dist = max(bot_radius * 6.0, player.speed * 1.5)
	var steering_basis = player.global_transform.basis
	
	for i in range(num_rays):
		var world_ray_dir = steering_basis * ray_directions[i]
		interests[i] = max(0.0, world_ray_dir.dot(world_goal_direction))
		
		var params = PhysicsShapeQueryParameters3D.new()
		params.shape = SphereShape3D.new()
		params.shape.radius = bot_radius
		params.collision_mask = 1
		params.exclude = [player.get_rid()]
		params.transform = Transform3D(Basis(), player.global_position)
		params.motion = world_ray_dir * sensor_dist
		
		var motion_result = space_state.cast_motion(params)
		if motion_result.is_empty(): dangers[i] = 1.0
		elif motion_result[0] < 1.0: dangers[i] = 1.0 - motion_result[0]
		else:
			var ray_end = player.global_position + world_ray_dir * sensor_dist
			if abs(ray_end.x) > World.X_SIZE or abs(ray_end.y) > World.Y_SIZE: dangers[i] = 0.9
			else: dangers[i] = 0.0

	var chosen_dir = Vector3.ZERO
	for i in range(num_rays):
		chosen_dir += (steering_basis * ray_directions[i]) * (interests[i] * pow(1.0 - dangers[i], 2.0))
	
	var local_dir = chosen_dir.normalized()

	if testing_mode:
		DebugDraw3D.draw_ray(player.global_position, world_goal_direction, 5.0, Color.AQUA)
		if closest_gem: DebugDraw3D.draw_line(player.global_position, closest_gem.global_position, Color.AQUA)
		for i in range(num_rays):
			var weight = interests[i] * pow(1.0 - dangers[i], 2.0)
			if weight > 0.1 or dangers[i] > 0.7:
				var ray_color = Color.GREEN.lerp(Color.RED, dangers[i])
				DebugDraw3D.draw_ray(player.global_position, steering_basis * ray_directions[i], 3.0, ray_color)
		DebugDraw3D.draw_arrow(player.global_position, player.global_position + local_dir * 5.0, Color.YELLOW, 0.5)

	return Vector2(local_dir.x, local_dir.y)

func get_speed_multiplier() -> float:
	# Base speed multiplier, adjusted by difficulty
	var mult = speed_multiplier # * (1.0 + (difficulty - 1.0) * 0.2) # +20% speed for each +1 difficulty
	#mult = clamp(mult, 0.5, 5.0) # Clamp to reasonable range

	#if is_instance_valid(Main.world):
		#var leader = Main.world.get_first_place()
		#if is_instance_valid(leader):
			#if leader != player:
				#var dist_behind = leader.global_position.z - player.global_position.z
				#mult += clamp(dist_behind / 250.0, 0.0, 1.0)
			#else: mult *= 0.85
	return mult

func log_results() -> void:
	var duration = (Time.get_ticks_msec() - player.start_time) / 1000.0
	
	# Also log difficulty for analysis
	all_test_results.append({
		"duration": duration,
		"collisions": player.collision_count,
		"difficulty": difficulty
	})
	print("--- AI TEST RESULTS [%s] ---" % player.player_name)
	print("Map length: ", Main.world.track_length)
	print("Seed: ", Global.game_seed)

	print("Time: %.3fs" % duration)
	print("Collisions: %d" % player.collision_count)
	print("Difficulty: %.1f" % difficulty)
	
	print("Cone res: ", cone_resolution)
	print("Cone angle: ", cone_angle_degrees)
	print("---------------------------")

	# Check if all participating bots have finished to print the average
	var testing_bots = get_tree().get_nodes_in_group("player").filter(
		func(p): return p.is_ai and p.ai_brain #and p.ai_brain.testing_mode
	)
	
	if all_test_results.size() >= testing_bots.size():
		var total_time := 0.0
		var total_collisions := 0
		for res in all_test_results:
			total_time += res.duration
			total_collisions += res.collisions
		
		print("\n=== FINAL AI AVERAGE RESULTS (%d BOTS) ===" % all_test_results.size())
		print("Average Time: %.3fs" % (total_time / all_test_results.size()))
		print("Average Collisions: %.2f" % (float(total_collisions) / all_test_results.size()))
		print("==========================================\n")
		all_test_results.clear()

func get_crash_knockback_multiplier() -> float:
	return knockback_multiplier
