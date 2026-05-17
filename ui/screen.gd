extends Control
class_name Screen

@export var pauses : bool = false :
	set(value):
		pauses = value
		if pauses:
			process_mode = PROCESS_MODE_ALWAYS
		else:
			process_mode = PROCESS_MODE_INHERIT

@export var visible_mouse := true


var open = false:
	set(on):
		open=on
		
		visible = open
		
		if open:
			ScreenManager.instance.open_screens.append(self)
			opened()
		else:
			ScreenManager.instance.open_screens.erase(self)
			closed()

		ScreenManager.instance.update_stack_state()



func opened():
	pass
	

func closed():
	pass
