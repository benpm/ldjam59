class_name EnemyCable extends Node3D

enum State { HOLDING, APPROACHING, STRIKING, RETREATING }

const ANCHOR_FORCE: float = 3.0
const ANCHOR_DAMPING: float = 0.90
const APPROACH_FORCE: float = 2.0
const STRIKE_FORCE: float = 10.0
const TIP_DAMPING: float = 0.88
const HIT_RADIUS: float = 0.55
const PROXIMITY_STRIKE_RADIUS: float = 2.5
const APPROACH_STRIKE_RADIUS: float = 4.0
const STRIKE_INTERVAL_MIN: float = 2.0
const STRIKE_INTERVAL_MAX: float = 6.0

var player: Player = null
var orbit_angle: float = 0.0
var hover_radius: float = 13.0
var orbit_center: Vector3 = Vector3.ZERO

@onready var _chain: DynamicChain = $Chain
@onready var _anchor: Node3D = $Chain/Anchor
@onready var _tip: Node3D = $Chain/Tip

var _anchor_vel: Vector3 = Vector3.ZERO
var _tip_vel: Vector3 = Vector3.ZERO
var _state := State.HOLDING
var _next_approach: float = 0.0
var _can_hit: bool = true
var _wiggle_phases := Vector3.ZERO


func _ready() -> void:
	_wiggle_phases = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
	_schedule_approach()


func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	var ppos := player.global_position
	var t := Time.get_ticks_msec() / 1000.0

	# Wiggle offset — incommensurate frequencies, per-enemy random phases
	var wx := sin(t * 0.6 + _wiggle_phases.x) * 1.0 + sin(t * 1.1 + _wiggle_phases.y) * 0.5
	var wz := sin(t * 0.8 + _wiggle_phases.z) * 1.0 + sin(t * 0.5 + _wiggle_phases.x) * 0.4
	var hover_target := Vector3(
		orbit_center.x + cos(orbit_angle) * hover_radius + wx,
		ppos.y + 0.5,
		orbit_center.z + sin(orbit_angle) * hover_radius + wz
	)

	# Proximity check — instant strike if player walks into tip (any state except STRIKING)
	if _state != State.STRIKING and _tip.global_position.distance_to(ppos) < PROXIMITY_STRIKE_RADIUS:
		_state = State.STRIKING
		_can_hit = true

	match _state:
		State.HOLDING:
			_move_anchor_toward(hover_target, ANCHOR_FORCE, delta)
			_move_tip_toward(_anchor.global_position, ANCHOR_FORCE, delta)
			if t >= _next_approach:
				_state = State.APPROACHING

		State.APPROACHING:
			# Anchor slithers toward player; tip trails behind via chain
			var approach_target := Vector3(ppos.x, hover_target.y, ppos.z)
			_move_anchor_toward(approach_target, APPROACH_FORCE, delta)
			_move_tip_toward(_anchor.global_position, ANCHOR_FORCE * 0.5, delta)
			if _tip.global_position.distance_to(ppos) < APPROACH_STRIKE_RADIUS:
				_state = State.STRIKING
				_can_hit = true

		State.STRIKING:
			# Anchor holds; tip lunges at ground level
			_move_anchor_toward(hover_target, ANCHOR_FORCE * 0.3, delta)
			var strike_target := Vector3(ppos.x, 0.5, ppos.z)
			var to_target := strike_target - _tip.global_position
			_tip_vel += to_target.normalized() * STRIKE_FORCE * delta
			_tip_vel *= TIP_DAMPING
			_tip.global_position += _tip_vel * delta
			if _can_hit and _tip.global_position.distance_to(ppos) < HIT_RADIUS:
				player.take_hit()
				_can_hit = false
			if _tip.global_position.distance_squared_to(strike_target) < 0.15:
				_state = State.RETREATING

		State.RETREATING:
			_move_anchor_toward(hover_target, ANCHOR_FORCE, delta)
			_move_tip_toward(_anchor.global_position, ANCHOR_FORCE, delta)
			if _tip.global_position.distance_squared_to(_anchor.global_position) < 0.5:
				_state = State.HOLDING
				_schedule_approach()


func _move_anchor_toward(target: Vector3, force: float, delta: float) -> void:
	_anchor_vel += (target - _anchor.global_position) * force * delta
	_anchor_vel *= ANCHOR_DAMPING
	_anchor.global_position += _anchor_vel * delta


func _move_tip_toward(target: Vector3, force: float, delta: float) -> void:
	_tip_vel += (target - _tip.global_position) * force * delta
	_tip_vel *= TIP_DAMPING
	_tip.global_position += _tip_vel * delta


func _schedule_approach() -> void:
	_next_approach = Time.get_ticks_msec() / 1000.0 + randf_range(STRIKE_INTERVAL_MIN, STRIKE_INTERVAL_MAX)
