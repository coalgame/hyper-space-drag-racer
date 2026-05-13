class_name Player extends CharacterBody3D

var starting_speed := 20.

var sideways_speed := 16.0
var top_speed := starting_speed


var speed = 0

var hit_cooldown = 0

var move_velocity := Vector2.ZERO
var acceleration := 145.0
var deceleration := 130.0
var top_acceleration = acceleration

func _enter_tree() -> void:
	set_multiplayer_authority(str(name).to_int())
	#if is_multiplayer_authority():
		#Global.local_player=self
		
func _ready() -> void:
	if !is_multiplayer_authority():
		$Camera3D.queue_free()
		#$Area3D.queue_free()
		$ScoreLabel.queue_free()

func _process(delta: float) -> void:
	if !is_multiplayer_authority(): 
		return
		
	DebugDraw2D.set_text("top_speed", snappedf(top_speed, 0.1))
	DebugDraw2D.set_text("speed", snappedf(speed, 0.1))
	DebugDraw2D.set_text("velocity", velocity)
	

func _physics_process(delta: float) -> void:
	if !is_multiplayer_authority(): 
		return
	
	var camoffset = Vector3(0, 1.05, -2.2)
	$Camera3D.global_position = $Camera3D.global_position.lerp((global_position+camoffset), delta * 12)
	
	hit_cooldown = move_toward(hit_cooldown, 0, delta)
	var speed_damp_strength = -0.008
	var speed_damp = ((speed_damp_strength*top_speed)+1)-(20*speed_damp_strength)
	#print(speed_damp)
	top_speed += delta * 0.5 * speed_damp
	speed = move_toward(speed, top_speed, delta * (10+(top_speed*0.4)))
	
	acceleration = move_toward(acceleration, top_acceleration, delta * (10+(top_speed*0.4)))
	print(acceleration)
	
	$ScoreLabel.text = str(int(global_position.z))

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
		
	#global_position.x = clamp(global_position.x, -Game.X_SIZE, Game.X_SIZE)
	#global_position.y = clamp(global_position.y, -Game.Y_SIZE, Game.Y_SIZE)
	
	move_and_slide()
	
	for i in get_slide_collision_count():
		if is_zero_approx(hit_cooldown):
				# how fast we were moving into the hit
			var impact_strength = abs(velocity.z)

			# convert impact into backward push
			var knockback = clamp(impact_strength * 0.2, 5.0, 40.0)

			speed = -knockback*1.6

			# optional: also reduce max speed so it matters long-term
			top_speed -= (knockback-5)*2.5
			
			if top_speed < 20:
				top_speed = 20
				
			print((knockback-5)*2.5)
			hit_cooldown = 1

func speed_boost(amount):
	top_speed += amount
	speed += amount
