extends Node2D

# --- NODE REFERENCES ---
@onready var player: AnimatedSprite2D = $ArenaWorld/Player
@onready var boss: Node2D = $ArenaWorld/Boss
@onready var action_menu: Control = $UILayer/ActionMenu
@onready var class_label: Label = $UILayer/ClassHUD/Label
@onready var dialogue_label: Label = $UILayer/DialogueBox/Label

@onready var attack_button: Button = $UILayer/ActionMenu/AttackButton
@onready var defend_button: Button = $UILayer/ActionMenu/DefendButton
@onready var skill_button: Button = $UILayer/ActionMenu/SkillButton

@onready var parry_bar: TextureProgressBar = $UILayer/ParryBar

@onready var hover_sound: AudioStreamPlayer = $HoverSound if has_node("HoverSound") else null
@onready var confirm_sound: AudioStreamPlayer = $ConfirmSound if has_node("ConfirmSound") else null

# --- CUSTOM MENU NAVIGATION ---
var menu_buttons: Array[Button] = []
var selected_index: int = 0

# --- MAGE SUB-MENU NAVIGATION ---
var is_in_spell_menu: bool = false
var selected_spell_index: int = 0
var spell_detonated_this_turn: bool = false

# --- TANK PARRY MINI-GAME VARIABLES ---
var is_parry_minigame_active: bool = false
var parry_value: float = 0.0
var parry_dir: float = 1.0
var parry_speed: float = 180.0
var parry_input_pressed: bool = false

# --- DIFFICULTY & STATS ---
var difficulty: Dictionary = {}
var max_hp: int = 100
var max_mp: int = 100
var current_hp: int = 100
var current_mp: int = 100
var attack_power: int = 10
var defense_power: int = 10
var speed: int = 10
var magic_power: int = 10

var is_defending: bool = false
var is_battle_over: bool = false

var class_stats: Dictionary = {
	"fighter": {
		"max_hp": 115,
		"attack": 20,
		"defense": 12,
		"speed": 14,
	},
	"mage": {
		"max_hp": 90,
		"max_mp": 100,
		"attack": 6,
		"defense": 8,
		"speed": 10,
		"magic": 22
	},
	"tank": {
		"max_hp": 140,
		"attack": 8,
		"defense": 16,
		"speed": 6,
	}
}


func _ready() -> void:
	MusicManager.stop_music()
	
	# Fetch current difficulty dictionary from Global
	difficulty = Global.get_active_difficulty()
	
	load_character_stats()
	
	menu_buttons = [attack_button, defend_button, skill_button]
	
	for btn in menu_buttons:
		btn.focus_mode = Control.FOCUS_NONE
		btn.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if boss.has_signal("boss_defeated"):
		boss.boss_defeated.connect(_on_boss_defeated)
	
	# Apply Hard Mode HP multiplier to Boss if Boss has max_hp
	if Global.is_hard_mode and boss.has_method("set_max_hp"):
		boss.set_max_hp(int(difficulty["boss_hp"]))
	
	if Global.selected_character.to_lower() == "fighter" and player.has_node("FighterBP"):
		var bp_system = player.get_node("FighterBP")
		bp_system.bp_changed.connect(_on_bp_changed)
		if bp_system.has_signal("stance_changed"):
			bp_system.stance_changed.connect(_on_stance_changed)
	
	if parry_bar:
		parry_bar.hide()

	setup_class_buttons()
	update_button_styles()
	start_player_turn()


func _process(delta: float) -> void:
	if is_parry_minigame_active and not parry_input_pressed and parry_bar:
		parry_value += parry_dir * parry_speed * delta
		
		if parry_value >= parry_bar.max_value:
			parry_value = parry_bar.max_value
			parry_dir = -1.0
		elif parry_value <= parry_bar.min_value:
			parry_value = parry_bar.min_value
			parry_dir = 1.0
			
		parry_bar.value = parry_value


func load_character_stats() -> void:
	var char_key = Global.selected_character.to_lower()
	
	if class_stats.has(char_key):
		var stats = class_stats[char_key]
		
		# Apply Hard Mode HP Multiplier
		var hp_mult: float = difficulty.get("hero_hp_mult", 1.0)
		max_hp = int(stats["max_hp"] * hp_mult)
		current_hp = max_hp
		
		max_mp = stats.get("max_mp", 0)
		current_mp = max_mp
		
		attack_power = stats.get("attack", 10)
		defense_power = stats.get("defense", 10)
		speed = stats.get("speed", 10)
		magic_power = stats.get("magic", 0)
		
		update_hp_ui()
		print("Loaded ", char_key.capitalize(), " | HP: ", max_hp, " (Mult: ", hp_mult, ")")


func update_hp_ui() -> void:
	var text = Global.selected_character.capitalize() + " - HP " + str(current_hp) + "/" + str(max_hp)
	
	if max_mp > 0:
		text += " | MP " + str(current_mp) + "/" + str(max_mp)
		
	class_label.text = text


func setup_class_buttons() -> void:
	match Global.selected_character.to_lower():
		"fighter":
			attack_button.text = "Attack"
			defend_button.text = "Default (+1 BP)"
			skill_button.text = "Brave (Extra Turn)"
		"mage":
			attack_button.text = "Staff Strike"
			defend_button.text = "Defend"
			skill_button.text = "Spells"
		"tank":
			var tank_node: TankParry = player.get_node("TankParry") if player.has_node("TankParry") else null
			if tank_node and tank_node.is_counter_primed:
				attack_button.text = "COUNTER STRIKE!"
			else:
				attack_button.text = "Attack"
			defend_button.text = "Iron Guard"
			skill_button.text = "Parry"


# --- DIALOGUE & BP / STANCE DISPLAY HELPERS ---

func _on_bp_changed(new_bp: int) -> void:
	_update_fighter_status_display(new_bp)


func _on_stance_changed(new_stance) -> void:
	if player.has_node("FighterBP"):
		var bp_system = player.get_node("FighterBP")
		
		match new_stance:
			bp_system.Stance.BERSERK:
				dialogue_label.text = "BERSERK STANCE! ATK UP / DEF DOWN!"
			bp_system.Stance.GUARD:
				dialogue_label.text = "GUARD STANCE! DEFENSIVE SHIELD ACTIVE!"
			bp_system.Stance.BALANCED:
				dialogue_label.text = "BALANCED STANCE RESTORED."


func _update_fighter_status_display(bp_value: int) -> void:
	var bp_text = "+" + str(bp_value) if bp_value > 0 else str(bp_value)
	var stance_text = "BALANCED"

	if player.has_node("FighterBP"):
		var bp_system = player.get_node("FighterBP")
		if bp_system.has_method("get") and bp_system.get("current_stance") != null:
			match bp_system.current_stance:
				bp_system.Stance.BERSERK:
					stance_text = "BERSERK"
				bp_system.Stance.GUARD:
					stance_text = "GUARD"
				bp_system.Stance.BALANCED:
					stance_text = "BALANCED"

	dialogue_label.text = "FIGHTER BP: " + bp_text + " | STANCE: " + stance_text


# --- INPUT HANDLING & STYLING ---

func _unhandled_input(event: InputEvent) -> void:
	if is_parry_minigame_active and event.is_action_pressed("confirm") and not parry_input_pressed:
		get_viewport().set_input_as_handled()
		parry_input_pressed = true
		return

	if not action_menu.visible or is_battle_over:
		return

	if event is InputEventJoypadMotion:
		return

	if is_in_spell_menu:
		if player.has_node("MageSpells"):
			var mage_node: MageSpells = player.get_node("MageSpells")
			var total_spells = mage_node.get_spell_count()

			if event.is_action_pressed("right") or event.is_action_pressed("down"):
				get_viewport().set_input_as_handled()
				selected_spell_index = (selected_spell_index + 1) % total_spells
				_on_button_hovered()
				update_spell_menu_display()

			elif event.is_action_pressed("left") or event.is_action_pressed("up"):
				get_viewport().set_input_as_handled()
				selected_spell_index = (selected_spell_index - 1 + total_spells) % total_spells
				_on_button_hovered()
				update_spell_menu_display()

			elif event.is_action_pressed("confirm"):
				get_viewport().set_input_as_handled()
				cast_selected_spell(mage_node.get_spell(selected_spell_index))

			elif event.is_action_pressed("cancel") or event.is_action_pressed("ui_cancel"):
				get_viewport().set_input_as_handled()
				exit_spell_menu()
		return

	if event.is_action_pressed("left"):
		get_viewport().set_input_as_handled()
		selected_index = (selected_index - 1 + menu_buttons.size()) % menu_buttons.size()
		update_button_styles()
		_on_button_hovered()

	elif event.is_action_pressed("right"):
		get_viewport().set_input_as_handled()
		selected_index = (selected_index + 1) % menu_buttons.size()
		update_button_styles()
		_on_button_hovered()

	elif event.is_action_pressed("confirm"):
		get_viewport().set_input_as_handled()
		trigger_selected_action()


func trigger_selected_action() -> void:
	match selected_index:
		0: _on_attack_button_pressed()
		1: _on_defend_button_pressed()
		2: _on_skill_button_pressed()


func update_button_styles() -> void:
	for i in range(menu_buttons.size()):
		var btn = menu_buttons[i]
		var stylebox = StyleBoxFlat.new()
		stylebox.bg_color = Color.BLACK
		stylebox.set_corner_radius_all(0)
		stylebox.set_border_width_all(2)

		if i == selected_index:
			match Global.selected_character.to_lower():
				"fighter": stylebox.border_color = Color("10b981")
				"mage":    stylebox.border_color = Color("8b5cf6")
				"tank":    stylebox.border_color = Color("0284c7")
				_:         stylebox.border_color = Color.WHITE
		else:
			stylebox.border_color = Color("555555")

		btn.add_theme_stylebox_override("normal", stylebox)
		btn.add_theme_stylebox_override("hover", stylebox)
		btn.add_theme_stylebox_override("focus", stylebox)
		btn.add_theme_stylebox_override("pressed", stylebox)


# --- MAGE SPELL SUB-MENU HELPERS ---

func open_spell_menu() -> void:
	is_in_spell_menu = true
	selected_spell_index = 0
	update_spell_menu_display()


func exit_spell_menu() -> void:
	is_in_spell_menu = false
	dialogue_label.text = "MAGE TURN!"


func update_spell_menu_display() -> void:
	if player.has_node("MageSpells"):
		var mage_node: MageSpells = player.get_node("MageSpells")
		var spell = mage_node.get_spell(selected_spell_index)
		var total = mage_node.get_spell_count()
		var mp_cost = spell.get("cost", 0)
		
		var status = ""
		if current_mp < mp_cost:
			status = " [NOT ENOUGH MP!]"
			
		var hp_cost_text = ""
		if Global.is_hard_mode:
			var hp_drain = mage_node.get_spell_hp_cost(max_hp, spell["name"])
			if hp_drain > 0:
				hp_cost_text = " (Drains " + str(hp_drain) + " HP)"
			elif spell["name"] == "Heal Bloom":
				hp_cost_text = " (HP Drain Exempt)"
		
		dialogue_label.text = "SPELL [" + str(selected_spell_index + 1) + "/" + str(total) + "]: " + spell["name"].to_upper() + status + hp_cost_text + "\n" + spell["desc"]


func cast_selected_spell(spell: Dictionary) -> void:
	var mp_cost = spell.get("cost", 0)
	
	if current_mp < mp_cost:
		dialogue_label.text = "NOT ENOUGH MANA!"
		is_in_spell_menu = true
		return
	
	_play_confirm_sound()
	is_in_spell_menu = false
	action_menu.hide()
	
	current_mp -= mp_cost
	
	# --- HARD MODE MAGE HP COST TWEAK ---
	var mage_node: MageSpells = player.get_node("MageSpells") if player.has_node("MageSpells") else null
	
	if Global.is_hard_mode and mage_node:
		var hp_drain = mage_node.get_spell_hp_cost(max_hp, spell["name"])
		if hp_drain > 0:
			current_hp = max(1, current_hp - hp_drain)
			dialogue_label.text = "OVERCHARGED CAST! (-" + str(hp_drain) + " HP)"
			await get_tree().create_timer(0.4).timeout

	update_hp_ui()

	# --- PLAY CAST ANIMATION ---
	# Checks for "mage_cast" first to match your SpriteFrames setup
	if player.sprite_frames and player.sprite_frames.has_animation("mage_cast"):
		player.play("mage_cast")
	elif player.has_method("play_cast"):
		player.play_cast()
	elif player.sprite_frames and player.sprite_frames.has_animation("cast"):
		player.play("cast")
	elif player.sprite_frames and player.sprite_frames.has_animation("mage_attack"):
		player.play("mage_attack")
	elif player.has_method("play_attack"):
		player.play_attack()

	# Wait until the cast animation completes playing all frames
	if player.is_playing():
		await player.animation_finished

	# --- EXECUTE SPELL EFFECT ---
	match spell["type"]:
		"instant_attack":
			var base_damage = int(magic_power * spell["power"])
			
			if spell_detonated_this_turn:
				base_damage = int(base_damage * 1.75)
				dialogue_label.text = "SPELL CHAIN! " + spell["name"].to_upper() + " AMPLIFIED!"
			else:
				dialogue_label.text = "CAST " + spell["name"].to_upper() + "!"
			
			if boss.has_method("take_damage"):
				boss.take_damage(base_damage)
			elif boss.has_method("play_hurt"):
				boss.play_hurt()
				
			await get_tree().create_timer(0.4).timeout

		"delayed_attack":
			if mage_node:
				var turns = mage_node.queue_delayed_spell(spell, magic_power)
				dialogue_label.text = "CAST " + spell["name"].to_upper() + "! (DETONATES IN " + str(turns) + " TURNS)"
			
			await get_tree().create_timer(0.5).timeout

		"heal":
			var heal_amount = int(magic_power * spell["power"])
			current_hp = min(current_hp + heal_amount, max_hp)
			update_hp_ui()
			dialogue_label.text = "HEAL BLOOM! RECOVERED " + str(heal_amount) + " HP!"
			await get_tree().create_timer(0.6).timeout

		"barrier":
			is_defending = true
			dialogue_label.text = "ARCANE BARRIER ERECTED! DAMAGE MITIGATED."
			await get_tree().create_timer(0.6).timeout

		"buff":
			if mage_node:
				mage_node.is_overcharged = true
			dialogue_label.text = "SPELL OVERCHARGE! NEXT DELAYED SPELL +50% POWER!"
			await get_tree().create_timer(0.6).timeout

	# --- RETURN TO IDLE ---
	if player.sprite_frames and player.sprite_frames.has_animation("mage_idle"):
		player.play("mage_idle")
	elif player.sprite_frames and player.sprite_frames.has_animation("idle"):
		player.play("idle")

	end_player_turn()


# --- TURN FLOW LOGIC ---

func start_player_turn() -> void:
	if is_battle_over:
		return

	is_defending = false
	spell_detonated_this_turn = false
	
	setup_class_buttons()
	
	if Global.selected_character.to_lower() == "fighter" and player.has_node("FighterBP"):
		var bp_system = player.get_node("FighterBP")
		if bp_system.is_in_debt():
			bp_system.current_bp += 1
			bp_system.bp_changed.emit(bp_system.current_bp)
			dialogue_label.text = "FIGHTER IS IN DEBT! RECOVERING BP..."
			end_player_turn()
			return
		else:
			_update_fighter_status_display(bp_system.current_bp)
			
	elif Global.selected_character.to_lower() == "mage" and player.has_node("MageSpells"):
		var regen_text = ""
		if current_mp < max_mp:
			var amount_gained = min(current_mp + 10, max_mp) - current_mp
			current_mp += amount_gained
			update_hp_ui()
			regen_text = " (+" + str(amount_gained) + " MP REGEN!)"
		
		var mage_node: MageSpells = player.get_node("MageSpells")
		var detonated_list = mage_node.process_turn_tick()
		
		if detonated_list.size() > 0:
			spell_detonated_this_turn = true
			for spell in detonated_list:
				dialogue_label.text = spell["name"].to_upper() + " DETONATES!"
				
				if boss.has_method("take_damage"):
					boss.take_damage(spell["damage"])
				elif boss.has_method("play_hurt"):
					boss.play_hurt()
					
				await get_tree().create_timer(0.6).timeout
				
				if is_battle_over:
					return
		
		dialogue_label.text = "MAGE TURN!" + regen_text
	else:
		dialogue_label.text = Global.selected_character.to_upper() + " TURN!"

	selected_index = 0
	update_button_styles()
	action_menu.show()


func end_player_turn() -> void:
	action_menu.hide()

	if is_battle_over:
		return

	if Global.selected_character.to_lower() == "fighter" and player.has_node("FighterBP"):
		var bp_system = player.get_node("FighterBP")
		bp_system.reset_turn_actions()

	start_boss_turn()


func start_boss_turn() -> void:
	if is_battle_over:
		return

	print("--- BOSS TURN STARTED ---")
	dialogue_label.text = "BOSS IS ATTACKING!"
	
	await get_tree().create_timer(0.6).timeout
	
	var attack_info = boss.get_attack_damage() if boss.has_method("get_attack_damage") else {"damage": 25, "is_crit": false}
	
	# Apply Hard Mode Boss Damage Multiplier
	var raw_boss_damage: int = int(attack_info["damage"] * difficulty.get("boss_damage_mult", 1.0))
	var is_crit: bool = attack_info["is_crit"]
	
	@warning_ignore("integer_division")
	var mitigated_damage: int = max(1, raw_boss_damage - int(defense_power / 2))

	var tank_node: TankParry = player.get_node("TankParry") if player.has_node("TankParry") else null

	if tank_node and tank_node.is_parry_active:
		if parry_bar:
			parry_bar.value = parry_bar.min_value
			parry_value = parry_bar.min_value
			parry_dir = 1.0
			parry_bar.show()

		parry_input_pressed = false
		dialogue_label.text = "GET READY..."
		
		await get_tree().create_timer(0.5).timeout
		
		# Apply Hard Mode Parry Bar Speed Boost
		var speed_mult = difficulty.get("parry_speed_mult", 1.0)
		parry_speed = randf_range(150.0, 240.0) * speed_mult

		is_parry_minigame_active = true
		dialogue_label.text = "TIME YOUR PARRY!"

		var timer = 0.0
		var max_parry_time = 1.8 / speed_mult
		
		while timer < max_parry_time and not parry_input_pressed:
			await get_tree().process_frame
			timer += get_process_delta_time()

		is_parry_minigame_active = false
		if parry_bar:
			parry_bar.hide()

		var center_target = (parry_bar.max_value - parry_bar.min_value) / 2.0 if parry_bar else 50.0
		var result = tank_node.evaluate_timing(parry_value, center_target, 10.0, 25.0)

		match result:
			TankParry.ParryResult.PERFECT:
				_play_confirm_sound()
				mitigated_damage = 0
				
				# --- HARD MODE TANK REFLECT TWEAK ---
				var reflect_pct = difficulty["hero_tweaks"]["tank_parry_reflect_percent"]
				if Global.is_hard_mode and reflect_pct > 0.0:
					var reflected_damage = int(raw_boss_damage * reflect_pct)
					dialogue_label.text = "PERFECT PARRY! REFLECTED " + str(reflected_damage) + " DAMAGE!"
					if boss.has_method("take_damage"):
						boss.take_damage(reflected_damage)
					elif boss.has_method("play_hurt"):
						boss.play_hurt()
				else:
					dialogue_label.text = "PERFECT PARRY! DAMAGE NEGATED!"

			TankParry.ParryResult.PARTIAL:
				mitigated_damage = max(1, int(mitigated_damage * 0.4))
				dialogue_label.text = "PARTIAL PARRY! " + ("CRIT REDUCED!" if is_crit else "DAMAGE REDUCED!")
			TankParry.ParryResult.MISS:
				mitigated_damage = raw_boss_damage
				dialogue_label.text = "PARRY MISSED! CRITICAL HIT!" if is_crit else "PARRY MISSED!"

		tank_node.reset_parry_stance()
		await get_tree().create_timer(0.8).timeout

	elif is_defending:
		mitigated_damage = max(1, int(mitigated_damage * 0.5))
		
	if Global.selected_character.to_lower() == "fighter" and player.has_node("FighterBP"):
		var bp_system = player.get_node("FighterBP")
		if bp_system.has_method("get") and bp_system.get("current_stance") != null:
			match bp_system.current_stance:
				bp_system.Stance.BERSERK:
					mitigated_damage = int(mitigated_damage * 1.25)
				bp_system.Stance.GUARD:
					mitigated_damage = int(mitigated_damage * 0.50)

	if boss.has_method("play_and_wait"):
		await boss.play_and_wait("attack")
	else:
		boss.play_attack()
		await get_tree().create_timer(0.4).timeout

	current_hp = max(0, current_hp - mitigated_damage)
	update_hp_ui()

	if player.has_method("take_damage"):
		player.take_damage(mitigated_damage)
	elif player.has_method("play_hurt"):
		player.play_hurt()

	if mitigated_damage > 0:
		if is_crit and not (tank_node and tank_node.is_parry_active):
			dialogue_label.text = "CRITICAL HIT! BOSS DEALT " + str(mitigated_damage) + " DAMAGE!"
		elif dialogue_label.text == "BOSS IS ATTACKING!" or is_defending:
			dialogue_label.text = "BOSS DEALT " + str(mitigated_damage) + " DAMAGE!"

	await get_tree().create_timer(0.8).timeout

	if current_hp <= 0:
		dialogue_label.text = "DEFEATED..."
		is_battle_over = true
		print("Player has been defeated!")
		
		await get_tree().create_timer(2.0).timeout
		get_tree().change_scene_to_file("res://Scenes/main_menu.tscn")
		return

	print("--- PLAYER TURN STARTED ---")
	start_player_turn()


# --- ACTION BUTTON ACTIONS ---

func _on_attack_button_pressed() -> void:
	_play_confirm_sound()
	action_menu.hide()

	# --- SPECIAL HEAVY TANK COUNTER STRIKE SEQUENCE ---
	var tank_node: TankParry = player.get_node("TankParry") if player.has_node("TankParry") else null
	if Global.selected_character.to_lower() == "tank" and tank_node and tank_node.is_counter_primed:
		var multiplier = tank_node.consume_counter_bonus()
		var counter_damage = int(attack_power * multiplier)
		
		dialogue_label.text = "DEVASTATING COUNTER STRIKE (" + str(counter_damage) + " DMG)!"

		var original_pos: Vector2 = player.position
		var windup_pos: Vector2 = original_pos + Vector2(-18, 0)
		var lunge_pos: Vector2 = original_pos + Vector2(55, 0)

		# 1. Wind-up pull back
		var windup_tween = create_tween()
		windup_tween.tween_property(player, "position", windup_pos, 0.10)\
			.set_trans(Tween.TRANS_QUAD)\
			.set_ease(Tween.EASE_OUT)
		await windup_tween.finished

		# 2. Switch to 1-frame Shield Bash pose & explosive forward thrust
		if player.sprite_frames and player.sprite_frames.has_animation("tank_bash"):
			player.play("tank_bash")
		elif player.sprite_frames and player.sprite_frames.has_animation("bash"):
			player.play("bash")

		var lunge_tween = create_tween()
		lunge_tween.tween_property(player, "position", lunge_pos, 0.08)\
			.set_trans(Tween.TRANS_EXPO)\
			.set_ease(Tween.EASE_IN)
		await lunge_tween.finished

		# 3. Apply heavy counter damage
		if boss.has_method("take_damage"):
			boss.take_damage(counter_damage)
		elif boss.has_method("play_hurt"):
			boss.play_hurt()

		# Brief freeze-frame pause at contact for physical weight
		await get_tree().create_timer(0.14).timeout

		# 4. Retract back to home position
		var return_tween = create_tween()
		return_tween.tween_property(player, "position", original_pos, 0.16)\
			.set_trans(Tween.TRANS_QUAD)\
			.set_ease(Tween.EASE_OUT)
		await return_tween.finished

		# Reset pose back to tank idle
		if player.sprite_frames and player.sprite_frames.has_animation("tank_idle"):
			player.play("tank_idle")
		elif player.sprite_frames and player.sprite_frames.has_animation("idle"):
			player.play("idle")

		attack_button.text = "Attack"
		end_player_turn()
		return

	# --- STANDARD ATTACK FLOW FOR OTHER CLASSES / REGULAR TANK HITS ---
	var attacks_to_run = 1

	if Global.selected_character.to_lower() == "fighter" and player.has_node("FighterBP"):
		var bp_system = player.get_node("FighterBP")
		attacks_to_run = bp_system.queued_actions

	var base_hit = attack_power
	dialogue_label.text = "ATTACKING (" + str(attacks_to_run) + "x)!"

	var original_pos: Vector2 = player.position
	var lunge_pos: Vector2 = original_pos + Vector2(40, 0)

	for i in range(attacks_to_run):
		var combo_multiplier: float = 1.0 + (i * 0.25)
		var hit_damage: int = int(base_hit * combo_multiplier)
		
		if Global.selected_character.to_lower() == "fighter" and player.has_node("FighterBP"):
			var bp_system = player.get_node("FighterBP")
			if bp_system.has_method("get") and bp_system.get("current_stance") != null:
				match bp_system.current_stance:
					bp_system.Stance.BERSERK:
						hit_damage = int(hit_damage * 1.5)

		# 1. Lunge forward toward boss
		var lunge_tween = create_tween()
		lunge_tween.tween_property(player, "position", lunge_pos, 0.15)\
			.set_trans(Tween.TRANS_QUAD)\
			.set_ease(Tween.EASE_OUT)

		# 2. Trigger attack animation
		if player.has_method("play_attack"):
			player.play_attack()
		elif player.sprite_frames and player.sprite_frames.has_animation("attack"):
			player.play("attack")

		# 3. Wait specifically for swing smear frame (Frame 1)
		if player.frame < 1 and player.is_playing():
			await player.frame_changed

		# 4. Apply damage at blade contact
		if boss.has_method("take_damage"):
			boss.take_damage(hit_damage)
		elif boss.has_method("play_hurt"):
			boss.play_hurt()

		await lunge_tween.finished
		await get_tree().create_timer(0.08).timeout

		# 5. Retract back to base position
		var return_tween = create_tween()
		return_tween.tween_property(player, "position", original_pos, 0.12)\
			.set_trans(Tween.TRANS_QUAD)\
			.set_ease(Tween.EASE_IN)
		
		await return_tween.finished

		if player.sprite_frames and player.sprite_frames.has_animation("idle"):
			player.play("idle")

		if is_battle_over:
			return

	attack_button.text = "Attack"
	end_player_turn()


func _on_defend_button_pressed() -> void:
	_play_confirm_sound()
	action_menu.hide()
	is_defending = true

	match Global.selected_character.to_lower():
		"fighter":
			if player.has_node("FighterBP"):
				var bp_system = player.get_node("FighterBP")
				var old_stance = bp_system.current_stance
				bp_system.perform_default()
				
				if old_stance == bp_system.current_stance:
					_update_fighter_status_display(bp_system.current_bp)
		"mage":
			var regen = 15
			current_mp = min(current_mp + regen, max_mp)
			update_hp_ui()
			dialogue_label.text = "MAGE GUARDS AND RECOVERS +" + str(regen) + " MP!"
		"tank":
			dialogue_label.text = "IRON GUARD! TANK FORTIFIES DEFENSES."

	end_player_turn()


func _on_skill_button_pressed() -> void:
	_play_confirm_sound()
	match Global.selected_character.to_lower():
		"fighter":
			if player.has_node("FighterBP"):
				var bp_system = player.get_node("FighterBP")
				var old_stance = bp_system.current_stance
				if bp_system.try_brave():
					attack_button.text = "Attack (" + str(bp_system.queued_actions) + "x)"
					
					if old_stance == bp_system.current_stance:
						_update_fighter_status_display(bp_system.current_bp)
				else:
					dialogue_label.text = "CANNOT BRAVE! Limit Reached."

		"mage":
			open_spell_menu()

		"tank":
			action_menu.hide()
			if player.has_node("TankParry"):
				var tank_node: TankParry = player.get_node("TankParry")
				tank_node.prime_parry_stance()
			dialogue_label.text = "TANK RAISES SHIELD! READY TO PARRY..."
			await get_tree().create_timer(0.6).timeout
			end_player_turn()


# --- VICTORY HANDLER ---

func _on_boss_defeated() -> void:
	is_battle_over = true
	action_menu.hide()
	if parry_bar:
		parry_bar.hide()
		
	# --- RECORD VICTORY ---
	SaveManager.record_victory(Global.selected_character)
	
	dialogue_label.text = "VICTORY! YOU DEFEATED THE BOSS!"
	print("BATTLE WON! Victory saved for: ", Global.selected_character)
	
	await get_tree().create_timer(2.5).timeout
	get_tree().change_scene_to_file("res://Scenes/main_menu.tscn")


# --- AUDIO HELPER METHODS ---

func _on_button_hovered() -> void:
	if hover_sound:
		hover_sound.play()


func _play_confirm_sound() -> void:
	if confirm_sound:
		confirm_sound.play()
