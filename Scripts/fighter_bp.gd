class_name FighterBP
extends Node2D

signal bp_changed(new_bp: int)
signal actions_updated(total_actions: int)
signal stance_changed(new_stance: Stance)

enum Stance { BERSERK, BALANCED, GUARD }

var current_stance: Stance = Stance.BALANCED

@export var max_bp: int = 3
@export var min_bp: int = -4
@export var max_actions_per_turn: int = 4

var current_bp: int = 0
var queued_actions: int = 1  # Standard 1 action per turn baseline


func _ready() -> void:
	# --- HARD MODE / DIFFICULTY STAT INTEGRATION ---
	var active_diff = Global.get_active_difficulty()
	if active_diff.has("hero_tweaks"):
		var tweaks = active_diff["hero_tweaks"]
		
		# Pull max BP from Global settings (3 in Normal, 5 in Hard Mode)
		if tweaks.has("fighter_max_stacks"):
			max_bp = tweaks["fighter_max_stacks"]
			
			# If max BP increased (like 5 in Hard Mode), allow max queued actions to match it
			if max_bp > max_actions_per_turn:
				max_actions_per_turn = max_bp + 1
				
	print("FighterBP Initialized | Max BP Limit: ", max_bp)


# --- STANCE EVALUATOR ---
func _update_stance() -> void:
	var old_stance = current_stance
	
	if current_bp > 0:
		current_stance = Stance.BERSERK
	elif current_bp < 0:
		current_stance = Stance.GUARD
	else:
		current_stance = Stance.BALANCED

	if old_stance != current_stance:
		stance_changed.emit(current_stance)
		_apply_stance_modifiers()


func _apply_stance_modifiers() -> void:
	match current_stance:
		Stance.BERSERK:
			print("Fighter Stance: BERSERK (+50% ATK, +25% DMG Taken)")
		Stance.BALANCED:
			print("Fighter Stance: BALANCED (Standard Stats)")
		Stance.GUARD:
			print("Fighter Stance: GUARD (Defensive Armor Active in Debt)")


# Call this when player hits the 'Default' button
func perform_default() -> bool:
	if current_bp < max_bp:
		current_bp += 1
		bp_changed.emit(current_bp)
		_update_stance()
	
	# Defaulting immediately ends turn planning with 1 defensive turn
	return true 


# Call this when player hits the 'Brave' button
func try_brave() -> bool:
	# Can't spend if we hit the negative limit OR reached max allowed actions
	if (current_bp - 1) < min_bp or queued_actions >= max_actions_per_turn:
		return false
		
	current_bp -= 1
	queued_actions += 1
	
	bp_changed.emit(current_bp)
	actions_updated.emit(queued_actions)
	_update_stance()
	return true


# Resets queued hits back to 1 for the next turn
func reset_turn_actions() -> void:
	queued_actions = 1
	actions_updated.emit(queued_actions)


# Helper to check if player is currently in BP debt
func is_in_debt() -> bool:
	return current_bp < 0
