class_name PlayerRaceStats extends Node

@onready var player: Player = get_parent()

@onready var indicator_labels: Node = $IndicatorLabels


var start_time := 0.0
var finish_time := INF
var finish_placement := 0

var collision_count := 0

func _ready() -> void:
	start_time = Time.get_ticks_msec()
	
	
	#for i in 10: # TODO change once we figure out what the max amount of racists should be
	#	indicator_labels.add_child(preload("res://player/player_indicator_label.tscn").instantiate())
		
#
func _process(delta: float) -> void:
	if !is_multiplayer_authority(): return
	
	if !has_finished() and player.global_position.z > Main.world.track_length:
		finish_time = Time.get_ticks_msec() - start_time
		finish_placement = get_placement()
		
		if player.ai_brain:
			#if ai_brain.testing_mode:
			player.ai_brain.log_results()
		#else:
			#print("--- PLAYER RESULTS [%s] ---" % player_name)
			#print("Time: %.3fs" % finish_time / 1000.0)
			#print("Collisions: %d" % player_race_stats.collision_count)
			#print("---------------------------")

		if !player.ai_brain:
			UIManager.show_finish_screen()

	#
	## Hide all indicators initially so they don't get "stuck" if a peer leaves
	#for label in indicator_labels.get_children():
		#label.visible = false
#
	#var i = 0
	#
	#for p in get_tree().get_nodes_in_group("player"):
		#if p == player: continue
		## Convert world position to screen position
		#var screen_pos := player.cam.unproject_position(p.global_position)
		#
		#var label: RichTextLabel = $IndicatorLabels.get_child(i)
		#i += 1
		#if  player.cam.is_position_behind(p.global_position):
			#label.visible = true
			#
			#var viewport_size := get_viewport().get_visible_rect().size
			#
			#screen_pos.x = viewport_size.x - screen_pos.x
			#screen_pos.x = clamp(screen_pos.x, 50.0, viewport_size.x - 50.0)
			#
			## Force labels to bottom of screen
			#screen_pos.y = viewport_size.y - 80.0
			#
			#label.text = p.player_name + " [font_size=50](" + str(int(p.global_position.distance_to(player.global_position))) + ")[/font_size]"
			#label.position = screen_pos
	#
	#var s = ""
	#s += str(int(( player.global_position.z / Main.world.track_length) * 100)) + "% \n"
	#for p in get_tree().get_nodes_in_group("player"):
		#if p == self: continue
		#s += p.player_name + ": " + str(int((p.global_position.z / Main.world.track_length) * 100)) + "% \n"
	#
	#$ScoreLabel.text = s

func get_placement() -> int:
	var all_players = get_tree().get_nodes_in_group("player")
	all_players.sort_custom(func(a, b):
		return a.global_position.z > b.global_position.z
	)
	var index = all_players.find(player)
	# 4. Convert 0-index to 1-based standing (0 becomes 1st)
	return index + 1

func has_finished():
	return finish_time != INF
