class_name PlayerTrail extends MeshInstance3D

var scale_multiplier := 0.01
var min_scale := 0.6
var max_scale := 2.5
var source: Player

static var _cam: Camera3D


func _ready() -> void:
	scale = Util.VEC3ZERO

	await Util.wait(0.5)


	var mat := get_surface_override_material(0) as ShaderMaterial
	if mat == null:
		mat = mesh.material as ShaderMaterial
	var base_color: Color = mat.get_shader_parameter("albedo")
	var tween = create_tween()
	tween.parallel().tween_property(self , "scale", Util.VEC3ZERO, 2)
	tween.parallel().tween_method(func(a): mat.set_shader_parameter("albedo", Color(base_color.r, base_color.g, base_color.b, a)), base_color.a, 0.0, 2)
	tween.tween_callback(queue_free)

func _process(delta: float) -> void:
	if not is_instance_valid(_cam):
		_cam = get_viewport().get_camera_3d()
	if not _cam:
		return
	
	var distance := global_position.distance_to(_cam.global_position)
	
	# Bigger when farther away
	var scale_amount := clampf(distance * scale_multiplier, min_scale, max_scale)
	
	scale = Vector3.ONE * scale_amount
	
	rotation += Vector3.ONE * 3 * delta

func _on_area_3d_body_entered(body: Node3D) -> void:
	if body is Player:
		if body == source: return # cant eat their own trail!
		if body.is_multiplayer_authority():
			body.speed_boost(0.45)
			# client side only, other players can eat the same trail 
			queue_free()
