extends Node

# --- SETTINGS VARIABLES ---
var particle_density: float = 1.0 : set = set_particle_density  # 0.0 to 1.0 (0% to 100%)
var window_mode: int = 0 : set = set_window_mode                 # 0 = Windowed, 1 = Borderless Fullscreen
var music_enabled: bool = true : set = set_music_enabled
var sfx_enabled: bool = true : set = set_sfx_enabled

# Audio Bus Indices (Assuming default Godot setup)
@onready var music_bus_idx: int = AudioServer.get_bus_index("Music") if AudioServer.get_bus_index("Music") != -1 else 0
@onready var sfx_bus_idx: int = AudioServer.get_bus_index("SFX") if AudioServer.get_bus_index("SFX") != -1 else 0


# --- SETTERS ---

func set_particle_density(value: float) -> void:
	particle_density = clamp(value, 0.0, 1.0)
	
	for particle_node in get_tree().get_nodes_in_group("particles"):
		if particle_node is CPUParticles2D:
			# Cache original particle amount if not already saved
			if not particle_node.has_meta("base_amount"):
				particle_node.set_meta("base_amount", particle_node.amount)
			
			var base_amount: int = particle_node.get_meta("base_amount")
			particle_node.amount = max(1, int(base_amount * particle_density))
			particle_node.emitting = (particle_density > 0.0)

func set_window_mode(mode: int) -> void:
	window_mode = mode
	match window_mode:
		0: # Windowed
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
		1: # Borderless Fullscreen
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)


func set_music_enabled(enabled: bool) -> void:
	music_enabled = enabled
	AudioServer.set_bus_mute(music_bus_idx, not music_enabled)


func set_sfx_enabled(enabled: bool) -> void:
	sfx_enabled = enabled
	AudioServer.set_bus_mute(sfx_bus_idx, not sfx_enabled)
