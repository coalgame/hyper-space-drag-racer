class_name PlayerTrail extends MeshInstance3D

var scale_multiplier := 0.01
var min_scale := 0.6
var max_scale := 2.0

# In player_trail.gd
var color: Color:
	set(value):
		color = value
		mesh.material.set_shader_parameter("albedo", value)

func _ready() -> void:
	scale=Vector3.ZERO
	
	await Util.wait(1)
	
	var tween = create_tween()
	tween.parallel().tween_property(self, "scale", Vector3.ZERO, 3)
	tween.parallel().tween_property(self, "transparency", 1, 3)
	
	tween.tween_callback(queue_free)

		
func _process(delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	
	if camera == null:
		return
	
	var distance := global_position.distance_to(camera.global_position)
	
	# Bigger when farther away
	var scale_amount := clampf(distance * scale_multiplier, min_scale, max_scale)
	
	scale = Vector3.ONE * scale_amount

	var rotate_speed = 3   
	rotate_x(delta*rotate_speed)
	rotate_y(delta*rotate_speed)
	rotate_z(delta*rotate_speed)


func _on_area_3d_body_entered(body: Node3D) -> void:
	if body is Player:
		if body.is_multiplayer_authority():
			body.speed_boost(0.45)
			# client side only, other players can eat the same trail 
			queue_free()
			
