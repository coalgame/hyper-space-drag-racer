extends Camera3D

@export var base_fov: float = 75.0
@export var boost_fov: float = 85.0

# Store the original position to return to after shaking
@onready var original_pos: Vector3 = position

func fov_boost(duration: float = 1.0) -> void:
	var tween = create_tween()
	# Fast kick out
	tween.tween_property(self, "fov", 80, 0.15).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	# Smooth return
	tween.tween_property(self, "fov", base_fov, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func screenshake(intensity: float = 0.2, duration: float = 0.5) -> void:
	var tween = create_tween()
	
	# We create a series of rapid movements to random offsets
	var shake_count = 10 
	for i in range(shake_count):
		var random_offset = Vector3(
			randf_range(-intensity, intensity),
			randf_range(-intensity, intensity),
			0 # Usually better to keep shake on X and Y for racing
		)
		tween.tween_property(self, "h_offset", random_offset.x, duration / shake_count)
		tween.tween_property(self, "v_offset", random_offset.y, duration / shake_count)
	
	# Reset offsets to zero at the end
	tween.tween_property(self, "h_offset", 0.0, 0.1)
	tween.tween_property(self, "v_offset", 0.0, 0.1)
