extends Node3D

@export var orbit_radius: float = 1000.0
@export var camera_smoothing: float = 6.0

@onready var camera: Camera3D = %camera
@onready var player: Player = %Player

const EnemyCableScene := preload("res://enemy_cable.tscn")

var orbit_center: Vector3
var camera_height: float
var _cam_angle: float = 0.0

func _ready() -> void:
	player.died.connect(_on_player_died)
	for child in $enemies_root.get_children():
		if child is EnemyCable:
			child.player = player
	_compute_orbit()
	_init_camera_angle()
	_build_visualization()

func _compute_orbit() -> void:
	camera_height = camera.global_position.y
	var cam_flat := Vector2(camera.global_position.x, camera.global_position.z)
	var player_flat := Vector2(player.global_position.x, player.global_position.z)
	var to_player := player_flat - cam_flat
	var dir := to_player.normalized() if to_player.length_squared() > 0.0 else Vector2(0.0, -1.0)
	var oc := cam_flat + dir * orbit_radius
	orbit_center = Vector3(oc.x, 0.0, oc.y)

func _init_camera_angle() -> void:
	var flat := Vector2(
		player.global_position.x - orbit_center.x,
		player.global_position.z - orbit_center.z
	)
	_cam_angle = flat.angle()

func _process(delta: float) -> void:
	var flat := Vector2(
		player.global_position.x - orbit_center.x,
		player.global_position.z - orbit_center.z
	)
	var target_angle := flat.angle()
	_cam_angle = lerp_angle(_cam_angle, target_angle, delta * camera_smoothing)

	camera.global_position = Vector3(
		orbit_center.x + cos(_cam_angle) * orbit_radius,
		camera_height,
		orbit_center.z + sin(_cam_angle) * orbit_radius
	)
	camera.look_at(player.global_position, Vector3.UP)

	# Camera basis after look_at — flatten to horizontal plane
	var cam_right := camera.global_basis.x
	cam_right.y = 0.0
	cam_right = cam_right.normalized()
	var cam_fwd := -camera.global_basis.z
	cam_fwd.y = 0.0
	cam_fwd = cam_fwd.normalized()


func _build_visualization() -> void:
	var unshaded := StandardMaterial3D.new()
	unshaded.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	unshaded.albedo_color = Color(1.0, 0.9, 0.0, 0.8)
	unshaded.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	# Center point marker
	var center_node := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.4
	sphere.height = 0.8
	center_node.mesh = sphere
	center_node.material_override = unshaded
	center_node.global_position = orbit_center
	add_child(center_node)

	# Orbit ring at camera height
	var ring_node := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = orbit_radius - 0.15
	torus.outer_radius = orbit_radius + 0.15
	torus.rings = 4
	torus.ring_segments = 6
	ring_node.mesh = torus
	ring_node.material_override = unshaded
	ring_node.global_position = Vector3(orbit_center.x, camera_height, orbit_center.z)
	add_child(ring_node)

func _on_player_died() -> void:
	get_tree().reload_current_scene()
