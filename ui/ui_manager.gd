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
		screen.show()

func unregister_screen(screen: Control):
	screen.hide()
	_active_screens.erase(screen)

func show_finish_screen():
	if !is_instance_valid(Main.world): return
	
	var screen = Main.world.get_node("FinishScreen")
	screen.on_shown()
	register_screen(screen)

func clear_all_screens():
	for screen in _active_screens:
		if is_instance_valid(screen):
			unregister_screen(screen)
