extends CPUParticles2D

@export var cycle_speed: float = 0.5  # Speed of rainbow rotation
var hue: float = 0.0

func _process(delta: float) -> void:
	# Increment hue from 0.0 to 1.0 continuously
	hue = fmod(hue + delta * cycle_speed, 1.0)
	
	# Set particle tint using HSV (Hue, Saturation 1.0, Value 1.0)
	color = Color.from_hsv(hue, 1.0, 1.0)
