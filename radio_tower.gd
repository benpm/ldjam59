class_name RadioTower extends Node3D

func _ready() -> void:
	RenderingServer.global_shader_parameter_set("tower_world_pos", global_position)
