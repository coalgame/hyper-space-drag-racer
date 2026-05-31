class_name Player extends CharacterBody3D

@onready var cam: Camera3D = $PlayerCamera
@onready var race_stats: PlayerRaceStats = $PlayerRaceStats

var is_ai := false
var ai_brain: PlayerAI = null

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

var tracked_body: Node3D = null
var near_miss_tracking = []
var near_miss_hit_cooldown = 0

var player_color: Color
var player_name: String

var lap := 0

var is_boost_mode := false
var boost_timer := 0.0
var has_block_smash_charge := false

func get_total_distance() -> float:
	if !Main.world: return global_position.z
	
	var start_z = Main.world.start_portal.global_position.z
	var end_z = Main.world.end_portal.global_position.z
	var lap_dist = end_z - start_z
	
	if lap <= 0:
		return global_position.z
	
	# Total distance = distance to start portal + completed laps + progress into current lap
	return start_z + (lap - 1) * lap_dist + (global_position.z - start_z)

func get_progress_percentage() -> float:
	if !Main.world: return 0.0
	var start_z = Main.world.start_portal.global_position.z
	var end_z = Main.world.end_portal.global_position.z
	var total_race_dist = start_z + Global.max_laps * (end_z - start_z)
	
	var total_dist = get_total_distance()
	return clamp((total_dist / total_race_dist) * 100.0, 0.0, 100.0)


func _enter_tree() -> void:
	# The MultiplayerSpawner syncs the node name before adding it to the tree.
	# We use this to identify bots on the client side immediately.
	if name.begins_with("BOT-"):
		is_ai = true

	if is_ai:
		set_multiplayer_authority(1)
	else:
		set_multiplayer_authority(str(name).to_int())

	if is_multiplayer_authority() and !is_ai:
		Global.local_player = self
	

func _ready() -> void:
	# If we are the authority and starting at the origin, snap to the calculated row position.
	# This ensures authority-controlled peers don't sync (0,0,0) back to the host.
	if is_multiplayer_authority() and global_position == Vector3.ZERO:
		if Main.world:
			global_position = Main.world.get_spawn_position(name)

	var info = NetworkManager.players.get(name.to_int())
	if info:
		player_color = info.color
		player_name = info.name
	else:
		player_color = Color.YELLOW
		player_name = "CHUD"
	
	if is_ai:
		ai_brain = PlayerAI.new()
		add_child(ai_brain)
		player_color = Color.SLATE_GRAY
	
	if player_color:
		var mat = $Mesh.mesh.material as ShaderMaterial
		if mat:
			$Mesh.set_surface_override_material(0, mat.duplicate())
			$Mesh.get_surface_override_material(0).set_shader_parameter("albedo", player_color)
		
		%NameLabel3D.text = player_name
		%NameLabel3D.modulate = player_color
		
	if !is_multiplayer_authority() or is_ai:
		if !ai_brain or !ai_brain.testing_mode:
			cam.queue_free()
		$Mesh.transparency = 0.67
		$GPUParticles3D.queue_free()
		%BitsAndBobs.queue_free()
		
	else:
		# the local player shouldn't have a name label
		%NameLabel3D.queue_free()
		$Mesh.transparency = 0.1
		race_stats.boost_activated.connect(activate_boost)


func _physics_process(delta: float) -> void:
	if !is_multiplayer_authority():
		return
	
	var camoffset = Vector3(0, 1.06, -2.2)
	if !is_ai or ai_brain.testing_mode:
		cam.global_position = cam.global_position.lerp((global_position + camoffset), delta * 12)
	
	hit_cooldown = move_toward(hit_cooldown, 0, delta)
	near_miss_hit_cooldown = move_toward(near_miss_hit_cooldown, 0, delta)
	
	if is_boost_mode:
		boost_timer -= delta
		if boost_timer <= 0:
			end_boost()

	var ai_speed_multiplier = 1.0
	if ai_brain:
		ai_speed_multiplier = ai_brain.get_speed_multiplier()
	
	var boost_speed_mult = 1.2 if is_boost_mode else 1.0

	var speed_damp_strength = -0.008
	var speed_damp = ((speed_damp_strength * top_speed) + 1) - (20 * speed_damp_strength)
	top_speed += delta * 0.5 * ai_speed_multiplier * speed_damp
	
	
	var braking = false
	# Only humans check the hardware brake key
	if !is_ai:
		braking = Input.is_action_pressed("brake")
	
	if braking:
		speed = move_toward(speed, 0, delta * 40.0)
	else:
		speed = move_toward(speed, top_speed * boost_speed_mult, delta * (10 + (top_speed * 0.4)) * boost_speed_mult)
	acceleration = move_toward(acceleration, top_acceleration * boost_speed_mult, delta * (10 + (top_speed * 0.4)) * boost_speed_mult)
	sideways_speed = move_toward(sideways_speed, top_sideways_speed, delta * 10)
	if sideways_speed < 0:
		sideways_speed = 0
	#print(acceleration)
	#print(sideways_speed)
	
	var current_track_dims = Main.world.get_track_dimensions(global_position.z)
	var is_out_of_bounds = abs(global_position.x) > current_track_dims.x or abs(global_position.y) > current_track_dims.y
	
	if is_out_of_bounds:
		# Slow down proportionately: high speeds bleed off faster than low speeds.
		var slowdown_rate = top_speed * 0.3
		top_speed = move_toward(top_speed, 20.0, delta * slowdown_rate)

	var input := Vector2.ZERO
	if ai_brain:
		input = ai_brain.get_input()
	else:
		input = Vector2(
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
	velocity.z = speed # still force forward travel direction
		
	
	move_and_slide()
	
	for i in get_slide_collision_count():
		#near_miss_tracking.clear()
		near_miss_hit_cooldown = 3
		#print(1)
		var impact_strength = abs(velocity.z)
	
		var collision := get_slide_collision(i)
		var collider = collision.get_collider()
		var piece_knockback_modifier := 1.0
		if collider is Asteroid:
			collider.hit()
		elif collider is Piece:
			if has_block_smash_charge:
				collider.hit(999999, self) # Instant destroy
				end_boost()
				continue

			if collider.health - impact_strength <= 0: # only reduce penalty if we will kill the block
				piece_knockback_modifier = clamp(collider.health / collider.max_health, 0.0, 1.0)
				
			# deal damage proportional to how fast we are going
			collider.hit(impact_strength, self)
			
	
			
		if is_zero_approx(hit_cooldown):
				# how fast we were moving into the hit

			race_stats.collision_count += 1

			var knockback = clamp(impact_strength * 0.2, 5.0, 40.0)
			knockback *= piece_knockback_modifier

			if ai_brain:
				knockback *= ai_brain.get_crash_knockback_multiplier()

			speed = - knockback * 1.6
			acceleration -= knockback * 5
			sideways_speed -= knockback * 0.6

			# optional: also reduce max speed so it matters long-term
			var speed_loss = (knockback - 5.0) * 2.5
			if speed_loss > 0.0:
				top_speed -= speed_loss
			
			if top_speed < 10:
				top_speed = 10
				
			hit_cooldown = 1

@rpc("any_peer", "call_local")
func speed_boost(amount):
	if !is_multiplayer_authority(): return
	#printt(str(multiplayer.get_unique_id()) , "speed_boost")
	top_speed += amount
	speed += amount
	#printt(str(multiplayer.get_unique_id()) , is_ai)
	#print_stack()
	

func _on_near_miss_area_3d_body_exited(body: Node3D) -> void:
	if !is_multiplayer_authority(): return
	if body == tracked_body:
		#print("Near miss distance: ", dist)
		# Example: Dynamic boost based on closeness
		# If dist is 2.0 (very close), boost is higher than if dist is 5.0
		var boost_multiplier = clamp(10.0 / 3, 1.0, 5.0)
		
		speed_boost(0.6 * boost_multiplier)
		if speed > 2:
			speed += (top_speed * 0.04) + (boost_multiplier) + 4
			#print((top_speed * 0.04) + (boost_multiplier) + 4)
		
		race_stats.add_score(race_stats.score_near_miss)
		
		tracked_body = null # Stop tracking
		
		#cam.fov_boost(1.05)

@rpc("any_peer", "call_local")
func activate_boost_rpc():
	if !is_multiplayer_authority(): return
	activate_boost()

func activate_boost():
	is_boost_mode = true
	boost_timer = 3.0
	has_block_smash_charge = true
	if is_multiplayer_authority() and !is_ai:
		cam.fov_boost(2.0)
	# Visual feedback could be added here (e.g. speed lines, color shift)
	
func end_boost():
	is_boost_mode = false
	boost_timer = 0.0
	has_block_smash_charge = false

func _on_near_miss_area_3d_body_entered(body: Node3D) -> void:
	if !is_multiplayer_authority(): return
	if is_zero_approx(near_miss_hit_cooldown):
		tracked_body = body


func _on_spark_area_3d_body_shape_entered(_body_rid: RID, _body: Node3D, _body_shape_index: int, local_shape_index: int) -> void:
	var local_shape_owner = $SparkArea3D.shape_find_owner(local_shape_index)
	var local_shape_node = $SparkArea3D.shape_owner_get_owner(local_shape_owner)
	if speed > 2:
		$Sparks.global_position = local_shape_node.global_position
		$Sparks.global_rotation = local_shape_node.global_rotation
		$Sparks.emitting = true

func _on_spark_area_3d_body_shape_exited(_body_rid: RID, _body: Node3D, _body_shape_index: int, _local_shape_index: int) -> void:
	await Util.wait(0.1)
	$Sparks.emitting = false


func _on_trail_spawn_timer_timeout() -> void:
	#if !is_ai:
		#if is_multiplayer_authority(): return #  local players dont have trails
	var c: PlayerTrail = preload("res://player/player_trail.tscn").instantiate()
	Main.world.add_child(c)
	c.global_position = $TrailSpawnPos.global_position
	c.source = self
	# HACK find a better way of doing this. instance uniforms are a solution but may hit the limit too fast with multiple players
	var mat = c.mesh.material as ShaderMaterial
	if mat:
		c.set_surface_override_material(0, mat.duplicate())
		c.get_surface_override_material(0).set_shader_parameter("albedo", player_color)
