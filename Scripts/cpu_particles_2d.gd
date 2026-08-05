extends CPUParticles2D

@export var cycle_speed: float = 0.2  # Speed of rainbow rotation
var hue: float = 0.0


func _ready() -> void:
	# Register with group so SettingsManager can update it dynamically when slider moves
	add_to_group("particle_emitters")
	
	# Apply current global setting from SettingsManager immediately on spawn
	if SettingsManager:
		SettingsManager.apply_density_to_node(self)


func _process(delta: float) -> void:
	# Increment hue from 0.0 to 1.0 continuously
	hue = fmod(hue + delta * cycle_speed, 1.0)
	
	# Set particle tint using HSV (Hue, Saturation 1.0, Value 1.0)
	color = Color.from_hsv(hue, .50, .50)
