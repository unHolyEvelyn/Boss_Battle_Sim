extends Node2D

signal hp_changed(current_hp: int, max_hp: int)
signal boss_defeated

@export_group("Stats")
@export var boss_name: String = "Boss"
@export var max_hp: int = 300
@export var defense: int = 5
@export var attack_power: int = 15

# --- CRITICAL HIT STATS ---
@export_range(0.0, 1.0) var crit_chance: float = 0.2  # 20% Chance to Crit
@export var crit_multiplier: float = 1.5                # 1.5x Damage on Crit

@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var current_hp: int = max_hp


func _ready() -> void:
	current_hp = max_hp
	# Automatically start the looping idle stance when the battle loads
	play_idle()


# --- STATS & DAMAGE LOGIC ---

func get_attack_damage() -> Dictionary:
	var is_crit: bool = randf() < crit_chance
	var final_damage: int = attack_power
	
	if is_crit:
		final_damage = int(attack_power * crit_multiplier)
		
	return {
		"damage": final_damage,
		"is_crit": is_crit
	}

func take_damage(amount: int) -> void:
	# Factor in defense (minimum 1 damage taken)
	var actual_damage: int = max(1, amount - defense)
	current_hp -= actual_damage
	
	print(boss_name, " took ", actual_damage, " damage! HP remaining: ", current_hp)
	
	hp_changed.emit(current_hp, max_hp)
	play_hurt()

	if current_hp <= 0:
		die()

func die() -> void:
	print(boss_name, " has been defeated!")
	boss_defeated.emit()


# --- ANIMATIONS ---

# Play looping idle animation
func play_idle() -> void:
	if anim_player.has_animation("idle"):
		anim_player.play("idle")

# Play attack animation and automatically queue back to idle when finished
func play_attack() -> void:
	if anim_player.has_animation("attack"):
		anim_player.play("attack")
		anim_player.queue("idle")

# Play hit/hurt animation when damaged
func play_hurt() -> void:
	if anim_player.has_animation("hurt"):
		anim_player.play("hurt")
		anim_player.queue("idle")

# Asynchronous helper to wait for a specific animation to finish during battle turns
func play_and_wait(anim_name: String) -> void:
	if anim_player.has_animation(anim_name):
		anim_player.play(anim_name)
		await anim_player.animation_finished
