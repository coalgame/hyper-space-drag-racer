extends Node

var game_seed = 0
var local_player : Player

func _ready() -> void:
	if OS.get_cmdline_args().has("-capfps"):
		maxfps("60")
	
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


func play_sound(sound: AudioStream, volume=1.0) -> void:
	var audio_player := AudioStreamPlayer.new()
	Game.game.add_child(audio_player)
	audio_player.stream = sound
	audio_player.play()
	audio_player.bus = "sfx"
	audio_player.pitch_scale = randf_range(0.75, 1.5)
	audio_player.volume_linear = volume
	
	await audio_player.finished
	audio_player.queue_free()
	
func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func maxfps(arg:String):
	Engine.max_fps = arg.to_int()
