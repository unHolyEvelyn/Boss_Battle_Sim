extends CanvasGroup

func _ready() -> void:
	var tween = create_tween().set_parallel(true)
	
	# 1. Fade transparency out over 0.4 seconds
	tween.tween_property(self, "modulate:a", 0.0, 0.4)
	
	# 2. Transition color to crimson red
	tween.tween_property(self, "modulate:r", 0.9, 0.4)
	tween.tween_property(self, "modulate:g", 0.05, 0.4)
	tween.tween_property(self, "modulate:b", 0.15, 0.4)
	
	# 3. Drift strictly 40 pixels RIGHT on the X axis, maintaining Y height
	var drift_target = global_position + Vector2(70.0, 0.0)
	tween.tween_property(self, "global_position", drift_target, 0.4)
	
	# 4. Slight scale expansion
	tween.tween_property(self, "scale", scale * 1.05, 0.4)
	
	await tween.finished
	queue_free()
