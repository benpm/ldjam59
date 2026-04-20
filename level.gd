extends Node3D

@export var transition_time: float = 0.45
@export var edge_threshold: float = 0.38
@export var arm_threshold: float = 0.25

@onready var camera: Camera3D = %camera
@onready var player: Player = %Player

const EnemyCableScene := preload("res://enemy_cable.tscn")

var _cam_focus: Vector3 = Vector3.ZERO
var _cam_offset: Vector3
var _page_size: Vector2
var _look_target: Vector3
var _tween: Tween
var _focus_marker: MeshInstance3D
var _page_armed_x: bool = true
var _page_armed_z: bool = true

func _ready() -> void:
	player.died.connect(_on_player_died)
	for child in $enemies_root.get_children():
		if child is EnemyCable:
			child.player = player
	_init_camera()
	_build_visualization()

func _init_camera() -> void:
	_cam_focus = Vector3(player.global_position.x, 0.0, player.global_position.z)
	_cam_offset = camera.global_position - _cam_focus
	_look_target = _cam_focus

	var dist := _cam_offset.length()
	var half_fov := deg_to_rad(camera.fov * 0.5)
	var half_extent := dist * tan(half_fov)
	var vp := get_viewport().get_visible_rect().size
	var aspect := vp.x / vp.y if vp.y > 0.0 else 1.778
	_page_size = Vector2(half_extent * aspect * 2.0, half_extent * 2.0)

func _process(_delta: float) -> void:
	camera.look_at(_look_target, Vector3.UP)
	_update_player_dirs()
	if is_instance_valid(_focus_marker):
		_focus_marker.global_position = _cam_focus

	if _tween and _tween.is_running():
		return

	var dx := player.global_position.x - _cam_focus.x
	var dz := player.global_position.z - _cam_focus.z
	var half_x := _page_size.x * 0.5
	var half_z := _page_size.y * 0.5

	# Re-arm when player returns inside the safe zone
	if abs(dx) < half_x * (1.0 - arm_threshold):
		_page_armed_x = true
	if abs(dz) < half_z * (1.0 - arm_threshold):
		_page_armed_z = true

	var page_dx := 0.0
	var page_dz := 0.0
	if _page_armed_x and abs(dx) > half_x * (1.0 - edge_threshold):
		page_dx = sign(dx) * _page_size.x
		_page_armed_x = false
	if _page_armed_z and abs(dz) > half_z * (1.0 - edge_threshold):
		page_dz = sign(dz) * _page_size.y
		_page_armed_z = false

	if page_dx != 0.0 or page_dz != 0.0:
		_page(Vector3(page_dx, 0.0, page_dz))

func _page(offset: Vector3) -> void:
	var new_focus := _cam_focus + offset
	_cam_focus = new_focus

	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.set_ease(Tween.EASE_IN_OUT)
	_tween.set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(camera, "global_position", new_focus + _cam_offset, transition_time)
	_tween.parallel().tween_property(self, "_look_target", new_focus, transition_time)

func _update_player_dirs() -> void:
	var cam_right := camera.global_basis.x
	cam_right.y = 0.0
	cam_right = cam_right.normalized()
	var cam_fwd := -camera.global_basis.z
	cam_fwd.y = 0.0
	cam_fwd = cam_fwd.normalized()
	player.camera_right = cam_right
	player.camera_forward = cam_fwd

func _build_visualization() -> void:
	var unshaded := StandardMaterial3D.new()
	unshaded.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	unshaded.albedo_color = Color(1.0, 0.9, 0.0, 0.8)
	unshaded.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	_focus_marker = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.4
	sphere.height = 0.8
	_focus_marker.mesh = sphere
	_focus_marker.material_override = unshaded
	_focus_marker.global_position = _cam_focus
	add_child(_focus_marker)

func _on_player_died() -> void:
	get_tree().reload_current_scene()
