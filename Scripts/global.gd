extends Node

var selected_character: String = "fighter" # Default fallback
var is_hard_mode: bool = false # Default to false so normal mode is initial default

const HARD_MODE_WIN_REQUIREMENT: int = 5

# --- DIFFICULTY CONFIGURATION ---
# Centralizing parameters to make balance tweaks easier in the future.
var difficulty_settings: Dictionary = {
	"normal": {
		"boss_hp": 300,
		"boss_damage_mult": 1.0,
		"parry_speed_mult": 1.0,
		"hero_hp_mult": 1.0,
		"hero_tweaks":{
			"fighter_max_stacks": 3,
			"fighter_stack_damage_mult": 1.25,
			"mage_hp_cost_percent": 0.0,
			"tank_parry_reflect_percent": 0.0
		}
	},
	"hard": {
		"boss_hp": 500,								# Higher HP pool
		"boss_damage_mult": 1.25,					# +25% Damage
		"parry_speed_mult": 1.25,					# +25% Parry Speed
		"hero_hp_mult": 1.6,
		"hero_tweaks": {
			"fighter_max_stacks": 5,				# Over-cap allows 5 stacks of Default
			"fighter_stack_damage_mult": 1.35,		# Stacking hits harder
			"mage_hp_cost_percent": 0.05,			# Spells drain 5% of health
			"tank_parry_reflect_percent": 0.25		# Parrying now reflects 25% of damage to The Boss.
		}
	}
}

# --- HELPER FUNCTIONS ---

func set_hard_mode(enabled: bool) -> void:
	is_hard_mode = enabled
	print("Difficulty set to: ", "HARD" if is_hard_mode else "NORMAL")


## Fetch active difficulty dictionary
func get_active_difficulty() -> Dictionary:
	return difficulty_settings["hard"] if is_hard_mode else difficulty_settings["normal"]


## Checks if the specified character has met the win requirement for Hard Mode
func is_hard_mode_unlocked(character_name: String) -> bool:
	var wins = SaveManager.get_hero_wins(character_name)
	return wins >= HARD_MODE_WIN_REQUIREMENT


## Optional helper to format progress strings (e.g. "2/5")
func get_unlock_progress(character_name: String) -> String:
	var wins = SaveManager.get_victories(character_name)
	return str(min(wins, HARD_MODE_WIN_REQUIREMENT)) + "/" + str(HARD_MODE_WIN_REQUIREMENT)
