class_name PlayerTrail extends MeshInstance3D

var scale_multiplier := 0.01
var min_scale := 0.6
var max_scale := 3.0
var source: Player

static var _cam: Camera3D


func _ready() -> void:
	scale=Util.VEC3ZERO

	await Util.wait(1)


	
	var tween = create_tween()
	tween.parallel().tween_property(self, "scale", Util.VEC3ZERO, 3)
	tween.parallel().tween_property(self, "transparency", 1, 3)
	
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
