extends Node3D

const INTERACT_RADIUS: float = 2.0

@onready var player_cable: DynamicChain = $player_cable
@onready var player: Player = %Player

var _indicator: MeshInstance3D
var _indicator_mat: StandardMaterial3D
var _prompt: Label3D
var _attached: bool = false

func _ready() -> void:
	add_to_group("cables_root")
	var sph := SphereMesh.new()
	sph.radius = 0.25
	sph.height = 0.5
	_indicator_mat = StandardMaterial3D.new()
	_indicator_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_indicator_mat.albedo_color = Color(0.3, 0.8, 1.0)
	_indicator_mat.emission_enabled = true
	_indicator_mat.emission = Color(0.3, 0.8, 1.0)
	_indicator = MeshInstance3D.new()
	_indicator.mesh = sph
	_indicator.material_override = _indicator_mat
	player_cable.end_anchor.add_child(_indicator)

	_prompt = Label3D.new()
	_prompt.text = "Press E"
	_prompt.position = Vector3(0, 0.7, 0)
	_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt.modulate = Color(0.3, 0.8, 1.0)
	_prompt.pixel_size = 0.008
	_prompt.no_depth_test = true
	_prompt.visible = false
	player_cable.end_anchor.add_child(_prompt)

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("grab"):
		return
	if player.holding_cable:
		# Yield to tower if player is in tower connect range
		for tower: RadioTower in get_tree().get_nodes_in_group("towers"):
			if player.global_position.distance_to(tower.global_position) < RadioTower.CONNECT_RADIUS:
				return
		player.holding_cable = false
	elif not _attached:
		var dist: float = player.global_position.distance_to(player_cable.end_anchor.global_position)
		if dist <= INTERACT_RADIUS:
			player.holding_cable = true
			get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if player.holding_cable:
		player_cable.end_anchor.global_position = player.global_position
		_indicator.visible = false
		_prompt.visible = false
		return

	if _attached:
		_indicator.visible = false
		_prompt.visible = false
		return

	var dist: float = player.global_position.distance_to(player_cable.end_anchor.global_position)
	var in_range: bool = dist < INTERACT_RADIUS * 3.0
	_indicator.visible = in_range
	_prompt.visible = dist <= INTERACT_RADIUS
	if in_range:
		var t: float = Time.get_ticks_msec() / 1000.0
		var close: bool = dist <= INTERACT_RADIUS
		var pulse: float = sin(t * (12.0 if close else 5.0)) * 0.5 + 0.5
		_indicator_mat.emission_energy_multiplier = pulse * (3.0 if close else 1.0)

func attach_to(pos: Vector3) -> void:
	_attached = true
	player.holding_cable = false
	player_cable.end_anchor.global_position = pos
