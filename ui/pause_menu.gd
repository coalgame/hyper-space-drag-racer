extends Control

func _ready():
	# Ensure the menu starts hidden
	hide()
	
	# This node must continue to process even when the game is paused
	process_mode = Node.PROCESS_MODE_ALWAYS

func _input(event):
	if event.is_action_pressed("ui_cancel"): # Default is the Escape key
		toggle_pause()

func toggle_pause():
	visible = !visible
	
	# Singleplayer: Pause the engine if no network connection exists
	# Multiplayer: Keep the engine running so network sync continues
	if not NetworkManager.has_connection():
		get_tree().paused = visible
	
	# Manage mouse visibility
	if visible:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		# Revert to whatever mode your game uses during gameplay
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_resume_button_pressed():
	toggle_pause()

func _on_quit_button_pressed():
	# 1. Properly close network peers and clear the player list
	NetworkManager.disconnect_from_game()
	
	# 2. Always unpause the tree before changing scenes
	# Failing to do this can cause the Main Menu to be frozen on load
	get_tree().paused = false
	
	# 3. Return to the main menu scene
	# Note: NetworkManager already handles redirecting clients if the host quits
	get_tree().change_scene_to_file("res://main_menu.tscn")
