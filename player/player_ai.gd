class_name PlayerAI extends Node

var testing_mode := false

var difficulty := 8.0 # 0 to 10
var knockback_multiplier := 1.0
var speed_multiplier := 1.0

var bot_radius := 0.5
var cone_angle_degrees := 60.0
var cone_resolution := 0.25
var num_rays := 0
var ray_directions: Array[Vector3] = []

var interests: Array[float] = []
var dangers: Array[float] = []

var shape_params: PhysicsShapeQueryParameters3D
var avoid_shape: SphereShape3D
var gem_ray_params: PhysicsRayQueryParameters3D

var logic_tick := 0
var cached_input := Vector2.ZERO
var target_gem: Node3D = null

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
	#speed_multiplier = (0.42 * difficulty) + 0.8
	
	#printt(knockback_multiplier, speed_multiplier)
	# Adjust personality based on difficulty
#	cone_angle_degrees += rng.randf_range(-25.0, 25.0) * (1.0 / max(0.1, difficulty)) # Harder AI has less random cone angle
#	cone_resolution = clamp(cone_resolution + rng.randf_range(-0.1, 0.1) * (1.0 / max(0.1, difficulty)), 0.15, 0.5) # Harder AI has more precise rays

	_generate_ray_directions(rng)
	
	# Pre-allocate physics objects to avoid per-frame GC pressure
	avoid_shape = SphereShape3D.new()
	avoid_shape.radius = bot_radius
	shape_params = PhysicsShapeQueryParameters3D.new()
	shape_params.shape = avoid_shape
	shape_params.collision_mask = 1
	
	gem_ray_params = PhysicsRayQueryParameters3D.create(Vector3.ZERO, Vector3.ZERO, 1, [player.get_rid()])

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
	interests.resize(num_rays)
	dangers.resize(num_rays)

func get_input() -> Vector2:
	logic_tick += 1
	
	# Only update steering every 3 frames to save CPU
	if logic_tick % 3 != 0:
		return cached_input

	var world_goal_direction = Vector3(0, 0, 1)
	var space_state = player.get_world_3d().direct_space_state
	var player_pos = player.global_position
	
	# Only search for gems every 10 frames
	#if logic_tick % 10 == 0:
	target_gem = null
	var min_gem_dist := 20.0
	for gem in get_tree().get_nodes_in_group("gem"):
		var dist = player_pos.distance_to(gem.global_position)
		if dist < min_gem_dist and gem.global_position.z > player_pos.z:
			gem_ray_params.from = player_pos
			gem_ray_params.to = gem.global_position
			var result = space_state.intersect_ray(gem_ray_params)
			if result.is_empty():
				min_gem_dist = dist
				target_gem = gem
	
	if target_gem:
		world_goal_direction = (target_gem.global_position - player_pos).normalized()

	var track_dims = Main.world.get_track_dimensions(player_pos.z)
	
	if abs(player_pos.x) > track_dims.x * 0.7:
		world_goal_direction.x = - sign(player_pos.x) * 0.5
	if abs(player_pos.y) > track_dims.y * 0.7:
		world_goal_direction.y = - sign(player_pos.y) * 0.5
	
	var steering_basis = player.global_transform.basis
	
	var sensor_dist = max(bot_radius * 6.0, player.speed * 1.5)
	
	for i in range(num_rays):
		var world_ray_dir = steering_basis * ray_directions[i]
		interests[i] = max(0.0, world_ray_dir.dot(world_goal_direction))
		
		shape_params.transform = Transform3D(Basis(), player_pos)
		shape_params.motion = world_ray_dir * sensor_dist
		
		var motion_result = space_state.cast_motion(shape_params)
		if motion_result.is_empty(): dangers[i] = 1.0
		elif motion_result[0] < 1.0: dangers[i] = 1.0 - motion_result[0]
		else:
			var ray_end = player_pos + world_ray_dir * sensor_dist
			if abs(ray_end.x) > track_dims.x or abs(ray_end.y) > track_dims.y: dangers[i] = 0.9
			else: dangers[i] = 0.0

	var chosen_dir = Vector3.ZERO
	for i in range(num_rays):
		chosen_dir += (steering_basis * ray_directions[i]) * (interests[i] * pow(1.0 - dangers[i], 2.0))
	
	var local_dir = chosen_dir.normalized()

	if testing_mode:
		DebugDraw3D.draw_ray(player_pos, world_goal_direction, 5.0, Color.AQUA)
		if target_gem: DebugDraw3D.draw_line(player_pos, target_gem.global_position, Color.AQUA)
		for i in range(num_rays):
			var weight = interests[i] * pow(1.0 - dangers[i], 2.0)
			if weight > 0.1 or dangers[i] > 0.7:
				var ray_color = Color.GREEN.lerp(Color.RED, dangers[i])
				DebugDraw3D.draw_ray(player_pos, steering_basis * ray_directions[i], 3.0, ray_color)
		DebugDraw3D.draw_arrow(player_pos, player_pos + local_dir * 5.0, Color.YELLOW, 0.5)

	cached_input = Vector2(local_dir.x, local_dir.y)
	return cached_input

func get_speed_multiplier() -> float:
	return speed_multiplier

func log_results() -> void:
	pass
	#var duration = (Time.get_ticks_msec() - player.start_time) / 1000.0
	#
	## Also log difficulty for analysis
	#all_test_results.append({
		#"duration": duration,
		#"collisions": player.collision_count,
		#"difficulty": difficulty
	#})
	#print("--- AI TEST RESULTS [%s] ---" % player.player_name)
	#print("Map length: ", Main.world.track_length)
	#print("Seed: ", Global.game_seed)
#
	#print("Time: %.3fs" % duration)
	#print("Collisions: %d" % player.collision_count)
	#print("Difficulty: %.1f" % difficulty)
	#
	#print("Cone res: ", cone_resolution)
	#print("Cone angle: ", cone_angle_degrees)
	#print("---------------------------")
#
	## Check if all participating bots have finished to print the average
	#var testing_bots = get_tree().get_nodes_in_group("player").filter(
		#func(p): return p.is_ai and p.ai_brain # and p.ai_brain.testing_mode
	#)
	#
	#if all_test_results.size() >= testing_bots.size():
		#var total_time := 0.0
		#var total_collisions := 0
		#for res in all_test_results:
			#total_time += res.duration
			#total_collisions += res.collisions
		#
		#print("\n=== FINAL AI AVERAGE RESULTS (%d BOTS) ===" % all_test_results.size())
		#print("Average Time: %.3fs" % (total_time / all_test_results.size()))
		#print("Average Collisions: %.2f" % (float(total_collisions) / all_test_results.size()))
		#print("==========================================\n")
		#all_test_results.clear()

func get_crash_knockback_multiplier() -> float:
	return max(knockback_multiplier, 0.0)
