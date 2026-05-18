class_name Player extends CharacterBody3D

@onready var cam: Camera3D = $PlayerCamera

var is_ai := false
var bot_radius := 0.5
var cone_angle_degrees := 100.0
var cone_resolution := 0.3
var num_rays := 0
var ray_directions: Array[Vector3] = []

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

var has_finished = false

var player_color: Color
var player_name: String

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
	if is_ai:
		# Use a local RNG seeded by name so each bot has a unique, persistent personality
		var rng = RandomNumberGenerator.new()
		rng.seed = name.hash()
		
		# Randomize the base cone stats
		cone_angle_degrees += rng.randf_range(-25.0, 25.0)
		cone_resolution = clamp(cone_resolution + rng.randf_range(-0.1, 0.1), 0.15, 0.5)
		
		_generate_ray_directions(rng)
		player_color = ProfileManager.PRESET_COLORS[rng.randi() % ProfileManager.PRESET_COLORS.size()]
		player_name = name
	
	var info = NetworkManager.players.get(name.to_int())
	if info:
		player_color = info.color
		player_name = info.name

	if player_color:
		var mat = $Mesh.mesh.material as ShaderMaterial
		if mat:
			$Mesh.set_surface_override_material(0, mat.duplicate())
			$Mesh.get_surface_override_material(0).set_shader_parameter("albedo", player_color)
		
		%NameLabel3D.text = player_name
		%NameLabel3D.modulate = player_color
		
	if !is_multiplayer_authority() or is_ai:
		cam.queue_free()
		$ScoreLabel.queue_free()
	else:
		# the local player shouldn't have a name label
		%NameLabel3D.queue_free()

func _generate_ray_directions(rng: RandomNumberGenerator = null) -> void:
	ray_directions.clear()
	var cone_angle_rad = deg_to_rad(cone_angle_degrees)
	var current_angle_x = - cone_angle_rad / 2.0
	var jitter := 0.1 # Max angle offset for individual rays
	
	while current_angle_x <= cone_angle_rad / 2.0:
		var current_angle_y = - cone_angle_rad / 2.0
		while current_angle_y <= cone_angle_rad / 2.0:
			# Add random jitter to each ray to create a non-uniform sensing pattern
			var j_x = current_angle_x + (rng.randf_range(-jitter, jitter) if rng else 0.0)
			var j_y = current_angle_y + (rng.randf_range(-jitter, jitter) if rng else 0.0)
			
			var dir = Vector3(sin(j_x), sin(j_y), cos(j_x) * cos(j_y)).normalized()
			ray_directions.append(dir)
			current_angle_y += cone_resolution
		current_angle_x += cone_resolution
	num_rays = ray_directions.size()

func _process(delta: float) -> void:
	if !is_multiplayer_authority() or is_ai:
		return
	
	if !has_finished and global_position.z > Main.world.track_length:
		complete_race()
	
	
	# Hide all indicators initially so they don't get "stuck" if a peer leaves
	for label in $IndicatorLabels.get_children():
		label.visible = false

	var i = 0
	
	for player in get_tree().get_nodes_in_group("player"):
		if player == self: continue
		# Convert world position to screen position
		var screen_pos := cam.unproject_position(player.global_position)
		
		var label: RichTextLabel = $IndicatorLabels.get_child(i)
		i += 1
		if cam.is_position_behind(player.global_position):
			label.visible = true
			
			var viewport_size := get_viewport().get_visible_rect().size
			
			screen_pos.x = viewport_size.x - screen_pos.x
			screen_pos.x = clamp(screen_pos.x, 50.0, viewport_size.x - 50.0)
			
			# Force labels to bottom of screen
			screen_pos.y = viewport_size.y - 80.0
			
			label.text = player.player_name + " [font_size=60](" + str(int(player.global_position.distance_to(global_position))) + ")[/font_size]"
			label.position = screen_pos
	
	var s = ""
	s += str(int((global_position.z / Main.world.track_length) * 100)) + "% \n"
	for player in get_tree().get_nodes_in_group("player"):
		if player == self: continue
		s += player.player_name + ": " + str(int((player.global_position.z / Main.world.track_length) * 100)) + "% \n"
	
	$ScoreLabel.text = s
	
	DebugDraw2D.set_text("top_speed", snappedf(top_speed, 0.1))
	DebugDraw2D.set_text("speed", snappedf(speed, 0.1))
	DebugDraw2D.set_text("velocity", velocity)
	

func _get_ai_input() -> Vector2:
	var world_goal_direction = Vector3(0, 0, 1)
	var space_state = get_world_3d().direct_space_state
	
	# Gem Targeting: Find the closest gem ahead within a 30m detection radius
	var closest_gem: Node3D = null
	var min_gem_dist := 20.0
	for gem in get_tree().get_nodes_in_group("gem"):
		var dist = global_position.distance_to(gem.global_position)
		# Ensure gem is within range and ahead of us on the Z axis
		if dist < min_gem_dist and gem.global_position.z > global_position.z:
			# Raycast to check for line-of-sight (obstacles in collision mask 1)
			var ray_params = PhysicsRayQueryParameters3D.create(global_position, gem.global_position)
			ray_params.collision_mask = 1
			ray_params.exclude = [get_rid()]
			
			var result = space_state.intersect_ray(ray_params)
			
			# If the path is clear (no hits), the bot "sees" the gem
			if result.is_empty():
				min_gem_dist = dist
				closest_gem = gem
	
	if closest_gem:
		world_goal_direction = (closest_gem.global_position - global_position).normalized()

	if abs(global_position.x) > World.X_SIZE * 0.7:
		world_goal_direction.x = - sign(global_position.x) * 0.5
	if abs(global_position.y) > World.Y_SIZE * 0.7:
		world_goal_direction.y = - sign(global_position.y) * 0.5
	
	var interests = []
	var dangers = []
	interests.resize(num_rays)
	dangers.resize(num_rays)
	
	var sensor_dist = max(bot_radius * 6.0, speed * 1.5)
	var steering_basis = global_transform.basis # Align rays with current ship rotation
	
	for i in range(num_rays):
		var world_ray_dir = steering_basis * ray_directions[i]
		interests[i] = max(0.0, world_ray_dir.dot(world_goal_direction))
		
		var params = PhysicsShapeQueryParameters3D.new()
		params.shape = SphereShape3D.new()
		params.shape.radius = bot_radius
		params.collision_mask = 1
		params.exclude = [get_rid()]
		params.transform = Transform3D(Basis(), global_position)
		params.motion = world_ray_dir * sensor_dist
		
		var motion_result = space_state.cast_motion(params)
		if motion_result.is_empty(): dangers[i] = 1.0
		elif motion_result[0] < 1.0: dangers[i] = 1.0 - motion_result[0]
		else:
			var ray_end = global_position + world_ray_dir * sensor_dist
			if abs(ray_end.x) > World.X_SIZE or abs(ray_end.y) > World.Y_SIZE: dangers[i] = 0.9
			else: dangers[i] = 0.0

	var chosen_dir = Vector3.ZERO
	for i in range(num_rays):
		chosen_dir += (steering_basis * ray_directions[i]) * (interests[i] * pow(1.0 - dangers[i], 2.0))
	
	var local_dir = chosen_dir.normalized()
	return Vector2(local_dir.x, local_dir.y)

func _physics_process(delta: float) -> void:
	if !is_multiplayer_authority():
		return
	
	# If bot is behind ALL human players, disable collision to cheese back into the race
	#if is_ai:
		#var min_human_z := INF
		#for p in get_tree().get_nodes_in_group("player"):
			#if not p.is_ai:
				#min_human_z = min(min_human_z, p.global_position.z)
		#
		#if min_human_z != INF:
			#$CSGBakedCollisionShape3D.disabled = global_position.z < min_human_z

	if tracked_body:
		# Calculate current distance
		# this code is kinda flawed cause its tracking the object origin, not the exact closest vertex or whatever
		var current_dist = global_position.distance_to(tracked_body.global_position)
		## Keep the smallest value
		if current_dist < min_distance:
			min_distance = current_dist
	
	var camoffset = Vector3(0, 1.06, -2.2)
	if !is_ai:
		cam.global_position = cam.global_position.lerp((global_position + camoffset), delta * 12)
	
	hit_cooldown = move_toward(hit_cooldown, 0, delta)
	near_miss_hit_cooldown = move_toward(near_miss_hit_cooldown, 0, delta)
	
	var ai_speed_multiplier = 1.0
	if is_ai:
		ai_speed_multiplier = 2.4
		if is_instance_valid(Main.world):
			var leader = Main.world.get_first_place()
			if is_instance_valid(leader):
				if leader != self:
					var dist_behind = leader.global_position.z - global_position.z
					# Increase speed multiplier by up to 1.0 if 250m behind
					ai_speed_multiplier += clamp(dist_behind / 250.0, 0.0, 1.0)
				else:
					# If leading, slow down slightly to keep the race tight
					ai_speed_multiplier *= 0.85

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
		speed = move_toward(speed, top_speed, delta * (10 + (top_speed * 0.4)) * ai_speed_multiplier)
	acceleration = move_toward(acceleration, top_acceleration, delta * (10 + (top_speed * 0.4)) * ai_speed_multiplier)
	sideways_speed = move_toward(sideways_speed, top_sideways_speed, delta * 10 * ai_speed_multiplier)
	if sideways_speed < 0:
		sideways_speed = 0
	#print(acceleration)
	#print(sideways_speed)
	
	
	var input := Vector2.ZERO
	if is_ai:
		input = _get_ai_input()
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
		
	global_position.x = clamp(global_position.x, -World.X_SIZE, World.X_SIZE)
	global_position.y = clamp(global_position.y, -World.Y_SIZE, World.Y_SIZE)
	
	move_and_slide()
	
	for i in get_slide_collision_count():
		#near_miss_tracking.clear()
		near_miss_hit_cooldown = 3
		#print(1)
	
		var collision := get_slide_collision(i)
		var collider = collision.get_collider()
		if collider is Asteroid:
			collider.hit()
		
		if is_zero_approx(hit_cooldown):
				# how fast we were moving into the hit
			var impact_strength = abs(velocity.z)

			# convert impact into backward push
			var knockback = clamp(impact_strength * 0.2, 5.0, 40.0)
			
			if is_ai:
				# Bots are minimally affected by crashing
				knockback *= 0.52 # Reduce knockback for AI

			speed = - knockback * 1.6
			acceleration -= knockback * 5
			sideways_speed -= knockback * 0.6

			# optional: also reduce max speed so it matters long-term
			top_speed -= (knockback - 5) * 2.5
			
			if top_speed < 20:
				top_speed = 20
				
			hit_cooldown = 1

@rpc("any_peer", "call_local")
func speed_boost(amount):
	#printt(str(multiplayer.get_unique_id()) , "speed_boost")
	top_speed += amount
	speed += amount
var min_distance: float = 9999.0
var tracked_body: Node3D = null

func _on_near_miss_area_3d_body_exited(body: Node3D) -> void:
	if body == tracked_body:
		var dist = min_distance
		print("Near miss distance: ", dist)
		# Example: Dynamic boost based on closeness
		# If dist is 2.0 (very close), boost is higher than if dist is 5.0
		var boost_multiplier = clamp(10.0 / dist, 1.0, 5.0)
		
		speed_boost(0.6 * boost_multiplier)
		if speed > 2:
			speed += (top_speed * 0.04) + (boost_multiplier) + 4
			print((top_speed * 0.04) + (boost_multiplier) + 4)
		tracked_body = null # Stop tracking
		
		#cam.fov_boost(1.05)

func _on_near_miss_area_3d_body_entered(body: Node3D) -> void:
	if is_zero_approx(near_miss_hit_cooldown):
		tracked_body = body
		min_distance = 9999.0 # Reset for the new encounter


func _on_spark_area_3d_body_shape_entered(body_rid: RID, body: Node3D, body_shape_index: int, local_shape_index: int) -> void:
	var local_shape_owner = $SparkArea3D.shape_find_owner(local_shape_index)
	var local_shape_node = $SparkArea3D.shape_owner_get_owner(local_shape_owner)
	if speed > 2:
		$Sparks.global_position = local_shape_node.global_position
		$Sparks.global_rotation = local_shape_node.global_rotation
		$Sparks.emitting = true

func _on_spark_area_3d_body_shape_exited(body_rid: RID, body: Node3D, body_shape_index: int, local_shape_index: int) -> void:
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

func complete_race():
	has_finished = true
	# Call your UI manager
	UIManager.show_finish_screen(get_standing())
	
func get_standing() -> int:
	var all_players = get_tree().get_nodes_in_group("player")
	all_players.sort_custom(func(a, b):
		return a.global_position.z > b.global_position.z
	)
	var index = all_players.find(self )
	# 4. Convert 0-index to 1-based standing (0 becomes 1st)
	return index + 1
