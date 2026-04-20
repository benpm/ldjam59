extends Control


@onready var _play_button: Button = %PlayButton
@onready var _volume_slider: HSlider = %VolumeSlider


func _ready() -> void:
	_play_button.pressed.connect(_on_play_pressed)
	_volume_slider.value_changed.connect(_on_volume_changed)
	# Initialize slider to current master bus volume
	var master_idx: int = AudioServer.get_bus_index("Master")
	_volume_slider.value = db_to_linear(AudioServer.get_bus_volume_db(master_idx))


func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://level.tscn")


func _on_volume_changed(value: float) -> void:
	var master_idx: int = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(master_idx, linear_to_db(value))
