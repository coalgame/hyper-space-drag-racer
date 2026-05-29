extends Area3D

@export var is_end_portal = false # minecraft
var to_z := 0


func _on_body_entered(body: Node3D) -> void:
	var player = body as Player
	if !player: 
		return
	
	if !player.is_multiplayer_authority():
		return
	
	if player.lap == 0:  #start of the race
		player.lap = 1
	else:
		if is_end_portal:
			player.lap += 1
			
			if player.lap == Global.max_laps: 
				player.race_stats.finish()
				return # dont teleport
				
				
			player.global_position.z = to_z
