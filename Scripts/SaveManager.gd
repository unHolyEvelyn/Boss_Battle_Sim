extends Node

const SAVE_PATH: String = "user://save_data.cfg"
const SECTION_NAME: String = "victories" # Standardized lowercase header name


## Record a win for the specified character
func record_victory(character_name: String) -> void:
	var config = ConfigFile.new()
	
	# Load existing file if it exists, otherwise creates a fresh one
	config.load(SAVE_PATH)
	
	var key = character_name.to_lower()
	var current_wins = config.get_value(SECTION_NAME, key, 0)
	
	config.set_value(SECTION_NAME, key, current_wins + 1)
	var err = config.save(SAVE_PATH)
	
	if err == OK:
		print("Victory saved for ", key, "! Total wins: ", current_wins + 1)
	else:
		print("Failed to save config! Error code: ", err)


## Fetch total victories for a specific character
func get_hero_wins(character_name: String) -> int:
	var config = ConfigFile.new()
	var err = config.load(SAVE_PATH)
	
	if err == OK:
		var key = character_name.to_lower()
		return config.get_value(SECTION_NAME, key, 0)
		
	return 0
