class_name World extends Node3D

var track_length := 500

var server_random: RandomNumberGenerator
var track_noise: FastNoiseLite

var loading_gate = NetworkGate.new("Loading")
var post_gen_gate = NetworkGate.new("PostGeneration")

func _ready() -> void:
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
	
	post_gen_gate.all_players_ready.connect(_on_everyone_finished_gen, CONNECT_ONE_SHOT)
	post_gen_gate.start_check()

func _on_everyone_finished_gen():
	printt(multiplayer.get_unique_id(), "Everyone has geometry! Spawning players now...")
	
	if not multiplayer.is_server():
		return
		
	var p_ids = NetworkManager.players.keys()
	p_ids.sort()
	if !NetworkManager.has_connection(): # is singleplayer
		p_ids = [1]
		
	var bot_count = max(0, NetworkManager.MAX_CLIENTS - p_ids.size())
	
	# Spawn human players (Host and Peers)
	for id in p_ids:
		add_player(id, get_spawn_position(str(id)))
		
	# Spawn Bots
	for i in range(bot_count):
		add_bot("BOT-" + str(i), get_spawn_position("BOT-" + str(i)))

# Humans: Occupy the first slots (0, 1, 2...) based on their Network ID.
# Bots: Occupy the remaining slots ($N, N+1...$) based on their name (BOT-0, BOT-1).
func get_spawn_position(node_name: String) -> Vector3:
	var p_ids = NetworkManager.players.keys()
	p_ids.sort() # the client can ask, "My name is '12345', what is my slot?" and calculate the exact same position the server did.
	
	var bot_count = max(0, NetworkManager.MAX_CLIENTS - p_ids.size())
	var total_count = p_ids.size() + bot_count
	
	# Calculate dynamic spacing to fit the track width (16m total)
	# We leave a margin from the walls to avoid instant collisions.
	var spawn_dims = get_track_dimensions(0) # Get dimensions at Z=0 for spawning
	var available_width = (spawn_dims.x * 2.0) - 4.0
	var spacing = 4.0 # Default max spacing for small groups
	if total_count > 1:
		spacing = min(4.0, available_width / float(total_count - 1))
		
	var start_x = - ((total_count - 1) * spacing) / 2.0
	
	var idx = -1
	if node_name.begins_with("BOT-"):
		# Bots are placed AFTER all human players
		idx = p_ids.size() + node_name.replace("BOT-", "").to_int()
	else:
		var id_int = node_name.to_int()
		idx = p_ids.find(id_int)
	
	if idx == -1:
		return Vector3.ZERO
		
	return Vector3(start_x + (float(idx) * spacing), 0, 0)

func get_track_dimensions(z_coord: float) -> Vector2:
	# Normalize noise from [-1, 1] to [0, 1]
	var raw_x = (track_noise.get_noise_1d(z_coord) + 1.0) / 2.0
	var raw_y = (track_noise.get_noise_1d(z_coord + 1000.0) + 1.0) / 2.0
	var x_size = lerp(4.0, 16.0, raw_x)
	var y_size = lerp(4.0, 14.0, raw_y)
	# Ensure minimum safety sizes
	x_size = max(x_size, 4.0)
	y_size = max(y_size, 4.0)
	return Vector2(x_size, y_size)
		
func _on_everyone_spawned():
	pass

func add_bot(bot_name: String, start_pos: Vector3):
	var bot: Player = preload("res://player/player.tscn").instantiate()
	bot.name = bot_name
	bot.position = start_pos
	add_child.call_deferred(bot)

# the multiplayerspawner will spawn the players automatically as long as the host has them in the scenetree
func add_player(id, start_pos: Vector3):
	assert(is_multiplayer_authority())
	#Notifications.notify(multiplayer.get_unique_id() , "add_player", id)
	
	var player = preload("res://player/player.tscn").instantiate()
	player.name = str(id)
	player.position = start_pos
	add_child.call_deferred(player)
	
func generate() -> void:
	printt(multiplayer.get_unique_id(), "is generating")

	seed(Global.game_seed)
	
	track_noise = FastNoiseLite.new()
	track_noise.seed = Global.game_seed
	track_noise.frequency = 0.001 # Controls how fast the track width/height changes
	
	if multiplayer.is_server():
		server_random = RandomNumberGenerator.new()
		server_random.seed = Global.game_seed
	
	var scenes = [
		preload("res://pieces/cube1.blend"),
		preload("res://pieces/cube2.blend"),
	]
	
	var z: float = 50.0
	for i in track_length:
		# Offset by 2000.0 to keep the noise independent from X and Y scaling
		var noise_val = (track_noise.get_noise_1d(z + 2000.0) + 1.0) / 2.0
		var current_z_spacing = lerp(3.0, 6.0, noise_val)
		
		z += current_z_spacing
		if z > track_length: break

		var current_track_dims = get_track_dimensions(z)
		var x := randf_range(-current_track_dims.x - 6.5, current_track_dims.x + 6.5)
		var y := randf_range(-current_track_dims.y - 6.5, current_track_dims.y + 6.5)

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
		var edge_x = abs(x) / current_track_dims.x
		var edge_y = abs(y) / current_track_dims.y

		# Use whichever axis is closer to the edge
		var edge_factor = max(edge_x, edge_y)
		# Smooth the growth so it ramps up nicer
		edge_factor = pow(edge_factor, 2.0)

		# Noise-based scale variation (independent from X/Y/Z scaling)
		var raw_scale_noise = (track_noise.get_noise_1d(z + 3000.0) + 1.0) / 2.0
		var scale_noise = clamp((raw_scale_noise - 0.5) * 1.5 + 0.5, 0.0, 1.0)
		
		# Base scale range (widened for more drastic look)
		var min_scale := 1.2
		var max_scale := 2.4

		# Interpolate scale based on edge distance
		var scale_mul := lerpf(min_scale, max_scale, edge_factor)
		scale_mul *= lerp(0.7, 1.5, scale_noise)

		block.scale = Vector3.ONE * scale_mul
		
		## spawn gem (independent roll)
		if multiplayer.is_server():
			if server_random.randf() < 0.1:
				var gem = preload("res://world/gem.tscn").instantiate()
				add_child.call_deferred(gem, true)
				gem.position = Vector3(server_random.randf_range(-current_track_dims.x, current_track_dims.x), server_random.randf_range(-current_track_dims.y, current_track_dims.y), z)


func _process(delta: float) -> void:
	var cam = get_viewport().get_camera_3d()
	if !cam:
		return
	
	DebugDraw2D.begin_text_group("world", 15, Color.LIGHT_YELLOW)
	DebugDraw2D.set_text("cam pos", cam.global_position)
	DebugDraw2D.set_text("track dimension", get_track_dimensions(cam.global_position.z))

	# Boundary corner lines visualization that follow the camera
	var z_cam = cam.global_position.z
	var line_color = Color(0.999, 1.0, 0.93, 0.149) # Glowing neon gold
	
	var seg_count = 60
	var step = 4.0
	var z_start = snappedf(z_cam - 20.0, step)
	
	var last_pts = []

	for i in range(seg_count):
		var z = z_start + (i * step)
		var d = get_track_dimensions(z)
		var curr_pts = [
			Vector3(-d.x, d.y, z),
			Vector3(d.x, d.y, z),
			Vector3(-d.x, -d.y, z),
			Vector3(d.x, -d.y, z)
		]

		if i > 0:
			var alpha_factor = 1.0 - (float(i) / seg_count)
			var color = line_color
			color.v *= pow(alpha_factor, 2.0) # Quadratic falloff for a smoother fade
			
			for j in range(4):
				DebugDraw3D.draw_line(last_pts[j], curr_pts[j], color)
		
		last_pts = curr_pts


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
