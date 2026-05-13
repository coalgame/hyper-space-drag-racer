extends Node3D

func _ready() -> void:
	generate()
	
func generate() -> void:
	var scenes = [
		preload("res://pieces/cube1.blend"),
		preload("res://pieces/cube2.blend"),
		
	]
	# Random spread around the center path.
	var x_range := Vector2(-5.0, 5.0)
	var y_range := Vector2(-5.0, 5.0)

	
	var z_spacing := 5
	var random_scale := Vector2(0.8, 1.5)
	
	for i in 10000:
		var block_scene = scenes.pick_random()
		
		var block = block_scene.instantiate()
		add_child(block)

		var x := randf_range(x_range.x, x_range.y)
		var y := randf_range(y_range.x, y_range.y)
		var z := i * z_spacing

		block.position = Vector3(x, y, -z)

		# Random rotation helps break up obvious repetition.
		block.rotation = Vector3(
			randf_range(0.0, TAU),
			randf_range(0.0, TAU),
			randf_range(0.0, TAU)
		)
	
		# Slight size variation makes the tunnel feel more natural.
		var scale_mul := randf_range(random_scale.x, random_scale.y)
		block.scale = Vector3.ONE * scale_mul
