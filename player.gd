class_name Player extends CharacterBody3D

const SPEED: float = 5.0
const SPEED_HELD: float = 2.0
const JUMP_VELOCITY: float = 6.0
const HIT_WINDOW: float = 5.0
const MAX_HITS: int = 3
const INVINCIBLE_DURATION: float = 0.6

var holding_cable: bool = false
var camera_right: Vector3 = Vector3.RIGHT
var camera_forward: Vector3 = Vector3.BACK
var _last_move_dir: Vector3 = Vector3.ZERO
var _hit_times: Array[float] = []
var _invincible_timer: float = 0.0

signal died

func _physics_process(delta: float) -> void:
	_invincible_timer = maxf(0.0, _invincible_timer - delta)

	if not is_on_floor():
		velocity += get_gravity() * delta
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		var dodge_dir := _last_move_dir if _last_move_dir.length_squared() > 0.0 else Vector3.ZERO
		velocity.x = dodge_dir.x * SPEED
		velocity.z = dodge_dir.z * SPEED

	var input := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_forward", "move_back")
	)
	var dir := camera_right * input.x + camera_forward * (-input.y)
	dir.y = 0.0
	if dir.length_squared() > 0.0:
		dir = dir.normalized()
		_last_move_dir = dir
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
