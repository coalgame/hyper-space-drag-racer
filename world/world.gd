class_name World extends Node3D

const X_SIZE = 8
const Y_SIZE = 8

var track_length := 5000

var server_random: RandomNumberGenerator

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
	
	post_gen_gate.all_players_ready.connect(_on_everyone_finished_gen, CONNECT_ONE_SHOT)
	post_gen_gate.start_check()

func _on_everyone_finished_gen():
	printt(multiplayer.get_unique_id(), "Everyone has geometry! Spawning players now...")
	
	if not multiplayer.is_server():
		return

	var p_ids = NetworkManager.players.keys()
	p_ids.sort()
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
	# We leave a margin from the walls (X_SIZE=8) to avoid instant collisions.
	var available_width = (X_SIZE * 2.0) - 4.0
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
	
	if multiplayer.is_server():
		server_random = RandomNumberGenerator.new()
		server_random.seed = Global.game_seed
	
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
		if multiplayer.is_server():
			if server_random.randf() < 0.1:
				var gem = preload("res://world/gem.tscn").instantiate()
				add_child.call_deferred(gem, true)
				gem.position = Vector3(server_random.randf_range(-X_SIZE, X_SIZE), server_random.randf_range(-Y_SIZE, Y_SIZE), z)
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
	var z = 9999
	var c = Color(3.746, 3.746, 3.266, 1.0)
	DebugDraw3D.draw_line(Vector3(x, y, 0), Vector3(x, y, z), c)
	DebugDraw3D.draw_line(Vector3(-x, y, 0), Vector3(-x, y, z), c)
	DebugDraw3D.draw_line(Vector3(x, -y, 0), Vector3(x, -y, z), c)
	DebugDraw3D.draw_line(Vector3(-x, -y, 0), Vector3(-x, -y, z), c)
	
	if get_viewport().get_camera_3d():
		DebugDraw2D.set_text("cam pos", get_viewport().get_camera_3d().global_position)

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
