@tool

class_name DynamicChain extends Node3D

@export_range(2, 50) var link_count: int = 10:
    set(value):
        link_count = value
        _regenerate_chain()

@export var link_length: float = 1.0
@export var link_radius: float = 0.1
@export var stiffness: float = 10.0
@export var damping: float = 0.5

@export var anchor: StaticBody3D
@export var link_container: Node3D

# Angular limits (swing range)
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
    for child in link_container.get_children():
        if is_instance_valid(child):
            child.queue_free()

func _generate_chain() -> void:
    # Create cylinder mesh which will be instanced
    cylinder_mesh = CylinderMesh.new()
    cylinder_mesh.top_radius = link_radius
    cylinder_mesh.bottom_radius = link_radius
    cylinder_mesh.height = link_length
    
    # Clear existing links and joints
    _clear_chain()

    for i in range(link_count):
        var link = _create_link(i)
        link_container.add_child(link)
        links.append(link)
        link.position = Vector3(0, - (i + 1) * link_length, 0)
    
    # Wait for links to be added to scene tree before creating joints
    await get_tree().process_frame

    for i in range(link_count):
        var body_a: Node3D = (anchor as Node3D) if (i == 0) else (links[i - 1])
        var body_b: RigidBody3D = links[i]
        var joint = _create_joint(body_a, body_b)
        body_b.add_child(joint)
        joints.append(joint)

func _regenerate_chain() -> void:
    if Engine.is_editor_hint():
        _generate_chain()

func _create_link(idx: int) -> RigidBody3D:
    var link = RigidBody3D.new()
    link.name = "Link_" + str(idx)
    link.position = Vector3.ZERO
    link.mass = 0.5
    link.gravity_scale = 1.0
    link.linear_damp = damping
    link.angular_damp = damping

    var mesh_instance = MeshInstance3D.new()
    mesh_instance.mesh = cylinder_mesh
    mesh_instance.rotation_degrees = Vector3(0, 0, 0)
    link.add_child(mesh_instance)

    var collision_shape = CollisionShape3D.new()
    var capsule_shape = CapsuleShape3D.new()
    capsule_shape.radius = link_radius
    capsule_shape.height = link_length
    collision_shape.shape = capsule_shape
    link.add_child(collision_shape)

    return link

func _create_joint(link_a: Node3D, link_b: RigidBody3D) -> Generic6DOFJoint3D:
    var joint := Generic6DOFJoint3D.new()
    joint.node_a = link_a.get_path()
    joint.node_b = link_b.get_path()
    joint.position = Vector3(0, link_length / 2.0, 0)

    # Lock X axis (no left/right stretch)
    joint.set_flag_x(Generic6DOFJoint3D.FLAG_ENABLE_LINEAR_LIMIT, true)
    joint.set_param_x(Generic6DOFJoint3D.PARAM_LINEAR_LOWER_LIMIT, 0)
    joint.set_param_x(Generic6DOFJoint3D.PARAM_LINEAR_UPPER_LIMIT, 0)

    # Lock Y axis (no up/down stretch)
    joint.set_flag_y(Generic6DOFJoint3D.FLAG_ENABLE_LINEAR_LIMIT, true)
    joint.set_param_y(Generic6DOFJoint3D.PARAM_LINEAR_LOWER_LIMIT, 0)
    joint.set_param_y(Generic6DOFJoint3D.PARAM_LINEAR_UPPER_LIMIT, 0)

    # Lock Z axis (no forward/backward stretch)
    joint.set_flag_z(Generic6DOFJoint3D.FLAG_ENABLE_LINEAR_LIMIT, true)
    joint.set_param_z(Generic6DOFJoint3D.PARAM_LINEAR_LOWER_LIMIT, 0)
    joint.set_param_z(Generic6DOFJoint3D.PARAM_LINEAR_UPPER_LIMIT, 0)

    # X axis swing (pitch)
    joint.set_flag_x(Generic6DOFJoint3D.FLAG_ENABLE_ANGULAR_LIMIT, true)
    joint.set_param_x(Generic6DOFJoint3D.PARAM_ANGULAR_LOWER_LIMIT, -angular_limit_rad)
    joint.set_param_x(Generic6DOFJoint3D.PARAM_ANGULAR_UPPER_LIMIT, angular_limit_rad)

    # Y axis twist
    joint.set_flag_y(Generic6DOFJoint3D.FLAG_ENABLE_ANGULAR_LIMIT, true)
    joint.set_param_y(Generic6DOFJoint3D.PARAM_ANGULAR_LOWER_LIMIT, -twist_limit_rad)
    joint.set_param_y(Generic6DOFJoint3D.PARAM_ANGULAR_UPPER_LIMIT, twist_limit_rad)

    # Z axis swing (roll)
    joint.set_flag_z(Generic6DOFJoint3D.FLAG_ENABLE_ANGULAR_LIMIT, true)
    joint.set_param_z(Generic6DOFJoint3D.PARAM_ANGULAR_LOWER_LIMIT, -twist_limit_rad)
    joint.set_param_z(Generic6DOFJoint3D.PARAM_ANGULAR_UPPER_LIMIT, twist_limit_rad)

    # Set node paths after joint is added to scene tree
    joint.ready.connect(func():
        joint.node_a = link_a.get_path()
        joint.node_b = link_b.get_path()
    )

    return joint