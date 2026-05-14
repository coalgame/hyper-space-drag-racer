extends Control

func set_result(standing: int):
	var suffix = "th"
	match standing:
		1: suffix = "st"
		2: suffix = "nd"
		3: suffix = "rd"
	
	var msg = "You finished %d%s!" % [standing, suffix]
	%StatsLabel.text = msg

func _on_restart_button_pressed() -> void:
	# Since it's multiplayer, you'll likely want the host to trigger this
	if multiplayer.is_server():
		Global.restart_game(randi())
	else:
		Notifications.notify("Waiting for host to restart...")

func _on_quit_button_pressed() -> void:
	queue_free()
	get_tree().change_scene_to_file("res://main_menu.tscn")
