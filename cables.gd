extends Node3D

@onready var player_cable: DynamicChain = $player_cable

const RAY_LENGTH: float = 100.0

func _ready() -> void:
	pass

func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	var mousepos := get_viewport().get_mouse_position()
	var origin := cam.project_ray_origin(mousepos)
	var query := PhysicsRayQueryParameters3D.create(
		origin,
		origin + cam.project_ray_normal(mousepos) * RAY_LENGTH
	)
	query.collide_with_areas = true
	query.collision_mask = 1 << 0

	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return

	var p: Vector3 = result.position
	var anchor := player_cable.anchor
	anchor.global_position = Vector3(p.x, anchor.global_position.y, p.z)
