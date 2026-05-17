extends Control

func set_result(standing: int):
	var suffix = "th"
	match standing:
		1: suffix = "st"
		2: suffix = "nd"
		3: suffix = "rd"
	
	var msg = "You finished %d%s!" % [standing, suffix]
	%StatsLabel.text = msg

func _on_continue_pressed() -> void:
	if multiplayer.is_server():
		Main.instance.back_to_lobby.rpc()
	else:
		Notifications.notify("Only the host can continue")
