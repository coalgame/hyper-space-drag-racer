class_name PlayerRaceStats extends Node

@onready var player: Player = get_parent()

@onready var indicator_labels: Node = $IndicatorLabels


var start_time := 0.0
var finish_time := INF
var finish_placement := 0

var collision_count := 0

var top_speed_reached := 0.0

func _ready() -> void:
	start_time = Time.get_ticks_msec()
	
	
	#for i in 10: # TODO change once we figure out what the max amount of racists should be
	#	indicator_labels.add_child(preload("res://player/player_indicator_label.tscn").instantiate())
		
#
func _process(_delta: float) -> void:
	if !is_multiplayer_authority(): return
	
	top_speed_reached = max(player.speed, top_speed_reached)
	

func get_placement() -> int:
	var all_players = get_tree().get_nodes_in_group("player")
	all_players.sort_custom(func(a, b):
		return a.get_total_distance() > b.get_total_distance()
	)
	var index = all_players.find(player)
	# 4. Convert 0-index to 1-based standing (0 becomes 1st)
	return index + 1

func has_finished():
	return finish_time != INF

func finish():
	if has_finished(): return
	
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
