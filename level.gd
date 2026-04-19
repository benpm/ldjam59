extends Node3D

@onready var camera: Camera3D = %camera
@onready var player: Player = %Player

const EnemyCableScene := preload("res://enemy_cable.tscn")

func _ready() -> void:
	player.died.connect(_on_player_died)

	# Compute radius just outside the frustum corners at ground level (y=0)
	var vp := get_viewport().get_visible_rect().size
	var aspect := vp.x / vp.y
	var cam_height := camera.global_position.y
	var half_v := tan(deg_to_rad(camera.fov / 2.0)) * cam_height
	var half_h := half_v * aspect
	var frustum_radius := sqrt(half_h * half_h + half_v * half_v) + 1.5

	var cam_ground := Vector3(camera.global_position.x, 0.0, camera.global_position.z)

func _on_player_died() -> void:
	get_tree().reload_current_scene()
