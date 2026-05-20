extends Control

func _ready():
	var color_names = ["Red", "Orange", "Yellow", "Green", "Blue", "Purple", "Pink"]
	for i in range(color_names.size()):
		var color_value = ProfileManager.PRESET_COLORS[i]
		
		# Generate a 16x16 solid color square
		var img = Image.create(16, 16, false, Image.FORMAT_RGB8)
		img.fill(color_value)
		var tex = ImageTexture.create_from_image(img)
		
		%ColorOptionButton.add_icon_item(tex, color_names[i])
	
	%NameLineEdit.text = ProfileManager.data.name
	
	if has_node("%DifficultySlider"):
		%DifficultySlider.min_value = 1.0
		%DifficultySlider.max_value = 9.9
		%DifficultySlider.step = 0.1
		var saved_diff = Global.get("difficulty")
		%DifficultySlider.value = saved_diff if saved_diff != null else 8.0
		%DifficultySlider.value_changed.connect(_on_difficulty_slider_value_changed)
		# Initialize the label and global value
		_on_difficulty_slider_value_changed(%DifficultySlider.value)

	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.connected_to_server.connect(_on_connection_succeeded)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	
	NetworkManager.update_ui.connect(refresh_lobby)
	
	open()
	_parse_args()

func open():
	show()
	if NetworkManager.has_connection(): # we are connected to someone, so open the lobby instead
		show_screen("lobby")
		refresh_lobby()
	else:
		# i guess we quit or something else, show main menu
		show_screen("main")

func _parse_args():
	var args = Array(OS.get_cmdline_args())
	if args.has("-host"):
		print("autohost")
		_on_host_button_pressed()
	elif args.has("-client"):
		print("autoclient")
		_on_join_button_pressed()
	

func _on_host_button_pressed():
	print("host button pressed")
	#Notifications.notify("Starting server...")
	var result = NetworkManager.create_game()
	if result == OK:
		show_screen("lobby")
		refresh_lobby()

func refresh_lobby():
	if !%LobbyScreen.visible: return
	if !NetworkManager.has_connection(): return
	
	var my_id = multiplayer.get_unique_id()
	if !NetworkManager.players.has(my_id): return
	
	var my_color = NetworkManager.players[my_id].color
	%ColorOptionButton.selected = ProfileManager.PRESET_COLORS.find(my_color)

	for child in %PlayerList.get_children():
		child.queue_free()
		
	for id in NetworkManager.players:
		var p_info = NetworkManager.players[id]
		var lbl = Label.new()
		lbl.text = p_info.name + (" (You)" if id == my_id else "")
		lbl.modulate = p_info.color
		%PlayerList.add_child(lbl)


func _on_join_button_pressed():
	var address = %AddressInput.text.strip_edges()
	if address.is_empty():
		address = "127.0.0.1"
	
	NetworkManager.join_game(address)


func _on_connection_succeeded():
	NetworkManager._log("Connection to server succeeded.")
	
	# Use our loaded local data instead of generating random info
	NetworkManager.update_local_player_registration()
	
	show_screen("lobby")
	refresh_lobby()


func _on_connection_failed():
	NetworkManager._log("Connection to server failed.")
	Notifications.notify("Connection failed.")
	show_screen("main")


func _on_server_disconnected():
	Notifications.notify("Disconnected from server.")
	show_screen("main")


func _on_player_connected(peer_id: int):
	Notifications.notify(str(multiplayer.get_unique_id()), "Player joined: ", str(peer_id))


func _on_singleplayer_button_pressed():
	Main.instance.start_world()


func _on_color_option_button_item_selected(index: int) -> void:
	var color = ProfileManager.PRESET_COLORS[index]
	ProfileManager.set_color(color)


# host
func _on_start_game_pressed() -> void:
	Main.instance.start_world.rpc(randi())


func _on_quit_lobby_pressed():
	NetworkManager.disconnect_from_game()
	show_screen("main")


func show_screen(screen_name: String):
	%MainScreen.visible = (screen_name == "main")
	%LobbyScreen.visible = (screen_name == "lobby")
	
	# Ensure only the host can see the Start Game button when in the lobby
	if screen_name == "lobby":
		%LobbyScreen/StartGame.visible = NetworkManager.is_host()
		if has_node("%DifficultySlider"):
			%DifficultySlider.visible = NetworkManager.is_host()
	elif screen_name == "main":
		if has_node("%DifficultySlider"):
			%DifficultySlider.visible = true
		

func _on_name_line_edit_text_changed(new_text: String) -> void:
	if new_text.strip_edges() != "":
		 # Save current cursor position
		var caret_pos = %NameLineEdit.caret_column
		# Convert text to uppercase
		%NameLineEdit.text = new_text.to_upper()
		# Restore cursor position (Godot resets it to the end when text changes)
		%NameLineEdit.caret_column = caret_pos
		
		ProfileManager.set_username(%NameLineEdit.text)

func _on_difficulty_slider_value_changed(value: float) -> void:
	Global.set("difficulty", value)
	if has_node("%DifficultyLabel"):
		%DifficultyLabel.text = "Difficulty: %.1f" % value
