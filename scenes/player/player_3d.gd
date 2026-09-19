extends CharacterBody3D

@export var speed: float = 3.2
@export var camera: Camera3D
var controls_enabled: bool = true
var _facing: StringName = &"down"

@onready var sprite: AnimatedSprite3D = $AnimatedSprite3D

func _physics_process(delta: float) -> void:
	var input_direction := Vector2.ZERO
	if controls_enabled:
		input_direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var right := Vector3.RIGHT
	var back := Vector3.BACK
	if is_instance_valid(camera):
		right = camera.global_basis.x
		back = camera.global_basis.z
		right.y = 0.0
		back.y = 0.0
		right = right.normalized()
		back = back.normalized()
	var direction := right * input_direction.x + back * input_direction.y
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	if not is_on_floor():
		velocity += get_gravity() * delta
	else:
		velocity.y = 0.0
	move_and_slide()
	_update_animation(input_direction)

func _update_animation(direction: Vector2) -> void:
	if not direction.is_zero_approx():
		sprite.flip_h = direction.x < 0.0
		if is_zero_approx(direction.x):
			_facing = &"down" if direction.y > 0.0 else &"up"
		elif is_zero_approx(direction.y):
			_facing = &"side"
		else:
			_facing = &"down_side" if direction.y > 0.0 else &"up_side"
	var actual_velocity := Vector2(get_real_velocity().x, get_real_velocity().z)
	var moving: bool = controls_enabled and actual_velocity.length_squared() > 0.01
	sprite.play(StringName(("walk_" if moving else "idle_") + String(_facing)))
