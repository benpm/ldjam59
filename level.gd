extends Node3D

@onready var camera: Camera3D = %camera
@onready var player := %Player

func _process(_delta: float) -> void:
	camera.global_position = Vector3(player.global_position.x, 50.0, player.global_position.z)
