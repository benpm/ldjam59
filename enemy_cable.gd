@tool
class_name EnemyCable extends Node3D

enum State {HOLDING, APPROACHING, STRIKING, RETREATING}

const ANCHOR_FORCE: float = 3.0
const ANCHOR_DAMPING: float = 0.90
const APPROACH_FORCE: float = 2.0
const STRIKE_FORCE: float = 10.0
const SNAP_FORCE: float = 28.0
const TIP_DAMPING: float = 0.88
const HIT_RADIUS: float = 0.55
const PROXIMITY_STRIKE_RADIUS: float = 2.5
const APPROACH_STRIKE_RADIUS: float = 4.0
const STRIKE_INTERVAL_MIN: float = 2.0
const STRIKE_INTERVAL_MAX: float = 6.0
const ORBIT_DIST: float = 4.5
const SNAP_RADIUS: float = 2.2
const ANCHOR_MOVE_INTERVAL_MIN: float = 4.0
const ANCHOR_MOVE_INTERVAL_MAX: float = 8.0
const ANCHOR_SETTLE_THRESHOLD: float = 0.3

@export var chain_length: float = 10.0:
	set(value):
		chain_length = value
		_rebuild_range_indicator()

var player: Player = null

@onready var _chain: DynamicChain = $Chain
@onready var _anchor: Node3D = $Chain/Anchor
@onready var _tip: Node3D = $Chain/Tip

var _anchor_vel: Vector3 = Vector3.ZERO
var _tip_vel: Vector3 = Vector3.ZERO
var _state := State.HOLDING
var _next_approach: float = 0.0
var _can_hit: bool = true
var _wiggle_phases := Vector3.ZERO
var _range_indicator: MeshInstance3D
var _orbit_angle: float = 0.0
var _is_snap: bool = false
var _anchor_target: Vector3 = Vector3.ZERO
var _anchor_moving: bool = false
var _next_anchor_move: float = 0.0


func _ready() -> void:
	_rebuild_range_indicator()
	if Engine.is_editor_hint():
		return
	_chain.link_count = roundi(chain_length / _chain.link_length) * 2
	_wiggle_phases = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
	_orbit_angle = randf() * TAU
	_anchor_target = _anchor.global_position
	_schedule_anchor_move()
	_schedule_approach()


func _rebuild_range_indicator() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	if not is_instance_valid(_range_indicator):
		_range_indicator = MeshInstance3D.new()
		add_child(_range_indicator)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.2, 0.1, 1.0)
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, mat)
	for i in range(33):
		var a := float(i % 32) / 32.0 * TAU
		im.surface_add_vertex(Vector3(cos(a) * chain_length, 0.05, sin(a) * chain_length))
	im.surface_end()
	_range_indicator.mesh = im


func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	var ppos := player.global_position
	var t := Time.get_ticks_msec() / 1000.0

	# Move anchor to a new spot near the player once in a while
	if t >= _next_anchor_move and not _anchor_moving:
		_anchor_moving = true
		_orbit_angle = randf() * TAU
		_anchor_target = Vector3(
			ppos.x + cos(_orbit_angle) * ORBIT_DIST,
			0.0,
			ppos.z + sin(_orbit_angle) * ORBIT_DIST
		)
	if _anchor_moving:
		_move_anchor_toward(_anchor_target, ANCHOR_FORCE, delta)
		if _anchor.global_position.distance_to(_anchor_target) < ANCHOR_SETTLE_THRESHOLD:
			_anchor_moving = false
			_anchor_vel = Vector3.ZERO
			_schedule_anchor_move()

	# Snap attack when player walks close to the anchor
	if _state != State.STRIKING and _anchor.global_position.distance_to(ppos) < SNAP_RADIUS:
		_state = State.STRIKING
		_can_hit = true
		_is_snap = true

	# Fallback: proximity from tip
	if _state != State.STRIKING and _tip.global_position.distance_to(ppos) < PROXIMITY_STRIKE_RADIUS:
		_state = State.STRIKING
		_can_hit = true
		_is_snap = false

	match _state:
		State.HOLDING:
			_move_tip_toward(_anchor.global_position, ANCHOR_FORCE, delta)
			if t >= _next_approach:
				_state = State.APPROACHING

		State.APPROACHING:
			_move_tip_toward(_anchor.global_position, ANCHOR_FORCE * 0.5, delta)
			if _tip.global_position.distance_to(ppos) < APPROACH_STRIKE_RADIUS:
				_state = State.STRIKING
				_can_hit = true
				_is_snap = false

		State.STRIKING:
			var strike_target := Vector3(ppos.x, 0.5, ppos.z)
			var to_target := strike_target - _tip.global_position
			var force := SNAP_FORCE if _is_snap else STRIKE_FORCE
			_tip_vel += to_target.normalized() * force * delta
			_tip_vel *= TIP_DAMPING
			_tip.global_position += _tip_vel * delta
			if _can_hit and _tip.global_position.distance_to(ppos) < HIT_RADIUS:
				player.take_hit()
				_can_hit = false
			if _tip.global_position.distance_squared_to(strike_target) < 0.15:
				_state = State.RETREATING
				_is_snap = false

		State.RETREATING:
			_move_tip_toward(_anchor.global_position, ANCHOR_FORCE, delta)
			if _tip.global_position.distance_squared_to(_anchor.global_position) < 0.5:
				_state = State.HOLDING
				_schedule_approach()


func _move_anchor_toward(target: Vector3, force: float, delta: float) -> void:
	_anchor_vel += (target - _anchor.global_position) * force * delta
	_anchor_vel *= ANCHOR_DAMPING
	_anchor.global_position += _anchor_vel * delta


func _move_tip_toward(target: Vector3, force: float, delta: float) -> void:
	var to_target := target - _anchor.global_position
	var dist := to_target.length()
	var max_reach := _chain.total_length() - 1.0
	if dist > max_reach:
		target = _anchor.global_position + to_target.normalized() * max_reach
	_tip_vel += (target - _tip.global_position) * force * delta
	_tip_vel *= TIP_DAMPING
	_tip.global_position += _tip_vel * delta


func _schedule_approach() -> void:
	_next_approach = Time.get_ticks_msec() / 1000.0 + randf_range(STRIKE_INTERVAL_MIN, STRIKE_INTERVAL_MAX)


func _schedule_anchor_move() -> void:
	_next_anchor_move = Time.get_ticks_msec() / 1000.0 + randf_range(ANCHOR_MOVE_INTERVAL_MIN, ANCHOR_MOVE_INTERVAL_MAX)
