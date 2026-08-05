extends CanvasLayer

@onready var color_rect: ColorRect = $ColorRect


func _ready() -> void:
	# Ensure the screen starts completely transparent
	color_rect.modulate.a = 0.0


func transition_to_scene(target_scene_path: String, duration: float = 0.4) -> void:
	# 1. Fade OUT to Black
	var tween = create_tween()
	tween.tween_property(color_rect, "modulate:a", 1.0, duration)
	await tween.finished

	# 2. Change Scene while screen is completely black
	get_tree().change_scene_to_file(target_scene_path)

	# 3. Fade IN from Black
	var tween_in = create_tween()
	tween_in.tween_property(color_rect, "modulate:a", 0.0, duration)
