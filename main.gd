class_name Main extends Node

static var instance: Main
static var world: World

@onready var hud: HUD = $HUD
@onready var main_menu: Control = $MainMenu

func _init() -> void:
	instance = self

var _freecam_node: Camera3D = null

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

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F1:
		_toggle_freecam()

func _toggle_freecam():
	if _freecam_node:
		_freecam_node.queue_free()
		_freecam_node = null
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		Notifications.notify("Freecam Disabled")
	else:
		_freecam_node = Camera3D.new()
		_freecam_node.set_script(load("res://player/free_cam.gd"))
		add_child(_freecam_node)
		
		var currentcam = get_viewport().get_camera_3d()
		if currentcam:
			_freecam_node.global_position = currentcam.global_position + Vector3(0, 2, 5)
			
		_freecam_node.make_current()
		Notifications.notify("Freecam Enabled (WASD/QE to fly, F1 to exit)")

@rpc("call_local")
func start_world(game_seed: int = randi(), p_track_length: int = 5000):
	Notifications.notify("Starting world...")
	Global.game_seed = game_seed
	Global.track_length = p_track_length
	#Global.game_seed = 67
	
	$MainMenu.hide()
	
	# Only the server should instantiate the world and set its properties
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


func _on_world_spawner_spawned(node: Node) -> void:
	# This is called immediately after the node is added to the scene tree and synced.
	# It's safe to cache here. Using 'as World' provides type-safety.
	world = node as World

func _on_world_spawner_despawned(_node: Node) -> void:
	# Clear the reference so systems checking 'if Main.world' know it's gone.
	world = null
