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
	
	# singleplayer pausing
	if !NetworkManager.has_connection():
		get_tree().paused = visible
	
	if visible:
		UIManager.register_screen(self )
		# Ensure pause menu is visually on top if opened last
		move_to_front()
	else:
		UIManager.unregister_screen(self )

func _on_resume_button_pressed():
	toggle_pause()

func _on_quit_button_pressed():
	toggle_pause()
	if multiplayer.is_server():
		Main.instance.exit_world.rpc() #if host quits, disconnect every1
	else:
		Main.instance.exit_world()
