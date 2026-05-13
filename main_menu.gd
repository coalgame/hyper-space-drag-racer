extends Control

@onready var host_button: Button = $VBoxContainer/HostButton
@onready var join_button: Button = $VBoxContainer/HBoxContainer/JoinButton
@onready var address_input: LineEdit = $VBoxContainer/HBoxContainer/AddressInput
@onready var label: Label = $VBoxContainer/Label
@onready var singleplayer_button: Button = $VBoxContainer/SingleplayerButton

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	# Connect buttons
	host_button.pressed.connect(_on_host_button_pressed)
	join_button.pressed.connect(_on_join_button_pressed)
	singleplayer_button.pressed.connect(_on_singleplayer_button_pressed)
	
	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.connected_to_server.connect(_on_connection_succeeded)
	multiplayer.connection_failed.connect(_on_connection_failed)
	
	#await get_tree().process_frame
	#_switch_to_game()
	#return
	
	var args = Array(OS.get_cmdline_args())
	if args.has("-host"):
		_on_host_button_pressed()
	elif args.has("-client"):
		_on_join_button_pressed()

func _on_host_button_pressed():
	Notifications.notify( "Starting server...")
	var result = NetworkManager.create_game()
	
	if result == OK:
		Notifications.notify(  "Server started! Waiting for players")
		join_button.visible=false
		address_input.visible=false
		host_button.visible=false
		singleplayer_button.visible=false
	else:
		Notifications.notify(  "Failed to start server")
	
func _on_join_button_pressed():
	var address = address_input.text.strip_edges()
	if address.is_empty():
		address = "127.0.0.1"
	
	#Notifications.notify(  "Connecting to " + address + "...")
	NetworkManager.join_game(address)

func _on_connection_succeeded():
	join_button.visible=false
	address_input.visible=false
	host_button.visible=false
	singleplayer_button.visible=false
	Notifications.notify("Success!!!!!!!!!!!!")
	label.text = "waiting for host to start"

func _on_connection_failed():
	Notifications.notify(  "Connection failed. Try again.")

func _on_player_connected(peer_id: int):
	Notifications.notify(str(multiplayer.get_unique_id()) , "Player joined: " , str( peer_id ))
	
	if NetworkManager.is_host():
		$VBoxContainer/StartGame.visible=true

func _on_singleplayer_button_pressed():
	_switch_to_game(randi())

@rpc("authority", "call_local", "reliable")
func _switch_to_game(seed):
	Global.game_seed = seed
	get_tree().change_scene_to_file("res://game.tscn")


# host
func _on_start_game_pressed() -> void:
	_switch_to_game.rpc(randi())
