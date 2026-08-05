extends Node2D

signal hp_changed(current_hp: int, max_hp: int)
signal boss_defeated

@export_group("Stats")
@export var boss_name: String = "Boss"
@export var max_hp: int = 1000
@export var defense: int = 10
@export var attack_power: int = 22

# --- AOE & CRIT STATS ---
@export var aoe_attack_power: int = 14                 # Slightly lower damage since it hits everyone
@export_range(0.0, 1.0) var aoe_chance: float = 0.3    # 30% chance to perform an AoE attack
@export_range(0.0, 1.0) var crit_chance: float = 0.25
@export var crit_multiplier: float = 1.5

@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var current_hp: int = max_hp

# Property alias so external scripts checking 'boss.hp' or 'boss.current_hp' both work!
var hp: int:
	get:
		return current_hp
	set(value):
		current_hp = value

var default_position: Vector2


func _ready() -> void:
	default_position = global_position
	current_hp = max_hp
	hp_changed.emit(current_hp, max_hp) # Notify UI immediately on start
	play_idle()


# --- STATS & DAMAGE LOGIC ---

func get_attack_damage(base_power: int) -> Dictionary:
	var is_crit: bool = randf() < crit_chance
	var final_damage: int = base_power
	
	if is_crit:
		final_damage = int(base_power * crit_multiplier)
		
	return {
		"damage": final_damage,
		"is_crit": is_crit
	}

func take_damage(amount: int) -> void:
	var actual_damage: int = max(1, amount - defense)
	current_hp = max(0, current_hp - actual_damage)
	
	print(boss_name, " took ", actual_damage, " damage! HP remaining: ", current_hp)
	
	hp_changed.emit(current_hp, max_hp)
	play_hurt()

	if current_hp <= 0:
		die()

func die() -> void:
	print(boss_name, " has been defeated!")
	boss_defeated.emit()


# --- MULTI-TARGET & AOE PARTY LOGIC ---

func choose_target(living_party: Array) -> Variant:
	if living_party.is_empty():
		return null
	return living_party.pick_random()

# Main turn sequence called by PartyBattleManager
func perform_turn(living_party: Array) -> Dictionary:
	if living_party.is_empty():
		return {}

	var is_aoe: bool = randf() < aoe_chance
	
	if is_aoe:
		# AoE Attack: Targets ALL living party members
		var attack_info = get_attack_damage(aoe_attack_power)
		await animate_attack_lunge(null) # Null target = mid-screen shake/pulse for AoE
		
		return {
			"is_aoe": true,
			"targets": living_party,  # Array of all alive heroes
			"damage": attack_info["damage"],
			"is_crit": attack_info["is_crit"]
		}
	else:
		# Single Target Attack
		var target = choose_target(living_party)
		var attack_info = get_attack_damage(attack_power)
		await animate_attack_lunge(target)
		
		return {
			"is_aoe": false,
			"targets": [target],     # Wrapped in an array for easy iteration in manager
			"damage": attack_info["damage"],
			"is_crit": attack_info["is_crit"]
		}


# --- TWEEN ANIMATIONS ---

func animate_attack_lunge(target: Variant) -> void:
	var tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var lunge_pos: Vector2
	
	if target and target.has("sprite") and is_instance_valid(target["sprite"]):
		# Step towards the specific hero sprite (left offset)
		lunge_pos = target["sprite"].global_position + Vector2(25, 0)
	else:
		# AoE lunge: Step slightly forward toward center field
		lunge_pos = default_position + Vector2(-30, 0)
		
	# 1. Dash Forward
	tween.tween_property(self, "global_position", lunge_pos, 0.2)
	await tween.finished
	
	# 2. Play Attack Sprite Animation
	play_attack()
	await get_tree().create_timer(0.3).timeout
	
	# 3. Return to Base Position
	var return_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	return_tween.tween_property(self, "global_position", default_position, 0.25)
	await return_tween.finished
	
	play_idle()


# --- ANIMATIONS ---

func play_idle() -> void:
	if anim_player and anim_player.has_animation("idle"):
		anim_player.play("idle")

func play_attack() -> void:
	if anim_player and anim_player.has_animation("attack"):
		anim_player.play("attack")
		anim_player.queue("idle")

func play_hurt() -> void:
	if anim_player and anim_player.has_animation("hurt"):
		anim_player.play("hurt")
		anim_player.queue("idle")

func play_and_wait(anim_name: String) -> void:
	if anim_player and anim_player.has_animation(anim_name):
		anim_player.play(anim_name)
		await anim_player.animation_finished
