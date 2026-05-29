extends GPUParticles3D

func set_material(mat: Material):
	draw_pass_1.material = mat

func _ready():
	emitting = true
	await get_tree().create_timer(lifetime + 0.5).timeout
	queue_free()
