class_name RadioTower extends Node3D

const CONNECT_RADIUS: float = 3.0

var _connected: bool = false
var _prompt: Label3D
var _player: Player

func _ready() -> void:
	RenderingServer.global_shader_parameter_set("tower_world_pos", global_position)
	add_to_group("towers")
	_player = %Player

	_prompt = Label3D.new()
	_prompt.text = "Press E to connect"
	_prompt.position = Vector3(0, 5.5, 0)
	_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt.modulate = Color(1.0, 0.9, 0.0)
	_prompt.pixel_size = 0.008
	_prompt.no_depth_test = true
	_prompt.visible = false
	add_child(_prompt)

func _process(_delta: float) -> void:
	if _connected or not is_instance_valid(_player):
		return
	_prompt.visible = _player.holding_cable and \
		_player.global_position.distance_to(global_position) < CONNECT_RADIUS

func _unhandled_input(event: InputEvent) -> void:
	if _connected or not event.is_action_pressed("grab"):
		return
	if not is_instance_valid(_player) or not _player.holding_cable:
		return
	if _player.global_position.distance_to(global_position) >= CONNECT_RADIUS:
		return
	_do_connect()

func _do_connect() -> void:
	_connected = true
	_prompt.visible = false
	# Find the cables node and anchor the cable end here
	var cables := get_tree().get_first_node_in_group("cables_root")
	if cables:
		cables.attach_to(global_position + Vector3(0, 0.2, 0))
	# Yellow, no waves
	for child in get_children():
		if child is MeshInstance3D:
			var mat := child.material_override as ShaderMaterial
			if mat:
				mat.set_shader_parameter("albedo", Color(1.0, 0.85, 0.0, 1.0))
				mat.set_shader_parameter("ring_speed", 0.0)
				mat.set_shader_parameter("ring_color", Color(1.0, 0.85, 0.0, 1.0))
	get_viewport().set_input_as_handled()
