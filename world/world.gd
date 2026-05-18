class_name World extends Node3D

const X_SIZE = 8
const Y_SIZE = 8

var track_length := 500
const VOXEL_SIZE = 1

var server_random := RandomNumberGenerator.new()

var voxel_grid: Dictionary = {} # Vector3i -> bool
var safe_path: Array[Vector3] = [] # Pre-calculated safe points

var loading_gate = NetworkGate.new("Loading")
var post_gen_gate = NetworkGate.new("PostGeneration")

func _ready() -> void:
	seed(Global.game_seed)
	
	add_child(loading_gate)
	add_child(post_gen_gate)
	
	# TODO when some1 tries to join, host gets this error E 0:00:04:732 world.gd:27 @ _on_everyone_loaded(): Signal 'all_players_ready' is already connected to given callable
	# CONNECT_ONE_SHOT fixes but idk why
	
	loading_gate.all_players_ready.connect(_on_everyone_loaded, CONNECT_ONE_SHOT)
	loading_gate.start_check()
	
func _on_everyone_loaded():
	generate()

	# Wait a frame to ensure all generated geometry is fully in the scene tree and ready for physics queries. 
	await get_tree().physics_frame
	
	bake_voxels()
	# Now that we have the voxel grid, we can calculate the safe path for the bots to follow. This ensures they won't get stuck on obstacles and provides a more consistent racing line.
	find_safe_path()
	
	post_gen_gate.all_players_ready.connect(_on_everyone_finished_gen, CONNECT_ONE_SHOT)
	post_gen_gate.start_check()

func _on_everyone_finished_gen():
	printt(multiplayer.get_unique_id(), "Everyone has geometry! Spawning players now...")
	
	if multiplayer.is_server():
		#add_player(1)
		for peer in multiplayer.get_peers():
			add_player(peer)
		
		# Spawn a few AI bots for testing
		for i in range(1):
			add_bot("Bot_" + str(i))
		
func _on_everyone_spawned():
	pass

func add_bot(bot_name: String):
	var bot = preload("res://player/bot_player.tscn").instantiate()
	bot.name = bot_name
	add_child.call_deferred(bot)

# the multiplayerspawner will spawn the players automatically as long as the host has them in the scenetree
func add_player(id):
	assert(is_multiplayer_authority())
	#Notifications.notify(multiplayer.get_unique_id() , "add_player", id)
	
	var player = preload("res://player/player.tscn").instantiate()
	player.name = str(id)
	add_child.call_deferred(player)

func bake_voxels():
	printt(multiplayer.get_unique_id(), "Baking voxel grid...")
	voxel_grid.clear()
	
	# Ensure physics is synced before querying
	var space_state = get_world_3d().direct_space_state

	var box_shape = BoxShape3D.new()
	# Use full size to ensure no gaps in detection
	box_shape.size = Vector3.ONE * VOXEL_SIZE

	var query = PhysicsShapeQueryParameters3D.new()
	query.shape = box_shape
	query.collision_mask = 1
	query.margin = 0.0 # Remove margin for exact volume checking
	
	# Offset the loop so probes are centered in the grid cells
	var offset = VOXEL_SIZE / 2.0
	for z in range(0, track_length + 50, VOXEL_SIZE):
		for x in range(-X_SIZE, X_SIZE, VOXEL_SIZE):
			for y in range(-Y_SIZE, Y_SIZE, VOXEL_SIZE):
				var v_world_pos = Vector3(x + offset, y + offset, z + offset)
				var v_key = Vector3i(
					floori(v_world_pos.x / VOXEL_SIZE),
					floori(v_world_pos.y / VOXEL_SIZE),
					floori(v_world_pos.z / VOXEL_SIZE)
				)
				
				query.transform = Transform3D(Basis(), v_world_pos)
				var hits = space_state.intersect_shape(query, 1)
				if not hits.is_empty():
					voxel_grid[v_key] = true

func find_safe_path():
	printt(multiplayer.get_unique_id(), "Calculating safe backbone path...")
	safe_path.clear()
	var last_pos = Vector2.ZERO
	
	# 1. Generate the raw greedy path
	for z in range(0, track_length + 50, VOXEL_SIZE):
		var best_xy = last_pos
		var max_score = - INF
		
		for x in range(-X_SIZE, X_SIZE + 1, VOXEL_SIZE):
			for y in range(-Y_SIZE, Y_SIZE + 1, VOXEL_SIZE):
				var v = Vector3i(x / VOXEL_SIZE, y / VOXEL_SIZE, z / VOXEL_SIZE)
				
				if not is_voxel_occupied(v):
					var clearance = 0
					for ox in range(-1, 2):
						for oy in range(-1, 2):
							if not is_voxel_occupied(v + Vector3i(ox, oy, 0)):
								clearance += 1
					
					var dist_from_prev = last_pos.distance_to(Vector2(x, y))
					var dist_from_center = Vector2(x, y).length()
					
					# NEW SCORING: 
					# - High penalty for jumping far from the previous point (Continuity)
					# - Slight penalty for being far from center (stays in middle of tunnel)
					# - Clearance is important, but not enough to justify a huge jump
					var score = (clearance * 20.0)
					score -= (dist_from_prev * 60.0) # Heavy penalty for twitchy X/Y jumps
					score -= (dist_from_center * 1.5)
					
					if score > max_score:
						max_score = score
						best_xy = Vector2(x, y)
		
		safe_path.append(Vector3(best_xy.x, best_xy.y, z))
		last_pos = best_xy

	# 2. Smoothing Pass (Box Filter)
	var raw_path = safe_path.duplicate()
	var smoothing_window = 5 # Larger window for a more "flowing" racing line
	var smoothed_path: Array[Vector3] = []
	
	for i in range(raw_path.size()):
		var sum = Vector3.ZERO
		var count = 0
		for j in range(max(0, i - smoothing_window), min(raw_path.size(), i + smoothing_window + 1)):
			sum += raw_path[j]
			count += 1
		
		var avg = sum / count

		# 3. Iterative Constraint Satisfaction
		# Instead of snapping back to raw, lerp toward it until the 3x3 buffer is clear.
		var raw_safe_pos = raw_path[i]
		var final_pos = avg
		
		# Attempt to find the smoothest point that is also safe
		for step in range(11): # Try 10 increments of "safety"
			var weight = step / 10.0
			var test_pos = avg.lerp(raw_safe_pos, weight)
			
			if _is_area_safe(test_pos, raw_path[i].z):
				final_pos = test_pos
				break
				
		# Maintain the original Z to ensure the bot doesn't slow down or speed up
		smoothed_path.append(Vector3(final_pos.x, final_pos.y, raw_path[i].z))
		
	safe_path = smoothed_path

func _is_area_safe(pos: Vector3, z_world: float) -> bool:
	for ox in range(-1, 2):
		for oy in range(-1, 2):
			var v = Vector3i(
				round(pos.x / VOXEL_SIZE) + ox,
				round(pos.y / VOXEL_SIZE) + oy,
				round(z_world / VOXEL_SIZE)
			)
			if is_voxel_occupied(v):
				return false
	return true

func get_safe_path_point(z_pos: float) -> Vector3:
	if safe_path.is_empty():
		return Vector3(0, 0, z_pos)
	
	# Map Z world position to path index
	var index = clampi(int(z_pos / VOXEL_SIZE), 0, safe_path.size() - 1)
	return safe_path[index]

func is_voxel_occupied(v: Vector3i) -> bool:
	# 1. Check world bounds (Tunnel walls)
	if abs(v.x * VOXEL_SIZE) > X_SIZE or abs(v.y * VOXEL_SIZE) > Y_SIZE:
		return true
	
	# 2. Check baked obstacles
	return voxel_grid.has(v)

func generate() -> void:
	printt(multiplayer.get_unique_id(), "is generating")
	
	var scenes = [
		preload("res://pieces/cube1.blend"),
		preload("res://pieces/cube2.blend"),
	]
	
	# Random spread around the center path.
	var x_range := Vector2(-X_SIZE - 6.5, X_SIZE + 6.5)
	var y_range := Vector2(-Y_SIZE - 6.5, Y_SIZE + 6.5)

	
	var z_spacing := 4.15
	
	for i in track_length:
		var x := randf_range(x_range.x, x_range.y)
		var y := randf_range(y_range.x, y_range.y)
		var z := 50 + (i * z_spacing)
		if z > track_length: break

		var block_scene = scenes.pick_random()
		var block = block_scene.instantiate()
		add_child(block)
		block.name = "cube_" + str(i) # Ensure we can identify them for baking
		block.position = Vector3(x, y, z)

		# Random rotation helps break up obvious repetition.
		block.rotation = Vector3(
			randf_range(0.0, TAU),
			randf_range(0.0, TAU),
			randf_range(0.0, TAU)
		)
	
				# Position strength from center to edge
		var edge_x = abs(x) / X_SIZE
		var edge_y = abs(y) / Y_SIZE

		# Use whichever axis is closer to the edge
		var edge_factor = max(edge_x, edge_y)

		# Smooth the growth so it ramps up nicer
		edge_factor = pow(edge_factor, 2.0)

		# Scale range
		var min_scale := 1.5
		var max_scale := 2.3

		# Interpolate scale based on edge distance
		var scale_mul := lerpf(min_scale, max_scale, edge_factor)

		# Optional randomness so sizes are less uniform
		scale_mul *= randf_range(0.85, 1.15)

		block.scale = Vector3.ONE * scale_mul
		
		## spawn gem (independent roll)
		#if multiplayer.is_server():
			#if server_random.randf() < 0.1:
				#var gem = preload("res://world/gem.tscn").instantiate()
				#add_child.call_deferred(gem, true)
				#gem.position = Vector3(server_random.randf_range(-X_SIZE, X_SIZE), server_random.randf_range(-Y_SIZE, Y_SIZE), z)
			#
			#if server_random.randf() < 0.05:
				#var asteroid = preload("res://world/asteroid.tscn").instantiate()
				#add_child.call_deferred(asteroid, true)
#
				#asteroid.position = Vector3(server_random.randf_range(-X_SIZE, X_SIZE), server_random.randf_range(-Y_SIZE, Y_SIZE), z)
	#

func _process(delta: float) -> void:
	var x = X_SIZE
	var y = Y_SIZE
	var z = 99999
	var c = Color(3.746, 3.746, 3.266, 1.0)
	DebugDraw3D.draw_line(Vector3(x, y, 0), Vector3(x, y, z), c)
	DebugDraw3D.draw_line(Vector3(-x, y, 0), Vector3(-x, y, z), c)
	DebugDraw3D.draw_line(Vector3(x, -y, 0), Vector3(x, -y, z), c)
	DebugDraw3D.draw_line(Vector3(-x, -y, 0), Vector3(-x, -y, z), c)
	
	_draw_voxel_debug()
	
	if get_viewport().get_camera_3d():
		DebugDraw2D.set_text("cam pos", get_viewport().get_camera_3d().global_position)
	
	# Draw the safe backbone path
	if not safe_path.is_empty():
		DebugDraw3D.draw_line_path(safe_path, Color.CYAN)

func _draw_voxel_debug():
	# To keep FPS high, only draw voxels near the camera or lead player
	var lead = get_first_place()
	var cam = get_viewport().get_camera_3d()
	var reference_pos = cam.global_position if cam else (lead.global_position if lead else Vector3.ZERO)
	
	var view_distance = 100.0
	
	for v in voxel_grid:
		var world_pos = Vector3(v) * VOXEL_SIZE
		if world_pos.distance_to(reference_pos) < view_distance:
			# We use the VOXEL_SIZE for both position and box scale
			DebugDraw3D.draw_box(world_pos, Quaternion.IDENTITY, Vector3.ONE * VOXEL_SIZE, Color(1, 0, 0, 0.15), true)

func get_first_place() -> Player:
	var lead_player: Player = null
	var max_z: float = - INF # Start at negative infinity
	
	# We use get_tree().get_nodes_in_group() or loop through children 
	# to make sure we include the Host and the Clients.
	for player in get_tree().get_nodes_in_group("player"):
		if player is Player:
			if player.global_position.z > max_z:
				max_z = player.global_position.z
				lead_player = player
				
	return lead_player

func get_player(id: int) -> Player:
	return get_node_or_null(str(id))
