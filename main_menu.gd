extends Control

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	var color_names = ["Red", "Orange", "Yellow", "Green", "Cyan", "Blue", "Purple", "Pink", "White", "Lime"]
	%ColorOptionButton.clear()
	for i in range(color_names.size()):
		var color_value = NetworkManager.PRESET_COLORS[i]
		
		# Generate a 16x16 solid color square
		var img = Image.create(16, 16, false, Image.FORMAT_RGB8)
		img.fill(color_value)
		var tex = ImageTexture.create_from_image(img)
		
		%ColorOptionButton.add_icon_item(tex, color_names[i])
	
	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.connected_to_server.connect(_on_connection_succeeded) # only emitted on clients
	multiplayer.connection_failed.connect(_on_connection_failed) # only emitted on clients
	
	# CHECK: Are we returning to the lobby from a finished game?
	if NetworkManager.has_connection():
		show_screen("lobby")
	else:
		show_screen("main") # show main screen by default
		_parse_args()


func _parse_args():
	var args = Array(OS.get_cmdline_args())
	if args.has("-host"):
		_on_host_button_pressed()
	elif args.has("-client"):
		_on_join_button_pressed()
	

func _on_host_button_pressed():
	#Notifications.notify("Starting server...")
	var result = NetworkManager.create_game()
	if result == OK:
		show_screen("lobby")
		setup_lobby_ui()

func setup_lobby_ui():
	var my_color = NetworkManager.players[multiplayer.get_unique_id()].color
	%ColorOptionButton.selected = NetworkManager.PRESET_COLORS.find(my_color)


func _on_join_button_pressed():
	var address = %AddressInput.text.strip_edges()
	if address.is_empty():
		address = "127.0.0.1"
	
	NetworkManager.join_game(address)


func _on_connection_succeeded():
	#Notifications.notify("Success!!!!!!!!!!!!")
	# Transition clients to the lobby screen once connected
	show_screen("lobby")
	setup_lobby_ui()


func _on_connection_failed():
	Notifications.notify("Connection failed. Try again.")


func _on_player_connected(peer_id: int):
	Notifications.notify(str(multiplayer.get_unique_id()), "Player joined: ", str(peer_id))

func _on_singleplayer_button_pressed():
	Global.switch_to_game(randi())


func _on_color_option_button_item_selected(index: int) -> void:
	var my_id = multiplayer.get_unique_id()
	if NetworkManager.players.has(my_id):
		var color = NetworkManager.PRESET_COLORS[index]
		NetworkManager.players[my_id].color = color
		NetworkManager._register_player.rpc(NetworkManager.players[my_id])


# host
func _on_start_game_pressed() -> void:
	Global.switch_to_game.rpc(randi())


func _on_quit_lobby_pressed():
	NetworkManager.disconnect_from_game()
	show_screen("main")


func show_screen(screen_name: String):
	%MainScreen.visible = (screen_name == "main")
	%LobbyScreen.visible = (screen_name == "lobby")
	
	# Ensure only the host can see the Start Game button when in the lobby
	if screen_name == "lobby":
		%LobbyScreen/StartGame.visible = NetworkManager.is_host()
