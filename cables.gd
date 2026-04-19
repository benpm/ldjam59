extends Node3D

@onready var player_cable: DynamicChain = $player_cable
@onready var player := %Player

func _ready() -> void:
	pass

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("grab"):
		player.holding_cable = not player.holding_cable

func _process(_delta: float) -> void:
	if player.holding_cable:
		player_cable.end_anchor.global_position = player.global_position
