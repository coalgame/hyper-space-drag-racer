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
		if world:
			world.queue_free()
		
		world = load("res://world/world.tscn").instantiate()
		add_child.call_deferred(world)


@rpc("call_local")
func exit_world():
	NetworkManager._log("exiting world...")

	UIManager.clear_all_screens()
	
	if world:
		world.queue_free.call_deferred()
	
	$MainMenu.open()
	

# client: cache world reference
func _on_world_spawner_spawned(node: Node) -> void:
	world = node # TODO when does this get called exactly? could we crash if something else tries to access world before its spawned? is that even possible?

# client: delete cached referenece (worldspawner handles queuefree)
func _on_world_spawner_despawned(_node: Node) -> void:
	world = null
