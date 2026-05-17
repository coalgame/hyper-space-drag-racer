class_name Main extends Node

static var instance: Main
static var world: World

func _init() -> void:
	instance = self

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

func _on_peer_connected(id: int):
	# If a world exists on the server, a race is already in progress.
	if multiplayer.is_server() and world != null:
		_reject_joiner.rpc_id(id)

func _on_peer_disconnected(id: int):
	# If a race is in progress, find and remove the disconnected player's ship
	if is_instance_valid(world):
		var player_node = world.get_player(id)
		if player_node:
			player_node.queue_free()
			Notifications.notify("Player " + str(id) + " disconnected.")

@rpc("call_local")
func start_world(game_seed: int = randi()):
	Notifications.notify("Starting world...")
	Global.game_seed = game_seed
	
	$MainMenu.hide()
	
	if not multiplayer.is_server():
		return

	_cleanup_world()
	world = load("res://world/world.tscn").instantiate()
	add_child.call_deferred(world)


func exit_world():
	print("exiting world...")
	UIManager.clear_all_screens()
	NetworkManager.disconnect_from_game()
	_cleanup_world()
	$MainMenu.open()

@rpc("call_local", "reliable")
func back_to_lobby():
	NetworkManager._log("returning to lobby...")
	UIManager.clear_all_screens()
	_cleanup_world()
	$MainMenu.open()

func _cleanup_world() -> void:
	if world:
		# Disable processing to prevent race conditions (e.g. physics running on freed nodes)
		world.process_mode = Node.PROCESS_MODE_DISABLED
		# we get some dumb error because of the players getting freed, doesnt seem to harm the game tho
		# https://github.com/godotengine/godot/issues/101847
		world.queue_free.call_deferred()
		world = null

@rpc("authority", "reliable")
func _reject_joiner():
	Notifications.notify("Race in progress! Please try joining again in a minute.")
	# By calling exit_world, the client disconnects and resets their UI state,
	# avoiding the 'ghost lobby' hang.
	exit_world()


# client: cache world reference
func _on_world_spawner_spawned(node: Node) -> void:
	world = node # TODO when does this get called exactly? could we crash if something else tries to access world before its spawned? is that even possible?

# client: delete cached referenece (worldspawner handles queuefree)
func _on_world_spawner_despawned(_node: Node) -> void:
	world = null
