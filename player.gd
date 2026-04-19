class_name Player extends CharacterBody3D

const SPEED: float = 5.0
const SPEED_HELD: float = 2.0
const JUMP_VELOCITY: float = 6.0

var holding_cable: bool = false

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var input := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_forward", "move_back")
	)
	var dir := Vector3(input.x, 0.0, input.y)
	if dir.length_squared() > 0.0:
		dir = dir.normalized()
	var spd := SPEED_HELD if holding_cable else SPEED
	velocity.x = dir.x * spd
	velocity.z = dir.z * spd

	move_and_slide()
