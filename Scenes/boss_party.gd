extends Node2D

signal hp_changed(current_hp: int, max_hp: int)
signal boss_defeated

@export_group("Stats")
@export var boss_name: String = "Boss"
@export var max_hp: int = 1000 # Back to 1000 HP
@export var defense: int = 8 # Baseline party defense
@export var attack_power: int = 38 # Hits hard enough to require Mage healing

# --- PARTY MULTIPLIERS (Does not affect Solo Mode) ---
@export_group("Party Type Modifiers")
@export var physical_damage_multiplier: float = 1.4 # Boosts Fighter/Physical damage by +40%

# --- AOE & CRIT STATS ---
@export_group("Combat Behavior")
@export var aoe_attack_power: int = 26 # Spams group damage forcing healing
@export_range(0.0, 1.0) var aoe_chance: float = 0.45
@export_range(0.0, 1.0) var crit_chance: float = 0.25
@export var crit_multiplier: float = 1.5

# --- GHOST TRAIL SETTINGS ---
@export_group("Visual FX")
@export var ghost_spawn_interval: float = 0.1
var is_spawning_ghosts: bool = true

# --- FLOATING SINE SETTINGS ---
@export var float_distance: float = 8.0
@export var float_duration: float = 1.2
var float_tween: Tween

@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var current_hp: int = max_hp

var hp: int:
	get:
		return current_hp
	set(value):
		current_hp = value

var default_position: Vector2


func _ready() -> void:
	default_position = global_position
	current_hp = max_hp
	hp_changed.emit(current_hp, max_hp)
	play_idle()
	
	_start_continuous_ghost_trail()
	_start_floating_animation()


# --- SINE OSCILLATION FLOATING TWEEN ---

func _start_floating_animation() -> void:
	if not has_node("BossPuppet"):
		return
		
	var puppet = $BossPuppet
	
	float_tween = create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	float_tween.tween_property(puppet, "position:y", -float_distance, float_duration)
	float_tween.tween_property(puppet, "position:y", float_distance, float_duration)


# --- CONTINUOUS GHOST TRAIL LOOP ---

func _start_continuous_ghost_trail() -> void:
	while is_spawning_ghosts and is_inside_tree():
		_create_single_ghost()
		await get_tree().create_timer(ghost_spawn_interval).timeout


func _create_single_ghost() -> void:
	if not has_node("BossPuppet"): 
		return
		
	var puppet = $BossPuppet
	
	var ghost = puppet.duplicate() as CanvasGroup
	ghost.set_script(preload("res://Scripts/boss_ghost.gd"))
	ghost.z_index = z_index - 1
	ghost.global_position = puppet.global_position
	ghost.scale = puppet.scale
	ghost.modulate = Color(0.9, 0.1, 0.2, 0.75)
	
	get_parent().add_child(ghost)


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

# OPTION 2 INTEGRATED:
# Set `is_physical` to true by default, or pass false for Mage spell attacks!
func take_damage(amount: int, is_physical: bool = true) -> void:
	var calculated_amount: float = float(amount)
	
	if is_physical:
		calculated_amount *= physical_damage_multiplier
		
	var actual_damage: int = max(1, int(calculated_amount) - defense)
	current_hp = max(0, current_hp - actual_damage)
	
	hp_changed.emit(current_hp, max_hp)
	play_hurt()

	if current_hp <= 0:
		is_spawning_ghosts = false
		if float_tween and float_tween.is_valid():
			float_tween.kill()
		die()

func die() -> void:
	boss_defeated.emit()


# --- TURN DECISION ENGINE ---

func choose_target(living_party: Array) -> Variant:
	if living_party.is_empty():
		return null
	return living_party.pick_random()

func perform_turn(living_party: Array) -> Dictionary:
	if living_party.is_empty():
		return {}

	var is_aoe: bool = randf() < aoe_chance
	
	if is_aoe:
		var attack_info = get_attack_damage(aoe_attack_power)
		await animate_attack_lunge(null)
		
		return {
			"is_aoe": true,
			"targets": living_party,
			"damage": attack_info["damage"],
			"is_crit": attack_info["is_crit"]
		}
	else:
		var target = choose_target(living_party)
		var attack_info = get_attack_damage(attack_power)
		await animate_attack_lunge(target)
		
		return {
			"is_aoe": false,
			"targets": [target],
			"damage": attack_info["damage"],
			"is_crit": attack_info["is_crit"]
		}


# --- ATTACK ANIMATION TWEEN ---

func animate_attack_lunge(target: Variant) -> void:
	var tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var lunge_pos: Vector2 = default_position + Vector2(-60, 0)
	
	tween.tween_property(self, "global_position", lunge_pos, 0.18)
	await tween.finished
	
	play_attack()
	await get_tree().create_timer(0.3).timeout
	
	var return_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	return_tween.tween_property(self, "global_position", default_position, 0.22)
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
