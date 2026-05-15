extends Node

# Track open screens in a stack to manage mouse and layering
var _active_screens: Array[Control] = []

var is_ui_focused: bool:
	get: return _active_screens.size() > 0

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS

func register_screen(screen: Control):
	if not _active_screens.has(screen):
		_active_screens.append(screen)
	_update_ui_state()

func unregister_screen(screen: Control):
	_active_screens.erase(screen)
	_update_ui_state()

func _update_ui_state():
	var ui_open = is_ui_focused
	
	# Handle Singleplayer Pause
	if not NetworkManager.has_connection():
		get_tree().paused = ui_open

func show_finish_screen(placing: int):
	var screen = preload("res://ui/finish_screen.tscn").instantiate()
	add_child(screen)
	screen.set_result(placing)
	register_screen(screen)

func is_any_screen_visible() -> bool:
	return _active_screens.size() > 0

func close_top_screen():
	if _active_screens.size() > 0:
		var top = _active_screens.back()
		if top.has_method("close"):
			top.close()
		else:
			top.hide()
			unregister_screen(top)

func clear_all_screens():
	_active_screens.clear()
	_update_ui_state()
