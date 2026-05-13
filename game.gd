class_name Game extends Node3D

static var game : Game


func _init() -> void:
	game=self

func _ready() -> void:
	seed(Global.game_seed)
	
	if NetworkManager.is_host():
		add_player(1)
		for i in len(multiplayer.get_peers()):
			var peer = multiplayer.get_peers()[i]
			add_player(peer)
			
	generate()
	

# the multiplayerspawner will spawn the players automatically as long as the host has them in the scenetree
func add_player(id):
	assert(is_multiplayer_authority())
	Notifications.notify(multiplayer.get_unique_id() , "add_player", id)
	
	var player = load("res://player.tscn").instantiate()
	player.name = str(id)
	add_child.call_deferred(player)

func generate() -> void:
	
	var scenes = [
		preload("res://pieces/cube1.blend"),
		preload("res://pieces/cube2.blend"),
		
	]
	# Random spread around the center path.
	var x_range := Vector2(-5.0, 5.0)
	var y_range := Vector2(-5.0, 5.0)

	
	var z_spacing := 5
	var random_scale := Vector2(0.8, 1.5)
	
	for i in 10000:
		var block_scene = scenes.pick_random()
		
		var block = block_scene.instantiate()
		add_child(block)

		var x := randf_range(x_range.x, x_range.y)
		var y := randf_range(y_range.x, y_range.y)
		var z := 20 + ( i * z_spacing)

		block.position = Vector3(x, y, -z)

		# Random rotation helps break up obvious repetition.
		block.rotation = Vector3(
			randf_range(0.0, TAU),
			randf_range(0.0, TAU),
			randf_range(0.0, TAU)
		)
	
		# Slight size variation makes the tunnel feel more natural.
		var scale_mul := randf_range(random_scale.x, random_scale.y)
		block.scale = Vector3.ONE * scale_mul
