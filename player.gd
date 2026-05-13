class_name Player extends CharacterBody3D

@onready var cam: Camera3D = $PlayerCamera

var starting_speed := 20.

var sideways_speed := 16.0
var top_sideways_speed = sideways_speed
var top_speed := starting_speed


var speed = 0

var hit_cooldown = 0

var move_velocity := Vector2.ZERO
var acceleration := 145.0
var deceleration := 130.0
var top_acceleration = acceleration

var near_miss_tracking = []
var near_miss_hit_cooldown = 0

func _enter_tree() -> void:
	set_multiplayer_authority(str(name).to_int())
	if is_multiplayer_authority():
		Global.local_player=self
		
func _ready() -> void:
	if !is_multiplayer_authority():
		cam.queue_free()
		#$Area3D.queue_free()
		$ScoreLabel.queue_free()

func _process(delta: float) -> void:
	if !is_multiplayer_authority(): 
		return
	
	var s = ""
	s += str(int((global_position.z / Game.game.track_length) * 100)) + "% \n"
	for peer in multiplayer.get_peers():
		var p = Game.game.get_node(str(peer)) as Player
		if p:
			s += "CHUD: " + str(int((p.global_position.z / Game.game.track_length) * 100)) + "% \n"
			
	$ScoreLabel.text = s
	
	DebugDraw2D.set_text("top_speed", snappedf(top_speed, 0.1))
	DebugDraw2D.set_text("speed", snappedf(speed, 0.1))
	DebugDraw2D.set_text("velocity", velocity)
	
	

func _physics_process(delta: float) -> void:
	if !is_multiplayer_authority(): 
		return
	
	if tracked_body:
		# Calculate current distance
		# this code is kinda flawed cause its tracking the object origin, not the exact closest vertex or whatever
		var current_dist = global_position.distance_to(tracked_body.global_position)
		
		# Keep the smallest value
		if current_dist < min_distance:
			min_distance = current_dist
	
	var camoffset = Vector3(0, 1.06, -2.2)
	cam.global_position = cam.global_position.lerp((global_position+camoffset), delta * 12)
	
	hit_cooldown = move_toward(hit_cooldown, 0, delta)
	near_miss_hit_cooldown = move_toward(near_miss_hit_cooldown, 0, delta)
	

	var speed_damp_strength = -0.008
	var speed_damp = ((speed_damp_strength*top_speed)+1)-(20*speed_damp_strength)
	top_speed += delta * 0.5 * speed_damp
	
	var braking = Input.is_action_pressed("brake")
	
	if braking:
		speed = move_toward(speed, 0, delta * 40.0)
	else:
		speed = move_toward(speed, top_speed, delta * (10+(top_speed*0.4)))
	acceleration = move_toward(acceleration, top_acceleration, delta *(10+(top_speed*0.4)))
	sideways_speed = move_toward(sideways_speed, top_sideways_speed, delta*10 )
	if sideways_speed < 0:
		sideways_speed = 0
	#print(acceleration)
	#print(sideways_speed)
	

	# Using action strengths avoids weird diagonal speed differences.
	var input := Vector2(
	Input.get_action_strength("move_left") - Input.get_action_strength("move_right"),
	Input.get_action_strength("move_up") - Input.get_action_strength("move_down")
)
	input = input.normalized()
	
	
	var target_velocity := input * sideways_speed

	# Move forward constantly.

	var target_roll := -input.x * 0.3
	var target_pitch := -input.y * 0.4

	# rotate the whole ship
	rotation.z = lerp(rotation.z, target_roll, delta * 16)
	rotation.x = lerp(rotation.x, target_pitch, delta * 16)

	# faster response when pushing, slower when releasing
	var rate := acceleration if input != Vector2.ZERO else deceleration

	move_velocity = move_velocity.move_toward(target_velocity, rate * delta)

	velocity.x = move_velocity.x
	velocity.y = move_velocity.y
	velocity.z = speed  # still force forward travel direction
		
	global_position.x = clamp(global_position.x, -Game.X_SIZE, Game.X_SIZE)
	global_position.y = clamp(global_position.y, -Game.Y_SIZE, Game.Y_SIZE)
	
	move_and_slide()
	
	for i in get_slide_collision_count():
		#near_miss_tracking.clear()
		near_miss_hit_cooldown = 3
		#print(1)
		
		if is_zero_approx(hit_cooldown):
				# how fast we were moving into the hit
			var impact_strength = abs(velocity.z)

			# convert impact into backward push
			var knockback = clamp(impact_strength * 0.2, 5.0, 40.0)

			speed = -knockback*1.6
			acceleration -=knockback*5
			sideways_speed-= knockback *0.6

			# optional: also reduce max speed so it matters long-term
			top_speed -= (knockback-5)*2.5
			
			if top_speed < 20:
				top_speed = 20
				
			hit_cooldown = 1

@rpc("any_peer", "call_local")
func speed_boost(amount):
	printt(str(multiplayer.get_unique_id()) , "speed_boost")

	top_speed += amount
	speed += amount

var min_distance: float = 9999.0
var tracked_body: Node3D = null

func _on_near_miss_area_3d_body_exited(body: Node3D) -> void:
	if body == tracked_body:
		var dist=min_distance
		print("Near miss distance: ", dist)
		# Example: Dynamic boost based on closeness
		# If dist is 2.0 (very close), boost is higher than if dist is 5.0
		var boost_multiplier = clamp(10.0 / dist, 1.0, 5.0) 
		
		speed_boost(0.8 * boost_multiplier)
		tracked_body = null # Stop tracking
		
		#cam.fov_boost(1.05)

func _on_near_miss_area_3d_body_entered(body: Node3D) -> void:
	if is_zero_approx(near_miss_hit_cooldown):
		tracked_body = body
		min_distance = 9999.0 # Reset for the new encounter
