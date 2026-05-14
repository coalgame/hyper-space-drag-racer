extends Node

func show_finish_screen(placing: int):
	var screen = preload("res://ui/finish_screen.tscn").instantiate()
	add_child(screen)
	screen.set_result(placing)
	
	# Release the mouse
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
