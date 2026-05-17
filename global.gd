extends Node

var game_seed = 0
var local_player: Player

func _ready() -> void:
	if OS.get_cmdline_args().has("-capfps"):
		Util.maxfps("60")
	
	DebugDraw2D.debug_enabled = true


func _process(delta: float) -> void:
	DebugDraw2D.begin_text_group("main", 5, Color.WHITE)
	DebugDraw2D.set_text("fps", Engine.get_frames_per_second())
	DebugDraw2D.end_text_group()

	#if Input.is_action_just_pressed("fullscreen_toggle"):
		#if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
			#DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		#else:
			#DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	#
	#if Input.is_action_just_pressed("debug_toggle"):
		#DebugDraw2D.debug_enabled = !DebugDraw2D.debug_enabled


@rpc("call_local")
func switch_to_game(_seed):
	Notifications.notify("Starting game...")
	Global.game_seed = _seed
	get_tree().change_scene_to_file("res://game.tscn")


@rpc("call_local")
func return_to_lobby():
	Notifications.notify("Returning to lobby...")
	get_tree().change_scene_to_file("res://main_menu.tscn")
