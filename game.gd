class_name Game extends Node3D

const X_SIZE = 8
const Y_SIZE = 8


static var game : Game

var server_random := RandomNumberGenerator.new()

func _init() -> void:
	game=self

func _ready() -> void:
	seed(Global.game_seed)
	
	generate()
	
	if NetworkManager.is_host():
		add_player(1)
		for peer in multiplayer.get_peers():
			add_player(peer)

# the multiplayerspawner will spawn the players automatically as long as the host has them in the scenetree
func add_player(id):
	assert(is_multiplayer_authority())
	Notifications.notify(multiplayer.get_unique_id() , "add_player", id)
	
	var player = preload("res://player.tscn").instantiate()
	player.name = str(id)
	add_child.call_deferred(player)

func generate() -> void:
	
	var scenes = [
		preload("res://pieces/cube1.blend"),
		preload("res://pieces/cube2.blend"),
	]
	
	# Random spread around the center path.
	var x_range := Vector2(-X_SIZE, X_SIZE)
	var y_range := Vector2(-Y_SIZE, Y_SIZE)

	
	var z_spacing := 6
	var random_scale := Vector2(1.3, 2)
	
	for i in 3000:
		var block_scene = scenes.pick_random()
		
		var block = block_scene.instantiate()
		add_child(block)

		var x := randf_range(x_range.x, x_range.y)
		var y := randf_range(y_range.x, y_range.y)
		var z := 50 + (i * z_spacing)

		block.position = Vector3(x, y, z)

		# Random rotation helps break up obvious repetition.
		block.rotation = Vector3(
			randf_range(0.0, TAU),
			randf_range(0.0, TAU),
			randf_range(0.0, TAU)
		)
	
		# Slight size variation makes the tunnel feel more natural.
		var scale_mul := randf_range(random_scale.x, random_scale.y)
		block.scale = Vector3.ONE * scale_mul
		
		# spawn gem (independent roll)
		if NetworkManager.is_host():
			if server_random.randf() < 0.05:
				var gem = preload("res://gem.tscn").instantiate()
				add_child.call_deferred(gem, true)

				gem.position = Vector3(server_random.randf_range(-X_SIZE, X_SIZE), server_random.randf_range(-Y_SIZE, Y_SIZE), z)
			

func _process(delta: float) -> void:

	var x = X_SIZE
	var y = Y_SIZE
	var z = 99999
	var c = Color(3.746, 3.746, 3.266, 1.0)
	DebugDraw3D.draw_line(Vector3(x,y, 0), Vector3(x,y, z), c)
	DebugDraw3D.draw_line(Vector3(-x,y, 0), Vector3(-x,y, z), c)
	DebugDraw3D.draw_line(Vector3(x,-y, 0), Vector3(x,-y, z), c)
	DebugDraw3D.draw_line(Vector3(-x,-y, 0), Vector3(-x,-y, z), c)
	
