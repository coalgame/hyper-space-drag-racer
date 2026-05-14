extends MeshInstance3D

var scale_multiplier := 0.01
var min_scale := 0.6
var max_scale := 2.0

var dummy = false

func _ready() -> void:
	if dummy:
		scale=Vector3.ZERO
	else:
		scale=Vector3.ONE * 0.2
		transparency = 0.95
	
	
	await Global.wait(1)
	
	if dummy:
		var tween = create_tween()
		tween.parallel().tween_property(self, "scale", Vector3.ZERO, 3)
		tween.parallel().tween_property(self, "transparency", 1, 3)
		
		tween.tween_callback(queue_free)
	else:
		queue_free()
		
func _process(delta: float) -> void:
	if !dummy: return
	
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
			body.speed_boost(0.2)
			queue_free()
