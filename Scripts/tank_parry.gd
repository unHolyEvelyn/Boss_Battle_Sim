extends Node

class_name TankParry

# --- PARRY STATE ---
var is_parry_active: bool = false       # Player chose Parry for this turn
var is_counter_primed: bool = false     # Successfully achieved a Perfect Parry
var counter_multiplier: float = 7.5     # Damage multiplier for next Attack

# --- PARRY RESULT ENUM ---
enum ParryResult {
	PERFECT,
	PARTIAL,
	MISS
}

# --- CORE METHODS ---

func prime_parry_stance() -> void:
	is_parry_active = true

func reset_parry_stance() -> void:
	is_parry_active = false

## Evaluates accuracy based on value percentage (0.0 to 100.0)
## Assuming sweet spot/center is at 50%
func evaluate_timing(current_val: float, target_val: float = 50.0, perfect_range: float = 10.0, partial_range: float = 25.0) -> ParryResult:
	var diff = abs(current_val - target_val)
	
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
