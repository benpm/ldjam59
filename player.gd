class_name Player extends CharacterBody3D

const SPEED: float = 5.0
const SPEED_HELD: float = 2.0
const JUMP_VELOCITY: float = 6.0
const HIT_WINDOW: float = 5.0
const MAX_HITS: int = 3
const INVINCIBLE_DURATION: float = 0.6

var holding_cable: bool = false
var _hit_times: Array[float] = []
var _invincible_timer: float = 0.0

signal died

func _physics_process(delta: float) -> void:
	_invincible_timer = maxf(0.0, _invincible_timer - delta)

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

func take_hit() -> void:
	if _invincible_timer > 0.0:
		return
	_invincible_timer = INVINCIBLE_DURATION
	var now := Time.get_ticks_msec() / 1000.0
	_hit_times.append(now)
	_hit_times = _hit_times.filter(func(t: float) -> bool: return now - t < HIT_WINDOW)
	if _hit_times.size() >= MAX_HITS:
		died.emit()
