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
	
	if visible:
		UIManager.register_screen(self )
		# Ensure pause menu is visually on top if opened last
		move_to_front()
	else:
		UIManager.unregister_screen(self )

func _on_resume_button_pressed():
	toggle_pause()

func _on_quit_button_pressed():
	# 1. Properly close network peers and clear the player list
	NetworkManager.disconnect_from_game()
	
	# 2. Reset UI State
	UIManager.clear_all_screens()
	
	# 3. Return to the main menu scene
	get_tree().change_scene_to_file("res://main_menu.tscn")
