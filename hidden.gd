extends Sprite3D

# Visible in editor only

func _ready() -> void:
    visible = Engine.is_editor_hint()