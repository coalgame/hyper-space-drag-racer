extends Camera3D

@export var speed := 30.0
@export var sensitivity := 0.25

var _rotation := Vector3.ZERO

func _ready() -> void:
	_rotation = rotation_degrees
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_rotation.x -= event.relative.y * sensitivity
		_rotation.y -= event.relative.x * sensitivity
		_rotation.x = clamp(_rotation.x, -89, 89)
		rotation_degrees = _rotation
	
	# Toggle mouse capture without disabling the camera
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED

func _process(delta: float) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
		
	var input_dir = Vector3.ZERO
	if Input.is_key_pressed(KEY_W): input_dir.z -= 1
	if Input.is_key_pressed(KEY_S): input_dir.z += 1
	if Input.is_key_pressed(KEY_A): input_dir.x -= 1
	if Input.is_key_pressed(KEY_D): input_dir.x += 1
	if Input.is_key_pressed(KEY_Q): input_dir.y -= 1 # Down
	if Input.is_key_pressed(KEY_E): input_dir.y += 1 # Up
	
	var move_speed = speed
	if Input.is_key_pressed(KEY_SHIFT):
		move_speed *= 4.0
			
	var motion = (global_transform.basis * input_dir).normalized() * move_speed * delta
	global_position += motion