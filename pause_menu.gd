extends Control


@onready var _resume_button: Button = %ResumeButton
@onready var _quit_button: Button = %QuitButton
@onready var _volume_slider: HSlider = %PauseVolumeSlider


func _ready() -> void:
	_resume_button.pressed.connect(_on_resume)
	_quit_button.pressed.connect(_on_quit)
	_volume_slider.value_changed.connect(_on_volume_changed)
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_toggle_pause()
		get_viewport().set_input_as_handled()


func _toggle_pause() -> void:
	var paused := not get_tree().paused
	get_tree().paused = paused
	visible = paused
	if paused:
		var master_idx: int = AudioServer.get_bus_index("Master")
		_volume_slider.value = db_to_linear(AudioServer.get_bus_volume_db(master_idx))


func _on_resume() -> void:
	_toggle_pause()


func _on_quit() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://main_menu.tscn")


func _on_volume_changed(value: float) -> void:
	var master_idx: int = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(master_idx, linear_to_db(value))
