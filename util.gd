## Util.gd -- Collection of utility functions
extends Node

const VEC3ZERO = Vector3.ONE * 0.001 # functionally zero for physics / rendering etc purposes

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
