class_name Piece extends StaticBody3D

# TODO (NOT FOR AGENTS) breaking blocks causes a lot of errors in the output (multiplayer). figure out whats up w that (probably related to breaking the blocks)

var max_health: float = 100.0
var health: float = 100.0

@onready var mesh: MeshInstance3D = _find_mesh(owner if owner else self )

func _find_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var found = _find_mesh(child)
		if found:
			return found
	return null

func _ready() -> void:
	# Health based on scale
	var avg_scale = (global_transform.basis.get_scale().x + global_transform.basis.get_scale().y + global_transform.basis.get_scale().z) / 3.0
	max_health = avg_scale * 100.0
	health = max_health
	
	if mesh:
		# Ensure we have a unique material for damage visuals
		var mat = mesh.get_surface_override_material(0)
		if !mat:
			mat = mesh.mesh.surface_get_material(0)
		
		if mat:
			mesh.set_surface_override_material(0, mat.duplicate())

func hit(damage_amount: float):
	if damage_amount < 15: return # dont let players 'slide' in to blocks, dealing a billion damage instantly
	request_hit.rpc_id(1, damage_amount)

@rpc("any_peer", "call_local")
func request_hit(damage_amount: float):
	if not multiplayer.is_server():
		return
	
	if health <= 0:
		return
		
	health -= damage_amount
	sync_damage.rpc(health)
	
	if health <= 0:
		destroy.rpc()

@rpc("any_peer", "call_local")
func sync_damage(new_health: float):
	health = new_health
	var damage_pct = 1.0 - (health / max_health)
	if mesh:
		var mat = mesh.get_surface_override_material(0)
		if mat:
			mat.set_shader_parameter("damage_blend", clamp(damage_pct, 0.0, 1.0))

@rpc("any_peer", "call_local")
func destroy():
	if multiplayer.is_server():
		var gem_scene = preload("res://world/gem.tscn")
		var p = Main.world
		for i in randi_range(1,2):
			var gem = gem_scene.instantiate()
			# Add immediately to the world so we can start a Tween
			p.add_child(gem, true)
			gem.global_position = global_position
			
			# Calculate a random 'pop' target with horizontal and vertical spread
			var dir = Vector3(randf_range(-1, 1), randf_range(0.2, 1.2), randf_range(-1, 1)).normalized()
			var target = global_position + dir * randf_range(6.0, 10.0)
			
			var tw = gem.create_tween()
			tw.tween_property(gem, "global_position", target, 1.0).set_trans(Tween.TransitionType.TRANS_CUBIC).set_ease(Tween.EaseType.EASE_OUT)

	spawn_particles()
	if owner:
		owner.queue_free()
	else:
		queue_free()

func spawn_particles():
	var particles = preload("res://pieces/piece_explosion.tscn").instantiate()
	get_tree().root.add_child(particles)
	particles.global_position = global_position
	# Pass the material to the particles so they match
	if mesh:
		var mat = mesh.get_surface_override_material(0)
		if mat:
			particles.set_material(mat)
