extends Node

class_name TankParry

# --- PARRY STATE ---
var is_parry_active: bool = false       # Player chose Parry for this turn
var is_counter_primed: bool = false     # Successfully achieved a Perfect Parry
var counter_multiplier: float = 7.5     # Base damage multiplier for next Attack

# --- PARRY RESULT ENUM ---
enum ParryResult {
	PERFECT,
	PARTIAL,
	MISS
}


func _ready() -> void:
	# Adjust counter payoff for Hard Mode
	if Global.is_hard_mode:
		counter_multiplier = 9.0  # High risk = higher reward (+9.0x Counter Strike)
		print("TankParry Initialized | Hard Mode Counter Multiplier: ", counter_multiplier)


# --- CORE METHODS ---

func prime_parry_stance() -> void:
	is_parry_active = true


func reset_parry_stance() -> void:
	is_parry_active = false


## Evaluates accuracy based on value percentage (0.0 to 100.0)
## Dynamically shrinks timing windows based on difficulty settings
func evaluate_timing(current_val: float, target_val: float = 50.0, base_perfect_range: float = 10.0, base_partial_range: float = 25.0) -> ParryResult:
	var diff = abs(current_val - target_val)
	
	# Fetch speed/timing multiplier (defaults to 1.0 in Normal Mode, ~1.35 in Hard Mode)
	var speed_mult = Global.get_active_difficulty().get("parry_speed_mult", 1.0)
	
	# Shrink tolerance windows in Hard Mode
	var perfect_range = base_perfect_range / speed_mult
	var partial_range = base_partial_range / speed_mult
	
	if diff <= perfect_range:
		is_counter_primed = true
		return ParryResult.PERFECT
	elif diff <= partial_range:
		return ParryResult.PARTIAL
	else:
		return ParryResult.MISS


func consume_counter_bonus() -> float:
	if is_counter_primed:
		is_counter_primed = false
		return counter_multiplier
	return 1.0
