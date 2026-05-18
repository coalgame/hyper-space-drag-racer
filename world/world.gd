class_name World extends Node3D

const X_SIZE = 8
const Y_SIZE = 8

var track_length := 3500
const VOXEL_SIZE = 2

var server_random := RandomNumberGenerator.new()

var voxel_grid: Dictionary = {} # Vector3i -> bool (Now stores REACHABLE voxels)
var safe_path = []

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
	#	add_player(1)
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
	box_shape.size = Vector3.ONE * (VOXEL_SIZE * 0.95)

	var query = PhysicsShapeQueryParameters3D.new()
	query.shape = box_shape
	query.collision_mask = 1
	query.margin = 0.0

	# Flood Fill (BFS) starting from 0,0,0
	var start_v = Vector3i(0, 0, 0)
	var queue: Array[Vector3i] = [start_v]
	voxel_grid[start_v] = true # Mark as reachable

	var head = 0
	while head < queue.size():
		var current = queue[head]
		head += 1

		# Check 6 neighbors (Up, Down, Left, Right, Forward, Back)
		for dir in [Vector3i.FORWARD, Vector3i.BACK, Vector3i.LEFT, Vector3i.RIGHT, Vector3i.UP, Vector3i.DOWN]:
			var next = current + dir
			
			# 1. Stay within tunnel bounds and track length
			if abs(next.x * VOXEL_SIZE) > X_SIZE or abs(next.y * VOXEL_SIZE) > Y_SIZE:
				continue
			if next.z < 0 or next.z * VOXEL_SIZE > track_length + 50:
				continue
				
			# 2. Skip if already visited
			if voxel_grid.has(next):
				continue

			# 3. Physics check: Is this specific neighbor blocked?
			query.transform = Transform3D(Basis(), Vector3(next) * VOXEL_SIZE)
			var hits = space_state.intersect_shape(query, 1)
			
			if hits.is_empty():
				voxel_grid[next] = true
				queue.push_back(next)

	printt("Bake complete. Reachable voxels:", voxel_grid.size())

func is_voxel_occupied(v: Vector3i) -> bool:
	# If it's in the grid, it was reached by the flood fill, meaning it's NOT occupied.
	# If it's NOT in the grid, it's either outside the tunnel or inside an object.
	if not voxel_grid.has(v):
		return true
	return false

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


func find_safe_path() -> void:
	safe_path.clear()
	var z_max = floori(track_length / float(VOXEL_SIZE))
	
	for vz in range(0, z_max, 3):  # every 3 voxels is fine
		var best: Vector3i
		var best_dist = INF
		
		for vx in range(-X_SIZE, X_SIZE + 1):
			for vy in range(-Y_SIZE, Y_SIZE + 1):
				var v = Vector3i(vx, vy, vz)
				if voxel_grid.has(v):
					var dist = Vector2(vx, vy).length()
					if dist < best_dist:
						best_dist = dist
						best = v
		
		if best_dist < INF:
			safe_path.append(Vector3(best) * VOXEL_SIZE)
			
	safe_path=smooth_path(safe_path)
func smooth_path(path: Array, iterations: int = 3) -> Array:
	var result = path.duplicate()
	for _i in iterations:
		var smoothed = [result[0]]
		for j in range(1, result.size() - 1):
			var candidate = (result[j-1] + result[j] + result[j+1]) / 3.0
			var voxel = Vector3i(candidate / VOXEL_SIZE)
			# only accept the smoothed point if it's free
			if voxel_grid.has(voxel):
				smoothed.append(candidate)
			else:
				smoothed.append(result[j])  # keep original if smoothed is blocked
		smoothed.append(result[-1])
		result = smoothed
	return result
	
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
	return
	# To keep FPS high, only draw voxels near the camera or lead player
	var lead = get_first_place()
	var cam = get_viewport().get_camera_3d()
	var reference_pos = cam.global_position if cam else (lead.global_position if lead else Vector3.ZERO)
	
	var view_distance = 30.0
	
	# Define the iteration range for voxel keys (v.x, v.y, v.z)
	var vx_min = floori(-X_SIZE / float(VOXEL_SIZE))
	var vx_max = floori(X_SIZE / float(VOXEL_SIZE))
	var vy_min = floori(-Y_SIZE / float(VOXEL_SIZE))
	var vy_max = floori(Y_SIZE / float(VOXEL_SIZE))
	var vz_min = 0
	var vz_max = floori((track_length + 50) / float(VOXEL_SIZE))

	for vx in range(vx_min, vx_max + 1):
		for vy in range(vy_min, vy_max + 1):
			for vz in range(vz_min, vz_max + 1):
				var v_key = Vector3i(vx, vy, vz)
				var world_pos = Vector3(v_key) * VOXEL_SIZE
				
				# Apply view_distance optimization
				if world_pos.distance_to(reference_pos) < view_distance:
					# Draw only if the voxel is considered occupied
					if is_voxel_occupied(v_key):
						DebugDraw3D.draw_box(world_pos, Quaternion.IDENTITY, Vector3.ONE * VOXEL_SIZE, Color(1, 0, 0, 0.15), true)
						DebugDraw3D.draw_sphere(world_pos, 0.1)

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
