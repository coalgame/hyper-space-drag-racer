extends Control


func on_shown():
	var player = Global.local_player
	
	var s = "Highest speed reached: %du/s" % [player.race_stats.top_speed_reached]
	s += "\nCollisions: " + str(player.race_stats.collision_count)
	%Stats.text = s
	
	
func _on_continue_pressed() -> void:
	if multiplayer.is_server():
		Main.instance.back_to_lobby.rpc()
	else:
		Notifications.notify("Only the host can continue")

func _process(_delta: float) -> void:
	var world = Main.world
	if not is_instance_valid(world):
		return
	
	var players = get_tree().get_nodes_in_group("player")
	players.sort_custom(func(a: Player, b: Player):
		var a_placement = a.race_stats.finish_placement
		var b_placement = b.race_stats.finish_placement
		
		# use live placement if they havent finished
		if !a.race_stats.has_finished():
			a_placement = a.race_stats.get_placement()
		if !b.race_stats.has_finished():
			b_placement = b.race_stats.get_placement()
		
		return a_placement < b_placement
	)
	
	var leaderboard_text = ""
	for i in range(players.size()):
		var p: Player = players[i]
		if not is_instance_valid(p): continue
		
		var pct = clamp(int(p.get_progress_percentage()), 0, 100)
		var time_display = "---"
		
		# Display time only if the player has finished the race
		if p.race_stats.has_finished():
			var duration = p.race_stats.finish_time / 1000.0
			var mins = int(duration / 60)
			var secs = int(duration) % 60
			var cents = int((duration - int(duration)) * 100)
			time_display = "%d:%02d.%02d" % [mins, secs, cents]
			
		var p_name = p.player_name
		if Global.local_player == p: leaderboard_text += "🫃"
		
		leaderboard_text += "%d. %s %d%% %s\n" % [i + 1, p_name.to_upper(), pct, time_display]
	
	%PlayerInfo.text = leaderboard_text
