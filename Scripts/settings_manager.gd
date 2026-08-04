extends Node

const SAVE_PATH = "user://settings.cfg"

# Guard flag to prevent saving during initial file load
var _is_loading: bool = false

# --- SETTINGS VARIABLES ---
var particle_density: float = 1.0 : set = set_particle_density  # 0.0 to 1.0 (0% to 100%)
var window_mode: int = 0 : set = set_window_mode                 # 0 = Windowed, 1 = Borderless Fullscreen
var music_enabled: bool = true : set = set_music_enabled
var sfx_enabled: bool = true : set = set_sfx_enabled

# Audio Bus Indices (Assuming default Godot setup)
@onready var music_bus_idx: int = AudioServer.get_bus_index("Music") if AudioServer.get_bus_index("Music") != -1 else 0
@onready var sfx_bus_idx: int = AudioServer.get_bus_index("SFX") if AudioServer.get_bus_index("SFX") != -1 else 0


func _ready() -> void:
	load_settings()


# --- PERSISTENCE (SAVE & LOAD) ---

func save_settings() -> void:
	# Don't write to disk if we are currently loading values
	if _is_loading:
		return

	var config = ConfigFile.new()

	config.set_value("Graphics", "particle_density", particle_density)
	config.set_value("Graphics", "window_mode", window_mode)
	config.set_value("Audio", "music_enabled", music_enabled)
	config.set_value("Audio", "sfx_enabled", sfx_enabled)

	var err = config.save(SAVE_PATH)
	if err != OK:
		print("Failed to save settings to disk. Error code: ", err)


func load_settings() -> void:
	var config = ConfigFile.new()
	var err = config.load(SAVE_PATH)

	# If the file doesn't exist yet, create default settings on disk
	if err != OK:
		print("No settings file found at ", SAVE_PATH, ". Writing defaults...")
		save_settings()
		return

	# Block disk writes while assigning loaded values to triggers
	_is_loading = true

	# Setting properties directly invokes setters to apply audio/graphics
	particle_density = config.get_value("Graphics", "particle_density", 1.0)
	window_mode = config.get_value("Graphics", "window_mode", 0)
	music_enabled = config.get_value("Audio", "music_enabled", true)
	sfx_enabled = config.get_value("Audio", "sfx_enabled", true)

	_is_loading = false


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

	save_settings()


func set_window_mode(mode: int) -> void:
	window_mode = mode
	match window_mode:
		0: # Windowed
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
		1: # Borderless Fullscreen
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)

	save_settings()


func set_music_enabled(enabled: bool) -> void:
	music_enabled = enabled
	AudioServer.set_bus_mute(music_bus_idx, not music_enabled)

	save_settings()


func set_sfx_enabled(enabled: bool) -> void:
	sfx_enabled = enabled
	AudioServer.set_bus_mute(sfx_bus_idx, not sfx_enabled)

	save_settings()
