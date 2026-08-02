class_name FighterBP
extends Node2D

signal bp_changed(new_bp: int)
signal actions_updated(total_actions: int)

@export var max_bp: int = 3
@export var min_bp: int = -4
@export var max_actions_per_turn: int = 4

var current_bp: int = 0
var queued_actions: int = 1  # Standard 1 action per turn baseline

# Call this when player hits the 'Default' button
func perform_default() -> bool:
	if current_bp < max_bp:
		current_bp += 1
		bp_changed.emit(current_bp)
	
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
	return true

# Resets queued hits back to 1 for the next turn
func reset_turn_actions() -> void:
	queued_actions = 1
	actions_updated.emit(queued_actions)

# Helper to check if player is currently in BP debt
func is_in_debt() -> bool:
	return current_bp < 0
