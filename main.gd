class_name Main extends Node

static var instance: Main
static var world: World

func _init() -> void:
	instance = self

@rpc("call_local")
func start_world(game_seed: int = randi()):
	Notifications.notify("Starting world...")
	Global.game_seed = game_seed
	
	$MainMenu.hide()
	
	if multiplayer.is_server():
		multiplayer.multiplayer_peer.refuse_new_connections = true

		if world:
			world.queue_free()
		
		world = load("res://world/world.tscn").instantiate()
		add_child.call_deferred(world)


func exit_world():
	print("exiting world...")

	UIManager.clear_all_screens()
	
	NetworkManager.disconnect_from_game()
	
	if world:
	
		# Stop all processing immediately. This prevents race conditions where 
		# nodes (like the Player) try to run physics code while being deleted.
		world.process_mode = Node.PROCESS_MODE_DISABLED
		# The multiplayerspawner's opinions don't matter here, if we're the client, we are disconnected from the server and won't receive any despawn signals, so we have to free the world ourselves. 
		world.queue_free.call_deferred()
	
	$MainMenu.open()
	

@rpc("call_local", "reliable")
func back_to_lobby():
	NetworkManager._log("returning to lobby...")

	UIManager.clear_all_screens()
	
	if world:
		# Stop all processing immediately to prevent race conditions during deletion.
		world.process_mode = Node.PROCESS_MODE_DISABLED
		if multiplayer.is_server():
			multiplayer.multiplayer_peer.refuse_new_connections = false

			# The MultiplayerSpawner will automatically trigger despawn signals on clients.
			# we get some dumb error here because of the players getting freed, doesnt seem to harm the game tho
			# https://github.com/godotengine/godot/issues/101847
			world.queue_free.call_deferred()
	
	$MainMenu.open()


# client: cache world reference
func _on_world_spawner_spawned(node: Node) -> void:
	world = node # TODO when does this get called exactly? could we crash if something else tries to access world before its spawned? is that even possible?

# client: delete cached referenece (worldspawner handles queuefree)
func _on_world_spawner_despawned(_node: Node) -> void:
	world = null
