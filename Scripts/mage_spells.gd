extends Node

class_name MageSpells

# --- SPELL DATA STRUCTURE ---
var mage_spells: Array[Dictionary] = [
	{
		"name": "Spark",
		"desc": "Fast spell. Chains with detonating spells for 1.75x damage.",
		"type": "instant_attack",
		"power": 1.0,
		"cost": 15,
		"delay": 0
	},
	{
		"name": "Delayed Ruin",
		"desc": "Brewing spell. Detonates in 2 turns for heavy damage.",
		"type": "delayed_attack",
		"power": 3.0,
		"cost": 30,
		"delay": 2
	},
	{
		"name": "Frost Doom",
		"desc": "High-risk chant. Detonates in 3 turns for massive damage.",
		"type": "delayed_attack",
		"power": 5.0,
		"cost": 50,
		"delay": 3
	},
	{
		"name": "Heal Bloom",
		"desc": "Restores HP based on Magic Power.",
		"type": "heal",
		"power": 1.0,
		"cost": 25,
		"delay": 0
	},
	{
		"name": "Arcane Barrier",
		"desc": "Fortifies defenses, mitigating 60% of incoming damage.",
		"type": "barrier",
		"power": 0.0,
		"cost": 20,
		"delay": 0
	},
	{
		"name": "Overcharge",
		"desc": "Empowers the next delayed spell cast by damage multiplier.",
		"type": "buff",
		"power": 0.0,
		"cost": 15,
		"delay": 0
	}
]

# --- STATE TRACKING ---
var is_overcharged: bool = false
var active_delayed_spells: Array[Dictionary] = []


func _ready() -> void:
	# Update spell descriptions for Overcharge based on active difficulty
	if Global.is_hard_mode:
		mage_spells[5]["desc"] = "Empowers the next delayed spell cast by +75% damage (Hard Mode Boost)."


# --- CORE METHODS ---

func get_spell_count() -> int:
	return mage_spells.size()


func get_spell(index: int) -> Dictionary:
	return mage_spells[index]


## Helper to calculate the HP drain cost of a spell in Hard Mode
func get_spell_hp_cost(player_max_hp: int) -> int:
	var active_diff = Global.get_active_difficulty()
	if active_diff.has("hero_tweaks"):
		var hp_percent = active_diff["hero_tweaks"].get("mage_hp_cost_percent", 0.0)
		return int(player_max_hp * hp_percent)
	return 0


func queue_delayed_spell(spell: Dictionary, base_magic_power: int) -> int:
	var total_damage = int(base_magic_power * spell["power"])
	
	if is_overcharged:
		# Multiplier scales higher in Hard Mode (+75% vs +50%)
		var boost_mult = 1.75 if Global.is_hard_mode else 1.5
		total_damage = int(total_damage * boost_mult)
		is_overcharged = false

	active_delayed_spells.append({
		"name": spell["name"],
		"turns_left": spell["delay"],
		"damage": total_damage
	})
	return spell["delay"]


func process_turn_tick() -> Array[Dictionary]:
	var detonated_spells: Array[Dictionary] = []
	var remaining_spells: Array[Dictionary] = []

	for spell in active_delayed_spells:
		spell["turns_left"] -= 1
		if spell["turns_left"] <= 0:
			detonated_spells.append(spell)
		else:
			remaining_spells.append(spell)

	active_delayed_spells = remaining_spells
	return detonated_spells
