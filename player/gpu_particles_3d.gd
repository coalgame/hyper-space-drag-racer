extends GPUParticles3D

@export var ship: Player # Drag your ship node into this slot in the inspector
@export var base_speed: float = 1.0
@export var hyperspace_multiplier: float = 15.0

func _process(delta):
	self.global_rotation = Vector3.ZERO
	# Assuming your ship script has 'current_speed' and 'max_speed' variables
	if is_instance_valid(ship):
		# Get a percentage of how fast the ship is going (0.0 to 1.0)
		var speed_percent = ship.speed / 130.0
		
		# Ramp up the speed_scale of the particle system
		self.speed_scale = base_speed + (speed_percent * hyperspace_multiplier)
		
		self.draw_pass_1.size = Vector3(0.15, 0.15,  0.2 + (speed_percent*7))
		self.draw_pass_1.material.albedo_color = Color.from_hsv(.0,0, 1+(speed_percent*3))
