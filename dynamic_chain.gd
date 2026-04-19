@tool

class_name DynamicChain extends Node3D

enum AnchorMode {NONE, START, END, BOTH}

@export var path: Path3D:
	set(value):
		path = value
		if Engine.is_editor_hint() and is_inside_tree():
			_init_rope()

@export var anchor_mode: AnchorMode = AnchorMode.START:
	set(value):
		anchor_mode = value
		if Engine.is_editor_hint() and is_inside_tree():
			_init_rope()

@export var link_length: float = 0.5:
	set(value):
		link_length = maxf(0.01, value)
		if Engine.is_editor_hint() and is_inside_tree():
			_init_rope()

@export_range(2, 500) var link_count: int = 10:
	set(value):
		link_count = value
		if Engine.is_editor_hint() and is_inside_tree():
			_init_rope()

@export var gravity: float = 9.8
@export var damping: float = 0.98
@export_range(1, 20) var constraint_iterations: int = 5
@export var collision_radius: float = 0.05
@export_flags_3d_physics var collision_mask: int = 1

@export var anchor: Node3D
@export var end_anchor: Node3D
@export var link_container: Node3D

@export var link_material: Material

@export var link_mesh: Mesh:
	set(value):
		link_mesh = value
		_rebuild_visuals()

@export_group("Auto Grow")
@export var auto_grow: bool = false
@export var grow_max_links: int = 300
@export var grow_tension_threshold: float = 0.05
@export var grow_sustain_frames: int = 8
@export var grow_cooldown: float = 0.0

var _points: PackedVector3Array
var _prev_points: PackedVector3Array
var _mesh_instances: Array[MeshInstance3D] = []
var _taut_frames: int = 0
var _grow_cooldown_timer: float = 0.0
var _first_link_tension: float = 0.0


func _ready() -> void:
	_init_rope()


func _init_rope() -> void:
	_rebuild_visuals()
	_reset_points()


func _reset_points() -> void:
	var n := link_count + 1
	_points.resize(n)
	_prev_points.resize(n)

	var has_path := _has_path()
	var baked_len := path.curve.get_baked_length() if has_path else 0.0
	var start := anchor.global_position if is_instance_valid(anchor) else global_position

	for i in range(n):
		var p: Vector3
		if has_path:
			var t := float(i) / float(link_count) * baked_len
			p = path.global_transform * path.curve.sample_baked(t, true)
		else:
			p = start + Vector3(0, -i * link_length, 0)
		_points[i] = p
		_prev_points[i] = p


func _rebuild_visuals() -> void:
	if not is_instance_valid(link_container):
		return
	for inst in _mesh_instances:
		if is_instance_valid(inst):
			inst.queue_free()
	_mesh_instances.clear()

	var mesh := link_mesh
	if mesh == null:
		var cyl := CapsuleMesh.new()
		cyl.radius = collision_radius * 2.0
		cyl.height = link_length * 2.0
		mesh = cyl

	for i in range(link_count):
		var inst := MeshInstance3D.new()
		inst.mesh = mesh
		if is_instance_valid(link_material):
			inst.material_override = link_material
		link_container.add_child(inst)
		_mesh_instances.append(inst)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_simulate(delta)
	_update_visuals()
	if auto_grow:
		_try_grow(delta)


func _simulate(delta: float) -> void:
	var n := _points.size()
	var grav := Vector3(0, -gravity * delta * delta, 0)

	for i in range(n):
		if _is_anchored(i, n):
			continue
		var vel := (_points[i] - _prev_points[i]) * damping
		_prev_points[i] = _points[i]
		_points[i] += vel + grav

	_pin_anchors(n)

	_first_link_tension = 0.0
	for _iter in range(constraint_iterations):
		for i in range(link_count):
			var diff := _points[i + 1] - _points[i]
			var dist := diff.length()
			if dist < 0.0001:
				continue
			var correction := diff * (1.0 - link_length / dist)
			# Capture first-link stretch before any solving (first iteration only)
			if _iter == 0 and i == 0 and dist > link_length:
				_first_link_tension = dist - link_length
			var a_pinned := _is_anchored(i, n)
			var b_pinned := _is_anchored(i + 1, n)
			if not a_pinned and not b_pinned:
				_points[i] += correction * 0.5
				_points[i + 1] -= correction * 0.5
			elif not a_pinned:
				_points[i] += correction
			elif not b_pinned:
				_points[i + 1] -= correction

		_pin_anchors(n)

	_resolve_collisions(n)
	_clamp_points_to_floor(n)


func _try_grow(delta: float) -> void:
	_grow_cooldown_timer = maxf(0.0, _grow_cooldown_timer - delta)
	if _first_link_tension > grow_tension_threshold:
		_taut_frames += 1
	else:
		_taut_frames = 0
	if _taut_frames >= grow_sustain_frames and _grow_cooldown_timer <= 0.0 and link_count < grow_max_links:
		_add_link_at_anchor()
		_taut_frames = 0
		_grow_cooldown_timer = grow_cooldown


func _add_link_at_anchor() -> void:
	link_count += 1
	# Insert new point at anchor position — it will be pulled out naturally
	var new_pt := _points[0]
	_points.insert(1, new_pt)
	_prev_points.insert(1, new_pt)
	if not is_instance_valid(link_container):
		return
	var mesh := link_mesh
	if mesh == null:
		var cyl := CapsuleMesh.new()
		cyl.radius = collision_radius * 2.0
		cyl.height = link_length * 2.0
		mesh = cyl
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	if is_instance_valid(link_material):
		inst.material_override = link_material
	link_container.add_child(inst)
	_mesh_instances.insert(0, inst)


func _resolve_collisions(n: int) -> void:
	var space := get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.new()
	ray.collision_mask = collision_mask
	for i in range(n):
		if _is_anchored(i, n):
			continue
		ray.from = _points[i] + Vector3(0, collision_radius, 0)
		ray.to = _points[i] - Vector3(0, collision_radius, 0)
		var hit := space.intersect_ray(ray)
		if hit.is_empty():
			continue
		var normal: Vector3 = hit.normal
		var target := (hit.position as Vector3) + normal * collision_radius
		if (_points[i] - hit.position).dot(normal) < collision_radius:
			_points[i] = target
			var vel := _points[i] - _prev_points[i]
			vel -= minf(vel.dot(normal), 0.0) * normal
			_prev_points[i] = _points[i] - vel


func _clamp_points_to_floor(n: int) -> void:
	var min_y := -collision_radius
	for i in range(n):
		if _is_anchored(i, n):
			continue
		if _points[i].y < min_y:
			_points[i].y = min_y
			_prev_points[i].y = min_y


func _pin_anchors(n: int) -> void:
	if anchor_mode == AnchorMode.START or anchor_mode == AnchorMode.BOTH:
		if is_instance_valid(anchor):
			_points[0] = anchor.global_position
			_prev_points[0] = anchor.global_position
	if anchor_mode == AnchorMode.END or anchor_mode == AnchorMode.BOTH:
		if is_instance_valid(end_anchor):
			_points[n - 1] = end_anchor.global_position
			_prev_points[n - 1] = end_anchor.global_position


func _is_anchored(i: int, n: int) -> bool:
	if i == 0 and (anchor_mode == AnchorMode.START or anchor_mode == AnchorMode.BOTH):
		return true
	if i == n - 1 and (anchor_mode == AnchorMode.END or anchor_mode == AnchorMode.BOTH):
		return true
	return false


func _update_visuals() -> void:
	for i in range(_mesh_instances.size()):
		var inst := _mesh_instances[i]
		if not is_instance_valid(inst):
			continue
		var a := _points[i]
		var b := _points[i + 1]
		var dir := b - a
		var dist := dir.length()
		if dist < 0.0001:
			continue
		var up := dir / dist
		var ref := Vector3.FORWARD if absf(up.dot(Vector3.UP)) > 0.9 else Vector3.UP
		var right := ref.cross(up).normalized()
		var fwd := up.cross(right).normalized()
		inst.global_transform = Transform3D(Basis(right, up, -fwd), (a + b) * 0.5)


func _has_path() -> bool:
	return is_instance_valid(path) and path.curve != null and path.curve.get_baked_length() > 0.0

func total_length() -> float:
	return link_length * link_count