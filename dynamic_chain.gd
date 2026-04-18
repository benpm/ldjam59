@tool

class_name DynamicChain extends Node3D

enum AnchorMode {NONE, START, END, BOTH}

@export var path: Path3D:
	set(value):
		path = value
		_regenerate_chain()

@export var anchor_mode: AnchorMode = AnchorMode.START:
	set(value):
		anchor_mode = value
		_regenerate_chain()

@export var link_length: float = 1.0:
	set(value):
		link_length = max(0.01, value)
		_regenerate_chain()

@export var link_radius: float = 0.1
@export var stiffness: float = 10.0
@export var damping: float = 0.5
@export var link_mass: float = 0.5

@export var anchor: StaticBody3D
@export var end_anchor: StaticBody3D
@export var link_container: Node3D

@export var link_mesh: Mesh = null:
	set(value):
		link_mesh = value
		_regenerate_chain()

# Used only when path is null.
@export_range(2, 50) var link_count: int = 10:
	set(value):
		link_count = value
		_regenerate_chain()

const angular_limit_rad: float = deg_to_rad(30.0)
const twist_limit_rad: float = deg_to_rad(15.0)

var links: Array[RigidBody3D] = []
var joints: Array[Generic6DOFJoint3D] = []
var cylinder_mesh: CylinderMesh = null


func _ready() -> void:
	if not Engine.is_editor_hint():
		_generate_chain()

func _clear_chain() -> void:
	for link in links:
		if is_instance_valid(link):
			link.queue_free()
	for joint in joints:
		if is_instance_valid(joint):
			joint.queue_free()
	links.clear()
	joints.clear()
	if is_instance_valid(link_container):
		for child in link_container.get_children():
			if is_instance_valid(child):
				child.queue_free()

func _generate_chain() -> void:
	if not is_instance_valid(link_container):
		return

	if link_mesh == null:
		link_mesh = CylinderMesh.new()
		link_mesh.top_radius = link_radius
		link_mesh.bottom_radius = link_radius
		link_mesh.height = link_length

	_clear_chain()

	var n := _compute_link_count()
	for i in range(n):
		var link := _create_link(i)
		link_container.add_child(link)
		links.append(link)
		link.transform = _link_transform_at(i)

	# Snap anchors onto the path if requested.
	var has_path := _has_path()
	var baked_len := path.curve.get_baked_length() if has_path else 0.0
	if has_path:
		if anchor_mode == AnchorMode.START or anchor_mode == AnchorMode.BOTH:
			_place_path_anchor(anchor, 0.0)
		if anchor_mode == AnchorMode.END or anchor_mode == AnchorMode.BOTH:
			_place_path_anchor(end_anchor, baked_len)

	# Wait for links to be added to scene tree before creating joints.
	await get_tree().process_frame

	if anchor_mode == AnchorMode.START or anchor_mode == AnchorMode.BOTH:
		if is_instance_valid(anchor):
			var j_start := _create_joint(anchor, links[0], false)
			links[0].add_child(j_start)
			joints.append(j_start)
		else:
			push_warning("DynamicChain: anchor_mode requires `anchor` but it is null.")

	for i in range(1, n):
		var j_inter := _create_joint(links[i - 1], links[i], false)
		links[i].add_child(j_inter)
		joints.append(j_inter)

	if anchor_mode == AnchorMode.END or anchor_mode == AnchorMode.BOTH:
		if is_instance_valid(end_anchor):
			var j_end := _create_joint(links[n - 1], end_anchor, true)
			links[n - 1].add_child(j_end)
			joints.append(j_end)
		else:
			push_warning("DynamicChain: anchor_mode requires `end_anchor` but it is null.")

func _regenerate_chain() -> void:
	if Engine.is_editor_hint() and is_inside_tree():
		_generate_chain()

func _has_path() -> bool:
	return is_instance_valid(path) and path.curve != null and path.curve.get_baked_length() > 0.0

func _compute_link_count() -> int:
	if _has_path():
		return max(2, int(floor(path.curve.get_baked_length() / link_length)))
	return link_count

func _basis_with_y(tangent: Vector3) -> Basis:
	var t := tangent.normalized()
	var up_ref := Vector3.UP if absf(t.y) < 0.95 else Vector3.FORWARD
	var x_axis := up_ref.cross(t).normalized()
	var z_axis := x_axis.cross(t).normalized()
	return Basis(x_axis, t, z_axis)

func _link_transform_at(i: int) -> Transform3D:
	if _has_path():
		var curve := path.curve
		var off_a := i * link_length
		var off_b := off_a + link_length
		var p_a := curve.sample_baked(off_a, true)
		var p_b := curve.sample_baked(off_b, true)
		var mid := (p_a + p_b) * 0.5
		var local := Transform3D(_basis_with_y(p_b - p_a), mid)
		return global_transform.affine_inverse() * (path.global_transform * local)
	return Transform3D(Basis.IDENTITY, Vector3(0, - (i + 1) * link_length, 0))

func _place_path_anchor(body: StaticBody3D, offset: float) -> void:
	if not (_has_path() and is_instance_valid(body)):
		return
	var curve := path.curve
	var baked_len := curve.get_baked_length()
	var eps: float = min(0.01, baked_len * 0.5)
	var p := curve.sample_baked(offset, true)
	var tangent: Vector3
	if offset + eps <= baked_len:
		tangent = curve.sample_baked(offset + eps, true) - p
	else:
		tangent = p - curve.sample_baked(offset - eps, true)
	body.global_transform = path.global_transform * Transform3D(_basis_with_y(tangent), p)

func _create_link(idx: int) -> RigidBody3D:
	var link := RigidBody3D.new()
	link.name = "Link_" + str(idx)
	link.mass = link_mass
	link.gravity_scale = 1.0
	link.linear_damp = damping
	link.angular_damp = damping

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = link_mesh
	link.add_child(mesh_instance)

	var collision_shape := CollisionShape3D.new()
	var capsule_shape := CapsuleShape3D.new()
	capsule_shape.radius = link_radius
	capsule_shape.height = link_length
	collision_shape.shape = capsule_shape
	link.add_child(collision_shape)

	return link

# `trailing_end` = true means the joint sits at link_b's -Y/2 end (used for the
# end-anchor joint where link_b is the last link). Otherwise the joint sits at
# +Y/2, matching the start-anchor and inter-link convention.
func _create_joint(body_a: Node3D, body_b: Node3D, trailing_end: bool) -> Generic6DOFJoint3D:
	var joint := Generic6DOFJoint3D.new()
	var y_offset := -link_length / 2.0 if trailing_end else link_length / 2.0
	joint.position = Vector3(0, y_offset, 0)

	joint.set_flag_x(Generic6DOFJoint3D.FLAG_ENABLE_LINEAR_LIMIT, true)
	joint.set_param_x(Generic6DOFJoint3D.PARAM_LINEAR_LOWER_LIMIT, 0)
	joint.set_param_x(Generic6DOFJoint3D.PARAM_LINEAR_UPPER_LIMIT, 0)

	joint.set_flag_y(Generic6DOFJoint3D.FLAG_ENABLE_LINEAR_LIMIT, true)
	joint.set_param_y(Generic6DOFJoint3D.PARAM_LINEAR_LOWER_LIMIT, 0)
	joint.set_param_y(Generic6DOFJoint3D.PARAM_LINEAR_UPPER_LIMIT, 0)

	joint.set_flag_z(Generic6DOFJoint3D.FLAG_ENABLE_LINEAR_LIMIT, true)
	joint.set_param_z(Generic6DOFJoint3D.PARAM_LINEAR_LOWER_LIMIT, 0)
	joint.set_param_z(Generic6DOFJoint3D.PARAM_LINEAR_UPPER_LIMIT, 0)

	joint.set_flag_x(Generic6DOFJoint3D.FLAG_ENABLE_ANGULAR_LIMIT, true)
	joint.set_param_x(Generic6DOFJoint3D.PARAM_ANGULAR_LOWER_LIMIT, -angular_limit_rad)
	joint.set_param_x(Generic6DOFJoint3D.PARAM_ANGULAR_UPPER_LIMIT, angular_limit_rad)

	joint.set_flag_y(Generic6DOFJoint3D.FLAG_ENABLE_ANGULAR_LIMIT, true)
	joint.set_param_y(Generic6DOFJoint3D.PARAM_ANGULAR_LOWER_LIMIT, -twist_limit_rad)
	joint.set_param_y(Generic6DOFJoint3D.PARAM_ANGULAR_UPPER_LIMIT, twist_limit_rad)

	joint.set_flag_z(Generic6DOFJoint3D.FLAG_ENABLE_ANGULAR_LIMIT, true)
	joint.set_param_z(Generic6DOFJoint3D.PARAM_ANGULAR_LOWER_LIMIT, -twist_limit_rad)
	joint.set_param_z(Generic6DOFJoint3D.PARAM_ANGULAR_UPPER_LIMIT, twist_limit_rad)

	# NodePaths must be set after the joint is in the scene tree.
	joint.ready.connect(func():
		joint.node_a = body_a.get_path()
		joint.node_b = body_b.get_path()
	)

	return joint
