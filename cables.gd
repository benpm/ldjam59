extends Node3D

@onready var player_cable: DynamicChain = $player_cable

const RAY_LENGTH: float = 100.0

func _ready() -> void:
	pass

func _process(_delta: float) -> void:
	var mousepos = get_viewport().get_mouse_position()
	var space_state = get_world_3d().direct_space_state
	var cam := get_viewport().get_camera_3d()
	var origin = cam.project_ray_origin(mousepos)
	var end = origin + cam.project_ray_normal(mousepos) * RAY_LENGTH
	var query = PhysicsRayQueryParameters3D.create(origin, end)
	query.collide_with_areas = true
	query.collision_mask = 1 << 0 # Assuming the cable anchor is on layer 0
	
	var result = space_state.intersect_ray(query) # raycast result

	player_cable.anchor.move_and_collide((result.position - player_cable.position).normalized() * 0.1 * get_process_delta_time())
